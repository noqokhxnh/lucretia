#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/caching.sh"
qs_ensure_cache "music"

TMP_DIR="$QS_RUN_MUSIC/covers"
DEVICE_CACHE="$QS_RUN_MUSIC/device_cache.json"

mkdir -p "$TMP_DIR"
PLACEHOLDER="$TMP_DIR/placeholder_blank.png"

[ ! -f "$PLACEHOLDER" ] && convert -size 500x500 xc:"#313244" "$PLACEHOLDER"

RAW_URL="$1"
TITLE="$2"
ARTIST="$3"

CLEAN_URL="$RAW_URL"
if [[ "$RAW_URL" == file://* ]]; then
    CLEAN_URL="${RAW_URL#file://}"
    CLEAN_URL="$(printf '%b' "${CLEAN_URL//%/\\x}")"
fi

HASH_KEY="$CLEAN_URL"
if [[ "$HASH_KEY" =~ (googleusercontent\.com|ggpht\.com) ]]; then
    HASH_KEY="${HASH_KEY%%\=*}"
elif [[ "$HASH_KEY" =~ (vi|vi_webp)/([^/?&#]+) ]]; then
    HASH_KEY="yt_${BASH_REMATCH[2]}"
elif [[ "$HASH_KEY" =~ ab67([0-9a-f]{4})0000[0-9a-f]{4}([0-9a-f]+) ]]; then
    HASH_KEY="sp_${BASH_REMATCH[2]}"
fi

if [ -n "$HASH_KEY" ] && [ "$HASH_KEY" != "unknown" ]; then
    trackHash=$(echo -n "$HASH_KEY" | md5sum | cut -d" " -f1)
elif [ -n "$TITLE" ] || [ -n "$ARTIST" ]; then
    trackHash=$(echo -n "${TITLE}-${ARTIST}" | md5sum | cut -d" " -f1)
else
    trackHash=$(echo -n "unknown" | md5sum | cut -d" " -f1)
fi

FINAL_ART="$TMP_DIR/${trackHash}_art.jpg"
BLUR_PATH="$TMP_DIR/${trackHash}_blur.png"
COLOR_PATH="$TMP_DIR/${trackHash}_grad.txt"
TEXT_PATH="$TMP_DIR/${trackHash}_text.txt"
LOCK_DIR="$TMP_DIR/${trackHash}.lock"
FAIL_FILE="$TMP_DIR/${trackHash}.fail"

DISPLAY_ART="$PLACEHOLDER"
DISPLAY_BLUR="$PLACEHOLDER"
DISPLAY_GRAD="linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)"
DISPLAY_TEXT="#cdd6f4"
IS_PLACEHOLDER=true

CACHE_VALID=false
if [ -f "$FINAL_ART" ] && [ -s "$FINAL_ART" ]; then
    DISPLAY_ART="$FINAL_ART"
    IS_PLACEHOLDER=false
    [ -f "$BLUR_PATH" ] && [ -s "$BLUR_PATH" ] && DISPLAY_BLUR="$BLUR_PATH" || DISPLAY_BLUR="$FINAL_ART"
    [ -f "$COLOR_PATH" ] && [ -s "$COLOR_PATH" ] && DISPLAY_GRAD=$(cat "$COLOR_PATH")
    [ -f "$TEXT_PATH" ] && [ -s "$TEXT_PATH" ] && DISPLAY_TEXT=$(cat "$TEXT_PATH")

    if [[ "$RAW_URL" == http* ]]; then
        curW=$(identify -format "%w" "$FINAL_ART" 2>/dev/null)
        [[ "$curW" =~ ^[0-9]+$ ]] || curW=0
        if [ "$curW" -ge 500 ]; then
            CACHE_VALID=true
        fi
    else
        CACHE_VALID=true
    fi
fi

if ! $CACHE_VALID; then
    if [ -d "$LOCK_DIR" ]; then
        if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +0.25 2>/dev/null)" ]; then
            rmdir "$LOCK_DIR" 2>/dev/null
        fi
    fi

    should_attempt=true
    if [ -f "$FAIL_FILE" ]; then
        failcount=0; lastattempt=0
        read -r failcount lastattempt < "$FAIL_FILE" 2>/dev/null
        [[ "$failcount" =~ ^[0-9]+$ ]] || failcount=0
        [[ "$lastattempt" =~ ^[0-9]+$ ]] || lastattempt=0
        now=$(date +%s)
        backoff=$(( failcount > 6 ? 60 : (1 << failcount) ))
        [ $(( now - lastattempt )) -lt "$backoff" ] && should_attempt=false
    fi

    if $should_attempt && [ -n "$RAW_URL" ] && mkdir "$LOCK_DIR" 2>/dev/null; then
        (
            trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

            tempArt="$TMP_DIR/${trackHash}_temp_art.$$"
            tempBlur="$TMP_DIR/${trackHash}_temp_blur.$$"

            downloadOk=false
            if [[ "$RAW_URL" == http* ]]; then
                declare -a candidates=()
                if [[ "$RAW_URL" =~ (googleusercontent\.com|ggpht\.com) ]]; then
                    base="${RAW_URL%%\=*}"
                    candidates=(
                        "${base}=w1200-h1200-l90-rj"
                        "${base}=s1200"
                        "${base}=s0"
                        "$RAW_URL"
                    )
                elif [[ "$RAW_URL" =~ (vi|vi_webp)/([^/?&#]+) ]]; then
                    vid="${BASH_REMATCH[2]}"
                    candidates=(
                        "https://i.ytimg.com/vi/${vid}/maxresdefault.jpg"
                        "https://i.ytimg.com/vi/${vid}/sddefault.jpg"
                        "https://i.ytimg.com/vi/${vid}/hq720.jpg"
                        "https://i.ytimg.com/vi/${vid}/hqdefault.jpg"
                        "$RAW_URL"
                    )
                elif [[ "$RAW_URL" =~ ytimg\.com ]]; then
                    candidates=(
                        "$(echo "$RAW_URL" | sed -E 's/(default|hqdefault|mqdefault|sddefault|hq720)\.(jpg|webp)/maxresdefault.jpg/')"
                        "$(echo "$RAW_URL" | sed -E 's/(default|hqdefault|mqdefault|sddefault|hq720)\.(jpg|webp)/sddefault.jpg/')"
                        "$(echo "$RAW_URL" | sed -E 's/(default|hqdefault|mqdefault|sddefault|hq720)\.(jpg|webp)/hq720.jpg/')"
                        "$(echo "$RAW_URL" | sed -E 's/(default|hqdefault|mqdefault|sddefault|hq720)\.(jpg|webp)/hqdefault.jpg/')"
                        "$RAW_URL"
                    )
                elif [[ "$RAW_URL" =~ scdn\.co ]]; then
                    candidates=(
                        "$(echo "$RAW_URL" | sed -E 's/ab67([0-9a-f]{4})0000[0-9a-f]{4}/ab67\10000b273/')"
                        "$(echo "$RAW_URL" | sed -E 's/ab67([0-9a-f]{4})0000[0-9a-f]{4}/ab67\100001e02/')"
                        "$RAW_URL"
                    )
                elif [[ "$RAW_URL" =~ sndcdn\.com ]]; then
                    candidates=(
                        "$(echo "$RAW_URL" | sed -E 's/-(large|t[0-9]+x[0-9]+|mini|tiny|small|badge|crop)\.([a-zA-Z0-9]+)$/-original.\2/')"
                        "$(echo "$RAW_URL" | sed -E 's/-(large|t[0-9]+x[0-9]+|mini|tiny|small|badge|crop)\.([a-zA-Z0-9]+)$/-t500x500.\2/')"
                        "$RAW_URL"
                    )
                elif [[ "$RAW_URL" =~ mzstatic\.com ]]; then
                    candidates=(
                        "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+[a-z0-9-]*\.(jpg|jpeg|png|webp)/1400x1400bb.\1/')"
                        "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+[a-z0-9-]*\.(jpg|jpeg|png|webp)/1000x1000bb.\1/')"
                        "$RAW_URL"
                    )
                elif [[ "$RAW_URL" =~ dzcdn\.net ]]; then
                    candidates=(
                        "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+-000000/1000x1000-000000/')"
                        "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+-000000/500x500-000000/')"
                        "$RAW_URL"
                    )
                elif [[ "$RAW_URL" =~ bcbits\.com ]]; then
                    candidates=(
                        "$(echo "$RAW_URL" | sed -E 's/_[0-9]+\.jpg$/_10.jpg/')"
                        "$(echo "$RAW_URL" | sed -E 's/_[0-9]+\.jpg$/_0.jpg/')"
                        "$RAW_URL"
                    )
                elif [[ "$RAW_URL" =~ resources\.tidal\.com ]]; then
                    candidates=(
                        "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+\.jpg$/1280x1280.jpg/')"
                        "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+\.jpg$/640x640.jpg/')"
                        "$RAW_URL"
                    )
                elif [[ "$RAW_URL" =~ (amazon\.com|media-amazon\.com|images-amazon\.com) ]]; then
                    candidates=(
                        "$(echo "$RAW_URL" | sed -E 's/\._[A-Z0-9_,]+_\./._SL1400_./')"
                        "$RAW_URL"
                    )
                else
                    candidates=("$RAW_URL")
                fi

                for cand in "${candidates[@]}"; do
                    [ -z "$cand" ] && continue
                    httpCode=$(curl -s -L --max-time 10 -o "$tempArt" -w "%{http_code}" "$cand" 2>/dev/null)
                    if [[ "$httpCode" =~ ^2[0-9][0-9]$ ]] && [ -s "$tempArt" ]; then
                        dims=$(identify -format "%wx%h" "$tempArt" 2>/dev/null)
                        if [ -n "$dims" ]; then
                            if [[ "$cand" =~ ytimg\.com ]] && [ "$dims" = "120x90" ]; then
                                rm -f "$tempArt"
                                continue
                            fi
                            downloadOk=true
                            break
                        fi
                    fi
                    rm -f "$tempArt"
                done
            else
                if [ -f "$CLEAN_URL" ] && cp "$CLEAN_URL" "$tempArt" 2>/dev/null && [ -s "$tempArt" ]; then
                    if identify "$tempArt" >/dev/null 2>&1; then
                        downloadOk=true
                    fi
                fi
            fi

            if ! $downloadOk; then
                rm -f "$tempArt" "$tempBlur"
                now=$(date +%s)
                prevfail=0
                [ -f "$FAIL_FILE" ] && read -r prevfail _ < "$FAIL_FILE" 2>/dev/null
                [[ "$prevfail" =~ ^[0-9]+$ ]] || prevfail=0
                echo "$((prevfail + 1)) $now" > "$FAIL_FILE"
                exit 0
            fi

            rm -f "$FAIL_FILE"

            isPlaceholderStr=$(convert "$tempArt" -format "%[hex:u.p{0,0}]" info: 2>/dev/null | cut -c1-6)

            if [[ "$isPlaceholderStr" == "313244" ]]; then
                cp "$tempArt" "$tempBlur"
            else
                convert "$tempArt" -blur 0x20 -brightness-contrast -30x-10 "$tempBlur" 2>/dev/null
                colors=$(convert "$tempArt" -resize 50x50 -alpha off +dither -quantize RGB -colors 3 -depth 8 -format "%c" histogram:info: 2>/dev/null | grep -E -o '#[0-9A-Fa-f]{6}' | head -n 3 | tr '\n' ' ')
                read -r -a color_array <<< "$colors"

                c1=${color_array[0]:-#cba6f7}
                c2=${color_array[1]:-$c1}
                c3=${color_array[2]:-$c1}

                echo "linear-gradient(45deg, $c1, $c2, $c3, $c1)" > "$COLOR_PATH"

                hex="${c1#\#}"
                r=$((16#${hex:0:2}))
                g=$((16#${hex:2:2}))
                b=$((16#${hex:4:2}))

                brightness=$(( (299*r + 587*g + 114*b) / 1000 ))

                if [ "$brightness" -lt 70 ]; then
                    textColor="#ffffff"
                elif [ "$brightness" -lt 120 ]; then
                    textColor="#fafafa"
                elif [ "$brightness" -lt 170 ]; then
                    textColor="#f2f2f2"
                elif [ "$brightness" -lt 210 ]; then
                    textColor="#e8e8e8"
                elif [ "$brightness" -lt 235 ]; then
                    textColor="#444444"
                else
                    textColor="#1e1e2e"
                fi

                echo "$textColor" > "$TEXT_PATH"
            fi

            mv -f "$tempBlur" "$BLUR_PATH"
            mv -f "$tempArt" "$FINAL_ART"

            (cd "$TMP_DIR" && ls -1t -- *_art.jpg 2>/dev/null | tail -n +16 | while read -r f; do
                h="${f%_art.jpg}"
                rm -f "${h}_art.jpg" "${h}_blur.png" "${h}_grad.txt" "${h}_text.txt" "${h}.fail" "${h}_url.txt"
            done)
        ) </dev/null >/dev/null 2>&1 &
    fi
fi

NOW_TS=$(date +%s)
DEVICE_CACHE_OK=false
if [ -f "$DEVICE_CACHE" ]; then
    CACHE_TS=$(jq -r '.ts // 0' "$DEVICE_CACHE" 2>/dev/null)
    [[ "$CACHE_TS" =~ ^[0-9]+$ ]] || CACHE_TS=0
    [ $((NOW_TS - CACHE_TS)) -lt 5 ] && DEVICE_CACHE_OK=true
fi

if $DEVICE_CACHE_OK; then
    DEV_ICON=$(jq -r '.icon' "$DEVICE_CACHE")
    DEV_NAME=$(jq -r '.name' "$DEVICE_CACHE")
else
    WP_INSPECT=$(timeout 0.4 wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    NODE_NAME=$(echo "$WP_INSPECT" | awk -F'"' '/node\.name/ {print $2; exit}')
    NODE_DESC=$(echo "$WP_INSPECT" | awk -F'"' '/node\.description/ {print $2; exit}')

    DEV_ICON="󰓃"; DEV_NAME="Speaker"
    if [[ "$NODE_NAME" == *"bluez"* ]]; then
        DEV_ICON="󰂯"
        DEV_NAME="${NODE_DESC:-Bluetooth Audio}"
    elif [[ "$NODE_NAME" == *"usb"* ]]; then
        DEV_NAME="USB Audio"
    elif [[ "$NODE_NAME" == *"pci"* ]]; then
        DEV_NAME="Speaker"
    elif [ -n "$NODE_DESC" ]; then
        DEV_NAME="$NODE_DESC"
    fi

    jq -n -c --arg icon "$DEV_ICON" --arg name "$DEV_NAME" --argjson ts "$NOW_TS" \
        '{icon: $icon, name: $name, ts: $ts}' > "$DEVICE_CACHE"
fi

jq -n -c \
    --arg blur "$DISPLAY_BLUR" \
    --arg grad "$DISPLAY_GRAD" \
    --arg txtColor "$DISPLAY_TEXT" \
    --arg devIcon "$DEV_ICON" \
    --arg devName "$DEV_NAME" \
    --arg finalArt "$DISPLAY_ART" \
    --arg trackHash "$trackHash" \
    --argjson isPlaceholder "$IS_PLACEHOLDER" \
    '{
        blur: $blur,
        grad: $grad,
        textColor: $txtColor,
        deviceIcon: $devIcon,
        deviceName: $devName,
        artUrl: $finalArt,
        trackHash: $trackHash,
        isPlaceholder: $isPlaceholder
    }'
