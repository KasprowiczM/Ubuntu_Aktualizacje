#!/usr/bin/env bash
# =============================================================================
# scripts/update-drivers.sh — Hardware drivers and firmware updates
#
# Covers:
#   • NVIDIA driver (580 series) via apt
#   • NVIDIA Container Toolkit via apt
#   • Firmware via fwupd (Dell BIOS, Intel CPU microcode, GPU vBIOS)
#   • ubuntu-drivers (detects/recommends/applies driver updates)
#   • Kernel modules check
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Drivers & Firmware Updates"

require_sudo

# ── 1. NVIDIA driver via APT ──────────────────────────────────────────────────
print_section "NVIDIA Driver (APT)"

print_step "Refresh APT sources"
run_silent sudo apt-get update -q
print_ok

print_step "Upgrade nvidia-driver-580 and NVIDIA packages"
if sudo_silent apt-get install -y -q \
    --only-upgrade \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    nvidia-driver-580 \
    nvidia-container-toolkit \
    nvidia-container-runtime \
    2>/dev/null; then
    print_ok
    record_ok
else
    print_warn "NVIDIA APT upgrade returned non-zero (may be no update available)"
    record_warn
fi

# Show installed NVIDIA driver version
nvidia_ver=$(dpkg -l nvidia-driver-580 2>/dev/null | awk '/^ii/{print $3}')
[[ -n "$nvidia_ver" ]] && print_info "Installed NVIDIA driver: ${nvidia_ver}"

# Check nvidia-smi
print_step "nvidia-smi check"
if nvidia-smi &>/dev/null; then
    gpu_info=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)
    print_ok "${gpu_info}"
    record_ok
else
    print_warn "nvidia-smi not responding — may need reboot to load new kernel modules"
    print_info "Running kernel: $(uname -r)"
    print_info "NVIDIA modules available for: $(dpkg -l 'linux-modules-nvidia-580-*' 2>/dev/null | awk '/^ii/{print $2}' | sed 's/linux-modules-nvidia-580-//' | paste -sd', ')"
    record_warn
fi

# ── 2. ubuntu-drivers ─────────────────────────────────────────────────────────
# Note: autoinstall is intentionally skipped — it selects the "recommended" driver
# (535) which can downgrade an explicitly-managed newer driver (580) and fail DKMS
# on mainline kernels. Driver versions are managed explicitly via apt above.
print_section "Driver recommendations"

if has_cmd ubuntu-drivers; then
    ubuntu-drivers devices 2>/dev/null | grep -E "(modalias|driver|recommended)" | while IFS= read -r l; do
        print_info "${l}"
    done
else
    print_warn "ubuntu-drivers not installed — skipping"
    record_warn
fi

# ── 3. Firmware updates via fwupd ─────────────────────────────────────────────
print_section "Firmware Updates (fwupd)"

if ! has_cmd fwupdmgr; then
    print_warn "fwupdmgr not found — skipping firmware updates"
    record_warn
else
    print_step "Refresh firmware metadata"
    fwupd_refresh=$(sudo fwupdmgr refresh --force 2>&1 || true)
    echo "$fwupd_refresh" >> "${LOG_FILE}"
    if echo "$fwupd_refresh" | grep -qiE "(successfully|already up.to.date|no devices)"; then
        print_ok
        record_ok
    else
        print_ok "refresh completed"
        record_ok
    fi

    print_step "Check for firmware updates"
    fwupd_check=$(fwupdmgr get-updates 2>&1 || true)
    echo "$fwupd_check" >> "${LOG_FILE}"

    if echo "$fwupd_check" | grep -qiE "No upgrades for|No updates available"; then
        print_ok "No firmware updates available"
        record_ok
    elif echo "$fwupd_check" | grep -qiE "upgrade available|updates available|^\s+Version:"; then
        print_warn "Firmware updates available — apply manually with: fwupdmgr update"
        print_info "Available updates:"
        echo "$fwupd_check" | grep -E "(Version|Summary|Description)" | head -10 | while IFS= read -r l; do
            print_info "  ${l}"
        done
        record_warn
    else
        print_ok "Firmware is up to date"
        record_ok
    fi

    # Show current firmware devices
    print_section "Firmware device status"
    fwupdmgr get-devices 2>/dev/null | grep -E "^\s*(├|└|│|Device|Current version)" | \
        grep -v "^$" | head -20 | while IFS= read -r l; do
        print_info "${l}"
    done
fi

# ── 4. Kernel modules check ───────────────────────────────────────────────────
print_section "Kernel status"

current_kernel=$(uname -r)
print_info "Running kernel: ${current_kernel}"

# List available kernels
available_kernels=$(dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/{print $2}' | grep -v generic-hwe || true)
if [[ -n "$available_kernels" ]]; then
    print_info "Installed kernel images:"
    echo "$available_kernels" | while read -r k; do print_info "  ${k}"; done
fi

# Reboot check
if [[ -f /var/run/reboot-required ]]; then
    print_warn "*** REBOOT REQUIRED *** (kernel or driver update pending)"
    [[ -f /var/run/reboot-required.pkgs ]] && \
        print_info "Packages requiring reboot: $(cat /var/run/reboot-required.pkgs | paste -sd', ')"
    record_warn
else
    print_info "No reboot required"
fi

print_summary "Drivers & Firmware Summary"

# ── Update inventory (skipped when called from update-all.sh) ─────────────────
if [[ "${INVENTORY_SILENT:-0}" != "1" ]]; then
    print_section "Updating APPS.md"
    print_step "update-inventory.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && print_ok || print_warn "inventory update failed"
fi
