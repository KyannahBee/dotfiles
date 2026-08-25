#!/usr/bin/env bash
# Swap the active colorscheme + wallpaper across sway/waybar/rofi/gtklock.
# Usage: colorschemes/switch.sh <name>
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${1:?Usage: switch.sh <colorscheme-name>}"
SCHEME_DIR="$DOTFILES_DIR/colorschemes/$SCHEME"

if [[ ! -d "$SCHEME_DIR" ]]; then
    echo "error: no colorscheme at $SCHEME_DIR" >&2
    exit 1
fi

for f in sway.conf waybar.css rofi.rasi gtklock.css wallpaper.jpg; do
    if [[ ! -e "$SCHEME_DIR/$f" ]]; then
        echo "error: $SCHEME_DIR/$f is missing" >&2
        exit 1
    fi
done

ln -sf "../colorschemes/$SCHEME/sway.conf"     "$DOTFILES_DIR/sway/colorscheme.conf"
ln -sf "../colorschemes/$SCHEME/waybar.css"    "$DOTFILES_DIR/waybar/colorscheme.css"
ln -sf "../colorschemes/$SCHEME/rofi.rasi"     "$DOTFILES_DIR/rofi/colorscheme.rasi"
ln -sf "../colorschemes/$SCHEME/gtklock.css"   "$DOTFILES_DIR/gtklock/colorscheme.css"
ln -sf "../colorschemes/$SCHEME/wallpaper.jpg" "$DOTFILES_DIR/sway/wallpaper.jpg"

# Kill the old waybar before reload — sway/config's exec_always block
# relaunches it, and reload alone would stack a second instance on
# top of the still-running old one.
pkill waybar || true
swaymsg reload

echo "Switched to colorscheme: $SCHEME"
