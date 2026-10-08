#!/bin/bash
# volume.sh — rofi script-mode volume menu
# Deps: wpctl (WirePlumber/PipeWire)
#
# Device picker mirroring pavucontrol's Output Devices tab (already the
# right-click fallback for this module): lists real output sinks, marks
# the current default, and switches the default sink on selection.
# Per-device volume stepping is intentionally left out — hardware volume
# keys and waybar's scroll binding already call wpctl directly.

set -euo pipefail

THEME_DIR="$HOME/.config/rofi"
THEME="$THEME_DIR/shared.rasi"
POSITION="$THEME_DIR/position/bottom.rasi"

SINK="@DEFAULT_AUDIO_SINK@"

ICON_DEFAULT="󰓃"
ICON_SINK="󰓄"
ICON_MUTE_TOGGLE="󰖁 Toggle Mute"

notify() { notify-send -a "Volume" "$1" "${2:-}" 2>/dev/null || true; }

current_pct() {
    wpctl get-volume "$SINK" | awk '{printf "%d", $2 * 100}'
}

is_muted() {
    wpctl get-volume "$SINK" | grep -q MUTED
}

# Emits "<id>\x1f<default?>\x1f<name>\x1f<vol%>" per sink, in the order
# wpctl status lists them under "Sinks:".
list_sinks() {
    wpctl status | awk '
        /├─ Sinks:/ { insinks=1; next }
        /├─ Sources:/ { insinks=0 }
        insinks && /vol:/ { print }
    ' | while read -r line; do
        if [[ "$line" =~ ^\│[[:space:]]*(\*)?[[:space:]]*([0-9]+)\.[[:space:]]*(.+)[[:space:]]*\[vol:[[:space:]]*([0-9.]+)\] ]]; then
            default="${BASH_REMATCH[1]}"
            id="${BASH_REMATCH[2]}"
            name="$(echo "${BASH_REMATCH[3]}" | sed 's/[[:space:]]*$//')"
            vol="${BASH_REMATCH[4]}"
            pct=$(awk -v v="$vol" 'BEGIN{printf "%d", v*100}')
            printf '%s\x1f%s\x1f%s\x1f%s\n' "$id" "$default" "$name" "$pct"
        fi
    done
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

    list_sinks | while IFS=$'\x1f' read -r id default name pct; do
        icon="$ICON_SINK"
        [ "$default" = "*" ] && icon="$ICON_DEFAULT"
        printf "%s  %s  (%s%%)\n" "$icon" "$name" "$pct"
    done
}

id_for_name() {
    # `|| true`: awk exits as soon as it finds a match, which closes the
    # pipe early and SIGPIPEs list_sinks — under `set -o pipefail` that
    # would otherwise make this whole function (and the caller, under
    # `set -e`) fail even though the right id was found.
    list_sinks | awk -F'\x1f' -v n="$1" '$3==n{print $1; exit}' || true
}

set_default() {
    local name="$1"
    local id
    id=$(id_for_name "$name")
    [ -z "$id" ] && { notify "Device not found" "$name"; return; }

    if wpctl set-default "$id" &>/dev/null; then
        notify "Default output" "$name"
    else
        notify "Failed to switch" "$name"
    fi
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
        # Strip the leading icon + two spaces, then strip trailing " (NN%)"
        name="${1#* }"
        name="${name#* }"
        name="${name%  (*}"
        set_default "$name"
        ;;
esac
