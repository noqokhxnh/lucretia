#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# 1. Flatten Matugen v4.0 Nested JSON for Quickshell (C++ helper)
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
FLATTEN_BIN="$SCRIPT_DIR/flatten_colors"
QS_JSON="$HOME/.config/niri/bin/quickshell/qs_colors.json"

if [ ! -x "$FLATTEN_BIN" ]; then
    bash "$SCRIPT_DIR/compile_flatten.sh" >/dev/null
fi

if [ -f "$QS_JSON" ]; then
    "$FLATTEN_BIN" "$QS_JSON"
fi

# ------------------------------------------------------------------------------
# 2. Atomic Flatten Output in Standard Text Configs
# ------------------------------------------------------------------------------
TEXT_FILES=(
    "$HOME/.config/niri/bin/quickshell/qs_colors.json"
    "$HOME/.config/kitty/kitty-matugen-colors.conf"
    "$HOME/.config/nvim/matugen_colors.lua"
    "$HOME/.config/cava/colors"
    "$HOME/.config/swayosd/style.css"
    "$HOME/.config/rofi/theme.rasi"
    "$HOME/.cache/matugen/colors-gtk.css"
    "$HOME/.config/qt5ct/colors/matugen.conf"
    "$HOME/.config/qt6ct/colors/matugen.conf"
    "$HOME/.config/qt5ct/qss/matugen-style.qss"
    "$HOME/.config/qt6ct/qss/matugen-style.qss"
    "$HOME/.config/niri/colors.conf"
)

for file in "${TEXT_FILES[@]}"; do
    if [ -f "$file" ] && [ -w "$file" ]; then
        sed -E 's/\{[[:space:]]*"color":[[:space:]]*"([^"]+)"[[:space:]]*\}/\1/g' "$file" > "${file}.tmp" 2>/dev/null && mv -f "${file}.tmp" "$file"
    fi
done

# ------------------------------------------------------------------------------
# 3. Asynchronous Non-Blocking App Reloads
# ------------------------------------------------------------------------------
(
    killall -USR1 kitty 2>/dev/null || true

    cat ~/.config/cava/config_base ~/.config/cava/colors > ~/.config/cava/config 2>/dev/null
    if pgrep -x "cava" > /dev/null; then
        killall -USR1 cava 2>/dev/null
    fi

    if pgrep -x "swayosd-server" > /dev/null; then
        killall swayosd-server 2>/dev/null
        swayosd-server --top-margin 0.9 --style "$HOME/.config/swayosd/style.css" > /dev/null 2>&1 &
    fi

    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null
        sleep 0.03
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null
        gsettings set org.gnome.desktop.interface color-scheme 'default' 2>/dev/null
        sleep 0.03
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
    fi

    if [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ] && command -v hyprctl &> /dev/null; then
        hyprctl reload 2>/dev/null || true
    elif [ "$XDG_CURRENT_DESKTOP" = "niri" ]; then
        niri msg action load-config-file 2>/dev/null || true
    fi
) &
