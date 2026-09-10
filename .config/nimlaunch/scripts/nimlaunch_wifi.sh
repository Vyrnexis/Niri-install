#!/usr/bin/env bash

# Connect to a visible Wi-Fi network through NimLaunch.
set -euo pipefail

# Exit with an actionable error when a required command is missing.
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'nimlaunch_wifi: required command not found: %s\n' "$1" >&2
    exit 127
  }
}

# Split an escaped nmcli record into the global nmcli_fields array.
parse_nmcli_record() {
  local record="$1" character field="" escaped=0 index
  nmcli_fields=()
  for ((index = 0; index < ${#record}; index++)); do
    character="${record:index:1}"
    if ((escaped)); then
      field+="$character"
      escaped=0
    elif [[ $character == "\\" ]]; then
      escaped=1
    elif [[ $character == : ]]; then
      nmcli_fields+=("$field")
      field=""
    else
      field+="$character"
    fi
  done
  ((escaped)) && field+="\\"
  nmcli_fields+=("$field")
}

# Send a Wi-Fi status notification when notifications are available.
notify_wifi() {
  command -v notify-send >/dev/null 2>&1 &&
    notify-send "Wi-Fi" "$1" -i network-wireless || true
}

require_command nimlaunch
require_command nmcli
require_command zenity

declare -a wifi_ssids=() wifi_security=() wifi_labels=() nmcli_fields=()
declare -A seen_ssids=()

while IFS= read -r record; do
  parse_nmcli_record "$record"
  ((${#nmcli_fields[@]} >= 3)) || continue
  active="${nmcli_fields[0]}"
  security="${nmcli_fields[1]}"
  ssid="${nmcli_fields[2]}"
  [[ -n $ssid && -z ${seen_ssids[$ssid]+present} ]] || continue
  seen_ssids["$ssid"]=1
  status=""
  [[ $active == "*" || $active == yes ]] && status=" [connected]"
  [[ -n $security && $security != -- ]] || security="open"
  wifi_ssids+=("$ssid")
  wifi_security+=("$security")
  wifi_labels+=("$ssid$status [$security]")
done < <(nmcli --terse --escape yes --fields IN-USE,SECURITY,SSID device wifi list)

((${#wifi_ssids[@]})) || {
  printf 'nimlaunch_wifi: no Wi-Fi networks found\n' >&2
  exit 1
}

selection="$(printf '%s\n' "${wifi_labels[@]}" | nimlaunch --dmenu -p 'Wi-Fi:')" || exit $?
[[ -n $selection ]] || exit 0

selected_index=""
for index in "${!wifi_labels[@]}"; do
  [[ ${wifi_labels[$index]} == "$selection" ]] || continue
  selected_index="$index"
  break
done
[[ -n $selected_index ]] || exit 1

ssid="${wifi_ssids[$selected_index]}"
security="${wifi_security[$selected_index]}"
notify_wifi "Connecting to $ssid"
if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
  notify_wifi "Connected to $ssid"
  exit 0
fi

[[ $security != open ]] || {
  notify_wifi "Failed to connect to $ssid"
  exit 1
}

password="$(zenity --password --title='Wi-Fi password' --text="Password for $ssid")" || exit 0
[[ -n $password ]] || exit 0
if nmcli device wifi connect "$ssid" password "$password" >/dev/null; then
  notify_wifi "Connected to $ssid"
else
  notify_wifi "Failed to connect to $ssid"
  exit 1
fi
