#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
exec "$(dirname "$0")/focus_daemon" 

