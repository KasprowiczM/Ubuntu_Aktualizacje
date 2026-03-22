#!/usr/bin/env bash
# =============================================================================
# scripts/update-snap.sh — Update all Snap packages
#
# Reads package list from: config/snap-packages.list
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

CONFIG_SNAP="${SCRIPT_DIR}/config/snap-packages.list"

print_header "Snap — Package Updates"

require_sudo

if ! has_cmd snap; then
    print_warn "snapd not available — skipping"
    exit 0
fi

# ── 1. Refresh all snaps ───────────────────────────────────────────────────────
print_section "Refreshing snap packages"

print_step "snap refresh"
refresh_out=$(sudo snap refresh 2>&1) || true
echo "${refresh_out}" >> "${LOG_FILE}"

if echo "${refresh_out}" | grep -q "All snaps up to date"; then
    print_ok "All snaps up to date"; record_ok
elif echo "${refresh_out}" | grep -qi "error:"; then
    # snap-store must be closed before refresh — try with --ignore-running
    print_warn "snap refresh had errors, retrying with --ignore-running"
    refresh_out2=$(sudo snap refresh --ignore-running 2>&1) || true
    echo "${refresh_out2}" >> "${LOG_FILE}"
    if echo "${refresh_out2}" | grep -qi "error:"; then
        print_error "snap refresh failed"; record_err
        echo "${refresh_out2}" | grep -i "error:" | while IFS= read -r l; do print_info "  $l"; done
    else
        print_ok "Completed with --ignore-running"; record_ok
    fi
else
    print_ok "Snap refresh completed"
    echo "${refresh_out}" | grep -Ev "^$" | while IFS= read -r line; do
        print_info "${line}"
    done
    record_ok
fi

# ── 2. Report configured snaps vs installed ───────────────────────────────────
print_section "Snap package status"

if [[ -f "$CONFIG_SNAP" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        pkg=$(echo "$line" | awk '{print $1}')
        if snap_installed "$pkg"; then
            ver=$(snap_version "$pkg")
            print_info "${pkg}: ${ver}"
            record_ok
        else
            print_warn "${pkg}: NOT INSTALLED (run setup.sh to install)"
            record_warn
        fi
    done < <(parse_config_lines "$CONFIG_SNAP")
fi

# ── 3. List all installed user snaps ─────────────────────────────────────────
print_section "All installed snaps"
scan_snaps_user | while IFS='|' read -r name ver rev chan pub; do
    print_info "${name}: ${ver} (rev ${rev}, ${chan})"
done

# ── 4. Clean disabled snap revisions ─────────────────────────────────────────
print_section "Cleaning disabled snap revisions"
disabled=$(snap list --all 2>/dev/null | awk '$NF ~ /disabled/ {print $1, $3}')
if [[ -n "$disabled" ]]; then
    echo "$disabled" | while read -r name rev; do
        print_step "Remove disabled ${name} rev${rev}"
        sudo snap remove "${name}" --revision="${rev}" >> "${LOG_FILE}" 2>&1 && print_ok || print_warn "failed"
    done
else
    print_info "No disabled snap revisions"
fi

print_summary "Snap Update Summary"

# ── Update inventory (skipped when called from update-all.sh) ─────────────────
if [[ "${INVENTORY_SILENT:-0}" != "1" ]]; then
    print_section "Updating APPS.md"
    print_step "update-inventory.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && print_ok || print_warn "inventory update failed"
fi
