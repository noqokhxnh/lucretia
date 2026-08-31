#!/usr/bin/env bash

SHELL_PATH="$HOME/.config/niri/bin/quickshell/Shell.qml"
DAEMON_PATH="$HOME/.config/niri/bin/quickshell/qs_daemon"

# 1. Reload Niri config
if command -v niri &>/dev/null; then
    niri msg action load-config-file 2>/dev/null || true
fi

# 2. Hard kill existing Quickshell and Daemon instances to prevent frozen/orphan states
killall -9 quickshell 2>/dev/null || pkill -9 -f "quickshell.*Shell.qml" 2>/dev/null || true
killall -9 qs_daemon 2>/dev/null || pkill -9 -f "qs_daemon" 2>/dev/null || true

sleep 0.15

# 3. Start C++ qs_daemon
if [ -f "$DAEMON_PATH" ]; then
    setsid -f "$DAEMON_PATH" >/dev/null 2>&1
fi

# 4. Start Quickshell
setsid -f quickshell -p "$SHELL_PATH" >/dev/null 2>&1

# 5. Notify user
if command -v notify-send &>/dev/null; then
    notify-send -a "Lucretia" -i "preferences-desktop" "Quickshell" "Đã nạp lại toàn bộ shell thành công!" -t 2000 2>/dev/null || true
fi
