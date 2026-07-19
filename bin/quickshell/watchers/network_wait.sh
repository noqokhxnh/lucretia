#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_network_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

cleanup() {
    rm -f "$PIPE" 2>/dev/null
    [ -n "$MON_PID" ] && kill "$MON_PID" 2>/dev/null
    [ -n "$GREP_PID" ] && kill "$GREP_PID" 2>/dev/null
    wait 2>/dev/null
}
trap 'cleanup; exit 0' EXIT
trap 'cleanup; exit 143' TERM INT

LC_ALL=C nmcli monitor 2>/dev/null > "$PIPE" &
MON_PID=$!

grep -m 1 -iwE "connected|disconnected|enabled|disabled|activated|deactivated|available|unavailable" < "$PIPE" > /dev/null &
GREP_PID=$!

wait $GREP_PID 2>/dev/null

