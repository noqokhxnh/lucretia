#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Per-wallpaper matugen color override helper
#   matugen_apply.sh save <hex> <scheme>          # remember color for current wallpaper
#   matugen_apply.sh clear                        # forget color, regenerate from image
#   matugen_apply.sh scheme <scheme>              # regenerate from image with a scheme
#   matugen_apply.sh apply <key> <image_target>   # apply saved color, or image defaults
#
# Overrides live in settings.json under "wallpaperColorOverrides",
# keyed by the wallpaper's original path (current_wallpaper.path).
# -----------------------------------------------------------------------------
SETTINGS_FILE="$HOME/.config/niri/settings.json"
SETTINGS_LOCK="$SETTINGS_FILE.lock"
WALL_CACHE="$HOME/.cache/quickshell/wallpaper_picker"

# Matugen can't process videos directly; fall back to the cached thumb.
image_target() {
    case "$1" in
        *.mp4|*.mkv|*.mov|*.webm|*.gif) echo "$WALL_CACHE/current_wallpaper.png" ;;
        *) echo "$1" ;;
    esac
}

case "${1:-}" in
  save)
    HEX="${2:-}"; SCHEME="${3:-}"
    [ -n "$HEX" ] && [ -n "$SCHEME" ] || exit 1

    KEY="$(cat "$WALL_CACHE/current_wallpaper.path" 2>/dev/null)"
    [ -n "$KEY" ] || exit 0

    ( flock 9; mkdir -p "$(dirname "$SETTINGS_FILE")"
      [ ! -s "$SETTINGS_FILE" ] && echo '{}' > "$SETTINGS_FILE"
      jq --arg k "$KEY" --arg h "$HEX" --arg s "$SCHEME" \
         '.wallpaperColorOverrides[$k] = {hex: $h, scheme: $s}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" &&
      mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE" ) 9>"$SETTINGS_LOCK"
    ;;

  clear)
    KEY="$(cat "$WALL_CACHE/current_wallpaper.path" 2>/dev/null)"
    if [ -n "$KEY" ] && [ -s "$SETTINGS_FILE" ]; then
        ( flock 9
          jq --arg k "$KEY" 'del(.wallpaperColorOverrides[$k]) |
              if (.wallpaperColorOverrides | length) == 0 then del(.wallpaperColorOverrides) else . end' \
              "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" &&
          mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE" ) 9>"$SETTINGS_LOCK"
    fi

    TARGET="$(image_target "$KEY")"
    if [ -f "$TARGET" ]; then
        matugen image "$TARGET" --source-color-index 0
    fi
    exit 0
    ;;

  scheme)
    SCHEME="${2:-}"
    [ -n "$SCHEME" ] || exit 1
    KEY="$(cat "$WALL_CACHE/current_wallpaper.path" 2>/dev/null)"
    TARGET="$(image_target "$KEY")"
    if [ -f "$TARGET" ]; then
        matugen image "$TARGET" -t "$SCHEME" --source-color-index 0
    fi
    exit 0
    ;;

  apply)
    KEY="${2:-}"; TARGET="${3:-}"

    OVERRIDE=""
    if [ -n "$KEY" ] && [ -s "$SETTINGS_FILE" ]; then
        OVERRIDE="$(jq -r --arg k "$KEY" '.wallpaperColorOverrides[$k] // empty' "$SETTINGS_FILE" 2>/dev/null)"
    fi

    if [ -n "$OVERRIDE" ]; then
        HEX="$(jq -r '.hex // empty' <<< "$OVERRIDE")"
        SCHEME="$(jq -r '.scheme // empty' <<< "$OVERRIDE")"
        if [ -n "$HEX" ] && [ -n "$SCHEME" ]; then
            echo "[matugen_apply] using saved color $HEX ($SCHEME) for $KEY"
            matugen color hex "$HEX" -t "$SCHEME"
            exit $?
        fi
    fi

    [ -n "$TARGET" ] && matugen image "$TARGET" --source-color-index 0
    ;;
esac
