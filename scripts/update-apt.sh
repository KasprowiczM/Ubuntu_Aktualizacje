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

UPGRADE_NVIDIA="${UPGRADE_NVIDIA:-0}"

# ── Helper: hold / unhold all installed nvidia-* packages ────────────────────
_nvidia_hold() {
    local action="$1"
    # Match packages actually present in dpkg (any status: ii, iF, iU, hi, etc.)
    local pkgs
    pkgs=$(dpkg -l 'nvidia-*' 'libnvidia-*' 2>/dev/null \
        | awk '/^[iuh][iUFHWt]/{print $2}' | tr '\n' ' ')
    [[ -z "${pkgs// }" ]] && return 0
    # shellcheck disable=SC2086
    sudo apt-mark "$action" $pkgs 2>/dev/null >> "${LOG_FILE}" || true
}

# ── 0. Manage NVIDIA hold state ───────────────────────────────────────────────

# Detect half-configured nvidia packages (iF state) — warn upfront so the
# repeated dpkg reconfigure failures below are expected, not surprising.
_broken_nvidia=$(dpkg -l 'nvidia-*' 'libnvidia-*' 2>/dev/null | awk '/^iF/{print $2}' | tr '\n' ' ')
if [[ -n "${_broken_nvidia// }" ]]; then
    print_warn "nvidia-dkms is in a broken dpkg state (iF) — each apt command will attempt DKMS rebuild and fail"
    print_info "Broken packages: ${_broken_nvidia}"
    print_info "Fix: sudo apt install gcc-14 && sudo dpkg --configure -a"
fi

if [[ "${UPGRADE_NVIDIA}" -eq 0 ]]; then
    print_info "NVIDIA packages held (use --nvidia to upgrade)"
    _nvidia_hold hold
fi

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
    if grep -qiE "nvidia-dkms|dkms.*nvidia" "${LOG_FILE}" 2>/dev/null; then
        print_warn "upgrade had NVIDIA DKMS build failure — run with --nvidia flag to attempt repair"
    else
        print_warn "upgrade returned non-zero — some packages may be held"
    fi
    record_warn
fi

print_step "apt-get dist-upgrade (metapackages & kernel)"
if sudo_silent apt-get dist-upgrade "${APT_OPTS[@]}"; then
    print_ok; record_ok
else
    if grep -qiE "nvidia-dkms|dkms.*nvidia" "${LOG_FILE}" 2>/dev/null; then
        print_warn "dist-upgrade had NVIDIA DKMS failure — run with --nvidia to attempt repair"
    else
        print_warn "dist-upgrade returned non-zero"
    fi
    record_warn
fi

# ── 3. Cleanup ────────────────────────────────────────────────────────────────
print_section "Cleaning up"

print_step "Remove orphaned packages"
if sudo_silent apt-get autoremove -y -q; then
    print_ok; record_ok
else
    if grep -qiE "nvidia-dkms|dkms.*nvidia" "${LOG_FILE}" 2>/dev/null; then
        print_warn "autoremove had NVIDIA DKMS failure (expected on mainline kernels)"
    else
        print_warn "autoremove non-zero"
    fi
    record_warn
fi

print_step "Clean package cache"
sudo_silent apt-get autoclean -q && print_ok || { print_warn "autoclean non-zero"; record_warn; }

# ── Restore NVIDIA hold state ─────────────────────────────────────────────────
if [[ "${UPGRADE_NVIDIA}" -eq 0 ]]; then
    _nvidia_hold unhold
fi

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
