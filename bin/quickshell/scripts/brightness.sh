#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"

ACTION=$1

case $ACTION in
    raise)
        brightnessctl set 5%+
        ;;
    lower)
        brightnessctl set 5%-
        ;;
esac
