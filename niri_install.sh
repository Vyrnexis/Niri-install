#!/bin/bash

# Automated Niri desktop bootstrapper for minimal Arch installs.
# Lays down required packages, theming, and user configuration.

set -euo pipefail
IFS=$'\n\t'

# --- palette (16-color friendly) ------------------------------------------
PURPLE=$'\033[95m'   # bright magenta
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TARGET_BASHRC="$HOME/.bashrc"
readonly REPO_BASHRC="$SCRIPT_DIR/.bashrc"
readonly TARGET_ZSHRC="$HOME/.zshrc"
readonly REPO_ZSHRC="$SCRIPT_DIR/.zshrc"

PACMAN_SETS=(
  "packages/pacman-core.txt|Core system packages|required"
  "packages/pacman-desktop.txt|Desktop environment packages|required"
  "packages/pacman-audio.txt|PipeWire audio stack|required"
  "packages/pacman-fonts.txt|Font packages|required"
  "packages/pacman-extras.txt|CLI utilities and extras|optional"
)

PARU_SETS=(
  "packages/paru-apps.txt|AUR applications|optional"
  "packages/paru-themes.txt|AUR theming packages|required"
)

# --- logging helpers ------------------------------------------------------
log_info()   { printf '%b[INFO]%b %s\n'    "${PURPLE}" "${NC}" "$1"; }
log_ok()     { printf '%b[SUCCESS]%b %s\n' "${GREEN}"  "${NC}" "$1"; }
log_warn()   { printf '%b[WARNING]%b %s\n' "${YELLOW}" "${NC}" "$1"; }
log_err()    { printf '%b[ERROR]%b %s\n'   "${RED}"    "${NC}" "$1"; }

show_banner() {
  if command -v clear >/dev/null 2>&1; then
    clear
  else
    printf '\033c'
  fi
  local -r banner="$(cat <<'EOF'
███╗   ██╗██╗██████╗ ██╗      ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
████╗  ██║██║██╔══██╗██║      ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
██╔██╗ ██║██║██████╔╝██║█████╗██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
██║╚██╗██║██║██╔══██╗██║╚════╝██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
██║ ╚████║██║██║  ██║██║      ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝      ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
EOF
)"
  printf '%b%s%b\n' "${PURPLE}" "$banner" "${NC}"
}

# --- sanity checks --------------------------------------------------------
require_environment() {
  if [[ $EUID -eq 0 ]]; then
    log_err "Run as a regular user with sudo access, not root."
    exit 1
  fi
  if ! command -v pacman >/dev/null 2>&1; then
    log_err "pacman not found. This script targets Arch Linux."
    exit 1
  fi
}

confirm_run() {
  if [[ ! -t 0 ]]; then
    if [[ ${ASSUME_YES:-0} == 1 ]]; then
      log_warn "Non-interactive session with ASSUME_YES=1; continuing without prompt."
      return
    fi
    log_err "Non-interactive session. Re-run with ASSUME_YES=1 to allow upgrades."
    exit 1
  fi

  while true; do
    read -r -p "Proceed with Niri installation? [Y/n]: " reply || {
      log_warn "No input received; aborting."
      exit 0
    }
    case ${reply} in
      [Yy]*|"") return ;;
      [Nn]*) log_warn "Installation cancelled."; exit 0 ;;
      *) log_warn "Please answer y or n." ;;
    esac
  done
}

# --- package helpers ------------------------------------------------------
read_pkg_file() {
  local file="$1"
  if [[ ! -f $file ]]; then
    log_err "Package list '$file' not found."
    exit 1
  fi
  sed -e 's/#.*//' -e 's/^[ \t]*//' -e 's/[ \t]*$//' "$file" | awk 'NF'
}

install_pkg_set() {
  local manager="$1" file="$2" label="$3" required="${4:-optional}"
  local pkgs
  mapfile -t pkgs < <(read_pkg_file "$file")
  if ((${#pkgs[@]} == 0)); then
    log_warn "No packages defined in $file; skipping."
    return
  fi
  local available=() missing=() pkg
  for pkg in "${pkgs[@]}"; do
    if "$manager" -Si "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      missing+=("$pkg")
    fi
  done
  if ((${#missing[@]})); then
    if [[ $required == required && ${ALLOW_PARTIAL_INSTALL:-0} != 1 ]]; then
      log_err "Required package set has unavailable packages ($manager): ${missing[*]}"
      log_err "Fix package names or re-run with ALLOW_PARTIAL_INSTALL=1 to continue."
      exit 1
    fi
    log_warn "Skipping unavailable packages ($manager): ${missing[*]}"
  fi
  if ((${#available[@]} == 0)); then
    if [[ $required == required && ${ALLOW_PARTIAL_INSTALL:-0} != 1 ]]; then
      log_err "Required package set has no installable packages: $file"
      log_err "Fix package sources or re-run with ALLOW_PARTIAL_INSTALL=1 to continue."
      exit 1
    fi
    log_warn "No installable packages in $file; skipping."
    return
  fi
  log_info "$label"
  if [[ $manager == pacman ]]; then
    sudo pacman -S --noconfirm --needed "${available[@]}"
  else
    paru -S --noconfirm --needed --skipreview "${available[@]}"
  fi
}

install_pkg_sets() {
  local manager="$1"; shift
  local entry file label required
  for entry in "$@"; do
    IFS='|' read -r file label required <<< "$entry"
    install_pkg_set "$manager" "$SCRIPT_DIR/$file" "$label" "${required:-optional}"
  done
}

# --- tooling installs -----------------------------------------------------
install_paru() {
  if command -v paru >/dev/null 2>&1; then
    log_warn "paru already installed; skipping build."
    return
  fi

  log_info "Installing paru AUR helper"
  if pacman -Si paru >/dev/null 2>&1 && sudo pacman -S --noconfirm --needed paru; then
    return
  fi
  log_warn "Repository install failed; building from AUR."

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN
  log_info "Cloning paru into $tmpdir"
  if ! git clone https://aur.archlinux.org/paru.git "$tmpdir"; then
    log_err "Failed to clone paru repository."
    exit 1
  fi
  (cd "$tmpdir" && makepkg -si --noconfirm)

  if ! command -v paru >/dev/null 2>&1; then
    log_err "paru installation failed."
    exit 1
  fi
}

install_local_bin() {
  local repo="$1" binary="$2" post="${3:-}"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN
  log_info "Cloning ${repo##*/}"
  if ! git clone "$repo" "$tmpdir"; then
    log_err "Failed to clone ${repo##*/}."
    exit 1
  fi
  local src="$tmpdir/bin/$binary"
  if [[ ! -f $src ]]; then
    log_err "Binary $binary not found in cloned repository."
    exit 1
  fi
  mkdir -p "$HOME/.local/bin"
  install -Dm755 "$src" "$HOME/.local/bin/$binary"
  if [[ -n $post ]]; then
    if ! (cd "$tmpdir" && eval "$post"); then
      log_err "Post-install for ${repo##*/} failed."
      exit 1
    fi
  fi
}

# --- theming --------------------------------------------------------------
run_gsettings() {
  command -v gsettings >/dev/null 2>&1 || return 1
  if command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- gsettings "$@"
  else
    gsettings "$@"
  fi
}

apply_theme() {
  command -v gsettings >/dev/null 2>&1 || {
    log_warn "gsettings unavailable; skipping GTK theme sync."
    return
  }

  local failed=0
  local setting schema key value
  local settings=(
    "org.gnome.desktop.interface|gtk-theme|Ant-Dracula"
    "org.gnome.desktop.interface|icon-theme|Dracula"
    "org.gnome.desktop.interface|color-scheme|prefer-dark"
    "org.gnome.desktop.interface|cursor-theme|Dracula-cursors"
    "org.gnome.desktop.interface|font-name|JetBrainsMono Nerd Font 11"
    "org.gnome.desktop.wm.preferences|theme|Ant-Dracula"
  )
  for setting in "${settings[@]}"; do
    IFS='|' read -r schema key value <<< "$setting"
    run_gsettings set "$schema" "$key" "$value" || failed=1
  done

  if ((failed)); then
    log_warn "Could not apply all theme settings; continue manually if needed."
  else
    log_info "Applied GTK/icon/cursor theme via gsettings."
  fi
}

write_theme_env() {
  local env_dir="$HOME/.config/environment.d"
  mkdir -p "$env_dir"
  local env_vars=(
    "GTK_THEME=Ant-Dracula"
    "XCURSOR_THEME=Dracula-cursors"
    "XCURSOR_SIZE=24"
    "QT_QPA_PLATFORMTHEME=gtk3"
    "GTK_USE_PORTAL=1"
    "XDG_CURRENT_DESKTOP=niri"
    "XDG_SESSION_DESKTOP=niri"
    "XDG_SESSION_TYPE=wayland"
    "QT_QPA_PLATFORM=wayland"
    "SDL_VIDEODRIVER=wayland"
    "CLUTTER_BACKEND=wayland"
    "MOZ_ENABLE_WAYLAND=1"
  )

  printf '%s\n' "${env_vars[@]}" > "$env_dir/10-dracula.conf"

  local env_names=()
  local pair name
  for pair in "${env_vars[@]}"; do
    name="${pair%%=*}"
    env_names+=("$name")
    export "$pair"
  done

  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment "${env_names[@]}" >/dev/null 2>&1 || true
  fi

  if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment "${env_vars[@]}" >/dev/null 2>&1 || true
  fi
}

# --- display manager ------------------------------------------------------
configure_greetd() {
  log_info "Configuring greetd + tuigreet"
  sudo install -d -m 755 /etc/greetd
  sudo tee /etc/greetd/config.toml > /dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --user-menu --cmd 'dbus-run-session niri'"
user = "greeter"
EOF
}

# --- configuration --------------------------------------------------------
configure_virtualization() {
  log_info "Detecting virtualization..."
  local virt="unknown"
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    virt=$(systemd-detect-virt 2>/dev/null || echo "unknown")
  else
    log_warn "systemd-detect-virt not available; skipping guest utils install."
    return
  fi
  case "$virt" in
    oracle)
      log_info "VirtualBox detected; installing guest utils."
      sudo pacman -S --noconfirm --needed virtualbox-guest-utils
      sudo systemctl enable --now vboxservice
      ;;
    vmware)
      log_info "VMware detected; installing open-vm-tools."
      sudo pacman -S --noconfirm --needed open-vm-tools
      sudo systemctl enable --now vmtoolsd.service
      ;;
    qemu|kvm)
      log_info "QEMU/KVM detected; installing guest agents."
      sudo pacman -S --noconfirm --needed qemu-guest-agent spice-vdagent
      sudo systemctl enable --now qemu-guest-agent.service
      ;;
    none)
      log_info "Bare metal detected; no guest utilities required."
      ;;
    *)
      log_warn "Virtualization type '$virt' unsupported for automatic helpers."
      ;;
  esac
}

sync_configs() {
  log_info "Preparing config directories"
  mkdir -p "$HOME/.config" "$HOME/.config/gtk-4.0" ~/.themes ~/.icons ~/.config/environment.d

  log_info "Setting Dracula cursor theme as default"
  mkdir -p "$HOME/.icons/default"
  cat > "$HOME/.icons/default/index.theme" <<'EOF'
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=Dracula-cursors
EOF

  log_info "Syncing repository configs to ~/.config"
  rsync -a --exclude '.gitkeep' "$SCRIPT_DIR/.config/" "$HOME/.config/"

  if [[ -d "$HOME/.config/waybar/scripts" ]]; then
    chmod +x "$HOME/.config/waybar/scripts/"* || true
  fi

  if command -v mpd >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/mpd" "$HOME/.local/share/mpd/playlists"
  fi

  apply_theme
  write_theme_env
}

install_desktop_entries() {
  log_info "Installing desktop entries"
  install -Dm644 "$SCRIPT_DIR/.local/share/applications/helix-kitty.desktop" \
    "$HOME/.local/share/applications/helix-kitty.desktop"
  sed -i "s|^Icon=.*|Icon=$HOME/.local/share/icons/hicolor/scalable/apps/helix.svg|" \
    "$HOME/.local/share/applications/helix-kitty.desktop"
  install -Dm644 "$SCRIPT_DIR/.local/share/applications/thunar.desktop" \
    "$HOME/.local/share/applications/thunar.desktop"
  install -Dm644 "$SCRIPT_DIR/.local/share/icons/hicolor/scalable/apps/helix.svg" \
    "$HOME/.local/share/icons/hicolor/scalable/apps/helix.svg"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" || true
  fi
}

enable_services() {
  log_info "Enabling system services"
  sudo systemctl enable --now NetworkManager
  sudo systemctl enable --now bluetooth
  sudo systemctl enable --now seatd
  sudo systemctl enable greetd
  log_warn "greetd enabled; it will start at boot."

  log_info "Enabling PipeWire user services"
  if systemctl --user list-unit-files >/dev/null 2>&1; then
    systemctl --user enable --now pipewire.service
    systemctl --user enable --now pipewire-pulse.service
    systemctl --user enable --now wireplumber.service
    if command -v mpd >/dev/null 2>&1; then
      systemctl --user enable --now mpd.service || log_warn "Could not enable mpd.service for user."
    fi
  else
    log_warn "systemd --user not available; skipping PipeWire enablement."
  fi
}

ensure_user_groups() {
  log_info "Adding user to video/audio/input groups"
  sudo usermod -aG video,audio,input,seat "$USER"
}

ensure_niri_desktop_entry() {
  log_info "Ensuring niri.desktop exists"
  if [[ -f /usr/share/wayland-sessions/niri.desktop ]]; then
    log_info "Existing niri.desktop found."
    return
  fi
  log_warn "niri.desktop missing; creating minimal entry."
  sudo tee /usr/share/wayland-sessions/niri.desktop > /dev/null <<'EOF'
[Desktop Entry]
Name=Niri
Comment=Dynamic Wayland tiling compositor
Exec=niri
TryExec=niri
Type=Application
EOF
}

install_bashrc() {
  if [[ ! -f $REPO_BASHRC ]]; then
    log_err "Repository .bashrc missing at $REPO_BASHRC"
    exit 1
  fi
  local backup="$TARGET_BASHRC.pre-niri-install.$(date +%Y%m%d%H%M%S)"
  if [[ -e $TARGET_BASHRC ]]; then
    log_warn "Backing up existing ~/.bashrc to ${backup/#$HOME/~}"
    cp -L "$TARGET_BASHRC" "$backup"
  fi
  install -Dm644 "$REPO_BASHRC" "$TARGET_BASHRC"
  log_info "Installed repository .bashrc"
}

install_zshrc() {
  if [[ ! -f $REPO_ZSHRC ]]; then
    log_err "Repository .zshrc missing at $REPO_ZSHRC"
    exit 1
  fi
  local backup="$TARGET_ZSHRC.pre-niri-install.$(date +%Y%m%d%H%M%S)"
  if [[ -e $TARGET_ZSHRC ]]; then
    log_warn "Backing up existing ~/.zshrc to ${backup/#$HOME/~}"
    cp -L "$TARGET_ZSHRC" "$backup"
  fi
  install -Dm644 "$REPO_ZSHRC" "$TARGET_ZSHRC"
  log_info "Installed repository .zshrc"
}

set_default_shell_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null || true)"
  if [[ -z $zsh_path ]]; then
    log_warn "zsh not found after install; skipping default shell change."
    return
  fi
  if [[ ${SHELL:-} == "$zsh_path" ]]; then
    log_info "Default shell already set to zsh."
    return
  fi
  if chsh -s "$zsh_path" "$USER"; then
    log_info "Changed default shell to zsh for $USER"
  else
    log_warn "Could not change default shell. Run: chsh -s \"$zsh_path\" \"$USER\""
  fi
}

final_summary() {
  show_banner
  log_ok "Niri installation and configuration complete!"
  echo
  log_info "Configuration summary:"
  cat <<'EOF'
  • greetd + tuigreet display manager enabled
  • Niri compositor with Waybar (Ant-Dracula theme)
  • Kitty terminal emulator (Dracula theme)
  • Brave browser
  • NimLaunch application launcher
  • Nymph fetch utility (auto-runs in terminal)
  • Gtklock screen locker with Dracula theme
  • Mako notification daemon (Dracula theme)
  • GTK applications themed with Ant-Dracula
  • PipeWire audio system (modern replacement for PulseAudio)
  • Paru AUR helper installed
  • Nerd Fonts with icon support
  • Screenshot tools (grim + slurp + swappy + satty)
  • Clipboard history collection via cliphist
  • Removable-drive tray automounter (udiskie)
  • Audio/brightness controls configured
  • Auto-lock after 5 minutes of inactivity
  • Consistent Dracula theme across all components
EOF
  log_warn "Please reboot to start greetd. Select 'Niri' from the session menu."
  echo
  log_info "Basic key bindings:"
  cat <<'EOF'
  • Super + Enter: Open terminal (Kitty)
  • Super + D: NimLaunch application launcher
  • Super + B: Open Brave browser
  • Super + N: Open Thunar file manager
  • Mod + Shift + /: Show Niri keybinding overlay
  • Super + I: Lock screen
  • Super + Q: Close window
  • Super + Shift + E: Exit Niri session
  • Print: Screenshot
  • Ctrl + Print: Screenshot current display
  • Alt + Print: Screenshot focused window
  • Super + Shift + Print: Screenshot region and open Satty
EOF
  log_info "Configuration lives in ~/.config"
  log_info "Use 'paru' for additional AUR packages"
  log_ok "Installer finished. Reboot to enjoy your new desktop!"
}

# --- main flow ------------------------------------------------------------
main() {
  show_banner
  log_info "Starting Niri installation on minimal Arch Linux..."
  require_environment
  confirm_run

  log_info "Updating system packages"
  sudo pacman -Syu --noconfirm

  install_pkg_sets pacman "${PACMAN_SETS[@]}"
  configure_virtualization
  install_paru
  install_pkg_sets paru "${PARU_SETS[@]}"

  install_local_bin "https://github.com/Vyrnexis/NimLaunch.git" nimlaunch
  install_local_bin "https://github.com/Vyrnexis/Nymph.git" nymph \
    'rm -rf "$HOME/.config/nymph/logos"; mkdir -p "$HOME/.config/nymph"; cp -r bin/logos "$HOME/.config/nymph/"'

  sync_configs
  install_desktop_entries
  log_info "Creating ~/Pictures/Screenshots"
  mkdir -p "$HOME/Pictures/Screenshots"

  configure_greetd
  enable_services
  ensure_user_groups
  ensure_niri_desktop_entry

  log_info "Refreshing font cache"
  fc-cache -fv

  log_info "Deploying shell configs"
  install_bashrc
  install_zshrc
  set_default_shell_zsh

  final_summary
}

main "$@"
