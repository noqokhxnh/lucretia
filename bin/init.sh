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
qs_ensure_cache "wallpaper"
qs_ensure_cache "wallpaper_picker"

FLAG="$QS_STATE_DIR/wallpaper/wallpaper_initialized"
RELOAD_SCRIPT_PATH="$(dirname "${BASH_SOURCE[0]}")/quickshell/wallpaper/matugen_reload.sh"
MATUGEN_APPLY="$(dirname "${BASH_SOURCE[0]}")/quickshell/wallpaper/matugen_apply.sh"

# 1. Check for active video wallpaper
CUR_VID=""
for v in "$QS_CACHE_WALLPAPER/current_video.path" "$QS_CACHE_WALLPAPER_PICKER/current_video.path"; do
    if [ -f "$v" ] && [ -s "$v" ]; then
        vp="$(cat "$v" 2>/dev/null)"
        if [ -n "$vp" ] && [ -f "$vp" ]; then
            CUR_VID="$vp"
            break
        fi
    fi
done

# 2. Check for active static image wallpaper
CUR_WALL=""
for p in "$QS_CACHE_WALLPAPER/current_wallpaper.path" "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.path"; do
    if [ -f "$p" ] && [ -s "$p" ]; then
        wp="$(cat "$p" 2>/dev/null)"
        if [ -n "$wp" ] && [ -f "$wp" ]; then
            CUR_WALL="$wp"
            break
        fi
    fi
done

# 3. Check for cached png
CACHE_IMG=""
for img in "$QS_CACHE_WALLPAPER/current_wallpaper.png" "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.png"; do
    if [ -f "$img" ] && [ -s "$img" ]; then
        CACHE_IMG="$img"
        break
    fi
done

ensure_awww_ready() {
    if ! pgrep -x awww-daemon >/dev/null; then
        awww-daemon &
    fi
    local retries=30
    while [ $retries -gt 0 ]; do
        if awww query >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
        ((retries--))
    done
    return 1
}

if [ -n "$CUR_VID" ]; then
    pkill -x mpvpaper 2>/dev/null || true
    mpvpaper -o 'loop --no-audio --hwdec=auto --profile=fast' '*' "$CUR_VID" &

    if [ -n "$CACHE_IMG" ] && [ -f "$MATUGEN_APPLY" ]; then
        bash "$MATUGEN_APPLY" apply "$CUR_VID" "$CACHE_IMG"
    fi

    if [ -f "$RELOAD_SCRIPT_PATH" ]; then
        chmod +x "$RELOAD_SCRIPT_PATH"
        bash "$RELOAD_SCRIPT_PATH"
    fi

    mkdir -p "$(dirname "$FLAG")" "$QS_STATE_DIR/wallpaper_picker"
    touch "$FLAG" "$QS_STATE_DIR/wallpaper_picker/wallpaper_initialized"
    exit 0
fi

if [ -n "$CUR_WALL" ] || [ -n "$CACHE_IMG" ]; then
    TARGET_IMG="${CUR_WALL:-$CACHE_IMG}"

    if ! pgrep -x mpvpaper >/dev/null; then
        ensure_awww_ready
        awww img "$TARGET_IMG" --transition-type any --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1 || true
    fi

    # Keep cache files synchronized across both directories
    if [ -f "$TARGET_IMG" ]; then
        [ -f "$QS_CACHE_WALLPAPER/current_wallpaper.png" ] || cp "$TARGET_IMG" "$QS_CACHE_WALLPAPER/current_wallpaper.png" 2>/dev/null || true
        [ -f "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.png" ] || cp "$TARGET_IMG" "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.png" 2>/dev/null || true
        echo "$TARGET_IMG" > "$QS_CACHE_WALLPAPER/current_wallpaper.path" 2>/dev/null || true
        echo "$TARGET_IMG" > "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.path" 2>/dev/null || true
    fi

    if [ -f "$MATUGEN_APPLY" ]; then
        bash "$MATUGEN_APPLY" apply "${CUR_WALL:-$TARGET_IMG}" "${CACHE_IMG:-$TARGET_IMG}"
    fi

    if [ -f "$RELOAD_SCRIPT_PATH" ]; then
        chmod +x "$RELOAD_SCRIPT_PATH"
        bash "$RELOAD_SCRIPT_PATH"
    fi

    mkdir -p "$(dirname "$FLAG")" "$QS_STATE_DIR/wallpaper_picker"
    touch "$FLAG" "$QS_STATE_DIR/wallpaper_picker/wallpaper_initialized"
    exit 0
fi

# Fallback: only if no wallpaper was ever set
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
sleep 0.5

file=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)

if [ -n "$file" ]; then
    cp "$file" "$QS_CACHE_WALLPAPER/current_wallpaper.png" 2>/dev/null || true
    cp "$file" "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.png" 2>/dev/null || true
    echo "$file" > "$QS_CACHE_WALLPAPER/current_wallpaper.path" 2>/dev/null || true
    echo "$file" > "$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.path" 2>/dev/null || true

    ensure_awww_ready
    awww img "$file" --transition-type any --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1 || true

    matugen image "$file" --source-color-index 0

    if [ -f "$RELOAD_SCRIPT_PATH" ]; then
        chmod +x "$RELOAD_SCRIPT_PATH"
        bash "$RELOAD_SCRIPT_PATH"
    fi
fi

mkdir -p "$(dirname "$FLAG")" "$QS_STATE_DIR/wallpaper_picker"
touch "$FLAG" "$QS_STATE_DIR/wallpaper_picker/wallpaper_initialized"
