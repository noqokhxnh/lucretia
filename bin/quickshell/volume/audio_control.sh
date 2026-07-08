#!/usr/bin/env bash

ACTION=$1
TYPE=$2
ID=$3
VAL=$4

get_real_sink() {
    local default_sink=""
    if command -v pactl &>/dev/null; then
        default_sink=$(pactl get-default-sink 2>/dev/null)
    fi
    
    if [[ "$default_sink" == "easyeffects_sink" ]]; then
        local physical_sink=""
        if command -v pw-link &>/dev/null; then
            physical_sink=$(pw-link -l 2>/dev/null | grep -E "^ee_soe_output_level:output_FL" -A 1 | tail -n 1 | awk -F':' '{print $1}' | tr -d ' |-><')
        fi
        
        if [[ -z "$physical_sink" ]]; then
            physical_sink=$(pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -v "easyeffects_sink" | head -n 1)
        fi
        echo "$physical_sink"
    else
        echo "@DEFAULT_AUDIO_SINK@"
    fi
}

get_real_source() {
    local default_source=""
    if command -v pactl &>/dev/null; then
        default_source=$(pactl get-default-source 2>/dev/null)
    fi
    
    if [[ "$default_source" == "easyeffects_source" ]]; then
        local physical_source=""
        if command -v pactl &>/dev/null; then
            physical_source=$(pactl list sources short 2>/dev/null | awk '{print $2}' | grep -v -E "easyeffects|monitor" | head -n 1)
        fi
        echo "${physical_source:-@DEFAULT_AUDIO_SOURCE@}"
    else
        echo "@DEFAULT_AUDIO_SOURCE@"
    fi
}

case $ACTION in
    set-volume)
        if [[ "$ID" == "@DEFAULT@" ]]; then
            if [[ "$TYPE" == "sink" ]]; then
                local sink=$(get_real_sink)
                if [[ "$sink" == "@DEFAULT_AUDIO_SINK@" ]]; then
                    wpctl set-volume @DEFAULT_AUDIO_SINK@ "$VAL%"
                else
                    pactl set-sink-volume "$sink" "$VAL%"
                fi
            elif [[ "$TYPE" == "source" ]]; then
                local source=$(get_real_source)
                if [[ "$source" == "@DEFAULT_AUDIO_SOURCE@" ]]; then
                    wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "$VAL%"
                else
                    pactl set-source-volume "$source" "$VAL%"
                fi
            fi
        else
            pactl set-$TYPE-volume "$ID" "$VAL%"
        fi
        ;;
    toggle-mute)
        if [[ "$ID" == "@DEFAULT@" ]]; then
            if [[ "$TYPE" == "sink" ]]; then
                local sink=$(get_real_sink)
                if [[ "$sink" == "@DEFAULT_AUDIO_SINK@" ]]; then
                    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
                else
                    pactl set-sink-mute "$sink" toggle
                fi
            elif [[ "$TYPE" == "source" ]]; then
                local source=$(get_real_source)
                if [[ "$source" == "@DEFAULT_AUDIO_SOURCE@" ]]; then
                    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
                else
                    pactl set-source-mute "$source" toggle
                fi
            fi
        else
            pactl set-$TYPE-mute "$ID" toggle
        fi
        ;;
    set-default)
        pactl set-default-$TYPE "$ID"
        ;;
esac
