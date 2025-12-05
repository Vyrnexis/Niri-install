#!/usr/bin/env bash
set -euo pipefail

# Get weather (wttr.in)

# weather location (space = "+")
# example: "London", "Salt+Lake+City"
weather_location="${WEATHER_LOCATION:-Perth}"

# weather units (default = "?m")
# ?u - USCS (fahrenheit, mph)
# ?m - metric (celsius, km/h)
# ?M - metric (celsius, m/s)
weather_unit="${WEATHER_UNIT:-?m}"

BASE_URL="https://wttr.in/${weather_location}"
STATUS_URL="${BASE_URL}?format=%c%t&${weather_unit#?}"
FULL_URL="${BASE_URL}?${weather_unit#?}"

weather_status(){
    curl -fsS --max-time 10 "$STATUS_URL" | tr -d '\n' || echo "Weather unavailable"
}

print_weather(){
    local tmp
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT

    if curl -fsS --max-time 10 "$FULL_URL" -o "$tmp"; then
        ${PAGER:-less} -R "$tmp"
    else
        echo "Cannot reach wttr.in right now."
    fi
}

case "${1:-}" in
    -o)
        weather_status
        ;;
    *)
        print_weather
        ;;
esac
