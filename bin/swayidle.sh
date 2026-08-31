#!/usr/bin/env bash
# Dynamic idle daemon for niri with AC & Battery awareness

SETTINGS_FILE="$HOME/.config/lucretia/settings.json"

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

# Default timeouts in minutes
SCREEN_OFF_MIN=5
LOCK_MIN=10
SLEEP_MIN=60

if [ -f "$SETTINGS_FILE" ]; then
    s_off=$(jq -r '.idleScreenOffTimeout // empty' "$SETTINGS_FILE" 2>/dev/null)
    s_lock=$(jq -r '.idleLockTimeout // empty' "$SETTINGS_FILE" 2>/dev/null)
    s_sleep=$(jq -r '.idleSleepTimeout // empty' "$SETTINGS_FILE" 2>/dev/null)

    [[ "$s_off" =~ ^[0-9]+$ ]] && SCREEN_OFF_MIN="$s_off"
    [[ "$s_lock" =~ ^[0-9]+$ ]] && LOCK_MIN="$s_lock"
    [[ "$s_sleep" =~ ^[0-9]+$ ]] && SLEEP_MIN="$s_sleep"
fi

# Convert to seconds
SCREEN_OFF_SEC=$((SCREEN_OFF_MIN * 60))
LOCK_SEC=$((LOCK_MIN * 60))
SLEEP_SEC=$((SLEEP_MIN * 60))

# Aggressive power-saving timeouts when running on battery (only cap enabled timers)
if [ "$AC_STATUS" = "0" ]; then
    # Battery mode: Screen off max 3m (180s), Lock max 5m (300s), Suspend max 15m (900s)
    [ "$SCREEN_OFF_SEC" -gt 180 ] && SCREEN_OFF_SEC=180
    [ "$LOCK_SEC" -gt 300 ] && LOCK_SEC=300
    [ "$SLEEP_SEC" -gt 900 ] && SLEEP_SEC=900
fi

# Build swayidle arguments dynamically (0 = disabled / Never)
ARGS=("-w")

if [ "$SCREEN_OFF_SEC" -gt 0 ]; then
    [ "$SCREEN_OFF_SEC" -lt 30 ] && SCREEN_OFF_SEC=30
    ARGS+=(timeout "$SCREEN_OFF_SEC" 'niri msg action power-off-monitors' resume 'niri msg action power-on-monitors')
fi

if [ "$LOCK_SEC" -gt 0 ]; then
    [ "$LOCK_SEC" -lt 30 ] && LOCK_SEC=30
    ARGS+=(timeout "$LOCK_SEC" 'loginctl lock-session')
fi

if [ "$SLEEP_SEC" -gt 0 ]; then
    [ "$SLEEP_SEC" -lt 60 ] && SLEEP_SEC=60
    ARGS+=(timeout "$SLEEP_SEC" 'systemctl suspend')
fi

ARGS+=(before-sleep 'loginctl lock-session')

echo "[swayidle] Starting with timeouts: ScreenOff=${SCREEN_OFF_SEC}s, Lock=${LOCK_SEC}s, Suspend=${SLEEP_SEC}s (AC=${AC_STATUS})"

exec swayidle "${ARGS[@]}"
