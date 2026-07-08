#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

# Singleton lock: chỉ 1 instance kb_wait.sh được chạy cùng lúc
# LOCK="$QS_RUN_DIR/qs_kb_wait.lock"
# exec 9>"$LOCK"
# flock -n 9 || { sleep infinity; exit 0; }

PIPE="$QS_RUN_DIR/qs_kb_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

MONITOR_PID=""

cleanup() {
    rm -f "$PIPE"
    pkill -P $$ 2>/dev/null
}
trap 'cleanup' EXIT; trap 'cleanup; exit 143' TERM INT

if [ -n "$NIRI_SOCKET" ]; then
    LC_ALL=C niri msg -j event-stream 2>/dev/null | grep --line-buffered -E '"KeyboardLayoutsChanged"|"KeyboardLayoutSwitched"' > "$PIPE" &
else
    sleep 10 > "$PIPE" &
fi

# Skip the first match, which is the initial state dumped by niri msg on startup
read -r _ < "$PIPE"

# Block until the next actual keyboard layout change event occurs
read -r _ < "$PIPE"
sleep 0.05
