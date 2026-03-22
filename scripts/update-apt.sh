#!/usr/bin/env bash
# =============================================================================
# scripts/update-apt.sh — Update & upgrade all APT-managed packages
#
# Reads package list from: config/apt-packages.list
# Reads repo list from:    config/apt-repos.list
#
# Covers: Ubuntu OS, Brave, Chrome, VSCode, Docker, MegaSync, ProtonVPN,
#         Proton Mail, RDM, Grub Customizer, NVIDIA driver, Rclone, and
#         any other apt-managed package on the system.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

CONFIG_APT="${SCRIPT_DIR}/config/apt-packages.list"

print_header "APT — System & Application Updates"

require_sudo

# ── 1. Refresh all apt sources ────────────────────────────────────────────────
print_section "Refreshing package lists"

print_step "apt-get update"
if sudo_silent apt-get update -q; then
    print_ok; record_ok
else
    print_warn "apt-get update had errors — some repos may be unavailable"
    record_warn
fi

# ── 2. Safe upgrade (keep existing config files) ─────────────────────────────
print_section "Upgrading packages"

APT_OPTS=(
    -y -q
    -o Dpkg::Options::="--force-confdef"
    -o Dpkg::Options::="--force-confold"
    -o APT::Get::Show-Versions=true
)

print_step "apt-get upgrade"
if sudo_silent apt-get upgrade "${APT_OPTS[@]}"; then
    print_ok; record_ok
else
    print_warn "upgrade returned non-zero — some packages may be held"
    record_warn
fi

print_step "apt-get dist-upgrade (metapackages & kernel)"
if sudo_silent apt-get dist-upgrade "${APT_OPTS[@]}"; then
    print_ok; record_ok
else
    print_warn "dist-upgrade returned non-zero"
    record_warn
fi

# ── 3. Cleanup ────────────────────────────────────────────────────────────────
print_section "Cleaning up"

print_step "Remove orphaned packages"
sudo_silent apt-get autoremove -y -q && print_ok || { print_warn "autoremove non-zero"; record_warn; }

print_step "Clean package cache"
sudo_silent apt-get autoclean -q && print_ok || { print_warn "autoclean non-zero"; record_warn; }

# ── 4. Version report (from config) ──────────────────────────────────────────
print_section "Key package versions (from config/apt-packages.list)"

if [[ -f "$CONFIG_APT" ]]; then
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        ver=$(apt_pkg_version "$pkg")
        if [[ -n "$ver" ]]; then
            print_info "${pkg}: ${ver}"
        else
            print_warn "${pkg}: NOT INSTALLED"
            record_warn
        fi
    done < <(parse_config_names "$CONFIG_APT")
else
    print_warn "Config file not found: ${CONFIG_APT}"
fi

# ── 5. Reboot check ───────────────────────────────────────────────────────────
if [[ -f /var/run/reboot-required ]]; then
    echo
    print_warn "*** REBOOT REQUIRED ***"
    [[ -f /var/run/reboot-required.pkgs ]] && \
        print_info "  Packages: $(paste -sd', ' /var/run/reboot-required.pkgs)"
fi

print_summary "APT Update Summary"

# ── Update inventory (skipped when called from update-all.sh) ─────────────────
if [[ "${INVENTORY_SILENT:-0}" != "1" ]]; then
    print_section "Updating APPS.md"
    print_step "update-inventory.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && print_ok || print_warn "inventory update failed"
fi
