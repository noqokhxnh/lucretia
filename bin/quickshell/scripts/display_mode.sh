#!/usr/bin/env bash
# Wrapper for display_mode.py
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$DIR/display_mode.py" "$@"
