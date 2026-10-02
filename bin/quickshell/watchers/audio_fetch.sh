#!/usr/bin/env bash
get_real_sink() {
    local default_sink=""
    if command -v pactl &>/dev/null; then
        default_sink=$(pactl get-default-sink 2>/dev/null)
    fi
    echo "${default_sink:-@DEFAULT_AUDIO_SINK@}"
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
            vol=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{v=int(($2/1.5)*100); if(v>100)v=100; print v}')
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
