#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

# Singleton lock: chỉ 1 instance network_wait.sh được chạy cùng lúc
# LOCK="$QS_RUN_DIR/qs_network_wait.lock"
# exec 9>"$LOCK"
# flock -n 9 || { sleep infinity; exit 0; }

PIPE="$QS_RUN_DIR/qs_network_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

MONITOR_PID=""

# Trap: dọn dẹp FIFO và kill toàn bộ process group của nmcli (tránh zombie/orphan)
cleanup() {
    rm -f "$PIPE"
    pkill -P $$ 2>/dev/null
}
trap 'cleanup' EXIT; trap 'cleanup; exit 143' TERM INT

LC_ALL=C nmcli monitor 2>/dev/null > "$PIPE" &

# Grep block cho đến khi có sự kiện mạng, sau đó thoát → trigger cleanup
grep -m 1 -iwE "connected|disconnected|enabled|disabled|activated|deactivated|available|unavailable" < "$PIPE" > /dev/null
