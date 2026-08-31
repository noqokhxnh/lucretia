#!/usr/bin/env bash

BASE_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [ -f "$BASE_DIR/../caching.sh" ]; then
    source "$BASE_DIR/../caching.sh"
elif [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/../caching.sh" ]; then
    source "$SCRIPT_DIR/../caching.sh"
fi

if [ -n "$MAIN_QML" ] && command -v quickshell &>/dev/null; then
    quickshell -p "$MAIN_QML" ipc call theme reloadColors >/dev/null 2>&1 &
fi

killall -USR1 .kitty-wrapped 2>/dev/null || killall -USR1 kitty 2>/dev/null || true

wait 2>/dev/null || true
