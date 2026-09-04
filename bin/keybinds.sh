#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/niri/config.kdl"
BACKUP_FILE="$HOME/.config/niri/config.kdl.bak"

ACTION="$1"

backup_and_replace() {
    local tmp_file
    tmp_file=$(mktemp)
    cat > "$tmp_file"
    if [ -s "$tmp_file" ]; then
        [ -f "$CONFIG_FILE" ] && cp "$CONFIG_FILE" "$BACKUP_FILE"
        mv "$tmp_file" "$CONFIG_FILE"
        niri msg action load-config-file 2>/dev/null || true
    else
        rm -f "$tmp_file"
        echo "Error: Empty output generated, aborted." >&2
        return 1
    fi
}

case "$ACTION" in
    reload)
        niri msg action load-config-file 2>/dev/null || true
        ;;
    delete)
        COMBO="$2"
        [ -z "$COMBO" ] && { echo "Usage: $0 delete <combo>"; exit 1; }
        awk -v target="$COMBO" '
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            split(line, parts, /[[:space:]]*\{/)
            if (parts[1] == target) {
                next
            }
            print $0
        }
        ' "$CONFIG_FILE" | backup_and_replace
        ;;
    update)
        OLD_COMBO="$2"
        NEW_COMBO="$3"
        NEW_ACTION="$4"
        [ -z "$OLD_COMBO" ] || [ -z "$NEW_COMBO" ] || [ -z "$NEW_ACTION" ] && { echo "Usage: $0 update <old_combo> <new_combo> <action>"; exit 1; }
        
        awk -v old="$OLD_COMBO" -v new="$NEW_COMBO" -v act="$NEW_ACTION" '
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            split(line, parts, /[[:space:]]*\{/)
            curr = parts[1]
            if (curr == old) {
                print "    " new " { " act " }"
            } else if (old != new && curr == new) {
                next
            } else {
                print $0
            }
        }
        ' "$CONFIG_FILE" | backup_and_replace
        ;;
    add)
        NEW_COMBO="$2"
        NEW_ACTION="$3"
        [ -z "$NEW_COMBO" ] || [ -z "$NEW_ACTION" ] && { echo "Usage: $0 add <combo> <action>"; exit 1; }
        
        awk -v new="$NEW_COMBO" -v act="$NEW_ACTION" '
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            split(line, parts, /[[:space:]]*\{/)
            if (parts[1] == new) {
                next
            }
            print $0
            if ($0 ~ /^[[:space:]]*binds[[:space:]]*\{/) {
                print "    " new " { " act " }"
            }
        }
        ' "$CONFIG_FILE" | backup_and_replace
        ;;
    reset)
        if [ -f "$BACKUP_FILE" ]; then
            cp "$BACKUP_FILE" "$CONFIG_FILE"
            niri msg action load-config-file 2>/dev/null || true
        fi
        ;;
    write)
        backup_and_replace
        ;;
    *)
        echo "Usage: $0 {reload|delete <combo>|update <old> <new> <action>|add <combo> <action>|reset|write}"
        exit 1
        ;;
esac
