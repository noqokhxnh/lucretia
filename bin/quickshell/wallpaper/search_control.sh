#!/usr/bin/env bash
ACTION="$1"
RUN_DIR="$2"

mkdir -p "$RUN_DIR"
echo "$ACTION" > "$RUN_DIR/ddg_search_control"

if [ "$ACTION" = "stop" ]; then
    for p in $(pgrep -f ddg_search.sh); do
        if [ "$p" != "$$" ] && [ "$p" != "$BASHPID" ]; then
            kill -9 "$p" 2>/dev/null || true
        fi
    done
    pkill -f "[g]et_ddg_links.py" 2>/dev/null || true
fi
