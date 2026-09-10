#!/usr/bin/env bash

# Restore a text or image entry from cliphist through NimLaunch.
set -euo pipefail

# Exit with an actionable error when a required command is missing.
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'nimlaunch_clipboard: required command not found: %s\n' "$1" >&2
    exit 127
  }
}

require_command nimlaunch
require_command cliphist
require_command wl-copy

declare -a entries=() labels=()
mapfile -t entries < <(cliphist list)
((${#entries[@]})) || {
  printf 'nimlaunch_clipboard: clipboard history is empty\n' >&2
  exit 1
}

for index in "${!entries[@]}"; do
  preview="${entries[$index]//$'\t'/ }"
  preview="${preview//$'\n'/ }"
  labels+=("$((index + 1)): ${preview:0:100}")
done

selection="$(printf '%s\n' "${labels[@]}" | nimlaunch --dmenu -p 'Clipboard:')" || exit $?
[[ -n $selection ]] || exit 0

for index in "${!labels[@]}"; do
  [[ ${labels[$index]} == "$selection" ]] || continue
  printf '%s\n' "${entries[$index]}" | cliphist decode | wl-copy
  command -v notify-send >/dev/null 2>&1 &&
    notify-send "Clipboard" "Restored clipboard item" -i edit-paste || true
  exit 0
done

printf 'nimlaunch_clipboard: selected entry was not found\n' >&2
exit 1
