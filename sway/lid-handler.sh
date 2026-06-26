#!/bin/sh

# Check if any external output (not eDP-1) is connected and enabled
EXTERNAL_OUTPUT=$(swaymsg -t get_outputs | jq -r '.[] | select(.name!="eDP-1" and .active==true) | .name')

if [ -n "$EXTERNAL_OUTPUT" ]; then
    # External monitor is connected → turn off eDP-1
    swaymsg output eDP-1 disable
else
    # No external monitor → suspend
    systemctl suspend
fi

