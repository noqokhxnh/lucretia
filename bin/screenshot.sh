#!/usr/bin/env bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
exec "$SCRIPT_DIR/quickshell/scripts/screenshot.sh" "$@"