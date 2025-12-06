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
unit="${weather_unit#?}"
STATUS_URL="${BASE_URL}?format=%c%t&${unit}"
FULL_URL="${BASE_URL}?${unit}&format=3"

weather_status(){
    curl -fsS --http1.1 --max-time 10 "$STATUS_URL" | tr -d '\n' \
      || curl -fsS --http1.1 --max-time 10 "${BASE_URL}?format=%c%t" | tr -d '\n' \
      || printf "Weather unavailable"
}

print_weather(){
    local tmp
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT

    if curl -fsS --http1.1 --max-time 10 "$FULL_URL" -o "$tmp"; then
        ${PAGER:-less} -R "$tmp"
    elif curl -fsS --http1.1 --max-time 10 "${BASE_URL}?format=3" -o "$tmp"; then
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
