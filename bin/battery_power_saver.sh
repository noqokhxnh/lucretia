#!/usr/bin/env bash

# Prevent duplicate instances of this script
LOCKFILE="/tmp/battery_power_saver.lock"
if [ -e "$LOCKFILE" ]; then
    read -r PID < "$LOCKFILE" 2>/dev/null
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "battery_power_saver.sh is already running with PID $PID"
        exit 0
    fi
fi
echo "$$" > "$LOCKFILE"

cleanup() {
    trap - INT TERM EXIT
    if [ "$PREV_STATUS" = "saver" ]; then
        apply_performance 2>/dev/null || true
    fi
    rm -f "$LOCKFILE"
}
trap cleanup INT TERM EXIT

# Config and state files
SETTINGS_FILE="${QS_SETTINGS:-$HOME/.config/lucretia/settings.json}"
[ -e "$SETTINGS_FILE" ] && SETTINGS_FILE="$(readlink -f "$SETTINGS_FILE" 2>/dev/null || echo "$SETTINGS_FILE")"
[ ! -f "$SETTINGS_FILE" ] && SETTINGS_FILE="$HOME/.config/niri/settings.json"
PREV_AUTO_POWER_FILE="/tmp/battery_saver_prev_auto_power_mode"

CRIT_LEVEL_FILE="/tmp/battery_crit_level"          # "warn"|"suspend"|"shutdown" — latch cảnh báo
SUSPEND_LATCH_FILE="/tmp/battery_suspend_latch"    # capacity lúc suspend gần nhất

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

# Resolve battery capacity path
BAT_PATH=""
for b in /sys/class/power_supply/BAT*/capacity; do
    if [ -f "$b" ]; then
        BAT_PATH="$b"
        break
    fi
done

get_battery_capacity() {
    if [ -f "/tmp/mock_battery_capacity" ]; then
        local mock_cap=""
        read -r mock_cap < "/tmp/mock_battery_capacity" 2>/dev/null
        echo "$mock_cap"
        return
    fi
    if [ -n "$BAT_PATH" ] && [ -f "$BAT_PATH" ]; then
        local bat_cap=""
        read -r bat_cap < "$BAT_PATH" 2>/dev/null
        echo "$bat_cap"
        return
    fi
    cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1
}

# Track current state
PREV_STATUS=""
PREV_BOOST_SAVE=""

update_setting_bool() {
    local key="$1"
    local val="$2"
    local lock_path="${SETTINGS_FILE}.lock"
    if [ -f "$SETTINGS_FILE" ]; then
        ( flock 9
          if jq --arg key "$key" --argjson val "$val" '. + {($key): $val}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"; then
              mv -f "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
          else
              rm -f "${SETTINGS_FILE}.tmp"
          fi
        ) 9>"$lock_path"
    fi
}

update_setting_str() {
    local key="$1"
    local val="$2"
    local lock_path="${SETTINGS_FILE}.lock"
    if [ -f "$SETTINGS_FILE" ]; then
        ( flock 9
          if jq --arg key "$key" --arg val "$val" '. + {($key): $val}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"; then
              mv -f "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
          else
              rm -f "${SETTINGS_FILE}.tmp"
          fi
        ) 9>"$lock_path"
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

    # 5. Apply hardware and peripheral power savings
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
        local prev_auto=""
        read -r prev_auto < "$PREV_AUTO_POWER_FILE" 2>/dev/null
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



    # 6. Reload swayidle with standard AC idle timers
    if [ -f "$HOME/.config/niri/bin/swayidle.sh" ]; then
        bash "$HOME/.config/niri/bin/swayidle.sh" >/dev/null 2>&1 &
    fi

    # 7. Send notification
    notify-send -r 99103 -u low "Đã cắm sạc" "Đã khôi phục các thiết lập hiệu năng và tần số quét màn hình."
}

check_critical_battery() {
    [ "$CRIT_PROTECT" = "true" ] || return 0
    local cap
    cap=$(get_battery_capacity)
    [[ "$cap" =~ ^[0-9]+$ ]] || return 0

    # 1. Shutdown khẩn cấp — vô điều kiện, override latch
    if [ "$cap" -le "$CRIT_SHUTDOWN" ]; then
        local cur_crit=""
        [ -f "$CRIT_LEVEL_FILE" ] && read -r cur_crit < "$CRIT_LEVEL_FILE" 2>/dev/null
        if [ "$cur_crit" != "shutdown" ]; then
            echo "shutdown" > "$CRIT_LEVEL_FILE"
            notify-send -r 99112 -u critical "Pin cạn kiệt" "Máy sẽ tắt trong 3 giây..."
        fi
        sleep 3
        systemctl poweroff 2>/dev/null || true
        return
    fi

    # 2. Suspend khi pin cạn — ratchet: chỉ suspend lại khi tụt dưới latch − 1
    if [ "$cap" -le "$CRIT_SUSPEND" ]; then
        local latch=""
        [ -f "$SUSPEND_LATCH_FILE" ] && read -r latch < "$SUSPEND_LATCH_FILE" 2>/dev/null
        if [ -z "$latch" ] || [ "$cap" -le $((latch - 1)) ]; then
            local cur_crit=""
            [ -f "$CRIT_LEVEL_FILE" ] && read -r cur_crit < "$CRIT_LEVEL_FILE" 2>/dev/null
            if [ "$cur_crit" != "suspend" ]; then
                echo "suspend" > "$CRIT_LEVEL_FILE"
                notify-send -r 99111 -u critical "Pin yếu" "Pin còn ${cap}%. Máy sẽ tự ngủ để bảo vệ dữ liệu."
            fi
            echo "$cap" > "$SUSPEND_LATCH_FILE"
            systemctl suspend 2>/dev/null || true
        fi
        return
    fi

    # 3. Cảnh báo pin yếu — 1 lần mỗi mức
    if [ "$cap" -le "$CRIT_WARN" ]; then
        local cur_crit=""
        [ -f "$CRIT_LEVEL_FILE" ] && read -r cur_crit < "$CRIT_LEVEL_FILE" 2>/dev/null
        if [ "$cur_crit" != "warn" ]; then
            echo "warn" > "$CRIT_LEVEL_FILE"
            notify-send -r 99110 -u normal "Pin yếu" "Pin còn ${cap}%. Hãy cắm sạc."
        fi
    fi
}

LAST_SETTINGS_MTIME=0
AUTO_SAVER="true"
CRIT_PROTECT="true"
CRIT_WARN=15
CRIT_SUSPEND=5
CRIT_SHUTDOWN=2
BOOST_SAVE="true"

read_settings() {
    [ -f "$SETTINGS_FILE" ] || return 0
    local cur_mtime
    cur_mtime=$(stat -c %Y "$SETTINGS_FILE" 2>/dev/null || echo 0)
    if [ "$cur_mtime" != "$LAST_SETTINGS_MTIME" ]; then
        LAST_SETTINGS_MTIME="$cur_mtime"
        local raw
        raw=$(jq -r '[
            (.autoBatterySaver // true),
            (.critProtect // true),
            (.critBatteryWarn // 15),
            (.critBatterySuspend // 5),
            (.critBatteryShutdown // 2),
            (.boostPowerSave // true)
        ] | @tsv' "$SETTINGS_FILE" 2>/dev/null)

        if [ -n "$raw" ]; then
            local val_auto val_crit val_warn val_susp val_shut val_boost
            read -r val_auto val_crit val_warn val_susp val_shut val_boost <<< "$raw"

            [ "$val_auto" = "false" ] && AUTO_SAVER="false" || AUTO_SAVER="true"
            [ "$val_crit" = "false" ] && CRIT_PROTECT="false" || CRIT_PROTECT="true"

            [[ "$val_warn" =~ ^[0-9]+$ ]] && CRIT_WARN="$val_warn" || CRIT_WARN=15
            [[ "$val_susp" =~ ^[0-9]+$ ]] && CRIT_SUSPEND="$val_susp" || CRIT_SUSPEND=5
            [[ "$val_shut" =~ ^[0-9]+$ ]] && CRIT_SHUTDOWN="$val_shut" || CRIT_SHUTDOWN=2
            [ "$CRIT_WARN" -gt 100 ] && CRIT_WARN=15
            [ "$CRIT_SUSPEND" -gt 100 ] && CRIT_SUSPEND=5
            [ "$CRIT_SHUTDOWN" -gt 100 ] && CRIT_SHUTDOWN=2

            [ "$val_boost" = "false" ] && BOOST_SAVE="false" || BOOST_SAVE="true"
        fi
    fi
}

echo "[Battery Saver] Daemon started. Monitoring AC power state & settings..."

# Initial settings load
read_settings

# Main monitoring loop
while true; do
    read_settings

    # Turbo boost toggle — khi đổi, re-trigger udev để rule cài sẵn áp dụng ngay
    if [ -n "$PREV_BOOST_SAVE" ] && [ "$BOOST_SAVE" != "$PREV_BOOST_SAVE" ]; then
        udevadm trigger --subsystem-match=power_supply 2>/dev/null || true
    fi
    PREV_BOOST_SAVE="$BOOST_SAVE"

    # Read AC status (1 = AC plugged, 0 = on battery)
    AC_STATUS="1"
    if [ -f "$AC_PATH" ]; then
        read -r AC_STATUS < "$AC_PATH" 2>/dev/null || AC_STATUS="1"
    fi

    # Reset latch bảo vệ pin khi cắm sạc
    if [ "$AC_STATUS" != "0" ]; then
        rm -f "$CRIT_LEVEL_FILE" "$SUSPEND_LATCH_FILE"
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

    # Bảo vệ pin cạn — chạy bất kể autoBatterySaver (an toàn, không phải tùy chọn)
    local sleep_interval=10
    if [ "$AC_STATUS" = "0" ]; then
        check_critical_battery
        local cap
        cap=$(get_battery_capacity)
        if [[ "$cap" =~ ^[0-9]+$ ]] && [ "$cap" -le "$CRIT_WARN" ]; then
            sleep_interval=3
        else
            sleep_interval=8
        fi
    fi

    sleep "$sleep_interval"
done
