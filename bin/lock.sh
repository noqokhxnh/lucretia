#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
qs_ensure_cache "lock"

action="activate"
if [ "$1" = "--static" ] || [ "$1" = "static" ]; then
    action="activateStatic"
fi

quickshell -p "$QS_DIR/Shell.qml" ipc call lock "$action"
