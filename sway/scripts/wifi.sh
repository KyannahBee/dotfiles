#!/bin/bash
# wifi.sh — rofi script-mode WiFi menu
# Deps: nmcli (NetworkManager)
#
# rofi script-mode protocol: each invocation prints the current menu list
# to stdout; rofi calls the script again with the selected line as $1.
# We use ROFI_RETV to distinguish "show initial list" vs "selection made".

set -euo pipefail

THEME_DIR="$HOME/.config/rofi"
THEME="$THEME_DIR/shared.rasi"
POSITION="$THEME_DIR/position/bottom.rasi"

ICON_CONNECTED="󰤨"
ICON_SAVED="󰤥"
ICON_OPEN="󰤩"
ICON_BACK="󰁍 Back"
ICON_RESCAN="󰑐 Rescan"
ICON_DISCONNECT="󰤭 Disconnect"

notify() { notify-send -a "WiFi" "$1" "${2:-}" 2>/dev/null || true; }

list_networks() {
    nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL device wifi list --rescan no 2>/dev/null \
        | awk -F: '{
            if ($2 == "" ) next   # skip hidden/blank SSIDs
            inuse = ($1 == "*") ? "*" : ""
            printf "%s\t%s\t%s\t%s\n", inuse, $2, $3, $4
        }' \
        | sort -t$'\t' -k1,1r -k4,4nr \
        | awk -F'\t' '!seen[$2]++ { print }'
}

show_menu() {
    local current
    current=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2; exit}')

    if [ -n "$current" ]; then
        echo -en "\0message\x1f Connected: $current\n"
    else
        echo -en "\0message\x1f Not connected\n"
    fi

    list_networks | while IFS=$'\t' read -r inuse ssid security signal; do
        icon="$ICON_SAVED"
        [ -z "$security" ] && icon="$ICON_OPEN"
        [ "$inuse" = "*" ] && icon="$ICON_CONNECTED"
        printf "%s  %s  (%s%%)\n" "$icon" "$ssid" "$signal"
    done

    echo "$ICON_RESCAN"
    [ -n "$current" ] && echo "$ICON_DISCONNECT"
}

connect_to() {
    local ssid="$1"
    local security
    security=$(nmcli -t -f SSID,SECURITY device wifi list --rescan no \
        | awk -F: -v s="$ssid" '$1==s{print $2; exit}')

    # KNOWN LIMITATION: assumes saved connection profile name == SSID.
    # True for any profile nmcli auto-created (the common case). False
    # if you've manually renamed a connection via `nmcli con modify` —
    # in that case this falls through to the password-prompt branch
    # below and creates a *second* profile with the SSID as its name.
    if nmcli -t -f NAME connection show | grep -qx "$ssid"; then
        if nmcli connection up "$ssid" &>/dev/null; then
            notify "Connected" "$ssid"
        else
            notify "Failed to connect" "$ssid (saved profile rejected — credentials may be stale)"
        fi
        return
    fi

    if [ -z "$security" ]; then
        # Open network, no password needed
        if nmcli device wifi connect "$ssid" &>/dev/null; then
            notify "Connected" "$ssid"
        else
            notify "Failed to connect" "$ssid"
        fi
        return
    fi

    # Secured network with no saved profile — prompt for password via a
    # second rofi invocation in password mode (not script mode).
    local pass
    pass=$(rofi -dmenu -password -p "Password for $ssid" \
        -theme "$THEME" -theme "$POSITION" -lines 0)
    [ -z "$pass" ] && return

    if nmcli device wifi connect "$ssid" password "$pass" &>/dev/null; then
        notify "Connected" "$ssid"
    else
        notify "Failed to connect" "$ssid (wrong password?)"
    fi
}

# --- Entry point ---
if [ -z "${1:-}" ]; then
    echo -en "\0prompt\x1fWiFi\n"
    echo -en "\0no-custom\x1ftrue\n"
    show_menu
    exit 0
fi

case "$1" in
    "$ICON_RESCAN")
        nmcli device wifi rescan &>/dev/null || true
        sleep 1
        show_menu
        ;;
    "$ICON_DISCONNECT")
        dev=$(nmcli -t -f device,type,state device | awk -F: '$2=="wifi" && $3=="connected"{print $1; exit}')
        [ -n "$dev" ] && nmcli device disconnect "$dev" &>/dev/null
        notify "Disconnected"
        ;;
    *)
        # Strip the leading icon + two spaces, then strip trailing " (NN%)"
        ssid="${1#* }"
        ssid="${ssid#* }"
        ssid="${ssid%  (*}"
        connect_to "$ssid"
        ;;
esac
