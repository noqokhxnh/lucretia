#!/usr/bin/env bash

# Prevent duplicate instances of this script
LOCKFILE="/tmp/battery_power_saver.lock"
if [ -e "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "battery_power_saver.sh is already running with PID $PID"
        exit 0
    fi
fi
echo "$$" > "$LOCKFILE"

# Clean up lockfile on exit
trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT

# Config and state files
SETTINGS_FILE="$HOME/.config/niri/settings.json"
PREV_AUTO_POWER_FILE="/tmp/battery_saver_prev_auto_power_mode"
PREV_BRIGHTNESS_FILE="/tmp/battery_saver_prev_brightness"
PREV_KBD_FILE="/tmp/battery_saver_prev_kbd"

# Resolve the AC online path dynamically
if [ -f "/tmp/mock_ac_online" ]; then
    AC_PATH="/tmp/mock_ac_online"
else
    AC_TYPE_PATH=$(grep -l "Mains" /sys/class/power_supply/*/type | head -n1)
    if [ -n "$AC_TYPE_PATH" ]; then
        AC_PATH="$(dirname "$AC_TYPE_PATH")/online"
    else
        AC_PATH="/sys/class/power_supply/AC0/online"
    fi
fi

# Track current state
PREV_STATUS=""

update_setting_bool() {
    local key="$1"
    local val="$2"
    if [ -f "$SETTINGS_FILE" ]; then
        jq --arg key "$key" --argjson val "$val" '. + {($key): $val}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    fi
}

update_setting_str() {
    local key="$1"
    local val="$2"
    if [ -f "$SETTINGS_FILE" ]; then
        jq --arg key "$key" --arg val "$val" '. + {($key): $val}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    fi
}

get_monitor_info() {
    # Find internal display name (typically matches eDP-* or LVDS-*)
    local monitor=$(wlr-randr | grep -oE '^(eDP-[0-9]+|LVDS-[0-9]+)' | head -n1)
    if [ -z "$monitor" ]; then
        monitor=$(wlr-randr | grep -B1 'Enabled: yes' | grep -oE '^[a-zA-Z0-9-]+' | head -n1)
    fi
    echo "$monitor"
}

apply_power_saving() {
    echo "[Battery Saver] Applying power saving optimizations..."

    # 1. Save and disable Quickshell's autoPowerMode to keep power-saver active
    if [ -f "$SETTINGS_FILE" ]; then
        if [ ! -f "$PREV_AUTO_POWER_FILE" ]; then
            local current_auto=$(jq -r '.autoPowerMode' "$SETTINGS_FILE")
            echo "$current_auto" > "$PREV_AUTO_POWER_FILE"
        fi
        update_setting_bool "autoPowerMode" "false"
    fi

    # 2. Set power profile to power-saver
    powerprofilesctl set power-saver
    update_setting_str "powerProfile" "power-saver"

    # 3. Disable animations in Niri
    niri msg action disable-animations

    # 4. Reduce refresh rate of the internal display to the lowest supported
    local mon=$(get_monitor_info)
    if [ -n "$mon" ]; then
        local current_res=$(wlr-randr --output "$mon" | grep 'current' | awk '{print $1}')
        if [ -n "$current_res" ]; then
            # Extract all rates for that resolution
            local rates=($(wlr-randr --output "$mon" | grep "$current_res" | grep -oE '[0-9]+\.[0-9]+' | sort -n))
            if [ ${#rates[@]} -gt 0 ]; then
                local low_rate=${rates[0]}
                echo "[Battery Saver] Setting $mon refresh rate to ${low_rate}Hz"
                wlr-randr --output "$mon" --mode "${current_res}@${low_rate}"
            fi
        fi
    fi

    # 5. Save screen brightness and lower to 30%
    if which brightnessctl >/dev/null 2>&1; then
        if [ ! -f "$PREV_BRIGHTNESS_FILE" ]; then
            local cur_brightness=$(brightnessctl -m | awk -F, '{print substr($4, 1, length($4)-1)}')
            echo "$cur_brightness" > "$PREV_BRIGHTNESS_FILE"
        fi
        brightnessctl set 30%

        # Find and turn off keyboard backlight
        local kbd_dev=$(brightnessctl -l | grep -oE "Device '[^']*(kbd|keyboard)[^']*'" | head -n1 | cut -d"'" -f2)
        if [ -n "$kbd_dev" ]; then
            if [ ! -f "$PREV_KBD_FILE" ]; then
                local cur_kbd=$(brightnessctl --device="$kbd_dev" -m | awk -F, '{print substr($4, 1, length($4)-1)}')
                echo "$cur_kbd" > "$PREV_KBD_FILE"
            fi
            brightnessctl --device="$kbd_dev" set 0
        fi
    fi

    # 6. Send notification
    notify-send -r 99103 -u low "Chế độ Tiết kiệm Pin" "Đã tắt hiệu ứng chuyển động, giảm tần số quét màn hình và bật Power Saver."
}

apply_performance() {
    echo "[Battery Saver] Restoring performance/balanced settings..."

    # 1. Restore Quickshell's autoPowerMode
    if [ -f "$PREV_AUTO_POWER_FILE" ]; then
        local prev_auto=$(cat "$PREV_AUTO_POWER_FILE")
        update_setting_bool "autoPowerMode" "$prev_auto"
        rm -f "$PREV_AUTO_POWER_FILE"
    else
        update_setting_bool "autoPowerMode" "true"
    fi

    # 2. Set power profile to balanced
    powerprofilesctl set balanced
    update_setting_str "powerProfile" "balanced"

    # 3. Enable animations in Niri
    niri msg action enable-animations

    # 4. Restore refresh rate of the internal display to the highest supported
    local mon=$(get_monitor_info)
    if [ -n "$mon" ]; then
        local current_res=$(wlr-randr --output "$mon" | grep 'current' | awk '{print $1}')
        if [ -n "$current_res" ]; then
            # Extract highest refresh rate
            local rates=($(wlr-randr --output "$mon" | grep "$current_res" | grep -oE '[0-9]+\.[0-9]+' | sort -rn))
            if [ ${#rates[@]} -gt 0 ]; then
                local high_rate=${rates[0]}
                echo "[Battery Saver] Restoring $mon refresh rate to ${high_rate}Hz"
                wlr-randr --output "$mon" --mode "${current_res}@${high_rate}"
            fi
        fi
    fi

    # 5. Restore screen brightness and keyboard backlight
    if which brightnessctl >/dev/null 2>&1; then
        if [ -f "$PREV_BRIGHTNESS_FILE" ]; then
            local prev_bright=$(cat "$PREV_BRIGHTNESS_FILE")
            brightnessctl set "${prev_bright}%"
            rm -f "$PREV_BRIGHTNESS_FILE"
        else
            brightnessctl set 80%
        fi

        # Restore keyboard backlight
        local kbd_dev=$(brightnessctl -l | grep -oE "Device '[^']*(kbd|keyboard)[^']*'" | head -n1 | cut -d"'" -f2)
        if [ -n "$kbd_dev" ]; then
            if [ -f "$PREV_KBD_FILE" ]; then
                local prev_kbd=$(cat "$PREV_KBD_FILE")
                brightnessctl --device="$kbd_dev" set "${prev_kbd}%"
                rm -f "$PREV_KBD_FILE"
            else
                brightnessctl --device="$kbd_dev" set 50%
            fi
        fi
    fi

    # 6. Send notification
    notify-send -r 99103 -u low "Đã cắm sạc" "Đã khôi phục các thiết lập hiệu năng và tần số quét màn hình."
}

echo "[Battery Saver] Daemon started. Monitoring AC power state & settings..."

# Main monitoring loop
while true; do
    # Read autoBatterySaver setting (default to true)
    AUTO_SAVER="true"
    if [ -f "$SETTINGS_FILE" ]; then
        AUTO_SAVER=$(jq -r '.autoBatterySaver' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$AUTO_SAVER" != "true" ] && [ "$AUTO_SAVER" != "false" ]; then
            AUTO_SAVER="true"
        fi
    fi

    # Read AC status
    AC_STATUS="1"
    if [ -f "$AC_PATH" ]; then
        AC_STATUS=$(cat "$AC_PATH")
    fi

    # Determine desired mode
    DESIRED_MODE="performance"
    if [ "$AC_STATUS" = "0" ] && [ "$AUTO_SAVER" = "true" ]; then
        DESIRED_MODE="saver"
    fi

    if [ "$DESIRED_MODE" != "$PREV_STATUS" ]; then
        if [ "$DESIRED_MODE" = "saver" ]; then
            apply_power_saving
        else
            # Only apply performance settings if it wasn't the very first run
            if [ -n "$PREV_STATUS" ]; then
                apply_performance
            fi
        fi
        PREV_STATUS="$DESIRED_MODE"
    fi
    sleep 3
done
