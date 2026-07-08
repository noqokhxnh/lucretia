#!/usr/bin/env bash
# Idle daemon for niri — replaces hypridle
# Timeouts:
#   1800s (30 min): turn off monitors
#   2100s (35 min): lock session
#   4200s (70 min): suspend

swayidle -w \
  timeout 1800 'niri msg action power-off-monitors' \
  timeout 2100 'loginctl lock-session' \
  timeout 4200 'systemctl suspend' \
  before-sleep 'loginctl lock-session'
