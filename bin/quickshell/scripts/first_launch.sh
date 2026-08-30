#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/caching.sh"
source "$SCRIPT_DIR/config.sh"

FLAG_FILE="$QS_STATE_DIR/first_launch.done"

if [ -f "$FLAG_FILE" ]; then
    exit 0
fi

mkdir -p "$QS_STATE_DIR"
touch "$FLAG_FILE"

sleep 1

WP_DIR="$(get_setting "wallpaperDir" "")"
if [ -z "$WP_DIR" ]; then
    WP_DIR="$(get_setting "wallpaper_dir" "")"
fi

if [ -n "$WP_DIR" ] && [ -d "$WP_DIR" ]; then
    RANDOM_WP="$(find "$WP_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) 2>/dev/null | shuf -n 1)"
    if [ -n "$RANDOM_WP" ]; then
        quickshell -p "$MAIN_QML" ipc call wallpaper setWallpaper "all" "$RANDOM_WP" "fade" >/dev/null 2>&1 || true

        quickshell -p "$MAIN_QML" ipc call matugen generate "$RANDOM_WP" "" "" >/dev/null 2>&1 || quickshell -p "$MAIN_QML" ipc call matugen generate "$RANDOM_WP" >/dev/null 2>&1 || true

    fi
fi

START_QML="$(find "$SERPANTINUM_DIR/quickshell" -type f -name "Start.qml" | head -n 1)"

if [ -n "$START_QML" ]; then
    export SERPANTINUM_TARGET_FILE="$START_QML"
    export SERPANTINUM_LAUNCH_ARGS=""
    quickshell -p "$SERPANTINUM_DIR/quickshell/Runner.qml"
fi

if [ -f "$SERPANTINUM_DIR/scripts/qs_manager.sh" ]; then
    bash "$SERPANTINUM_DIR/scripts/qs_manager.sh" open guide
fi
