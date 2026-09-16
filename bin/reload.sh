#!/usr/bin/env bash

SHELL_PATH="$HOME/.config/niri/bin/quickshell/Shell.qml"
DAEMON_PATH="$HOME/.config/niri/bin/quickshell/qs_daemon"

# 1. Reload Niri config
if command -v niri &>/dev/null; then
    niri msg action load-config-file 2>/dev/null || true
fi

# 2. Hard kill existing Quickshell, Daemon, and visualizer instances to prevent frozen/orphan states
killall -9 quickshell 2>/dev/null || pkill -9 -f "quickshell.*Shell.qml" 2>/dev/null || true
killall -9 qs_daemon 2>/dev/null || pkill -9 -f "qs_daemon" 2>/dev/null || true
killall -9 cava 2>/dev/null || true
pkill -f "workspaces.sh" 2>/dev/null || true

# 3. Clean runtime sockets and locks
QS_DIR="${XDG_RUNTIME_DIR:-/tmp}/quickshell"
LUC_DIR="${XDG_RUNTIME_DIR:-/tmp}/lucretia"
mkdir -p "$QS_DIR" "$LUC_DIR"
rm -f "$QS_DIR/qs_daemon.sock" "$QS_DIR"/qs_*.lock "$LUC_DIR/qs_daemon.sock" "$LUC_DIR"/qs_*.lock /tmp/quickshell_qs_daemon.sock 2>/dev/null || true

sleep 0.2

# 4. Start Quickshell (Shell.qml supervises and starts qs_daemon & workspaces.sh cleanly)
setsid -f quickshell -p "$SHELL_PATH" >/dev/null 2>&1

# 5. Notify user
if command -v notify-send &>/dev/null; then
    notify-send -a "Lucretia" -i "preferences-desktop" "Quickshell" "Đã nạp lại toàn bộ shell thành công!" -t 2000 2>/dev/null || true
fi
