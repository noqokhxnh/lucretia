#!/usr/bin/env bash
set -euo pipefail

TEMP_MIN=1000
TEMP_MAX=10000
DAY_TEMP=6500
UPDATE_INTERVAL=60
PIDDIR="${XDG_RUNTIME_DIR:-/tmp}/quickshell-bluelight"

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"

qs_ensure_cache "bluelight"

VERBOSE=0
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#ARGS[@]} -gt 0 ]]; then
    set -- "${ARGS[@]}"
else
    set --
fi

log() {
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo "[verbose] $*" >&2
    fi
}

usage() {
    exit 1
}

require_binary() {
    local bin="$1"
    if [[ "$VERBOSE" -eq 1 ]]; then
        if ! command -v "$bin" >/dev/null; then
            log "Required binary '$bin' not found."
            exit 1
        fi
    else
        if ! command -v "$bin" >/dev/null 2>&1; then
            exit 1
        fi
    fi
}

run_busctl() {
    if [[ "$VERBOSE" -eq 1 ]]; then
        busctl --user "$@"
    else
        busctl --user "$@" >/dev/null 2>&1
    fi
}

sanitize_output() {
    local name="$1"
    echo "${name//-/_}"
}

pid_key() {
    local output="${1:-}"
    if [[ -n "$output" ]]; then
        sanitize_output "$output"
    else
        echo "global"
    fi
}

object_path() {
    local output="${1:-}"
    if [[ -n "$output" ]]; then
        echo "/outputs/$(sanitize_output "$output")"
    else
        echo "/"
    fi
}

gammarelay_running() {
    busctl --user status rs.wl-gammarelay >/dev/null 2>&1
}

gammarelay_start() {
    require_binary wl-gammarelay-rs
    log "Starting wl-gammarelay-rs."
    if [[ "$VERBOSE" -eq 1 ]]; then
        nohup wl-gammarelay-rs >/dev/null &
    else
        nohup wl-gammarelay-rs >/dev/null 2>&1 &
    fi
    disown
    local i=0
    while ! gammarelay_running && (( i < 30 )); do
        sleep 0.1
        i=$((i+1))
    done
}

gammarelay_ensure_running() {
    if ! gammarelay_running; then
        gammarelay_start
    fi
}

stop_auto_loop() {
    local output="${1:-}"
    mkdir -p "$PIDDIR"
    local pidfile="$PIDDIR/auto-$(pid_key "$output").pid"
    if [[ -f "$pidfile" ]]; then
        local pid
        pid="$(cat "$pidfile" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log "Stopping existing auto-schedule loop (pid $pid) for output '${output:-<all>}'."
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$pidfile"
    fi
}

calculate_solar_temp() {
    local lat="$1"
    local lon="$2"
    local night_temp="$3"
    local day_temp="$4"
    local now_ts
    now_ts="$(date +%s)"

    awk -v t="$now_ts" -v lat="$lat" -v lon="$lon" -v ntemp="$night_temp" -v dtemp="$day_temp" '
        function torad(d) { return d * 0.017453292519943295 }
        function todeg(r) { return r * 57.29577951308232 }
        function norm360(x) { x = x % 360; return x < 0 ? x + 360 : x }
        function asin_safe(x) {
            if (x >= 1) return 1.5707963267948966
            if (x <= -1) return -1.5707963267948966
            return atan2(x, sqrt(1 - x * x))
        }
        BEGIN {
            d = (t - 946728000) / 86400
            M = norm360(357.529 + 0.98560028 * d)
            L = norm360(280.459 + 0.98564736 * d)
            lambda = norm360(L + 1.915 * sin(torad(M)) + 0.020 * sin(torad(2 * M)))
            eps = 23.439 - 0.00000036 * d
            sinDec = sin(torad(eps)) * sin(torad(lambda))
            cosDec = sqrt(1 - sinDec * sinDec)
            RA = todeg(atan2(cos(torad(eps)) * sin(torad(lambda)), cos(torad(lambda))))
            GMST = norm360(280.46061837 + 360.98564736629 * d)
            H = norm360(GMST + lon - RA)
            sinAlt = sin(torad(lat)) * sinDec + cos(torad(lat)) * cosDec * cos(torad(H))
            alt = todeg(asin_safe(sinAlt))

            low = -6.0
            high = 3.0
            if (alt <= low) {
                target = ntemp
            } else if (alt >= high) {
                target = dtemp
            } else {
                x = (alt - low) / (high - low)
                smooth = x * x * (3 - 2 * x)
                target = ntemp + (dtemp - ntemp) * smooth
            }
            printf "%d\n", target + 0.5
        }'
}

gammarelay_auto_loop() {
    local path="$1"
    local night_temp="$2"
    local lat="$3"
    local lon="$4"

    while :; do
        local temp
        temp="$(calculate_solar_temp "$lat" "$lon" "$night_temp" "$DAY_TEMP")"
        busctl --user set-property rs.wl-gammarelay "$path" rs.wl.gammarelay Temperature q "$temp" >/dev/null 2>&1
        sleep "$UPDATE_INTERVAL"
    done
}

gammarelay_set_manual() {
    local temp="$1"
    local output="${2:-}"
    local path
    path="$(object_path "$output")"

    require_binary busctl
    gammarelay_ensure_running
    stop_auto_loop "$output"

    log "Setting manual temperature $temp on $path."
    run_busctl set-property rs.wl-gammarelay "$path" rs.wl.gammarelay Temperature q "$temp"
}

gammarelay_set_auto() {
    local temp="$1"
    local output="${2:-}"
    local lat="${3:-0}"
    local lon="${4:-0}"
    local path
    path="$(object_path "$output")"

    require_binary busctl
    gammarelay_ensure_running
    stop_auto_loop "$output"

    mkdir -p "$PIDDIR"
    local pidfile="$PIDDIR/auto-$(pid_key "$output").pid"

    log "Starting auto-schedule loop for $path (night_temp=$temp lat=$lat lon=$lon)."
    if [[ "$VERBOSE" -eq 1 ]]; then
        gammarelay_auto_loop "$path" "$temp" "$lat" "$lon" &
    else
        gammarelay_auto_loop "$path" "$temp" "$lat" "$lon" >/dev/null 2>&1 &
    fi
    disown
    echo "$!" > "$pidfile"
}

gammarelay_set() {
    local temp="$1"
    local output="${2:-}"
    local mode="${3:-manual}"
    local lat="${4:-0}"
    local lon="${5:-0}"

    if [[ "$mode" == "auto" ]]; then
        gammarelay_set_auto "$temp" "$output" "$lat" "$lon"
    else
        gammarelay_set_manual "$temp" "$output"
    fi
}

gammarelay_reset() {
    local output="${1:-}"
    local path
    path="$(object_path "$output")"

    require_binary busctl
    stop_auto_loop "$output"

    if gammarelay_running; then
        log "Resetting $path to neutral temperature and full brightness."
        run_busctl set-property rs.wl-gammarelay "$path" rs.wl.gammarelay Temperature q "$DAY_TEMP"
        run_busctl set-property rs.wl-gammarelay "$path" rs.wl.gammarelay Brightness d 1
        run_busctl set-property rs.wl-gammarelay "$path" rs.wl.gammarelay Gamma d 1
        run_busctl set-property rs.wl-gammarelay "$path" rs.wl.gammarelay Inverted b false
    else
        log "wl-gammarelay-rs is not running."
    fi
}

gammarelay_status() {
    local output="${1:-}"
    local path
    path="$(object_path "$output")"

    if ! gammarelay_running; then
        echo "stopped"
        return
    fi

    if [[ "$VERBOSE" -eq 1 ]]; then
        local temp brightness
        temp="$(busctl --user get-property rs.wl-gammarelay "$path" rs.wl.gammarelay Temperature 2>/dev/null | awk '{print $2}')"
        brightness="$(busctl --user get-property rs.wl-gammarelay "$path" rs.wl.gammarelay Brightness 2>/dev/null | awk '{print $2}')"
        log "Temperature: ${temp:-unknown}K, Brightness: ${brightness:-unknown}"
    fi

    echo "running"
}

[[ $# -ge 1 ]] || usage

CMD="$1"
shift

case "$CMD" in
    set)
        [[ $# -ge 1 ]] || usage
        temp="$1"
        output="${2:-}"
        mode="${3:-manual}"
        lat="${4:-0}"
        lon="${5:-0}"
        if ! [[ "$temp" =~ ^[0-9]+$ ]] || (( temp < TEMP_MIN || temp > TEMP_MAX )); then
            log "Temperature $temp is outside valid range ($TEMP_MIN-$TEMP_MAX)."
            exit 1
        fi
        if ! [[ "$lat" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$lon" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            log "Latitude '$lat' or longitude '$lon' is not a valid number."
            exit 1
        fi
        gammarelay_set "$temp" "$output" "$mode" "$lat" "$lon"
        ;;
    reset)
        output="${1:-}"
        gammarelay_reset "$output"
        ;;
    status)
        output="${1:-}"
        gammarelay_status "$output"
        ;;
    *)
        usage
        ;;
esac
