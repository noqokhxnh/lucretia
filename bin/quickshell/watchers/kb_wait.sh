#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_kb_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

cleanup() {
    rm -f "$PIPE" 2>/dev/null
    [ -n "$MON_PID" ] && kill "$MON_PID" 2>/dev/null
    [ -n "$READ_PID" ] && kill "$READ_PID" 2>/dev/null
    wait 2>/dev/null
}
trap 'cleanup; exit 0' EXIT
trap 'cleanup; exit 143' TERM INT

if [ -n "$NIRI_SOCKET" ]; then
    LC_ALL=C niri msg -j event-stream 2>/dev/null | grep --line-buffered -E '"KeyboardLayoutsChanged"|"KeyboardLayoutSwitched"' > "$PIPE" &
    MON_PID=$!
else
    sleep 10 > "$PIPE" &
    MON_PID=$!
fi

(
    # Skip the first match, which is the initial state dumped by niri msg on startup
    read -r _ < "$PIPE"
    # Block until the next actual keyboard layout change event occurs
    read -r _ < "$PIPE"
    sleep 0.05
) &
READ_PID=$!

wait $READ_PID 2>/dev/null

