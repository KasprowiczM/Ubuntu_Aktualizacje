#!/usr/bin/env bash
# =============================================================================
# scripts/apps/install-missing.sh — Install configured-but-missing packages.
#
# Walks `apps detect --json` for state="missing" entries and asks the user
# to confirm before invoking the appropriate package manager. Idempotent.
# Honours --yes for unattended runs.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/i18n.sh"

YES=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)  YES=1 ;;
        -h|--help) sed -n '4,11p' "$0"; exit 0 ;;
        *) echo "unknown: $1" >&2; exit 2 ;;
    esac
    shift
done

print_header "Ascendo — install configured-but-missing packages"

JSON=$(bash "${SCRIPT_DIR}/scripts/apps/detect.sh" --json)
mapfile -t MISSING < <(printf '%s' "$JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for it in d['items']:
    if it['state'] == 'missing':
        print(it['category'] + '|' + it['package'])
")

if (( ${#MISSING[@]} == 0 )); then
    print_ok "nothing to install"
    exit 0
fi

echo "Will install:"
for m in "${MISSING[@]}"; do
    echo "  • $m"
done
echo
if [[ $YES -ne 1 ]]; then
    read -rp "Proceed? [y/N] " ans
    [[ "$ans" =~ ^[yY]$ ]] || { echo "aborted"; exit 0; }
fi

require_sudo
for m in "${MISSING[@]}"; do
    cat="${m%%|*}"; pkg="${m#*|}"
    case "$cat" in
        apt)        sudo apt-get install -y "$pkg" || print_error "apt $pkg failed" ;;
        snap)       sudo snap install "$pkg" || print_error "snap $pkg failed" ;;
        brew)       run_as_user brew install "$pkg" || print_error "brew $pkg failed" ;;
        brew-cask)  run_as_user brew install --cask "$pkg" || print_error "cask $pkg failed" ;;
        npm)        run_as_user npm install -g "$pkg" || print_error "npm $pkg failed" ;;
        pipx)       run_as_user pipx install "$pkg" || print_error "pipx $pkg failed" ;;
        flatpak)    flatpak install -y --noninteractive flathub "$pkg" || print_error "flatpak $pkg failed" ;;
        *) print_warn "unknown category for $pkg" ;;
    esac
done
print_ok "install-missing complete"
