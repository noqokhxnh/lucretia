#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_bt_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

cleanup() {
    rm -f "$PIPE" 2>/dev/null
    [ -n "$PID1" ] && kill "$PID1" 2>/dev/null
    [ -n "$PID2" ] && kill "$PID2" 2>/dev/null
    [ -n "$READ_PID" ] && kill "$READ_PID" 2>/dev/null
    wait 2>/dev/null
}
trap 'cleanup; exit 0' EXIT
trap 'cleanup; exit 143' TERM INT

LC_ALL=C dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'" 2>/dev/null | grep --line-buffered 'string "Connected"' > "$PIPE" &
PID1=$!
LC_ALL=C dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Adapter1'" 2>/dev/null | grep --line-buffered 'string "Powered"' > "$PIPE" &
PID2=$!

read -r _ < "$PIPE" &
READ_PID=$!

wait $READ_PID 2>/dev/null || true
sleep 0.5

