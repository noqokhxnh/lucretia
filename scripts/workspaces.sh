#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CACHING & MIGRATION
# -----------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "workspaces"

# ============================================================================
# 1. ZOMBIE PREVENTION
# Kills any older instances of this script. When Quickshell reloads, 
# it can leave the old listener pipelines running in the background infinitely.
# ============================================================================
for pid in $(pgrep -f "workspaces.sh"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

# Cleanly kill immediate children (like niri event-stream) when the script exits normally
cleanup() {
    pkill -P $$ 2>/dev/null
}
trap cleanup EXIT SIGTERM SIGINT

# --- Special Cleanup for Network/Bluetooth ---
# The network toggle starts a background bluetooth scan that must be killed explicitly.
BT_PID_FILE="$QS_RUN_WORKSPACES/bt_scan_pid"

if [ -f "$BT_PID_FILE" ]; then
    kill $(cat "$BT_PID_FILE") 2>/dev/null
    rm -f "$BT_PID_FILE"
fi

# Ensure bluetooth scan is explicitly turned off (timeout prevents deadlocks on fresh installs)
(timeout 2 bluetoothctl scan off > /dev/null 2>&1) &
# ---------------------------------------------

# Configuration: Fallback to 8
SETTINGS_FILE="$HOME/.config/niri/settings.json"

print_workspaces() {
    # Dynamically read workspace count on each update
    SEQ_END=$(jq -r '.workspaceCount // 8' "$SETTINGS_FILE" 2>/dev/null)
    if ! [[ "$SEQ_END" =~ ^[0-9]+$ ]]; then
        SEQ_END=8
    fi

    # Get raw data with a timeout fallback
    spaces=$(timeout 2 niri msg -j workspaces 2>/dev/null)
    windows=$(timeout 2 niri msg -j windows 2>/dev/null)

    # Failsafe if niri crashes or returns empty
    if [ -z "$spaces" ] || [ -z "$windows" ]; then return; fi
    
    # Generate the JSON and write it atomically to prevent UI flickering
    echo "$spaces" | jq --unbuffered --argjson windows "$windows" --arg end "$SEQ_END" -c '
        # Map workspace ID to its index
        (map({key: (.id|tostring), value: .idx}) | from_entries) as $id_to_idx
        |
        # Map windows to their workspace indices and group by workspace index
        ([$windows[] | select(.workspace_id != null) | . + {workspace_idx: ($id_to_idx[.workspace_id|tostring])} | select(.workspace_idx != null)]
         | group_by(.workspace_idx)
         | map({((.[0].workspace_idx|tostring)): {count: length, last_focused: (map(select(.is_focused == true)) | .[0] // .[0])}})
         | add) as $w_map
        |
        # Get the active workspace index
        (map(select(.is_active == true or .is_focused == true)) | .[0].idx) as $active_idx
        |
        # Iterate from 1 to SEQ_END
        [range(1; ($end|tonumber) + 1)] | map(
            . as $i |
            ($w_map[$i|tostring]) as $w_info |
            # Determine state: active -> occupied -> empty
            (if $i == $active_idx then "active"
             elif ($w_info != null and $w_info.count > 0) then "occupied"
             else "empty" end) as $state |

            # Get window title for tooltip (if exists)
            (if $w_info != null and $w_info.last_focused != null then $w_info.last_focused.title else "Empty" end) as $win |

            {
                id: $i,
                state: $state,
                tooltip: $win
            }
        )
    ' > "$QS_RUN_WORKSPACES/workspaces.tmp"
    
    mv "$QS_RUN_WORKSPACES/workspaces.tmp" "$QS_RUN_WORKSPACES/workspaces.json"
}

# Print initial state
print_workspaces

# ============================================================================
# 2. THE EVENT DEBOUNCER
# Listen to Niri event-stream wrapped in an infinite loop
# ============================================================================
while true; do
    niri msg -j event-stream 2>/dev/null | while read -r line; do
        # Debounce: read and discard events arriving within a 50ms window
        while read -t 0.05 -r extra_line; do
            continue
        done
        print_workspaces
    done
    sleep 1
done
