#!/usr/bin/env bash
# Dynamic idle daemon for niri with AC & Battery awareness

SETTINGS_FILE="${QS_SETTINGS:-$HOME/.config/lucretia/settings.json}"
[ -e "$SETTINGS_FILE" ] && SETTINGS_FILE="$(readlink -f "$SETTINGS_FILE" 2>/dev/null || echo "$SETTINGS_FILE")"
[ ! -f "$SETTINGS_FILE" ] && SETTINGS_FILE="$HOME/.config/niri/settings.json"

# Kill any existing swayidle instances to allow clean reloading
killall -q -9 swayidle 2>/dev/null || true
pkill -x -9 swayidle 2>/dev/null || true
# Wait briefly for process to exit
sleep 0.1

# Resolve AC power state
AC_STATUS=1
if [ -f "/tmp/mock_ac_online" ]; then
    AC_STATUS=$(cat "/tmp/mock_ac_online" 2>/dev/null || echo 1)
else
    AC_TYPE_PATH=$(grep -l "Mains" /sys/class/power_supply/*/type 2>/dev/null | head -n1)
    if [ -n "$AC_TYPE_PATH" ]; then
        AC_STATUS=$(cat "$(dirname "$AC_TYPE_PATH")/online" 2>/dev/null || echo 1)
    fi
fi

IDLE_ENABLED=true
MANUAL_INHIBIT=false

DIM_SEC=0
LOCK_SEC=0
SCREEN_OFF_SEC=0
SLEEP_SEC=0

DIM_CMD=""
DIM_RESUME_CMD=""
LOCK_CMD=""
SCREEN_OFF_CMD=""
SCREEN_OFF_RESUME_CMD=""
SLEEP_CMD=""

CUSTOM_ACTIONS_JSON="[]"

if [ -f "$SETTINGS_FILE" ]; then
    HAS_IDLE=$(jq -r 'has("idle")' "$SETTINGS_FILE" 2>/dev/null)
    if [ "$HAS_IDLE" = "true" ]; then
        IDLE_ENABLED=$(jq -r 'if .idle.enabled != null then .idle.enabled else true end' "$SETTINGS_FILE" 2>/dev/null)
        MANUAL_INHIBIT=$(jq -r 'if .idle.manualInhibit != null then .idle.manualInhibit else false end' "$SETTINGS_FILE" 2>/dev/null)

        # Dim
        dim_en=$(jq -r 'if .idle.actions.dim.enabled != null then .idle.actions.dim.enabled else true end' "$SETTINGS_FILE" 2>/dev/null)
        dim_to=$(jq -r '.idle.actions.dim.timeout // 120' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$dim_en" = "true" ] && [[ "$dim_to" =~ ^[0-9]+$ ]] && [ "$dim_to" -gt 0 ]; then
            DIM_SEC="$dim_to"
            DIM_CMD=$(jq -r '.idle.actions.dim.command // empty' "$SETTINGS_FILE" 2>/dev/null)
            DIM_RESUME_CMD=$(jq -r '.idle.actions.dim.resumeCommand // empty' "$SETTINGS_FILE" 2>/dev/null)
        fi

        # Lock
        lock_en=$(jq -r 'if .idle.actions.lock.enabled != null then .idle.actions.lock.enabled else true end' "$SETTINGS_FILE" 2>/dev/null)
        lock_to=$(jq -r '.idle.actions.lock.timeout // 300' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$lock_en" = "true" ] && [[ "$lock_to" =~ ^[0-9]+$ ]] && [ "$lock_to" -gt 0 ]; then
            LOCK_SEC="$lock_to"
            LOCK_CMD=$(jq -r '.idle.actions.lock.command // empty' "$SETTINGS_FILE" 2>/dev/null)
        fi

        # DPMS (Screen off)
        dpms_en=$(jq -r 'if .idle.actions.dpms.enabled != null then .idle.actions.dpms.enabled else true end' "$SETTINGS_FILE" 2>/dev/null)
        dpms_to=$(jq -r '.idle.actions.dpms.timeout // 360' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$dpms_en" = "true" ] && [[ "$dpms_to" =~ ^[0-9]+$ ]] && [ "$dpms_to" -gt 0 ]; then
            SCREEN_OFF_SEC="$dpms_to"
            SCREEN_OFF_CMD=$(jq -r '.idle.actions.dpms.command // empty' "$SETTINGS_FILE" 2>/dev/null)
            SCREEN_OFF_RESUME_CMD=$(jq -r '.idle.actions.dpms.resumeCommand // empty' "$SETTINGS_FILE" 2>/dev/null)
        fi

        # Suspend
        sleep_en=$(jq -r 'if .idle.actions.suspend.enabled != null then .idle.actions.suspend.enabled else false end' "$SETTINGS_FILE" 2>/dev/null)
        sleep_to=$(jq -r '.idle.actions.suspend.timeout // 600' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$sleep_en" = "true" ] && [[ "$sleep_to" =~ ^[0-9]+$ ]] && [ "$sleep_to" -gt 0 ]; then
            SLEEP_SEC="$sleep_to"
            SLEEP_CMD=$(jq -r '.idle.actions.suspend.command // empty' "$SETTINGS_FILE" 2>/dev/null)
        fi

        # Custom actions
        CUSTOM_ACTIONS_JSON=$(jq -c '.idle.customActions // []' "$SETTINGS_FILE" 2>/dev/null)
    else
        # Fallback to legacy flat keys (in minutes)
        s_off=$(jq -r '.idleScreenOffTimeout // empty' "$SETTINGS_FILE" 2>/dev/null)
        s_lock=$(jq -r '.idleLockTimeout // empty' "$SETTINGS_FILE" 2>/dev/null)
        s_sleep=$(jq -r '.idleSleepTimeout // empty' "$SETTINGS_FILE" 2>/dev/null)

        [[ "$s_off" =~ ^[0-9]+$ ]] && [ "$s_off" -gt 0 ] && SCREEN_OFF_SEC=$((s_off * 60))
        [[ "$s_lock" =~ ^[0-9]+$ ]] && [ "$s_lock" -gt 0 ] && LOCK_SEC=$((s_lock * 60))
        [[ "$s_sleep" =~ ^[0-9]+$ ]] && [ "$s_sleep" -gt 0 ] && SLEEP_SEC=$((s_sleep * 60))
    fi
fi

# Inhibit or disable check
if [ "$IDLE_ENABLED" != "true" ] || [ "$MANUAL_INHIBIT" = "true" ]; then
    echo "[swayidle] Idle is disabled or inhibited (enabled=$IDLE_ENABLED, manualInhibit=$MANUAL_INHIBIT)."
    exit 0
fi

# Aggressive power-saving timeouts when running on battery (only cap enabled timers)
if [ "$AC_STATUS" = "0" ]; then
    # Battery mode caps: Screen off max 3m (180s), Lock max 5m (300s), Suspend max 15m (900s)
    [ "$SCREEN_OFF_SEC" -gt 180 ] && SCREEN_OFF_SEC=180
    [ "$LOCK_SEC" -gt 300 ] && LOCK_SEC=300
    [ "$SLEEP_SEC" -gt 900 ] && SLEEP_SEC=900
fi

ARGS=("-w")

# Resolve actual lock command for logind lock event and idle timeout
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
DEFAULT_LOCK_BIN="$SCRIPT_DIR/lock.sh"
[ ! -x "$DEFAULT_LOCK_BIN" ] && DEFAULT_LOCK_BIN="$HOME/.config/niri/bin/lock.sh"

ACTUAL_LOCK_CMD="$DEFAULT_LOCK_BIN"
if [ -n "$LOCK_CMD" ] && [ "$LOCK_CMD" != "loginctl lock-session" ]; then
    ACTUAL_LOCK_CMD="$LOCK_CMD"
fi

# Register lock handler with logind: when loginctl lock-session or DBus Lock is received, invoke lock screen
ARGS+=(lock "$ACTUAL_LOCK_CMD")

# 1. Dimming action
if [ "$DIM_SEC" -gt 0 ]; then
    [ "$DIM_SEC" -lt 10 ] && DIM_SEC=10
    dim_exec="${DIM_CMD}"
    dim_res="${DIM_RESUME_CMD}"
    if [ -z "$dim_exec" ] && command -v brightnessctl &>/dev/null; then
        dim_exec="brightnessctl -s set 15%"
        dim_res="brightnessctl -r"
    fi
    if [ -n "$dim_exec" ]; then
        if [ -n "$dim_res" ]; then
            ARGS+=(timeout "$DIM_SEC" "$dim_exec" resume "$dim_res")
        else
            ARGS+=(timeout "$DIM_SEC" "$dim_exec")
        fi
    fi
fi

# 2. Lock action
if [ "$LOCK_SEC" -gt 0 ]; then
    [ "$LOCK_SEC" -lt 30 ] && LOCK_SEC=30
    lock_exec="${LOCK_CMD:-loginctl lock-session}"
    ARGS+=(timeout "$LOCK_SEC" "$lock_exec")
fi

# 3. DPMS (Turn display off) action
if [ "$SCREEN_OFF_SEC" -gt 0 ]; then
    [ "$SCREEN_OFF_SEC" -lt 30 ] && SCREEN_OFF_SEC=30
    dpms_exec="${SCREEN_OFF_CMD:-niri msg action power-off-monitors}"
    dpms_res="${SCREEN_OFF_RESUME_CMD:-niri msg action power-on-monitors}"
    ARGS+=(timeout "$SCREEN_OFF_SEC" "$dpms_exec" resume "$dpms_res")
fi

# 4. Suspend action
if [ "$SLEEP_SEC" -gt 0 ]; then
    [ "$SLEEP_SEC" -lt 60 ] && SLEEP_SEC=60
    sleep_exec="${SLEEP_CMD:-systemctl suspend}"
    ARGS+=(timeout "$SLEEP_SEC" "$sleep_exec")
fi

# 5. Custom actions
if [ -n "$CUSTOM_ACTIONS_JSON" ] && [ "$CUSTOM_ACTIONS_JSON" != "[]" ] && [ "$CUSTOM_ACTIONS_JSON" != "null" ]; then
    while read -r action; do
        act_en=$(echo "$action" | jq -r 'if .enabled != null then .enabled else true end')
        act_to=$(echo "$action" | jq -r '.timeout // 0')
        act_cmd=$(echo "$action" | jq -r '.command // empty')
        act_res=$(echo "$action" | jq -r '.resumeCommand // empty')
        if [ "$act_en" = "true" ] && [[ "$act_to" =~ ^[0-9]+$ ]] && [ "$act_to" -gt 0 ] && [ -n "$act_cmd" ]; then
            if [ -n "$act_res" ]; then
                ARGS+=(timeout "$act_to" "$act_cmd" resume "$act_res")
            else
                ARGS+=(timeout "$act_to" "$act_cmd")
            fi
        fi
    done < <(echo "$CUSTOM_ACTIONS_JSON" | jq -c '.[]' 2>/dev/null)
fi

# Before sleep hook
ARGS+=(before-sleep 'loginctl lock-session')

echo "[swayidle] Starting with: Dim=${DIM_SEC}s, Lock=${LOCK_SEC}s, ScreenOff=${SCREEN_OFF_SEC}s, Suspend=${SLEEP_SEC}s (AC=${AC_STATUS})"

exec swayidle "${ARGS[@]}"
