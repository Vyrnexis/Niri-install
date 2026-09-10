#!/usr/bin/env bash

# Select the default PipeWire audio sink through NimLaunch.
set -euo pipefail

# Exit with an actionable error when a required command is missing.
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'nimlaunch_audio: required command not found: %s\n' "$1" >&2
    exit 127
  }
}

require_command nimlaunch
require_command pw-dump
require_command wpctl
require_command jq

default_id="$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null |
  awk '/^id[[:space:]]+[0-9]+,/ { gsub(",", "", $2); print $2; exit }')"
declare -a sink_ids=() sink_labels=()

while IFS=$'\t' read -r sink_id sink_name; do
  [[ -n $sink_id ]] || continue
  marker=""
  [[ $sink_id == "$default_id" ]] && marker=" [default]"
  sink_ids+=("$sink_id")
  sink_labels+=("$sink_name$marker [$sink_id]")
done < <(
  pw-dump --raw | jq -r '
    .[]
    | select(.type == "PipeWire:Interface:Node")
    | select(.info.props["media.class"] == "Audio/Sink")
    | [(.id | tostring), (
        .info.props["node.description"]
        // .info.props["device.description"]
        // .info.props["node.nick"]
        // .info.props["node.name"]
        // ("Sink " + (.id | tostring))
      )]
    | @tsv
  '
)

((${#sink_ids[@]})) || {
  printf 'nimlaunch_audio: no audio sinks found\n' >&2
  exit 1
}

selection="$(printf '%s\n' "${sink_labels[@]}" | nimlaunch --dmenu -p 'Audio output:')" || exit $?
[[ -n $selection ]] || exit 0

for index in "${!sink_labels[@]}"; do
  [[ ${sink_labels[$index]} == "$selection" ]] || continue
  wpctl set-default "${sink_ids[$index]}"
  command -v notify-send >/dev/null 2>&1 &&
    notify-send "Audio output" "Selected ${sink_labels[$index]}" -i audio-speakers || true
  exit 0
done

printf 'nimlaunch_audio: selected sink was not found\n' >&2
exit 1
