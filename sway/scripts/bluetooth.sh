#!/bin/bash
# bluetooth.sh — rofi script-mode Bluetooth menu
# Deps: bluetoothctl (BlueZ)
#
# SCOPE: connect/disconnect already-PAIRED devices only. Pairing new
# devices is a separate, much fiddlier flow (scan timing, agent
# capability, PIN entry) — deliberately out of scope here, same as the
# WiFi script doesn't do enterprise/EAP setup. Pair new hardware with
# `bluetoothctl` directly or `blueman-manager` (already a fallback
# bound in your config: bindsym ... blueman-manager via waybar on-click).

set -euo pipefail

THEME_DIR="$HOME/.config/rofi"
THEME="$THEME_DIR/shared.rasi"
POSITION="$THEME_DIR/position/bottom.rasi"

ICON_CONNECTED="󰂱"
ICON_PAIRED="󰂯"
ICON_POWER_ON="󰂲 Power: turning on"
ICON_POWER_OFF="󰂲 Turn Bluetooth off"
ICON_POWER_ON_LABEL="󰂯 Turn Bluetooth on"
ICON_MANAGER="󰍉 Open Bluetooth Manager"

notify() { notify-send -a "Bluetooth" "$1" "${2:-}" 2>/dev/null || true; }

is_powered() {
    bluetoothctl show | grep -q "Powered: yes"
}

show_menu() {
    if ! is_powered; then
        echo -en "\0message\x1f Bluetooth is off\n"
        echo "$ICON_POWER_ON_LABEL"
        echo "$ICON_MANAGER"
        return
    fi

    echo -en "\0message\x1f Bluetooth is on\n"

    bluetoothctl devices Paired | while read -r _ mac name; do
        if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
            printf "%s  %s\n" "$ICON_CONNECTED" "$name"
        else
            printf "%s  %s\n" "$ICON_PAIRED" "$name"
        fi
    done

    echo "$ICON_POWER_OFF"
    echo "$ICON_MANAGER"
}

mac_for_name() {
    bluetoothctl devices Paired | awk -v n="$1" '
        { mac=$2; $1=""; $2=""; sub(/^  /,""); if ($0==n) print mac }
    '
}

toggle_device() {
    local name="$1"
    local mac
    mac=$(mac_for_name "$name")
    [ -z "$mac" ] && { notify "Device not found" "$name"; return; }

    if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
        if bluetoothctl disconnect "$mac" &>/dev/null; then
            notify "Disconnected" "$name"
        else
            notify "Failed to disconnect" "$name"
        fi
    else
        if bluetoothctl connect "$mac" &>/dev/null; then
            notify "Connected" "$name"
        else
            notify "Failed to connect" "$name (device may be off/out of range)"
        fi
    fi
}

# --- Entry point ---
if [ -z "${1:-}" ]; then
    echo -en "\0prompt\x1fBluetooth\n"
    echo -en "\0no-custom\x1ftrue\n"
    show_menu
    exit 0
fi

case "$1" in
    "$ICON_POWER_OFF")
        bluetoothctl power off &>/dev/null
        notify "Bluetooth off"
        ;;
    "$ICON_POWER_ON_LABEL")
        bluetoothctl power on &>/dev/null
        sleep 1
        show_menu
        ;;
    "$ICON_MANAGER")
        blueman-manager &>/dev/null & disown
        ;;
    *)
        name="${1#* }"
        name="${name# }"
        toggle_device "$name"
        ;;
esac
