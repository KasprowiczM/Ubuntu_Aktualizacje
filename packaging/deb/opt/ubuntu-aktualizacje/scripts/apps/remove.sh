#!/usr/bin/env bash
# =============================================================================
# scripts/apps/remove.sh — Remove a package entry from the config/*.list.
#
# This only edits the configuration list — it does NOT uninstall the
# package from the system. Use the package manager to do that.
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
        -h|--help)  sed -n '4,11p' "$0"; exit 0 ;;
        *) [[ -z "$PKG" ]] && PKG="$1" || { echo "unexpected: $1"; exit 2; } ;;
    esac
    shift
done

[[ -z "$PKG" || -z "$CAT" ]] && { echo "usage: $0 <package> --category <cat>"; exit 2; }

case "$CAT" in
    apt)       FILE="${SCRIPT_DIR}/config/apt-packages.list" ;;
    snap)      FILE="${SCRIPT_DIR}/config/snap-packages.list" ;;
    brew)      FILE="${SCRIPT_DIR}/config/brew-formulas.list" ;;
    brew-cask) FILE="${SCRIPT_DIR}/config/brew-casks.list" ;;
    npm)       FILE="${SCRIPT_DIR}/config/npm-globals.list" ;;
    pipx)      FILE="${SCRIPT_DIR}/config/pipx-apps.list" ;;
    flatpak)   FILE="${SCRIPT_DIR}/config/flatpak-apps.list" ;;
    *) print_error "unknown category: $CAT"; exit 2 ;;
esac

[[ ! -f "$FILE" ]] && { print_warn "$FILE does not exist"; exit 0; }
cp -a "$FILE" "${FILE}.bak_$(date +%Y%m%d_%H%M%S)"
sed -i -E "/^[[:space:]]*${PKG}([[:space:]].*)?$/d" "$FILE"
print_ok "removed ${PKG} from ${FILE}"
