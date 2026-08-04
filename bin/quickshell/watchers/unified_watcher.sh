#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

# Monitor runtime and cache directories for changes in a single loop
WATCH_DIRS=("$QS_RUN_DIR" "$QS_CACHE_DIR")

exec inotifywait -m -r -e create,delete,modify,close_write \
    --format '%w%f' \
    "${WATCH_DIRS[@]}" 2>/dev/null | while read -r filepath; do
    case "$filepath" in
        *"current_widget"*)
            echo "widget"
            ;;
        *"recording"*)
            echo "recording"
            ;;
        *"updater"*)
            echo "updater"
            ;;
        *"settings.json"*)
            echo "settings"
            ;;
        *"qs_colors.json"*)
            echo "colors"
            ;;
        *"keycast/enabled"*)
            echo "keycast"
            ;;
        *"dnd/state"*)
            echo "dnd"
            ;;
        *"workspaces.json"*)
            echo "workspaces"
            ;;
    esac
done
