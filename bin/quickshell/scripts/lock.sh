#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
qs_ensure_cache "lock"

quickshell -p $MAIN_QML ipc call lock activate 
