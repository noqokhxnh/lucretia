#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_audio_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

cleanup() {
    rm -f "$PIPE" 2>/dev/null
    [ -n "$MON_PID" ] && kill "$MON_PID" 2>/dev/null
    [ -n "$GREP_PID" ] && kill "$GREP_PID" 2>/dev/null
    wait 2>/dev/null
}
trap 'cleanup; exit 0' EXIT
trap 'cleanup; exit 143' TERM INT

LC_ALL=C pactl subscribe 2>/dev/null > "$PIPE" &
MON_PID=$!

grep -m 1 -E "on (sink|server) #" < "$PIPE" > /dev/null &
GREP_PID=$!

wait $GREP_PID 2>/dev/null

