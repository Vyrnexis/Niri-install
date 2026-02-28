# Niri Install Script

![Dracula-themed Niri desktop](Screenshot.png)

This repository contains an automated installer that sets up a Dracula-themed Niri desktop environment on a freshly installed Arch Linux system. It installs core Wayland tooling, productivity utilities, fonts, and quality-of-life tweaks so you can log in and start working immediately.

## Prerequisites

Run the official Arch installer (`archinstall`) and pick these options for the smoothest run:

- Profile: `minimal`
- Audio: `pipewire`
- Network: `NetworkManager` (or “Copy ISO network configuration” so networking works after reboot)
- User: add a user and give it administrator privileges (sudo)
- Additional packages: `git` (needed only to clone this repo)
- Bootloader/filesystems: any default combination is fine; just ensure you can boot and get online

After installation finishes and you reboot, sign in as the regular sudo-capable user (not root) before running the script below. You need working internet for package installs.  
For Wi‑Fi on a minimal install, pick the `NetworkManager` option in `archinstall` so `nmcli` is present, then connect after reboot:

```bash
nmcli device wifi list
nmcli device wifi connect "YourSSID" password "YourPassword"
```

## Usage

1. If git is missing, install it and clone the repository:

   ```bash
   sudo pacman -S --needed git
   cd ~
   git clone https://github.com/Vyrnexis/Niri-install.git
   ```

2. Run the installer from inside the cloned directory:

   ```bash
   cd Niri-install
   ./niri_install.sh
   ```

The installer must not be run as root; it prompts for your sudo password whenever elevated privileges are required and asks for confirmation before proceeding.

## What the Script Installs

- Niri compositor, Waybar panel, gtklock/swayidle, and supporting Wayland tools (kanshi, wlr-randr, wev)
- Kitty terminal, Thunar file manager, notification daemon (mako), screenshot utilities (grim, slurp, swappy, satty)
- PipeWire audio stack with WirePlumber session manager
- Clipboard history tooling (`cliphist` + `nwg-clipman`), improved Qt/portal compatibility, and removable-drive helpers (`udiskie`)
- Paru AUR helper plus theme/application packages such as Brave browser, Ant-Dracula GTK, Dracula icons/cursors, NimLaunch, and Nymph
- Ant-Dracula GTK theme, Dracula icons/cursors, Nerd Fonts, and environment configuration for GTK/Qt apps
- System services: NetworkManager, Bluetooth, seatd, greetd + tuigreet, user-level PipeWire services (when available)
- Custom configuration files placed under `~/.config/`
- Zsh installed and set as the default shell (with bash config still installed and backed up)

## Post-Install Notes

- Reboot after the script completes so greetd and the configured services start cleanly.
- When Niri starts, custom bindings add `Super+Enter` (Kitty terminal), `Super+D` (NimLaunch), `Super+B` (Brave browser), `Super+N` (Thunar file manager), and `Mod+Shift+/` (Niri’s built-in keybinding overlay). Niri defaults remain for navigation and layout.
- Cursor theming: the script installs Dracula cursors and writes `~/.icons/default/index.theme` so the cursor is consistent across GTK, Qt, and Wayland applications.
- Clipboard history starts automatically via `wl-paste --watch cliphist store` (text + image). Use your preferred picker flow (`nwg-clipman` or direct `cliphist` commands).
- `udiskie` now autostarts for removable-drive tray/mount handling.
- `kanshi` autostarts only when `~/.config/kanshi/config` contains at least one active (uncommented) `profile` block; a template is included in the repo.
- Screenshot annotate shortcut: `Mod+Shift+Print` captures a region and opens it in Satty.
- Niri’s built-in keybinding overlay (`Mod+Shift+/`) is available without extra tooling.

## Troubleshooting

- If `paru` fails to build, ensure that `base-devel` is installed (the script installs it automatically) and that you have network access.
- Core desktop package sets and AUR theme packages are treated as required. If one is unavailable, the installer now stops instead of silently skipping it. You can bypass this with `ALLOW_PARTIAL_INSTALL=1 ./niri_install.sh`.
- Running the script twice is safe; package groups use `--needed` and configuration syncs refresh existing files.
- The installer backs up any existing `~/.bashrc` and `~/.zshrc` (timestamped) before installing the repository versions; adjust them afterwards if desired.

Feel free to fork this repository and adjust the package selection or configuration files to match your workflow.
