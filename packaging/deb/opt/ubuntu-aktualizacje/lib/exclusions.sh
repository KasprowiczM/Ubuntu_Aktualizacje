#!/usr/bin/env bash
# =============================================================================
# lib/exclusions.sh — Per-user exclusion list helpers.
#
# Reads config/exclusions.list (gitignored or local-only changes via overlay).
# Provides:
#   excl_load                     → load into EXCL_SET (assoc array)
#   excl_skip <category> <pkg>    → returns 0 if pkg is excluded
#   excl_category_skipped <cat>   → returns 0 if entire category excluded
#   excl_filter_args <cat> <args…> → echoes args minus excluded packages
# =============================================================================

# shellcheck disable=SC2034
declare -A EXCL_SET=()
EXCL_LOADED=0
declare -A EXCL_CATEGORY_ALL=()

excl_load() {
    [[ "$EXCL_LOADED" == "1" ]] && return 0
    EXCL_LOADED=1
    local file="${EXCL_FILE:-${SCRIPT_DIR:-$(pwd)}/config/exclusions.list}"
    [[ -f "$file" ]] || return 0
    local line cat pkg
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"   # ltrim
        line="${line%"${line##*[![:space:]]}"}"   # rtrim
        [[ -z "$line" ]] && continue
        if [[ "$line" == *":"* ]]; then
            cat="${line%%:*}"
            pkg="${line#*:}"
            if [[ "$pkg" == "*" ]]; then
                EXCL_CATEGORY_ALL[$cat]=1
            else
                EXCL_SET["${cat}:${pkg}"]=1
            fi
        fi
    done < "$file"
}

excl_skip() {
    excl_load
    local cat="$1" pkg="$2"
    [[ -n "${EXCL_CATEGORY_ALL[$cat]:-}" ]] && return 0
    [[ -n "${EXCL_SET["${cat}:${pkg}"]:-}" ]] && return 0
    return 1
}

excl_category_skipped() {
    excl_load
    [[ -n "${EXCL_CATEGORY_ALL["$1"]:-}" ]]
}

# Echo only those args not excluded for the given category.
# Usage:
#   filtered=( $(excl_filter_args apt "${pkgs[@]}") )
excl_filter_args() {
    excl_load
    local cat="$1"; shift
    local p
    for p in "$@"; do
        excl_skip "$cat" "$p" && continue
        echo "$p"
    done
}
