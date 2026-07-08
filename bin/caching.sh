#!/usr/bin/env bash
export QS_CACHE_DIR="$HOME/.cache/quickshell"
export QS_STATE_DIR="$HOME/.local/state/quickshell"
export QS_RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/quickshell"
export QS_LOG_DIR="$QS_RUN_DIR/logs"

[ -d "$QS_LOG_DIR" ] || mkdir -p "$QS_CACHE_DIR" "$QS_STATE_DIR" "$QS_RUN_DIR" "$QS_LOG_DIR"

# Fast pure-bash SCRIPT_DIR
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
else
    SCRIPT_DIR="."
fi
QS_DIR="$SCRIPT_DIR/quickshell"

# Function to dynamically create and export cache directories for ANY module by request
qs_ensure_cache() {
    local WIDGET_NAME="$1"
    local WIDGET_UPPER="${WIDGET_NAME^^}"
    
    local WIDGET_CACHE="$QS_CACHE_DIR/$WIDGET_NAME"
    local WIDGET_STATE="$QS_STATE_DIR/$WIDGET_NAME"
    local WIDGET_RUN="$QS_RUN_DIR/$WIDGET_NAME"
    
    [ -d "$WIDGET_CACHE" ] || mkdir -p "$WIDGET_CACHE"
    [ -d "$WIDGET_STATE" ] || mkdir -p "$WIDGET_STATE"
    [ -d "$WIDGET_RUN" ] || mkdir -p "$WIDGET_RUN"
    
    export "QS_CACHE_${WIDGET_UPPER}=$WIDGET_CACHE"
    export "QS_STATE_${WIDGET_UPPER}=$WIDGET_STATE"
    export "QS_RUN_${WIDGET_UPPER}=$WIDGET_RUN"
}

# Pre-initialize for all existing QML widget folders in the main directory
if [ -d "$QS_DIR" ]; then
    for dir in "$QS_DIR"/*/; do
        [ -d "$dir" ] || continue
        # Strip trailing slash and get basename natively
        temp="${dir%/}"
        WIDGET_NAME="${temp##*/}"
        qs_ensure_cache "$WIDGET_NAME"
    done
fi
