#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────
# POWER & THERMAL MANAGEMENT (chạy đầu tiên)
# ──────────────────────────────────────────────────────────────
# Mặc định power-saver để giảm nhiệt, chỉ lên balanced khi cần
if command -v gdbus &>/dev/null; then
    sudo -n systemctl enable --now power-profiles-daemon 2>/dev/null || true
    sleep 0.5
    gdbus call --system \
        --dest net.hadess.PowerProfiles \
        --object-path /net/hadess/PowerProfiles \
        --method org.freedesktop.DBus.Properties.Set \
        net.hadess.PowerProfiles \
        ActiveProfile "<'power-saver'>" 2>/dev/null || true
fi
# ──────────────────────────────────────────────────────────────
# ALSA — Headphone volume fix (tránh headphone bị mute sau reboot)
# ──────────────────────────────────────────────────────────────
if command -v amixer &>/dev/null; then
    # Card 1 = Realtek ALC897 (Ryzen HD Audio Controller)
    amixer -c 1 set Headphone 75% unmute 2>/dev/null || true
fi
# ──────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "wallpaper_picker"

FLAG="$QS_STATE_WALLPAPER_PICKER/wallpaper_initialized"
CACHE_IMG="$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.png"
CACHE_VID="$QS_CACHE_WALLPAPER_PICKER/current_video.path"

RELOAD_SCRIPT_PATH="$(dirname "${BASH_SOURCE[0]}")/quickshell/wallpaper/matugen_reload.sh"

# If the flag exists, restore current wallpaper (video or image) and exit
if [ -f "$FLAG" ]; then
    if [ -f "$CACHE_VID" ] && [ -s "$CACHE_VID" ]; then
        VID_PATH=$(cat "$CACHE_VID")
        if [ -f "$VID_PATH" ]; then
            pkill -x mpvpaper 2>/dev/null || true
            mpvpaper -o 'loop --no-audio --hwdec=auto --profile=fast' '*' "$VID_PATH" &
        else
            rm -f "$CACHE_VID"
        fi
    fi

    # If mpvpaper is not running, restore static image with awww
    if ! pgrep -x mpvpaper >/dev/null; then
        if [ -f "$CACHE_IMG" ]; then
            pgrep -x awww-daemon >/dev/null || (awww-daemon & sleep 0.5)
            awww img "$CACHE_IMG" --transition-type any --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1 &
        fi
    fi

    if [ -f "$CACHE_IMG" ]; then
        # Re-apply the saved per-wallpaper color override if one exists
        CUR_WALL="$(cat "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.path" 2>/dev/null)"
        MATUGEN_APPLY="$(dirname "${BASH_SOURCE[0]}")/quickshell/wallpaper/matugen_apply.sh"
        bash "$MATUGEN_APPLY" apply "$CUR_WALL" "$CACHE_IMG"
    fi

    if [ -f "$RELOAD_SCRIPT_PATH" ]; then
        chmod +x "$RELOAD_SCRIPT_PATH"
        bash "$RELOAD_SCRIPT_PATH"
    fi

    exit 0
fi

# If no wallpaper dir is set, default to a common one to prevent find from failing
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

sleep 0.5

# Find a random file
file=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)

if [ -n "$file" ]; then
    # Copy to our persistent cache location instead of /tmp
    cp "$file" "$CACHE_IMG"
    echo "$file" > "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.path"
    
    awww img "$file" --transition-type any --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1 &
    
    matugen image "$file" --source-color-index 0
    
    # Execute reload script if it exists
    if [ -f "$RELOAD_SCRIPT_PATH" ]; then
        chmod +x "$RELOAD_SCRIPT_PATH"
        bash "$RELOAD_SCRIPT_PATH"
    fi
fi

mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
