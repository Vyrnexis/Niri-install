#!/usr/bin/env bash
set -euo pipefail

LOCK_CMD=(gtklock)
if ! command -v gtklock >/dev/null 2>&1; then
    if command -v loginctl >/dev/null 2>&1; then
        LOCK_CMD=(loginctl lock-session)
    else
        echo "gtklock not found and no loginctl fallback available" >&2
        exit 1
    fi
elif [[ -f /usr/share/gtklock/style.css ]]; then
    LOCK_CMD=(gtklock -s /usr/share/gtklock/style.css)
fi

# Timeouts (seconds). Override with LOCK_TIMEOUT_SEC / DPMS_TIMEOUT_SEC env vars.
LOCK_TIMEOUT=${LOCK_TIMEOUT_SEC:-300}
DPMS_TIMEOUT=${DPMS_TIMEOUT_SEC:-360}

NIRI_SOCKET=${NIRI_SOCKET:-}
if [[ -z ${NIRI_SOCKET} && -n ${XDG_RUNTIME_DIR:-} ]]; then
    for cand in "$XDG_RUNTIME_DIR"/niri-ipc-*; do
        [[ -S $cand ]] || continue
        NIRI_SOCKET="$cand"
        break
    done
fi

POWER_OFF_CMD=()
POWER_ON_CMD=()
if command -v niri >/dev/null 2>&1; then
    POWER_OFF_CMD=(niri msg)
    POWER_ON_CMD=(niri msg)
    if [[ -n ${NIRI_SOCKET:-} ]]; then
        POWER_OFF_CMD+=(--socket "$NIRI_SOCKET")
        POWER_ON_CMD+=(--socket "$NIRI_SOCKET")
    fi
    POWER_OFF_CMD+=(action power-off-monitors)
    POWER_ON_CMD+=(action power-on-monitors)
fi

IDLE_CMD=(swayidle -w)
IDLE_CMD+=("timeout" "$LOCK_TIMEOUT" "${LOCK_CMD[@]}")
if ((${#POWER_OFF_CMD[@]})); then
    IDLE_CMD+=("timeout" "$DPMS_TIMEOUT" "${POWER_OFF_CMD[@]}")
    IDLE_CMD+=("resume" "${POWER_ON_CMD[@]}")
fi
IDLE_CMD+=("before-sleep" "${LOCK_CMD[@]}")

command -v swayidle >/dev/null 2>&1 || { echo "swayidle not found" >&2; exit 1; }

is_running() {
    pgrep -x swayidle >/dev/null 2>&1
}

start_idle() {
    if is_running; then
        return
    fi
    env WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
        XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
        DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
        NIRI_SOCKET="${NIRI_SOCKET:-}" \
        PATH="$PATH" \
        setsid -f "${IDLE_CMD[@]}" >/dev/null 2>&1 || {
            echo "Failed to start swayidle" >&2
            exit 1
        }
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
