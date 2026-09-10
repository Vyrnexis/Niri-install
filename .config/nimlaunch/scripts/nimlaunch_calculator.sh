#!/usr/bin/env bash

# Evaluate a calculator expression and copy its result when possible.
set -euo pipefail

command -v bc >/dev/null 2>&1 || {
  printf 'nimlaunch_calculator: required command not found: bc\n' >&2
  exit 127
}

expression="$*"
[[ -n $expression ]] || exit 0
[[ $expression =~ ^[[:space:][:digit:]+*/%().^=-]+$ ]] || {
  printf 'nimlaunch_calculator: expression contains unsupported characters\n' >&2
  exit 2
}

result="$(printf '%s\n' "$expression" | bc -l 2>/dev/null)" || {
  printf 'nimlaunch_calculator: invalid expression\n' >&2
  exit 2
}
[[ -n $result ]] || exit 2

clipboard_message=""
if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$result" | wl-copy
  clipboard_message=" and copied to the clipboard"
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send "Calculator" "Result: $result$clipboard_message" -i accessories-calculator || true
else
  printf 'Result: %s\n' "$result"
fi
