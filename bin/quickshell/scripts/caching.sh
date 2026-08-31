#!/usr/bin/env bash

if [ -z "$LUCRETIA_DIR" ]; then
    if [ -n "$SERPANTINUM_DIR" ]; then
        export LUCRETIA_DIR="$SERPANTINUM_DIR"
    else
        SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
        export LUCRETIA_DIR="$(dirname "$SCRIPT_DIR")"
    fi
fi
export SERPANTINUM_DIR="$LUCRETIA_DIR"

if [ -d "$LUCRETIA_DIR/quickshell" ]; then
    export QS_DIR="$LUCRETIA_DIR/quickshell"
else
    export QS_DIR="$LUCRETIA_DIR"
fi
export MAIN_QML="$QS_DIR/Shell.qml"
export IPC_SOCKET="${XDG_RUNTIME_DIR:-/tmp}/lucretia.sock"

export QS_CACHE_DIR="$HOME/.cache/lucretia"
export QS_STATE_DIR="$HOME/.local/state/lucretia"
export QS_RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/lucretia"
export QS_LOG_DIR="$QS_RUN_DIR/logs"
export QS_SETTINGS="$HOME/.config/lucretia/settings.json"

[[ -d "$QS_LOG_DIR" && -d "$QS_CACHE_DIR" && -d "$QS_STATE_DIR" ]] || mkdir -p "$QS_CACHE_DIR" "$QS_STATE_DIR" "$QS_RUN_DIR" "$QS_LOG_DIR"

qs_ensure_cache() {
    local WIDGET_NAME="$1"
    
    local WIDGET_UPPER="${WIDGET_NAME^^}"
    
    local WIDGET_CACHE="$QS_CACHE_DIR/$WIDGET_NAME"
    local WIDGET_STATE="$QS_STATE_DIR/$WIDGET_NAME"
    local WIDGET_RUN="$QS_RUN_DIR/$WIDGET_NAME"
    
    [[ -d "$WIDGET_RUN" && -d "$WIDGET_STATE" && -d "$WIDGET_CACHE" ]] || mkdir -p "$WIDGET_CACHE" "$WIDGET_STATE" "$WIDGET_RUN"
    
    export "QS_CACHE_${WIDGET_UPPER}=$WIDGET_CACHE"
    export "QS_STATE_${WIDGET_UPPER}=$WIDGET_STATE"
    export "QS_RUN_${WIDGET_UPPER}=$WIDGET_RUN"
}

if [ -d "$QS_DIR" ]; then
    for dir in "$QS_DIR"/*/; do
        [ -d "$dir" ] || continue
        
        dir_trimmed="${dir%/}"
        WIDGET_NAME="${dir_trimmed##*/}"
        
        qs_ensure_cache "$WIDGET_NAME"
    done
fi

qs_ensure_cache "focustime"
