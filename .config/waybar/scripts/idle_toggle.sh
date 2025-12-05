#!/usr/bin/env bash
set -euo pipefail

LOCK_CMD="gtklock -s"
if ! command -v gtklock >/dev/null 2>&1; then
    if command -v loginctl >/dev/null 2>&1; then
        LOCK_CMD="loginctl lock-session"
    else
        echo "gtklock not found and no loginctl fallback available" >&2
        exit 1
    fi
fi

IDLE_CMD=(swayidle -w \
    timeout 300 "$LOCK_CMD" \
    before-sleep "$LOCK_CMD")

command -v swayidle >/dev/null 2>&1 || { echo "swayidle not found" >&2; exit 1; }

is_running() {
    pgrep -x swayidle >/dev/null 2>&1
}

start_idle() {
    if is_running; then
        return
    fi
    setsid -f "${IDLE_CMD[@]}" >/dev/null 2>&1
}

stop_idle() {
    if ! is_running; then
        return
    fi
    pkill -x swayidle >/dev/null 2>&1 || true
}

print_status() {
    if is_running; then
        printf '{"text":"󰒲","tooltip":"Idle timers active","class":"active"}'
    else
        printf '{"text":"󰅶","tooltip":"Keep Awake enabled","class":"inhibited"}'
    fi
}

case "${1:-status}" in
    status)
        print_status
        ;;
    toggle)
        if is_running; then
            stop_idle
        else
            start_idle
        fi
        sleep 0.1
        print_status
        ;;
    enable)
        start_idle
        ;;
    disable)
        stop_idle
        ;;
    *)
        echo "Usage: $0 [status|toggle|enable|disable]" >&2
        exit 1
        ;;
esac
