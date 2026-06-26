#!/bin/bash
# volume.sh — rofi script-mode volume menu
# Deps: wpctl (WirePlumber/PipeWire)
#
# DECIDED: static stepped list (Option A), not live arrow-key redraw.
# Rofi script mode has no real in-place redraw — any arrow-key-driven
# live stepping closes and reopens the window per step (visible flicker),
# which isn't fixable within script mode. Static list trades "feels like
# a slider" for reliability.

set -euo pipefail

THEME_DIR="$HOME/.config/rofi"
THEME="$THEME_DIR/shared.rasi"
POSITION="$THEME_DIR/position/bottom.rasi"

SINK="@DEFAULT_AUDIO_SINK@"
STEP=5      # percent per row
MAX=150     # wpctl allows >100%; cap the list at a sane ceiling

ICON_MUTE_TOGGLE="󰖁 Toggle Mute"

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
    wpctl get-volume "$SINK" | awk '{printf "%d", $2 * 100}'
}

is_muted() {
    wpctl get-volume "$SINK" | grep -q MUTED
}

show_menu() {
    local cur
    cur=$(current_pct)
    if is_muted; then
        echo -en "\0message\x1f Muted (was ${cur}%)\n"
    else
        echo -en "\0message\x1f Current: ${cur}%\n"
    fi

    echo "$ICON_MUTE_TOGGLE"

    local pct=0
    while [ "$pct" -le "$MAX" ]; do
        marker=" "
        # mark the row closest to current volume
        if [ "$pct" -ge "$((cur - STEP/2))" ] && [ "$pct" -lt "$((cur + STEP/2 + (STEP%2)))" ]; then
            marker="●"
        fi
        printf "%s %s %3d%%\n" "$marker" "$(bar "$pct")" "$pct"
        pct=$(( pct + STEP ))
    done
}

# --- Entry point ---
if [ -z "${1:-}" ]; then
    echo -en "\0prompt\x1fVolume\n"
    echo -en "\0no-custom\x1ftrue\n"
    show_menu
    exit 0
fi

case "$1" in
    "$ICON_MUTE_TOGGLE")
        wpctl set-mute "$SINK" toggle
        ;;
    *)
        # Extract trailing "NNN%" from the selected row
        pct="${1##* }"
        pct="${pct%\%}"
        if [[ "$pct" =~ ^[0-9]+$ ]]; then
            wpctl set-mute "$SINK" 0
            wpctl set-volume "$SINK" "${pct}%"
        fi
        ;;
esac
