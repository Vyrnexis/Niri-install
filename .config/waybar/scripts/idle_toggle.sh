#!/usr/bin/env bash

# Toggle one installer-owned swayidle process and report its Waybar state.

set -euo pipefail

readonly RUNTIME_BASE="${XDG_RUNTIME_DIR:-/tmp}"
readonly PID_FILE="$RUNTIME_BASE/niri-install-swayidle.pid"
readonly LOCK_TIMEOUT=300
readonly DISPLAY_TIMEOUT=360

# Return success only when the recorded swayidle process is alive.
is_running() {
  local pid
  [[ -r $PID_FILE ]] || return 1
  read -r pid < "$PID_FILE"
  [[ $pid =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

# Start swayidle with lock, display-power, and suspend hooks.
start_idle() {
  is_running && return 0
  command -v swayidle >/dev/null 2>&1 || {
    printf 'swayidle is not installed\n' >&2
    return 1
  }
  command -v gtklock >/dev/null 2>&1 || {
    printf 'gtklock is not installed\n' >&2
    return 1
  }

  swayidle -w \
    timeout "$LOCK_TIMEOUT" 'gtklock' \
    timeout "$DISPLAY_TIMEOUT" 'niri msg action power-off-monitors' \
    resume 'niri msg action power-on-monitors' \
    before-sleep 'gtklock' >/dev/null 2>&1 &
  printf '%s\n' "$!" > "$PID_FILE"
}

# Stop only the swayidle process started by this script.
stop_idle() {
  local pid
  is_running || {
    rm -f -- "$PID_FILE"
    return 0
  }
  read -r pid < "$PID_FILE"
  kill "$pid"
  rm -f -- "$PID_FILE"
}

# Emit JSON describing the current idle-inhibitor state.
print_status() {
  if is_running; then
    printf '{"text":"󰒲","tooltip":"Idle timers active","class":"active"}'
  else
    printf '{"text":"󰅶","tooltip":"Keep awake enabled","class":"inhibited"}'
  fi
}

case "${1:-status}" in
  status) print_status ;;
  toggle)
    if is_running; then
      stop_idle
    else
      start_idle
    fi
    print_status
    ;;
  enable) start_idle ;;
  disable) stop_idle ;;
  *) printf 'Usage: %s [status|toggle|enable|disable]\n' "$0" >&2; exit 2 ;;
esac
