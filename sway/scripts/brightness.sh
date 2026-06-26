#!/bin/bash
# brightness.sh — rofi script-mode brightness menu
# Deps: brightnessctl
# Same Option-A static-list design as volume.sh — see that file's
# header for why arrow-key live stepping was rejected.

set -euo pipefail

THEME_DIR="$HOME/.config/rofi"
THEME="$THEME_DIR/shared.rasi"
POSITION="$THEME_DIR/position/bottom.rasi"

STEP=5
MIN=5    # avoid 0% — most panels go fully black and brightnessctl
         # can't recover without a hardware key on some laptops

bar() {
    local pct=$1 width=20
    local filled=$(( pct * width / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    [ "$filled" -lt 0 ] && filled=0
    local empty=$(( width - filled ))
    local out=""
    [ "$filled" -gt 0 ] && out+="$(printf '█%.0s' $(seq 1 "$filled"))"
    [ "$empty" -gt 0 ] && out+="$(printf '░%.0s' $(seq 1 "$empty"))"
    printf '%s' "$out"
}

current_pct() {
    local cur max
    cur=$(brightnessctl get 2>/dev/null) || { echo 50; return; }
    max=$(brightnessctl max 2>/dev/null) || { echo 50; return; }
    if [ -z "$cur" ] || [ -z "$max" ]; then echo 50; return; fi
    if [ "$max" -eq 0 ]; then echo 50; return; fi
    echo $(( cur * 100 / max ))
}

show_menu() {
    local cur
    cur=$(current_pct)
    echo -en "\0message\x1f Current: ${cur}%\n"

    local pct=$MIN
    while [ "$pct" -le 100 ]; do
        marker=" "
        if [ "$pct" -ge "$((cur - STEP/2))" ] && [ "$pct" -lt "$((cur + STEP/2 + (STEP%2)))" ]; then
            marker="●"
        fi
        printf "%s %s %3d%%\n" "$marker" "$(bar "$pct")" "$pct"
        pct=$(( pct + STEP ))
    done
}

# --- Entry point ---
if [ -z "${1:-}" ]; then
    echo -en "\0prompt\x1fBrightness\n"
    echo -en "\0no-custom\x1ftrue\n"
    show_menu
    exit 0
fi

pct="${1##* }"
pct="${pct%\%}"
if [[ "$pct" =~ ^[0-9]+$ ]]; then
    brightnessctl set "${pct}%" &>/dev/null
fi
