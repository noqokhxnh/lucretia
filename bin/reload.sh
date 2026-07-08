#!/usr/bin/env bash

# 1. Reload Niri configuration
niri msg action reload-config

# 2. Attempt to reload Quickshell via IPC (Soft Reload)
SHELL_PATH="$HOME/.config/niri/bin/quickshell/Shell.qml"
quickshell -p "$SHELL_PATH" ipc call main forceReload >/dev/null 2>&1

# 3. Give it a moment, then ensure it's actually running/fresh
# If the IPC failed or the shell is stuck, this hard restart will fix it.
sleep 0.5
if ! pgrep -f "quickshell.*Shell.qml" >/dev/null; then
    quickshell -p "$SHELL_PATH" >/dev/null 2>&1 &
    disown
fi

# Optional: Force a full restart if the user really wants a "Fresh" reload
# Uncomment the following lines if you prefer a hard restart every time:
# pkill -f "quickshell.*Shell.qml"
# sleep 0.3
# quickshell -p "$SHELL_PATH" >/dev/null 2>&1 &
# disown
