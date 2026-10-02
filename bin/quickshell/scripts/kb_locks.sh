#!/usr/bin/env bash

ACTION="${1:-get}"

get_locks() {
    local caps=0
    local num=0

    for f in /sys/class/leds/*capslock*/brightness; do
        if [ -r "$f" ]; then
            read -r val < "$f" 2>/dev/null
            if [ "${val:-0}" -gt 0 ] 2>/dev/null; then
                caps=1
                break
            fi
        fi
    done

    for f in /sys/class/leds/*numlock*/brightness; do
        if [ -r "$f" ]; then
            read -r val < "$f" 2>/dev/null
            if [ "${val:-0}" -gt 0 ] 2>/dev/null; then
                num=1
                break
            fi
        fi
    done

    echo "$caps $num"
}

watch_locks() {
    local led_files=(/sys/class/leds/*capslock*/brightness /sys/class/leds/*numlock*/brightness)
    if command -v inotifywait >/dev/null 2>&1 && [ -e "${led_files[0]}" ]; then
        inotifywait -m -q -e modify "${led_files[@]}" 2>/dev/null | while read -r path _ file; do
            full_path="${path}${file}"
            val=0
            [ -r "$full_path" ] && read -r val < "$full_path" 2>/dev/null
            state="off"
            [ "${val:-0}" -gt 0 ] && state="on"
            if [[ "$full_path" =~ capslock ]]; then
                echo "capslock $state"
            elif [[ "$full_path" =~ numlock ]]; then
                echo "numlock $state"
            fi
        done
    fi
}

case "$ACTION" in
    get)
        get_locks
        ;;
    watch)
        watch_locks
        ;;
    *)
        get_locks
        ;;
esac
