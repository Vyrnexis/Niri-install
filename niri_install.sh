#!/usr/bin/env bash

# Bootstrap a complete Dracula-themed Niri desktop on a minimal Arch install.
# Install official packages first, then AUR packages, configs, and services.

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

readonly PURPLE=$'\033[95m'
readonly GREEN=$'\033[32m'
readonly YELLOW=$'\033[33m'
readonly RED=$'\033[31m'
readonly NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
readonly RUN_STAMP
readonly BACKUP_ROOT="$HOME/.local/state/niri-install/backups/$RUN_STAMP"
BUILD_DIR=""
ASSUME_YES="${ASSUME_YES:-0}"
INSTALL_NYMPH="${INSTALL_NYMPH:-1}"
CHANGE_SHELL="${CHANGE_SHELL:-1}"

readonly -a PACMAN_SETS=(
  "packages/core.txt|Core Niri workstation packages|required"
  "packages/extras.txt|Optional utilities and diagnostics|optional"
)

readonly -a PARU_SETS=(
  "packages/aur.txt|AUR applications and Dracula themes|required"
)

# Print an informational installer message.
log_info() { printf '%b[INFO]%b %s\n' "$PURPLE" "$NC" "$1"; }

# Print a successful operation message.
log_ok() { printf '%b[OK]%b %s\n' "$GREEN" "$NC" "$1"; }

# Print a non-fatal warning message.
log_warn() { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; }

# Print an error message to standard error.
log_err() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1" >&2; }

# Display the installer name without clearing terminal history.
show_banner() {
  printf '%bNiri Desktop Installer%b\n' "$PURPLE" "$NC"
}

# Print supported command-line options.
show_help() {
  cat <<'EOF'
Usage: ./niri_install.sh [options]

Options:
  -y, --yes              Accept installer and package-manager prompts
      --no-nymph         Skip the optional Nymph system-summary binary
      --no-shell-change  Keep the current login shell
  -h, --help             Show this help text

Environment equivalents:
  ASSUME_YES=1 INSTALL_NYMPH=0 CHANGE_SHELL=0
EOF
}

# Parse installer flags and reject unknown arguments.
parse_args() {
  while (($#)); do
    case "$1" in
      -y|--yes) ASSUME_YES=1 ;;
      --no-nymph) INSTALL_NYMPH=0 ;;
      --no-shell-change) CHANGE_SHELL=0 ;;
      -h|--help) show_help; exit 0 ;;
      *) log_err "Unknown option: $1"; show_help >&2; exit 2 ;;
    esac
    shift
  done
}

# Remove only the installer-owned temporary build directory.
cleanup() {
  if [[ -n $BUILD_DIR && $BUILD_DIR == "$SCRIPT_DIR/.build/"* ]]; then
    rm -rf -- "$BUILD_DIR"
  fi
}

# Report the command and line that caused an unexpected failure.
report_error() {
  local exit_code="$1" line="$2" command="$3"
  log_err "Command failed with status $exit_code at line $line: $command"
}

# Verify the host, privileges, connectivity tools, and repository layout.
require_environment() {
  if [[ $EUID -eq 0 ]]; then
    log_err "Run as a regular user with sudo access, not root."
    exit 1
  fi
  if [[ ! -r /etc/arch-release ]] || ! command -v pacman >/dev/null 2>&1; then
    log_err "This installer supports Arch Linux only."
    exit 1
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    log_err "sudo is required."
    exit 1
  fi

  local required_path
  for required_path in \
    .config .config/paru/paru.conf .local \
    packages/core.txt packages/extras.txt packages/aur.txt; do
    if [[ ! -e "$SCRIPT_DIR/$required_path" ]]; then
      log_err "Required repository path is missing: $required_path"
      exit 1
    fi
  done

  local duplicates
  duplicates="$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' \
    "$SCRIPT_DIR/packages/core.txt" "$SCRIPT_DIR/packages/extras.txt" \
    "$SCRIPT_DIR/packages/aur.txt" | sort | uniq -d)"
  if [[ -n $duplicates ]]; then
    log_err "Duplicate official packages found: ${duplicates//$'\n'/, }"
    exit 1
  fi
}

# Ask once before applying system and home-directory changes.
confirm_run() {
  if [[ $ASSUME_YES == 1 ]]; then
    log_warn "Automatic confirmation enabled."
    return
  fi
  if [[ ! -t 0 ]]; then
    log_err "Non-interactive use requires --yes or ASSUME_YES=1."
    exit 1
  fi

  local reply
  read -r -p "Install and configure the complete Niri desktop? [Y/n]: " reply || exit 1
  case "$reply" in
    ""|[Yy]*) ;;
    [Nn]*) log_warn "Installation cancelled."; exit 0 ;;
    *) log_err "Please answer y or n."; exit 2 ;;
  esac
}

# Create a workspace-local directory for temporary build artifacts.
prepare_build_dir() {
  mkdir -p "$SCRIPT_DIR/.build"
  BUILD_DIR="$(mktemp -d "$SCRIPT_DIR/.build/run.XXXXXX")"
  trap cleanup EXIT
  trap 'report_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
}

# Read package names while ignoring comments and blank lines.
read_pkg_file() {
  local file="$1"
  if [[ ! -f $file ]]; then
    log_err "Package list not found: $file"
    return 1
  fi
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    -e '/^$/d' "$file"
}

# Install one validated package set with pacman or paru.
install_pkg_set() {
  local manager="$1" file="$2" label="$3" importance="$4"
  local -a packages=() available=() unavailable=() command_args=()
  local package
  mapfile -t packages < <(read_pkg_file "$file")

  for package in "${packages[@]}"; do
    if "$manager" -Si "$package" >/dev/null 2>&1; then
      available+=("$package")
    else
      unavailable+=("$package")
    fi
  done

  if ((${#unavailable[@]})); then
    if [[ $importance == required ]]; then
      log_err "Unavailable required packages from $file: ${unavailable[*]}"
      return 1
    fi
    log_warn "Skipping unavailable optional packages: ${unavailable[*]}"
  fi
  ((${#available[@]})) || return 0

  log_info "$label"
  command_args=(-S --needed)
  [[ $ASSUME_YES == 1 ]] && command_args+=(--noconfirm)
  if [[ $manager == pacman ]]; then
    sudo pacman "${command_args[@]}" "${available[@]}"
  else
    paru "${command_args[@]}" "${available[@]}"
  fi
}

# Install explicit system packages with consistent confirmation behavior.
install_system_packages() {
  local -a command_args=(-S --needed)
  [[ $ASSUME_YES == 1 ]] && command_args+=(--noconfirm)
  sudo pacman "${command_args[@]}" "$@"
}

# Install each package set described by a manager-specific manifest.
install_pkg_sets() {
  local manager="$1"
  shift
  local entry file label importance
  for entry in "$@"; do
    IFS='|' read -r file label importance <<< "$entry"
    install_pkg_set "$manager" "$SCRIPT_DIR/$file" "$label" "$importance"
  done
}

# Ensure a working Rust toolchain is available before building paru.
configure_rust_toolchain() {
  if command -v rustup >/dev/null 2>&1; then
    local configured_toolchains
    configured_toolchains="$(rustup toolchain list)"
    if [[ $configured_toolchains != *"(default)"* ]]; then
      log_info "Installing the stable Rust toolchain"
      rustup default stable
    fi
  elif command -v cargo >/dev/null 2>&1 && cargo --version >/dev/null 2>&1; then
    return
  else
    log_info "Installing Rustup for the paru build"
    install_system_packages rustup
    rustup default stable
  fi
  cargo --version >/dev/null 2>&1 || {
    log_err "cargo is unavailable after configuring Rustup."
    return 1
  }
}

# Build paru from its reviewed AUR package when it is not already installed.
install_paru() {
  if command -v paru >/dev/null 2>&1; then
    log_info "paru is already installed."
    return
  fi

  configure_rust_toolchain
  local source_dir="$BUILD_DIR/paru"
  log_info "Building paru from the AUR"
  git clone --depth 1 https://aur.archlinux.org/paru.git "$source_dir"
  if [[ $ASSUME_YES == 1 ]]; then
    (cd "$source_dir" && makepkg -si --needed --noconfirm)
  else
    (cd "$source_dir" && makepkg -si --needed)
  fi
  command -v paru >/dev/null 2>&1 || {
    log_err "paru was not installed successfully."
    return 1
  }
}

# Back up and deploy Paru settings before the first AUR package operation.
install_paru_config() {
  local source="$SCRIPT_DIR/.config/paru/paru.conf"
  local target="$HOME/.config/paru/paru.conf"

  log_info "Installing Paru configuration"
  backup_user_file "$target"
  install -Dm644 "$source" "$target"
}

# Download Nymph and verify its Git blob identity before installation.
install_nymph() {
  [[ $INSTALL_NYMPH == 1 ]] || {
    log_info "Skipping Nymph by request."
    return
  }

  local api_url="https://api.github.com/repos/Vyrnexis/Nymph/contents/bin/nymph"
  local metadata download_url expected_sha binary actual_sha
  metadata="$(curl -fsSL --retry 3 --connect-timeout 10 "$api_url")" || {
    log_warn "Could not retrieve Nymph metadata; continuing without it."
    return
  }
  download_url="$(jq -r '.download_url // empty' <<< "$metadata")"
  expected_sha="$(jq -r '.sha // empty' <<< "$metadata")"
  binary="$BUILD_DIR/nymph"

  if [[ -z $download_url || -z $expected_sha ]] || \
     ! curl -fsSL --retry 3 --connect-timeout 10 "$download_url" -o "$binary"; then
    log_warn "Could not download Nymph; continuing without it."
    return
  fi
  actual_sha="$(git hash-object "$binary")"
  if [[ $actual_sha != "$expected_sha" ]]; then
    log_warn "Nymph integrity verification failed; continuing without it."
    return
  fi

  install -Dm755 "$binary" "$HOME/.local/bin/nymph"
  log_ok "Installed verified Nymph binary."
}

# Apply GTK, icon, cursor, color-scheme, and font preferences.
apply_theme() {
  if ! command -v gsettings >/dev/null 2>&1; then
    log_warn "gsettings is unavailable; static GTK settings remain installed."
    return
  fi

  local -a settings=(
    "org.gnome.desktop.interface|gtk-theme|Ant-Dracula"
    "org.gnome.desktop.interface|icon-theme|Dracula"
    "org.gnome.desktop.interface|cursor-theme|Dracula-cursors"
    "org.gnome.desktop.interface|color-scheme|prefer-dark"
    "org.gnome.desktop.interface|font-name|JetBrainsMono Nerd Font 11"
  )
  local setting schema key value
  for setting in "${settings[@]}"; do
    IFS='|' read -r schema key value <<< "$setting"
    if ! gsettings set "$schema" "$key" "$value" 2>/dev/null; then
      dbus-run-session -- gsettings set "$schema" "$key" "$value" || \
        log_warn "Could not set $schema $key."
    fi
  done
}

# Back up and deploy repository-owned user configuration files.
sync_configs() {
  log_info "Installing user configuration"
  mkdir -p "$HOME/.config" "$HOME/.local/share" "$BACKUP_ROOT"

  local legacy_environment="$HOME/.config/environment.d/10-dracula.conf"
  if [[ -f $legacy_environment ]]; then
    mkdir -p "$BACKUP_ROOT/environment.d"
    mv "$legacy_environment" "$BACKUP_ROOT/environment.d/10-dracula.conf"
    log_info "Retired the legacy forced-Wayland environment file."
  fi

  rsync -a --backup --backup-dir="$BACKUP_ROOT/config" \
    --exclude '.gitkeep' "$SCRIPT_DIR/.config/" "$HOME/.config/"
  rsync -a --backup --backup-dir="$BACKUP_ROOT/local-share" \
    "$SCRIPT_DIR/.local/share/" "$HOME/.local/share/"
  rsync -a --backup --backup-dir="$BACKUP_ROOT/local-bin" \
    "$SCRIPT_DIR/.local/bin/" "$HOME/.local/bin/"

  if [[ -f $HOME/.config/gtklock/config.ini ]]; then
    sed -i "s|^style=.*|style=$HOME/.config/gtklock/style.css|" \
      "$HOME/.config/gtklock/config.ini"
  fi

  mkdir -p "$HOME/.icons/default"
  backup_user_file "$HOME/.icons/default/index.theme"
  install -Dm644 /dev/stdin "$HOME/.icons/default/index.theme" <<'EOF'
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=Dracula-cursors
EOF

  if [[ -d $HOME/.config/waybar/scripts ]]; then
    chmod +x "$HOME/.config/waybar/scripts/"*
  fi
  if [[ -d $HOME/.config/nimlaunch/scripts ]]; then
    chmod +x "$HOME/.config/nimlaunch/scripts/"*.sh
  fi
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/mpd/playlists"
  chmod +x "$HOME/.local/bin/helix-cheatsheet" "$HOME/.local/bin/kitty-cheatsheet"
  xdg-user-dirs-update
  mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Music" "$HOME/Projects"
  apply_theme

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" || true
  fi
}

# Back up a user file before the installer appends managed content.
backup_user_file() {
  local target="$1"
  [[ -e $target ]] || return 0
  local relative="${target#"$HOME"/}"
  mkdir -p "$BACKUP_ROOT/$(dirname "$relative")"
  cp -aL "$target" "$BACKUP_ROOT/$relative"
}

# Set Fish as the login shell unless the user opted out.
set_default_shell() {
  [[ $CHANGE_SHELL == 1 ]] || {
    log_info "Keeping the current login shell by request."
    return
  }
  local fish_path current_shell
  fish_path="$(command -v fish)"
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ $current_shell == "$fish_path" ]]; then
    log_info "Fish is already the login shell."
  elif ! sudo chsh -s "$fish_path" "$USER"; then
    log_warn "Could not change the login shell; run: sudo chsh -s $fish_path $USER"
  fi
}

# Install a modern tuigreet command unless another display manager owns the alias.
configure_greetd() {
  local display_manager="/etc/systemd/system/display-manager.service"
  local current_target=""
  if [[ -L $display_manager ]]; then
    current_target="$(readlink -f "$display_manager")"
  fi
  if [[ -n $current_target && $current_target != */greetd.service ]]; then
    log_warn "Another display manager is enabled: $current_target"
    log_warn "Niri is installed as a selectable session; greetd was not enabled."
    return
  fi

  log_info "Configuring greetd with niri-session"
  if sudo test -f /etc/greetd/config.toml; then
    sudo cp -a /etc/greetd/config.toml \
      "/etc/greetd/config.toml.pre-niri-install.$RUN_STAMP"
  fi
  sudo install -d -m 755 /etc/greetd
  sudo install -Dm644 /dev/stdin /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --user-menu --cmd niri-session"
user = "greeter"
EOF
  sudo systemctl enable greetd.service
}

# Enable system services needed for networking, hardware, and desktop integration.
enable_services() {
  log_info "Enabling system services"
  sudo systemctl enable --now NetworkManager.service
  sudo systemctl enable --now bluetooth.service
  sudo systemctl enable --now avahi-daemon.service
  sudo systemctl enable --now cups.socket
  sudo systemctl enable --now power-profiles-daemon.service
  sudo systemctl enable --now fstrim.timer

  if systemctl cat fwupd-refresh.timer >/dev/null 2>&1; then
    sudo systemctl enable --now fwupd-refresh.timer
  fi

  if systemctl --user list-unit-files >/dev/null 2>&1; then
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket
    systemctl --user enable --now wireplumber.service
    systemctl --user enable --now mpd.service || \
      log_warn "Could not enable the optional MPD user service."
  else
    log_warn "No systemd user session is available; user services will start after login."
  fi
}

# Install the CPU vendor's microcode package for early firmware updates.
configure_microcode() {
  local vendor
  vendor="$(awk -F: '/vendor_id/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' /proc/cpuinfo)"
  case "$vendor" in
    GenuineIntel) install_system_packages intel-ucode ;;
    AuthenticAMD) install_system_packages amd-ucode ;;
    *) log_warn "Could not identify an Intel or AMD CPU for microcode installation." ;;
  esac
}

# Grant the video-group access used by brightness-control udev rules.
ensure_user_groups() {
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx video; then
    sudo usermod -aG video "$USER"
    log_warn "Added $USER to video; the membership takes effect after login."
  fi
}

# Install and enable guest helpers for the detected virtualization platform.
configure_virtualization() {
  local virt
  virt="$(systemd-detect-virt 2>/dev/null || printf 'unknown')"
  case "$virt" in
    oracle)
      install_system_packages virtualbox-guest-utils
      sudo systemctl enable --now vboxservice.service
      ;;
    vmware)
      install_system_packages open-vm-tools
      sudo systemctl enable --now vmtoolsd.service
      ;;
    qemu|kvm)
      install_system_packages qemu-guest-agent spice-vdagent
      sudo systemctl enable --now qemu-guest-agent.service spice-vdagentd.service
      ;;
    none) log_info "Bare-metal system detected." ;;
    *) log_info "No supported virtual-machine guest integration detected." ;;
  esac
}

# Print the installed experience and the only required follow-up action.
final_summary() {
  show_banner
  log_ok "Niri desktop installation is complete."
  cat <<EOF

- Official Niri session with XWayland and GNOME/GTK desktop portals
- Waybar, Mako, SwayOSD, gtklock, idle handling, and clipboard history
- NimLaunch with Niri window, audio, network, Bluetooth, and screenshot tools
- PipeWire/WirePlumber audio, Bluetooth, NetworkManager, and power profiles
- Fish as the default interactive shell with a native Dracula prompt
- Thunar, Superfile, Kitty, Firefox, Brave when available, media tools, fonts, and themes
- Existing configuration replacements backed up under:
  $BACKUP_ROOT

Reboot, then select Niri in tuigreet. Use Super+Shift+/ for the keybinding overlay.
EOF
}

# Run the full installation in dependency order.
main() {
  parse_args "$@"
  show_banner
  require_environment
  confirm_run
  sudo -v
  prepare_build_dir

  log_info "Updating the complete Arch system"
  if [[ $ASSUME_YES == 1 ]]; then
    sudo pacman -Syu --noconfirm
  else
    sudo pacman -Syu
  fi

  install_pkg_sets pacman "${PACMAN_SETS[@]}"
  configure_microcode
  install_paru
  install_paru_config
  install_pkg_sets paru "${PARU_SETS[@]}"
  install_nymph
  configure_virtualization
  sync_configs
  configure_greetd
  enable_services
  ensure_user_groups

  log_info "Refreshing the font cache"
  fc-cache -f
  set_default_shell
  final_summary
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
