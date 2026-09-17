#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# GLOBAL VARS
# -----------------------------------------------------------------------------
SCRIPTS_DIR="$HOME/.config/niri/bin/quickshell"
SHELL_QML_PATH="$SCRIPTS_DIR/Shell.qml"

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# Must be first — before any sourcing, caching, or pgrep.
# -----------------------------------------------------------------------------
ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    # Send IPC command directly to Main.qml via Quickshell's native IPC handler
    quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "close" "" "" >/dev/null 2>&1

    if [ "$XDG_CURRENT_DESKTOP" = "niri" ]; then
        if [[ "$TARGET" == "move" ]]; then
            niri msg action move-column-to-workspace "$ACTION" >/dev/null 2>&1
        else
            niri msg action focus-workspace "$ACTION" >/dev/null 2>&1
        fi
    else
        if [[ "$TARGET" == "move" ]]; then
            hyprctl dispatch "hl.dsp.window.move({ workspace = $ACTION })" >/dev/null 2>&1
        else
            hyprctl dispatch "hl.dsp.focus({ workspace = $ACTION })" >/dev/null 2>&1
        fi
    fi
    exit 0
fi

if [[ "$ACTION" == "close" ]]; then
    # Send IPC command directly to Main.qml via Quickshell's native IPC handler
    quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "close" "" "" >/dev/null 2>&1

    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        QS_RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/quickshell"
        BT_PID_FILE="$QS_RUN_DIR/bt_scan_pid"
        if [ -f "$BT_PID_FILE" ]; then
            kill $(cat "$BT_PID_FILE") 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
        pkill -f "bluetoothctl.*scan on" 2>/dev/null || true
        (timeout 2 bluetoothctl scan off > /dev/null 2>&1) &
    fi
    exit 0
fi

if [[ "$ACTION" == "widgetredactor" || "$ACTION" == "widgets" || "$TARGET" == "widgets" || "$TARGET" == "widgetredactor" ]]; then
    quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "close" "" "" >/dev/null 2>&1
    MONITOR=""
    if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
        MONITOR="$SUBTARGET"
    else
        MONITOR="$TARGET"
    fi
    [[ "$MONITOR" == "widgets" || "$MONITOR" == "widgetredactor" ]] && MONITOR=""

    QS_RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/quickshell"
    LUCRETIA_RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/lucretia"
    mkdir -p "$QS_RUN_DIR" "$LUCRETIA_RUN_DIR"
    if [[ -n "$MONITOR" ]]; then
        echo "$MONITOR" > "$QS_RUN_DIR/redactor_target_monitor"
        echo "$MONITOR" > "$LUCRETIA_RUN_DIR/redactor_target_monitor"
    fi

    for p in $(pgrep -f '[R]unner\.qml'); do [ "$p" != "$$" ] && [ "$p" != "$PPID" ] && kill "$p" 2>/dev/null; done

    QS_WIDGET_MONITOR="$MONITOR" LUCRETIA_TARGET_FILE="$SCRIPTS_DIR/widgets/WidgetRedactor.qml" SERPANTINUM_TARGET_FILE="$SCRIPTS_DIR/widgets/WidgetRedactor.qml" quickshell -p "$SCRIPTS_DIR/Runner.qml" >/dev/null 2>&1 &
    disown
    exit 0
fi


# -----------------------------------------------------------------------------
# SLOW PATH: Everything below only runs for non-workspace actions
# -----------------------------------------------------------------------------

source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"

qs_ensure_cache "workspaces"
qs_ensure_cache "network"
qs_ensure_cache "wallpaper_picker"

BT_PID_FILE="$QS_RUN_DIR/bt_scan_pid"
BT_SCAN_LOG="$QS_LOG_DIR/bt_scan.log"
SRC_DIR="${WALLPAPER_DIR:-${srcdir:-$HOME/Pictures/Wallpapers}}"
THUMB_DIR="$QS_CACHE_WALLPAPER_PICKER/thumbs"
PREP_LOCK="$QS_RUN_DIR/wallpaper_prep.lock"

export MAGICK_THREAD_LIMIT=1

QS_NETWORK_CACHE="$QS_CACHE_NETWORK"
mkdir -p "$QS_NETWORK_CACHE" "$THUMB_DIR"

NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"

MANIFEST="$THUMB_DIR/.manifest"

# -----------------------------------------------------------------------------
# ZOMBIE WATCHDOG
# Only runs on slow path — not on every workspace switch
# -----------------------------------------------------------------------------

PID_FILE="$QS_RUN_DIR/quickshell.pid"
SHOULD_START=true

if [ -f "$PID_FILE" ]; then
    QS_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$QS_PID" ] && kill -0 "$QS_PID" 2>/dev/null; then
        SHOULD_START=false
    fi
fi

if [ "$SHOULD_START" = true ]; then
    # If the pid file didn't exist or process was dead, check with pidof just in case
    if pidof quickshell >/dev/null; then
        pidof quickshell | tr ' ' '\n' | head -n 1 > "$PID_FILE"
    else
        mkdir -p "$HOME/.cache/lucretia"
        quickshell -p "$SHELL_QML_PATH" > "$HOME/.cache/lucretia/quickshell.log" 2>&1 &
        echo $! > "$PID_FILE"
        disown
    fi
fi

# -----------------------------------------------------------------------------
# HELPERS
# -----------------------------------------------------------------------------
build_manifest() {
    find "$THUMB_DIR" -maxdepth 1 -type f ! -name '.source_dir' ! -name '.manifest' \
        -printf "%f\n" | sort > "$MANIFEST"
}

handle_wallpaper_prep() {
    :
}

handle_network_prep() {
    echo "" > "$BT_SCAN_LOG"
    pkill -f "bluetoothctl.*scan on" 2>/dev/null || true
    (timeout 15 bluetoothctl scan on > "$BT_SCAN_LOG" 2>&1) &
    echo $! > "$BT_PID_FILE"
    (timeout 5 nmcli device wifi rescan) >/dev/null 2>&1 &
}

# -----------------------------------------------------------------------------
# IPC ROUTING
# -----------------------------------------------------------------------------


if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    if [[ "$TARGET" == "network" ]]; then
        handle_network_prep
        [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
        quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "$ACTION" "$TARGET" "$SUBTARGET" >/dev/null 2>&1
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        handle_wallpaper_prep
        CURRENT_SRC=""

        # Detect current wallpaper from saved path, mpvpaper, video path, or awww cache
        for p in "$HOME/.cache/lucretia/wallpaper/current_wallpaper.path" \
                 "$QS_CACHE_DIR/wallpaper/current_wallpaper.path" \
                 "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.path"; do
            if [ -f "$p" ]; then
                SAVED_PATH=$(cat "$p" 2>/dev/null)
                if [ -n "$SAVED_PATH" ] && [ -f "$SAVED_PATH" ]; then
                    CURRENT_SRC="$SAVED_PATH"
                    break
                fi
            fi
        done

        if [ -z "$CURRENT_SRC" ]; then
            for p in "$HOME/.cache/lucretia/wallpaper/current_video.path" \
                     "$QS_CACHE_DIR/wallpaper/current_video.path" \
                     "$QS_CACHE_WALLPAPER_PICKER/current_video.path"; do
                if [ -f "$p" ]; then
                    SAVED_VID=$(cat "$p" 2>/dev/null)
                    if [ -n "$SAVED_VID" ] && [ -f "$SAVED_VID" ]; then
                        CURRENT_SRC="$SAVED_VID"
                        break
                    fi
                fi
            done
        fi

        if [ -z "$CURRENT_SRC" ] && pgrep mpvpaper > /dev/null 2>&1; then
            for pid in $(pgrep mpvpaper); do
                cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
                src=$(echo "$cmd" | grep -o "$SRC_DIR/[^ ]*")
                if [ -n "$src" ] && [ -f "$src" ]; then
                    CURRENT_SRC="$src"
                    break
                fi
            done
        fi

        # Fallback: read awww state cache (stores image path per monitor)
        if [ -z "$CURRENT_SRC" ] && [ -d "$HOME/.cache/awww" ]; then
            AWWS_VER_DIR=$(ls -td "$HOME/.cache/awww"/*/ 2>/dev/null | head -1)
            if [ -n "$AWWS_VER_DIR" ]; then
                for f in "$AWWS_VER_DIR"*; do
                    [ -f "$f" ] || continue
                    PATH_IN_FILE=$(cat "$f" | tr '\0' '\n' | tail -1)
                    case "$PATH_IN_FILE" in "$SRC_DIR"/*) CURRENT_SRC="$PATH_IN_FILE"; break ;; esac
                done
            fi
        fi

        TARGET_THUMB=""
        if [ -n "$CURRENT_SRC" ]; then
            BASE=$(basename "$CURRENT_SRC")
            EXT="${BASE##*.}"
            [[ "${EXT,,}" =~ ^(mp4|mkv|mov|webm)$ ]] && TARGET_THUMB="000_$BASE" || TARGET_THUMB="$BASE"
        fi

        quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "$ACTION" "$TARGET" "$TARGET_THUMB" >/dev/null 2>&1
    else
        quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "$ACTION" "$TARGET" "$SUBTARGET" >/dev/null 2>&1
    fi
    exit 0
fi
