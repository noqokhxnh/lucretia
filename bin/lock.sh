#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
qs_ensure_cache "lock"

quickshell -p "$QS_DIR/Shell.qml" ipc call lock activate
