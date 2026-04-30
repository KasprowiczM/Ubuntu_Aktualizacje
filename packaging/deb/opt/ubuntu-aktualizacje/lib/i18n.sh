#!/usr/bin/env bash
# =============================================================================
# lib/i18n.sh — minimal in-shell i18n (no gettext needed).
#
# Catalog format: i18n/<lang>.txt with `key = value` lines (UTF-8). Values
# may contain printf-style format specifiers; quote with double quotes if
# they include leading/trailing whitespace. Comments start with #.
#
# Public API:
#   t  KEY [FALLBACK]                  → echoes translation or fallback or key
#   tn KEY ARG1 ARG2 ...                → translation with positional %s/%d
#   i18n_load [LANG]                    → re-load catalog (default: $UI_LANG)
#
# Resolution order for current language:
#   1. UI_LANG env var
#   2. ~/.config/ascendo/lang file content
#   3. ${LANG:0:2} (system) when "en" or "pl"
#   4. fallback: "en"
# =============================================================================

# shellcheck disable=SC2034
ASCENDO_I18N_LIB_LOADED=1
ASCENDO_I18N_DIR="${ASCENDO_I18N_DIR:-${SCRIPT_DIR:-$(pwd)}/i18n}"
declare -gA _ASCENDO_T=()
ASCENDO_LANG_RESOLVED=""

_ascendo_resolve_lang() {
    local lang="${UI_LANG:-}"
    if [[ -z "$lang" ]]; then
        local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/ascendo/lang"
        [[ -r "$cfg" ]] && lang=$(tr -d '[:space:]' < "$cfg" 2>/dev/null)
    fi
    [[ -z "$lang" && -n "${LANG:-}" ]] && lang="${LANG:0:2}"
    case "$lang" in
        pl|en) ;;
        *) lang="en" ;;
    esac
    printf '%s' "$lang"
}

i18n_load() {
    local lang="${1:-$(_ascendo_resolve_lang)}"
    local f="${ASCENDO_I18N_DIR}/${lang}.txt"
    _ASCENDO_T=()
    ASCENDO_LANG_RESOLVED="$lang"
    [[ -r "$f" ]] || return 0
    local line key val
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and blanks
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        # Split on first =
        if [[ "$line" == *"="* ]]; then
            key="${line%%=*}"
            val="${line#*=}"
            # Trim ws
            key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
            val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
            _ASCENDO_T[$key]="$val"
        fi
    done < "$f"
}

t() {
    local key="$1" fallback="${2:-}"
    local val="${_ASCENDO_T[$key]:-}"
    if [[ -n "$val" ]]; then
        printf '%s' "$val"
    elif [[ -n "$fallback" ]]; then
        printf '%s' "$fallback"
    else
        printf '%s' "$key"
    fi
}

tn() {
    local key="$1"; shift
    local fmt
    fmt=$(t "$key" "$key")
    # shellcheck disable=SC2059
    printf "$fmt" "$@"
}

ascendo_set_lang() {
    local lang="$1"
    case "$lang" in pl|en) ;; *) return 2 ;; esac
    local cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ascendo"
    mkdir -p "$cfg_dir"
    printf '%s\n' "$lang" > "${cfg_dir}/lang"
    UI_LANG="$lang"
    export UI_LANG
    i18n_load "$lang"
}

# Auto-load on source so `t` is usable immediately.
i18n_load
