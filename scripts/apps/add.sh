#!/usr/bin/env bash
# =============================================================================
# scripts/apps/add.sh — Append a package to the right config/*.list.
#
# Usage: scripts/apps/add.sh <package> --category <apt|snap|brew|brew-cask|npm|pipx|flatpak>
#
# Idempotent: if already present, exit 0 with a notice.  Creates a .bak_<ts>
# copy of the .list before modifying.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

PKG=""
CAT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --category) shift; CAT="${1:-}" ;;
        -h|--help)  sed -n '4,12p' "$0"; exit 0 ;;
        *) [[ -z "$PKG" ]] && PKG="$1" || { echo "unexpected: $1"; exit 2; } ;;
    esac
    shift
done

[[ -z "$PKG" || -z "$CAT" ]] && { echo "usage: $0 <package> --category <cat>"; exit 2; }

case "$CAT" in
    apt)        FILE="${SCRIPT_DIR}/config/apt-packages.list" ;;
    snap)       FILE="${SCRIPT_DIR}/config/snap-packages.list" ;;
    brew)       FILE="${SCRIPT_DIR}/config/brew-formulas.list" ;;
    brew-cask)  FILE="${SCRIPT_DIR}/config/brew-casks.list" ;;
    npm)        FILE="${SCRIPT_DIR}/config/npm-globals.list" ;;
    pipx)       FILE="${SCRIPT_DIR}/config/pipx-apps.list" ;;
    flatpak)    FILE="${SCRIPT_DIR}/config/flatpak-apps.list" ;;
    *) print_error "unknown category: $CAT"; exit 2 ;;
esac

[[ ! -f "$FILE" ]] && { echo "# config list created by ascendo apps add" > "$FILE"; }

if grep -qE "^[[:space:]]*${PKG}([[:space:]]|$)" "$FILE"; then
    print_info "${PKG} already in ${FILE} — no change"
    exit 0
fi

cp -a "$FILE" "${FILE}.bak_$(date +%Y%m%d_%H%M%S)"
printf '%s\n' "$PKG" >> "$FILE"
print_ok "added ${PKG} → ${FILE}"
