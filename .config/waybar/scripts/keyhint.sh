#!/usr/bin/env bash
set -euo pipefail

entries=(
"Super+Enter|Open terminal|kitty"
"Super+D|Application launcher|~/.local/bin/nimlaunch"
"Super+B|Open browser|brave"
"Super+N|Open file manager|thunar"
"Super+B|Open browser|brave"
"Super+N|Open file manager|thunar"
"Super+I|Lock screen|gtklock -s"
"Super+Q|Close focused window|niri msg action close-window"
"Super+Shift+E|Exit Niri session|niri msg action quit"
"Print|Screenshot (full)|grim - | swappy -f -"
"Super+Print|Screenshot (area)|grim -g \"\$(slurp)\" - | swappy -f -"
"Super+Shift+I|Show this help|~/.config/waybar/scripts/keyhint.sh"
"XF86AudioRaiseVolume|Raise volume|wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.5"
"XF86AudioLowerVolume|Lower volume|wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.5"
"XF86AudioMute|Toggle mute|wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
"XF86MonBrightnessUp|Increase brightness|brightnessctl set +5%"
"XF86MonBrightnessDown|Decrease brightness|brightnessctl set 5%-"
)

make_rows() {
    printf "Key\tDescription\tCommand\n"
    for row in "${entries[@]}"; do
        IFS='|' read -r key desc cmd <<<"$row"
        printf "%s\t%s\t%s\n" "$key" "$desc" "$cmd"
    done
}

rows=$(make_rows)
formatted=$(printf '%s\n' "$rows" | column -t -s $'\t')
formatted=$(awk 'NR==1{print "\033[1;36m" $0 "\033[0m"; next} {print}' <<<"$formatted")
title=$'\033[1;35mNiri Keybindings\033[0m'
divider=$'\033[2m──────────────────────────────────────────────\033[0m'
formatted="$title"$'\n'$"$divider"$'\n'$formatted
formatted+=$'\n\n\033[2mPress q to close.\033[0m'

tmp_file=$(mktemp)
tmp_data_raw=$(mktemp)
tmp_data=$(mktemp)
trap 'rm -f "$tmp_file" "$tmp_data_raw" "$tmp_data"' EXIT
printf '%s\n' "$formatted" > "$tmp_file"
make_rows > "$tmp_data_raw"
tail -n +2 "$tmp_data_raw" > "$tmp_data"

if command -v yad >/dev/null 2>&1; then
    yad --title="Niri Keybindings" \
        --class=keyhint \
        --name=keyhint \
        --width=900 \
        --height=540 \
        --undecorated \
        --center \
        --borders=12 \
        --window-icon=utilities-terminal \
        --no-buttons \
        --fontname="JetBrainsMono Nerd Font 11" \
        --ellipsize=end \
        --separator=$'\t' \
        --list \
        --column="Key" \
        --column="Description" \
        --column="Command" < "$tmp_data" &
    wait $!
    exit 0
fi

if command -v kitty >/dev/null 2>&1; then
    kitty --class keyhint --title "Niri Keybindings" less -R "$tmp_file"
    exit 0
fi

less -R "$tmp_file"
