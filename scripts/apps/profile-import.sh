#!/usr/bin/env bash
# =============================================================================
# scripts/apps/profile-import.sh — Import a profile template into config/*.list.
#
# Usage:  scripts/apps/profile-import.sh <profile-name> [--dry-run]
#         (lists in config/profiles/<profile-name>.list)
#
# Effect: each line "cat:pkg" gets appended to config/<cat>-packages.list
# (creating the file if missing). Idempotent — already-present packages
# are skipped. Original .list files get a .bak_<ts> backup before edit.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

PROFILE="${1:-}"
DRY=0
shift || true
for a in "$@"; do [[ "$a" == "--dry-run" ]] && DRY=1; done
[[ -z "$PROFILE" ]] && { echo "usage: $0 <profile-name> [--dry-run]"; exit 2; }

SRC="${SCRIPT_DIR}/config/profiles/${PROFILE}.list"
[[ -f "$SRC" ]] || { echo "profile not found: ${SRC}"; ls "${SCRIPT_DIR}/config/profiles/" 2>/dev/null; exit 2; }

declare -A FILE_MAP=(
    [apt]="apt-packages.list"
    [snap]="snap-packages.list"
    [brew]="brew-formulas.list"
    [brew-cask]="brew-casks.list"
    [npm]="npm-globals.list"
    [pip]="pip-packages.list"
    [pipx]="pipx-packages.list"
    [flatpak]="flatpak-packages.list"
)

added=0; skipped=0
while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    cat="${line%%:*}"; rest="${line#*:}"
    target="${FILE_MAP[$cat]:-}"
    [[ -z "$target" ]] && { echo "skip unknown cat: $line"; continue; }
    file="${SCRIPT_DIR}/config/${target}"
    pkg=$(echo "$rest" | awk '{print $1}')
    if [[ -f "$file" ]] && grep -qE "^[[:space:]]*${pkg}([[:space:]]|$)" "$file"; then
        echo "  ⊘ ${cat}:${pkg} (already present)"
        skipped=$((skipped+1))
        continue
    fi
    if [[ $DRY -eq 1 ]]; then
        echo "  + ${cat}:${rest}  → ${target}"
    else
        [[ -f "$file" ]] && cp -a "$file" "${file}.bak_$(date +%Y%m%d_%H%M%S)"
        [[ ! -f "$file" ]] && echo "# created by ascendo profile import ${PROFILE}" > "$file"
        printf '%s\n' "$rest" >> "$file"
        echo "  + ${cat}:${rest}  → ${target}"
    fi
    added=$((added+1))
done < "$SRC"

echo
print_ok "Profile '${PROFILE}': ${added} added, ${skipped} skipped"
[[ $DRY -eq 1 ]] && print_info "(dry-run — nothing written)"
