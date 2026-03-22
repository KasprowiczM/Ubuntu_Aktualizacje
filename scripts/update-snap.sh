#!/usr/bin/env bash
# =============================================================================
# scripts/update-snap.sh — Update all Snap packages
#
# Covers:
#   • Firefox              (mozilla channel)
#   • Thunderbird          (canonical)
#   • KeePassXC            (keepassxreboot)
#   • htop                 (maxiberta)
#   • firmware-updater     (canonical)
#   • snap-store           (canonical)
#   • All snap base/runtime packages
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Snap — Package Updates"

require_sudo

# ── 1. Refresh all snaps ───────────────────────────────────────────────────────
print_section "Refreshing all snap packages"

print_step "snap refresh"
# snap refresh outputs useful info even when silent — capture and parse
output=$(sudo snap refresh 2>&1) || true
rc=$?

echo "${output}" >> "${LOG_FILE}"

# Parse snap output for results
if echo "${output}" | grep -q "All snaps up to date"; then
    print_ok "All snaps already up to date"
    record_ok
elif echo "${output}" | grep -q "error:"; then
    print_error "snap refresh encountered errors"
    echo "${output}" | grep "error:" | while IFS= read -r line; do
        print_info "  ${line}"
    done
    record_err
else
    print_ok "snap refresh completed"
    # Show what was updated
    echo "${output}" | grep -E "^[A-Za-z].*refreshed" | while IFS= read -r line; do
        print_info "${line}"
    done
    record_ok
fi

# ── 2. List current snap versions ─────────────────────────────────────────────
print_section "Installed snap packages"

snap list 2>/dev/null | tail -n +2 | while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    ver=$(echo  "$line" | awk '{print $2}')
    rev=$(echo  "$line" | awk '{print $3}')
    chan=$(echo "$line" | awk '{print $4}')
    # Skip base snaps and runtimes
    case "$name" in
        bare|core*|gnome-*|gtk-common*|kf5-*|mesa-*|snapd|snapd-desktop-*) continue ;;
    esac
    print_info "${name}: ${ver} (rev ${rev}, ${chan})"
done

# ── 3. Check for held snaps ───────────────────────────────────────────────────
print_section "Checking held snaps"
held=$(snap list --all 2>/dev/null | awk '$NF ~ /disabled/ {print $1}')
if [[ -n "$held" ]]; then
    print_warn "Disabled/old snap revisions present (they will be removed automatically):"
    echo "$held" | while read -r s; do print_info "  - $s"; done
    record_warn
else
    print_info "No disabled snap revisions"
fi

print_summary "Snap Update Summary"
