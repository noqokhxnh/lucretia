#!/usr/bin/env bash

# Prevent duplicate instances of this script
LOCKFILE="/tmp/battery_power_saver.lock"
if [ -e "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "battery_power_saver.sh is already running with PID $PID"
        exit 0
    fi
fi
echo "$$" > "$LOCKFILE"

cleanup() {
    if [ "$PREV_STATUS" = "saver" ]; then
        apply_performance 2>/dev/null || true
    fi
    rm -f "$LOCKFILE"
    exit
}
trap cleanup INT TERM EXIT

# Config and state files
SETTINGS_FILE="$HOME/.config/niri/settings.json"
PREV_AUTO_POWER_FILE="/tmp/battery_saver_prev_auto_power_mode"
PREV_BRIGHTNESS_FILE="/tmp/battery_saver_prev_brightness"
PREV_KBD_FILE="/tmp/battery_saver_prev_kbd"

# Resolve the AC online path dynamically
if [ -f "/tmp/mock_ac_online" ]; then
    AC_PATH="/tmp/mock_ac_online"
else
    AC_TYPE_PATH=$(grep -l "Mains" /sys/class/power_supply/*/type 2>/dev/null | head -n1)
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
    local lock_path="${SETTINGS_FILE}.lock"
    if [ -f "$SETTINGS_FILE" ]; then
        ( flock 9; jq --arg key "$key" --argjson val "$val" '. + {($key): $val}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE" ) 9>"$lock_path"
    fi
}

update_setting_str() {
    local key="$1"
    local val="$2"
    local lock_path="${SETTINGS_FILE}.lock"
    if [ -f "$SETTINGS_FILE" ]; then
        ( flock 9; jq --arg key "$key" --arg val "$val" '. + {($key): $val}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE" ) 9>"$lock_path"
    fi
}

get_monitor_info() {
    # Find internal display name (typically matches eDP-* or LVDS-*)
    local monitor=$(wlr-randr 2>/dev/null | grep -oE '^(eDP-[0-9]+|LVDS-[0-9]+)' | head -n1)
    if [ -z "$monitor" ]; then
        monitor=$(wlr-randr 2>/dev/null | grep -B1 'Enabled: yes' | grep -oE '^[a-zA-Z0-9-]+' | head -n1)
    fi
    echo "$monitor"
}

apply_hardware_powersave() {
    # Wi-Fi Power Save
    for iface in $(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}'); do
        iw dev "$iface" set power_save on 2>/dev/null || true
    done

    # Audio Codec Power Save
    if [ -w /sys/module/snd_hda_intel/parameters/power_save ]; then
        echo 1 > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || true
    fi

    # Runtime PM for PCI devices
    for dev in /sys/bus/pci/devices/*/power/control; do
        if [ -w "$dev" ]; then
            echo auto > "$dev" 2>/dev/null || true
        fi
    done
}

apply_power_saving() {
    echo "[Battery Saver] Applying power saving optimizations..."

    # 1. Save and disable Quickshell's autoPowerMode to prevent aggressive CPU spikes
    if [ -f "$SETTINGS_FILE" ]; then
        if [ ! -f "$PREV_AUTO_POWER_FILE" ]; then
            local current_auto=$(jq -r '.autoPowerMode // true' "$SETTINGS_FILE" 2>/dev/null)
            echo "$current_auto" > "$PREV_AUTO_POWER_FILE"
        fi
        update_setting_bool "autoPowerMode" "false"
    fi

    # 2. Set power profile to power-saver (EPP: power on AMD P-State)
    powerprofilesctl set power-saver 2>/dev/null || true
    update_setting_str "powerProfile" "power-saver"

    # 3. Disable animations in Niri
    niri msg action disable-animations 2>/dev/null || true

    # 4. Reduce refresh rate of internal display to lowest supported (e.g. 48Hz)
    local mon=$(get_monitor_info)
    if [ -n "$mon" ]; then
        local current_res=$(wlr-randr --output "$mon" 2>/dev/null | grep 'current' | awk '{print $1}')
        if [ -n "$current_res" ]; then
            local rates=($(wlr-randr --output "$mon" 2>/dev/null | grep "$current_res" | grep -oE '[0-9]+\.[0-9]+' | sort -n))
            if [ ${#rates[@]} -gt 0 ]; then
                local low_rate=${rates[0]}
                echo "[Battery Saver] Setting $mon refresh rate to ${low_rate}Hz"
                wlr-randr --output "$mon" --mode "${current_res}@${low_rate}" 2>/dev/null || true
            fi
        fi
    fi

    # 5. Save screen brightness and lower to 30% if currently higher
    if which brightnessctl >/dev/null 2>&1; then
        local cur_brightness=$(brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}')
        if [ -n "$cur_brightness" ]; then
            if [ ! -f "$PREV_BRIGHTNESS_FILE" ]; then
                echo "$cur_brightness" > "$PREV_BRIGHTNESS_FILE"
            fi
            if [ "$cur_brightness" -gt 30 ]; then
                brightnessctl set 30% 2>/dev/null || true
            fi
        fi

        # Find and turn off keyboard backlight
        local kbd_dev=$(brightnessctl -l 2>/dev/null | grep -oE "Device '[^']*(kbd|keyboard)[^']*'" | head -n1 | cut -d"'" -f2)
        if [ -n "$kbd_dev" ]; then
            if [ ! -f "$PREV_KBD_FILE" ]; then
                local cur_kbd=$(brightnessctl --device="$kbd_dev" -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}')
                echo "$cur_kbd" > "$PREV_KBD_FILE"
            fi
            brightnessctl --device="$kbd_dev" set 0 2>/dev/null || true
        fi
    fi

    # 6. Apply hardware and peripheral power savings
    apply_hardware_powersave

    # 7. Reload swayidle with battery-aware idle timers (3m screen off, 5m lock, 15m suspend)
    if [ -f "$HOME/.config/niri/bin/swayidle.sh" ]; then
        bash "$HOME/.config/niri/bin/swayidle.sh" >/dev/null 2>&1 &
    fi

    # 8. Send notification
    notify-send -r 99103 -u low "Chế độ Tiết kiệm Pin" "Đã chuyển sang Power Saver, giảm tần số quét 48Hz và tối ưu hóa thời lượng pin."
}

apply_performance() {
    echo "[Battery Saver] Restoring performance/balanced settings..."

    # 1. Restore Quickshell's autoPowerMode
    if [ -f "$PREV_AUTO_POWER_FILE" ]; then
        local prev_auto=$(cat "$PREV_AUTO_POWER_FILE" 2>/dev/null)
        [ "$prev_auto" != "true" ] && [ "$prev_auto" != "false" ] && prev_auto="true"
        update_setting_bool "autoPowerMode" "$prev_auto"
        rm -f "$PREV_AUTO_POWER_FILE"
    else
        update_setting_bool "autoPowerMode" "true"
    fi

    # 2. Set power profile to balanced
    powerprofilesctl set balanced 2>/dev/null || true
    update_setting_str "powerProfile" "balanced"

    # 3. Enable animations in Niri
    niri msg action enable-animations 2>/dev/null || true

    # 4. Restore refresh rate of internal display to highest supported (60Hz / max)
    local mon=$(get_monitor_info)
    if [ -n "$mon" ]; then
        local current_res=$(wlr-randr --output "$mon" 2>/dev/null | grep 'current' | awk '{print $1}')
        if [ -n "$current_res" ]; then
            local rates=($(wlr-randr --output "$mon" 2>/dev/null | grep "$current_res" | grep -oE '[0-9]+\.[0-9]+' | sort -rn))
            if [ ${#rates[@]} -gt 0 ]; then
                local high_rate=${rates[0]}
                echo "[Battery Saver] Restoring $mon refresh rate to ${high_rate}Hz"
                wlr-randr --output "$mon" --mode "${current_res}@${high_rate}" 2>/dev/null || true
            fi
        fi
    fi

    # 5. Restore screen brightness and keyboard backlight
    if which brightnessctl >/dev/null 2>&1; then
        if [ -f "$PREV_BRIGHTNESS_FILE" ]; then
            local prev_bright=$(cat "$PREV_BRIGHTNESS_FILE" 2>/dev/null)
            if [ -n "$prev_bright" ]; then
                brightnessctl set "${prev_bright}%" 2>/dev/null || true
            fi
            rm -f "$PREV_BRIGHTNESS_FILE"
        fi

        # Restore keyboard backlight
        local kbd_dev=$(brightnessctl -l 2>/dev/null | grep -oE "Device '[^']*(kbd|keyboard)[^']*'" | head -n1 | cut -d"'" -f2)
        if [ -n "$kbd_dev" ]; then
            if [ -f "$PREV_KBD_FILE" ]; then
                local prev_kbd=$(cat "$PREV_KBD_FILE" 2>/dev/null)
                if [ -n "$prev_kbd" ]; then
                    brightnessctl --device="$kbd_dev" set "${prev_kbd}%" 2>/dev/null || true
                fi
                rm -f "$PREV_KBD_FILE"
            fi
        fi
    fi

    # 6. Reload swayidle with standard AC idle timers
    if [ -f "$HOME/.config/niri/bin/swayidle.sh" ]; then
        bash "$HOME/.config/niri/bin/swayidle.sh" >/dev/null 2>&1 &
    fi

    # 7. Send notification
    notify-send -r 99103 -u low "Đã cắm sạc" "Đã khôi phục các thiết lập hiệu năng và tần số quét màn hình."
}

echo "[Battery Saver] Daemon started. Monitoring AC power state & settings..."

# Main monitoring loop
while true; do
    # Read autoBatterySaver setting (default to true)
    AUTO_SAVER="true"
    if [ -f "$SETTINGS_FILE" ]; then
        AUTO_SAVER=$(jq -r '.autoBatterySaver // true' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$AUTO_SAVER" != "true" ] && [ "$AUTO_SAVER" != "false" ]; then
            AUTO_SAVER="true"
        fi
    fi

    # Read AC status (1 = AC plugged, 0 = on battery)
    AC_STATUS="1"
    if [ -f "$AC_PATH" ]; then
        AC_STATUS=$(cat "$AC_PATH" 2>/dev/null || echo 1)
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
            # Only apply performance settings if transitioning from saver or explicit state change
            if [ -n "$PREV_STATUS" ]; then
                apply_performance
            fi
        fi
        PREV_STATUS="$DESIRED_MODE"
    fi
    sleep 3
done
