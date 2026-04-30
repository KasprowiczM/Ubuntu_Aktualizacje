#!/usr/bin/env bash
# =============================================================================
# scripts/apps/list.sh — Show every config/*.list grouped by category.
# Read-only, no side effects.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/i18n.sh"
source "${SCRIPT_DIR}/lib/tables.sh"

print_header "Ascendo — $(t apps.title) ($(t apps.state.tracked))"

declare -a ROWS=()
for entry in \
        "apt:apt-packages.list" \
        "snap:snap-packages.list" \
        "brew:brew-formulas.list" \
        "brew-cask:brew-casks.list" \
        "npm:npm-globals.list" \
        "pipx:pipx-apps.list" \
        "flatpak:flatpak-apps.list"; do
    cat="${entry%%:*}"
    file="${SCRIPT_DIR}/config/${entry##*:}"
    [[ -f "$file" ]] || continue
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        pkg=$(awk '{print $1}' <<<"$line")
        ROWS+=("$cat|$pkg|@info $(t apps.state.tracked)")
    done < "$file"
done

table_render "$(t apps.col_cat)|$(t apps.col_name)|$(t apps.col_state)" \
    "${ROWS[@]:-no-data|—|—}"
echo
echo "  total: ${#ROWS[@]}"
