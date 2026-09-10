#!/usr/bin/env bash

# Connect or disconnect a paired Bluetooth device through NimLaunch.
set -euo pipefail

# Exit with an actionable error when a required command is missing.
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'nimlaunch_bluetooth: required command not found: %s\n' "$1" >&2
    exit 127
  }
}

# Return success when a Bluetooth device is connected.
is_connected() {
  bluetoothctl info "$1" 2>/dev/null |
    awk -F': ' '$1 ~ /Connected$/ { found = 1; connected = ($2 == "yes") } END { exit (!found || !connected) }'
}

require_command nimlaunch
require_command bluetoothctl

declare -a device_macs=() device_names=() device_labels=()
while read -r record_type mac_address device_name; do
  [[ $record_type == Device && -n $mac_address ]] || continue
  [[ -n $device_name ]] || device_name="Unnamed device"
  marker=""
  is_connected "$mac_address" && marker=" [connected]"
  device_macs+=("$mac_address")
  device_names+=("$device_name")
  device_labels+=("$device_name$marker [$mac_address]")
done < <(bluetoothctl devices Paired 2>/dev/null || bluetoothctl devices)

((${#device_macs[@]})) || {
  printf 'nimlaunch_bluetooth: no paired devices found\n' >&2
  exit 1
}

selection="$(printf '%s\n' "${device_labels[@]}" | nimlaunch --dmenu -p 'Bluetooth:')" || exit $?
[[ -n $selection ]] || exit 0

for index in "${!device_labels[@]}"; do
  [[ ${device_labels[$index]} == "$selection" ]] || continue
  if is_connected "${device_macs[$index]}"; then
    bluetoothctl disconnect "${device_macs[$index]}"
    action="Disconnected"
  else
    bluetoothctl connect "${device_macs[$index]}"
    action="Connected"
  fi
  command -v notify-send >/dev/null 2>&1 &&
    notify-send "Bluetooth" "$action ${device_names[$index]}" -i bluetooth || true
  exit 0
done

printf 'nimlaunch_bluetooth: selected device was not found\n' >&2
exit 1
