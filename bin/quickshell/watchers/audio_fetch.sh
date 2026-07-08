#!/usr/bin/env bash
get_real_sink() {
    local default_sink=""
    if command -v pactl &>/dev/null; then
        default_sink=$(pactl get-default-sink 2>/dev/null)
    fi
    
    if [[ "$default_sink" == "easyeffects_sink" ]]; then
        local physical_sink=""
        if command -v pw-link &>/dev/null; then
            physical_sink=$(pw-link -l 2>/dev/null | grep -E "^ee_" -A 1 | grep -E "alsa_output\." | head -n 1 | awk -F'->' '{print $2}' | awk -F':' '{print $1}' | xargs)
        fi
        
        if [[ -z "$physical_sink" ]]; then
            physical_sink=$(pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -v "easyeffects_sink" | head -n 1)
        fi
        echo "$physical_sink"
    else
        echo "${default_sink:-@DEFAULT_AUDIO_SINK@}"
    fi
}

get_volume() {
    local sink=$(get_real_sink)
    local vol=""
    if [[ "$sink" != "@DEFAULT_AUDIO_SINK@" ]]; then
        if command -v pamixer &> /dev/null; then
            vol=$(LC_ALL=C pamixer --sink "$sink" --get-volume 2>/dev/null)
        elif command -v pactl &> /dev/null; then
            vol=$(LC_ALL=C pactl get-sink-volume "$sink" 2>/dev/null | grep -Po '[0-9]+(?=%)' | head -n 1)
        fi
    fi
    
    if [[ -z "$vol" ]]; then
        if command -v wpctl &> /dev/null; then 
            vol=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}')
        fi
        if [[ -z "$vol" ]] && command -v pamixer &> /dev/null; then 
            vol=$(LC_ALL=C pamixer --get-volume 2>/dev/null)
        fi
    fi
    echo "${vol:-0}"
}

is_muted() {
    local sink=$(get_real_sink)
    local muted=""
    if [[ "$sink" != "@DEFAULT_AUDIO_SINK@" ]]; then
        if command -v pamixer &> /dev/null; then
            if LC_ALL=C pamixer --sink "$sink" --get-mute 2>/dev/null | grep -q "true"; then muted="true"; else muted="false"; fi
        elif command -v pactl &> /dev/null; then
            if LC_ALL=C pactl get-sink-mute "$sink" 2>/dev/null | grep -qi "yes"; then muted="true"; else muted="false"; fi
        fi
    fi
    
    if [[ -z "$muted" ]]; then
        if command -v wpctl &> /dev/null; then
            if LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q "MUTED"; then muted="true"; else muted="false"; fi
        elif command -v pamixer &> /dev/null; then
            if LC_ALL=C pamixer --get-mute 2>/dev/null | grep -q "true"; then muted="true"; else muted="false"; fi
        else
            muted="false"
        fi
    fi
    echo "$muted"
}

get_volume_icon() {
    local vol=$(get_volume)
    local muted=$(is_muted)
    if [ "$muted" = "true" ]; then echo "󰝟"
    elif [ "$vol" -ge 70 ]; then echo "󰕾"
    elif [ "$vol" -ge 30 ]; then echo "󰖀"
    elif [ "$vol" -gt 0 ]; then echo "󰕿"
    else echo "󰝟"; fi
}

toggle_mute() {
    if command -v wpctl &> /dev/null; then
        LC_ALL=C wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    elif command -v pamixer &> /dev/null; then
        LC_ALL=C pamixer --toggle-mute 2>/dev/null
    fi
    if [ "$(is_muted)" = "true" ]; then notify-send -u low -i audio-volume-muted "Volume" "Muted"
    else notify-send -u low -i audio-volume-high "Volume" "Unmuted ($(get_volume)%)"; fi
}

case $1 in
    --toggle) toggle_mute ;;
    *) jq -n -c --arg volume "$(get_volume)" --arg icon "$(get_volume_icon)" --arg is_muted "$(is_muted)" '{volume: $volume, icon: $icon, is_muted: $is_muted}' ;;
esac
