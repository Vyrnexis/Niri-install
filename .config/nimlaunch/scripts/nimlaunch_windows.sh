#!/usr/bin/env bash

# Focus an open Niri window selected through NimLaunch.
set -euo pipefail

# Exit with an actionable error when a required command is missing.
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'nimlaunch_windows: required command not found: %s\n' "$1" >&2
    exit 127
  }
}

require_command nimlaunch
require_command niri
require_command jq
require_command base64

declare -a window_records=() window_ids=() window_labels=()
mapfile -t window_records < <(niri msg --json windows | jq -r '.[] | @base64')

for record in "${window_records[@]}"; do
  window_json="$(printf '%s' "$record" | base64 --decode)"
  window_id="$(jq -r '.id' <<< "$window_json")"
  title="$(jq -r '.title // "Untitled window" | gsub("[\\r\\n\\t]"; " ")' <<< "$window_json")"
  app_id="$(jq -r '.app_id // "unknown" | gsub("[\\r\\n\\t]"; " ")' <<< "$window_json")"
  [[ $window_id =~ ^[0-9]+$ ]] || continue
  window_ids+=("$window_id")
  window_labels+=("$title [$app_id, #$window_id]")
done

((${#window_ids[@]})) || {
  printf 'nimlaunch_windows: no open Niri windows found\n' >&2
  exit 1
}

selection="$(printf '%s\n' "${window_labels[@]}" | nimlaunch --dmenu -p 'Windows:')" || exit $?
[[ -n $selection ]] || exit 0

for index in "${!window_labels[@]}"; do
  [[ ${window_labels[$index]} == "$selection" ]] || continue
  niri msg action focus-window --id "${window_ids[$index]}"
  exit 0
done

printf 'nimlaunch_windows: selected window was not found\n' >&2
exit 1
