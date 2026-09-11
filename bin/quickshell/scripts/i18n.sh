#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh" 2>/dev/null || true
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh" 2>/dev/null || true

I18N_DIR="${I18N_DIR:-"${LUCRETIA_DIR:-"${SERPANTINUM_DIR:-"$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"}"}/assets/languages"}"

get_current_language() {
    if [[ -n "$_CACHED_CURRENT_LANG" ]]; then
        printf '%s' "$_CACHED_CURRENT_LANG"
        return
    fi
    local lang=""
    local sfile="${QS_SETTINGS:-$HOME/.config/lucretia/settings.json}"
    if [[ -f "$sfile" ]]; then
        lang=$(grep -oP '"language":\s*"\K[^"]+' "$sfile" 2>/dev/null)
    fi
    if [[ -z "$lang" ]] && command -v get_setting &>/dev/null; then
        local lang_settings
        lang_settings="$(get_setting "general" '{"language": "en"}')"
        lang="$(printf '%s' "$lang_settings" | jq -r '.language // "en"' 2>/dev/null)"
    fi
    if [[ "$lang" == "null" || -z "$lang" ]]; then
        lang="en"
    fi
    export _CACHED_CURRENT_LANG="$lang"
    printf '%s' "$lang"
}

t() {
    local manual_lang=""
    local key=""
    local -a args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--lang)
                manual_lang="$2"
                shift 2
                ;;
            --lang=*)
                manual_lang="${1#*=}"
                shift
                ;;
            -l=*)
                manual_lang="${1#*=}"
                shift
                ;;
            *)
                if [[ -z "$key" ]]; then
                    key="$1"
                else
                    args+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$key" ]]; then
        return
    fi

    local lang=""
    if [[ -n "$manual_lang" && -f "${I18N_DIR}/${manual_lang}.json" ]]; then
        lang="$manual_lang"
    else
        lang="$(get_current_language)"
    fi

    local i18n_file="${I18N_DIR}/${lang}.json"

    if [[ ! -f "$i18n_file" ]]; then
        printf '%s' "$key"
        return
    fi

    local translated
    translated="$(jq -r --arg k "$key" '
        ($k | split(".")) as $path |
        getpath($path) | strings
    ' "$i18n_file" 2>/dev/null)"

    if [[ -z "$translated" ]]; then
        printf '%s' "$key"
        return
    fi

    local arg k v
    for arg in "${args[@]}"; do
        k="${arg%%=*}"
        v="${arg#*=}"
        translated="${translated//\{$k\}/$v}"
    done

    printf '%s' "$translated"
}
