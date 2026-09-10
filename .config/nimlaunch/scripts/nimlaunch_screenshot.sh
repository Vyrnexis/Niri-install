#!/usr/bin/env bash

# Capture an area or the full desktop to the clipboard or a file.
set -euo pipefail

# Exit with an actionable error when a required command is missing.
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'nimlaunch_screenshot: required command not found: %s\n' "$1" >&2
    exit 127
  }
}

# Resolve and create the screenshot output directory.
screenshot_directory() {
  local pictures_directory
  pictures_directory="$(xdg-user-dir PICTURES 2>/dev/null || true)"
  [[ -n $pictures_directory ]] || pictures_directory="$HOME/Pictures"
  printf '%s/Screenshots' "$pictures_directory"
}

capture_mode="${1:-}"
output_mode="${2:-}"
[[ $capture_mode == area || $capture_mode == full ]] || {
  printf 'Usage: nimlaunch_screenshot.sh {area|full} {clipboard|save}\n' >&2
  exit 2
}
[[ $output_mode == clipboard || $output_mode == save ]] || {
  printf 'Usage: nimlaunch_screenshot.sh {area|full} {clipboard|save}\n' >&2
  exit 2
}

require_command grim
[[ $capture_mode == area ]] && require_command slurp
[[ $output_mode == clipboard ]] && require_command wl-copy

declare -a capture_args=()
if [[ $capture_mode == area ]]; then
  geometry="$(slurp)" || exit 0
  [[ -n $geometry ]] || exit 0
  capture_args=(-g "$geometry")
fi

if [[ $output_mode == clipboard ]]; then
  grim "${capture_args[@]}" - | wl-copy --type image/png
  message="Screenshot copied to the clipboard"
else
  output_directory="$(screenshot_directory)"
  mkdir -p "$output_directory"
  output_file="$output_directory/$(date '+%Y-%m-%d_%H-%M-%S').png"
  grim "${capture_args[@]}" "$output_file"
  message="Screenshot saved to $output_file"
fi

command -v notify-send >/dev/null 2>&1 &&
  notify-send "Screenshot" "$message" -i camera-photo || true
