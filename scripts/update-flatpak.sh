#!/usr/bin/env bash
# =============================================================================
# scripts/update-flatpak.sh — Update Flatpak applications
#
# Reads package list from: config/flatpak-packages.list
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

CONFIG_FLATPAK="${SCRIPT_DIR}/config/flatpak-packages.list"

print_header "Flatpak — Application Updates"

if ! has_cmd flatpak; then
    print_warn "Flatpak not installed — skipping"
    print_info "Install with: sudo apt install flatpak"
    exit 0
fi

# ── 1. Update all remotes ─────────────────────────────────────────────────────
print_section "Updating Flatpak remotes"
print_step "flatpak update metadata"
flatpak update --appstream 2>/dev/null >> "${LOG_FILE}" && print_ok || { print_warn "metadata update non-zero"; record_warn; }

# ── 2. Upgrade all installed apps ─────────────────────────────────────────────
print_section "Upgrading Flatpak applications"
print_step "flatpak update --noninteractive"
if flatpak update --noninteractive 2>&1 | tee -a "${LOG_FILE}" | grep -q "Nothing to do"; then
    print_ok "All apps up to date"; record_ok
else
    print_ok "Updates applied"; record_ok
fi

# ── 3. Install missing apps from config ───────────────────────────────────────
print_section "Installing configured apps"
if [[ -f "$CONFIG_FLATPAK" ]]; then
    while IFS= read -r app_id; do
        [[ -z "$app_id" ]] && continue
        print_step "flatpak install ${app_id}"
        if flatpak list --app --columns=application 2>/dev/null | grep -q "^${app_id}$"; then
            ver=$(flatpak list --app --columns=application,version 2>/dev/null | awk -v id="$app_id" '$1==id{print $2}')
            print_info "(already installed — ${ver})"
        else
            if flatpak install --noninteractive flathub "$app_id" >> "${LOG_FILE}" 2>&1; then
                print_ok; record_ok
            else
                print_warn "Failed: ${app_id}"; record_warn
            fi
        fi
    done < <(parse_config_names "$CONFIG_FLATPAK")
fi

# ── 4. Remove unused runtimes ─────────────────────────────────────────────────
print_section "Cleaning unused runtimes"
print_step "flatpak uninstall --unused"
flatpak uninstall --unused --noninteractive 2>&1 | tee -a "${LOG_FILE}" | grep -v "^$" | head -5 | \
    while IFS= read -r l; do print_info "$l"; done
print_ok; record_ok

# ── 5. List installed apps ────────────────────────────────────────────────────
print_section "Installed Flatpak applications"
fp_list=$(flatpak list --app --columns=name,application,version 2>/dev/null)
if [[ -n "$fp_list" ]]; then
    echo "$fp_list" | while IFS=$'\t' read -r name app_id ver; do
        print_info "${name} (${app_id}): ${ver}"
    done
else
    print_info "No Flatpak applications installed"
fi

print_summary "Flatpak Update Summary"

# ── 6. Update inventory ───────────────────────────────────────────────────────
if [[ "${INVENTORY_SILENT:-0}" != "1" ]]; then
    print_section "Updating APPS.md"
    print_step "update-inventory.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && print_ok || print_warn "inventory update failed"
fi
