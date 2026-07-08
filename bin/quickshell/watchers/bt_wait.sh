#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

# Singleton lock: chỉ 1 instance bt_wait.sh được chạy cùng lúc
# LOCK="$QS_RUN_DIR/qs_bt_wait.lock"
# exec 9>"$LOCK"
# flock -n 9 || { sleep infinity; exit 0; }

PIPE="$QS_RUN_DIR/qs_bt_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

PID1="" PID2=""

cleanup() {
    rm -f "$PIPE"
    pkill -P $$ 2>/dev/null
}
trap 'cleanup' EXIT; trap 'cleanup; exit 143' TERM INT

LC_ALL=C dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'" 2>/dev/null | grep --line-buffered 'string "Connected"' > "$PIPE" &
LC_ALL=C dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Adapter1'" 2>/dev/null | grep --line-buffered 'string "Powered"' > "$PIPE" &

read -r _ < "$PIPE"
