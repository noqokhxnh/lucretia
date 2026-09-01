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
    echo "${default_sink:-@DEFAULT_AUDIO_SINK@}"
}

get_real_source() {
    local default_source=""
    if command -v pactl &>/dev/null; then
        default_source=$(pactl get-default-source 2>/dev/null)
    fi
    echo "${default_source:-@DEFAULT_AUDIO_SOURCE@}"
}

case $ACTION in
    set-volume)
        if [[ "$ID" == "@DEFAULT@" ]]; then
            if [[ "$TYPE" == "sink" ]]; then
                local sink=$(get_real_sink)
                if [[ "$sink" == "@DEFAULT_AUDIO_SINK@" ]]; then
                    wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "$VAL%"
                else
                    pactl set-sink-volume "$sink" "$VAL%"
                fi
            elif [[ "$TYPE" == "source" ]]; then
                local source=$(get_real_source)
                if [[ "$source" == "@DEFAULT_AUDIO_SOURCE@" ]]; then
                    wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ "$VAL%"
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
