#!/usr/bin/env bash
# =============================================================================
# scripts/rebuild-dkms.sh — Rebuild DKMS kernel modules for current kernel
#
# Solves the NVIDIA (and other DKMS) module problem when running a mainline
# kernel that wasn't present when the driver was first installed.
#
# Covers:
#   • NVIDIA driver modules (580 series)
#   • Any other DKMS modules installed on the system
#
# Usage:
#   ./scripts/rebuild-dkms.sh               # Rebuild for current kernel
#   ./scripts/rebuild-dkms.sh --all-kernels # Rebuild for all installed kernels
#   ./scripts/rebuild-dkms.sh --status      # Show DKMS status only
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

CURRENT_KERNEL=$(uname -r)
ALL_KERNELS=0
STATUS_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all-kernels) ALL_KERNELS=1 ;;
        --status)      STATUS_ONLY=1 ;;
        -h|--help)
            echo "Usage: $0 [--all-kernels] [--status]"
            exit 0 ;;
    esac
    shift
done

print_header "DKMS — Kernel Module Rebuild"

require_sudo

# ── 1. DKMS status ────────────────────────────────────────────────────────────
print_section "Current DKMS status"

if ! has_cmd dkms; then
    print_warn "dkms not installed — installing"
    sudo_silent apt-get install -y -q dkms && print_ok || { print_error "dkms install failed"; exit 1; }
fi

DKMS_STATUS=$(dkms status 2>/dev/null)
if [[ -z "$DKMS_STATUS" ]]; then
    print_warn "No DKMS modules found"
    exit 0
fi

echo "$DKMS_STATUS" | while IFS= read -r line; do
    if echo "$line" | grep -q "installed"; then
        print_info "  ${GREEN}✔${RESET} ${line}"
    elif echo "$line" | grep -qE "built|added"; then
        print_warn "  ⚠ ${line} (built but not installed)"
    else
        print_info "  ${line}"
    fi
done

[[ $STATUS_ONLY -eq 1 ]] && { print_summary "DKMS Status"; exit 0; }

# ── 2. Determine kernels to build for ────────────────────────────────────────
if [[ $ALL_KERNELS -eq 1 ]]; then
    KERNELS=$(ls /lib/modules/ 2>/dev/null)
    print_info "Rebuilding for ALL installed kernels"
else
    KERNELS="$CURRENT_KERNEL"
    print_info "Rebuilding for current kernel: ${CURRENT_KERNEL}"
fi

# ── 3. Install kernel headers if missing ─────────────────────────────────────
print_section "Kernel headers"

for kernel in $KERNELS; do
    headers_pkg="linux-headers-${kernel}"
    print_step "Check headers: ${headers_pkg}"
    if dpkg -l "$headers_pkg" &>/dev/null 2>&1; then
        print_info "(already installed)"
    else
        # Try installing
        if sudo_silent apt-get install -y -q "$headers_pkg" 2>/dev/null; then
            print_ok; record_ok
        else
            # May need to use generic or mainline headers
            print_warn "Package not found: ${headers_pkg}"
            print_info "Attempting: linux-headers-generic"
            if sudo_silent apt-get install -y -q linux-headers-generic 2>/dev/null; then
                print_ok "installed linux-headers-generic"; record_ok
            else
                print_warn "Could not install headers for ${kernel} — module build may fail"
                record_warn
            fi
        fi
    fi
done

# ── 4. NVIDIA: ensure kernel source is available ─────────────────────────────
print_section "NVIDIA DKMS rebuild"

detect_gpu

if [[ $HAS_NVIDIA -eq 0 ]]; then
    print_info "No NVIDIA GPU detected — skipping NVIDIA rebuild"
else
    NVIDIA_DRV_PKG=$(dpkg -l 'nvidia-driver-*' 2>/dev/null | awk '/^ii/{print $2}' | head -1)
    NVIDIA_VER=$(dpkg -l "$NVIDIA_DRV_PKG" 2>/dev/null | awk '/^ii/{print $3}' | head -1)
    print_info "NVIDIA driver package: ${NVIDIA_DRV_PKG} (${NVIDIA_VER})"

    # Get DKMS module name for NVIDIA
    NVIDIA_DKMS_NAME=$(dkms status 2>/dev/null | grep -i nvidia | awk -F, '{print $1}' | head -1 | tr -d ' ')

    if [[ -z "$NVIDIA_DKMS_NAME" ]]; then
        print_warn "No NVIDIA DKMS module found — trying nvidia-current"
        # Try reinstalling to register with DKMS
        print_step "Reinstall ${NVIDIA_DRV_PKG} (register DKMS)"
        sudo_silent apt-get install -y -q --reinstall "$NVIDIA_DRV_PKG" && print_ok || { print_warn "reinstall failed"; record_warn; }
        NVIDIA_DKMS_NAME=$(dkms status 2>/dev/null | grep -i nvidia | awk -F, '{print $1}' | head -1 | tr -d ' ')
    fi

    if [[ -n "$NVIDIA_DKMS_NAME" ]]; then
        for kernel in $KERNELS; do
            print_step "dkms install ${NVIDIA_DKMS_NAME} for kernel ${kernel}"
            if dkms status 2>/dev/null | grep -q "${NVIDIA_DKMS_NAME}.*${kernel}.*installed"; then
                print_info "(already installed for ${kernel})"
            else
                if sudo dkms install "${NVIDIA_DKMS_NAME}" -k "$kernel" >> "${LOG_FILE}" 2>&1; then
                    print_ok; record_ok
                else
                    print_warn "dkms build failed for ${kernel} — may need newer headers"
                    record_warn
                fi
            fi
        done
    fi
fi

# ── 5. Rebuild ALL other DKMS modules ────────────────────────────────────────
print_section "Rebuild all DKMS modules"

dkms status 2>/dev/null | awk -F'[, ]' '{print $1"/"$2}' | sort -u | while read -r module_ver; do
    module=$(echo "$module_ver" | cut -d/ -f1)
    version=$(echo "$module_ver" | cut -d/ -f2)
    [[ -z "$module" || -z "$version" ]] && continue

    for kernel in $KERNELS; do
        status=$(dkms status "$module" -v "$version" -k "$kernel" 2>/dev/null | awk -F: '{print $NF}' | tr -d ' ')
        if [[ "$status" == "installed" ]]; then
            print_info "  ${module}/${version} on ${kernel}: already installed"
        else
            print_step "dkms install ${module}/${version} -k ${kernel}"
            if sudo dkms install "$module" -v "$version" -k "$kernel" --force >> "${LOG_FILE}" 2>&1; then
                print_ok; record_ok
            else
                print_warn "Failed: ${module}/${version} on ${kernel}"
                record_warn
            fi
        fi
    done
done

# ── 6. Final status ───────────────────────────────────────────────────────────
print_section "DKMS status after rebuild"
dkms status 2>/dev/null | while IFS= read -r line; do
    print_info "  $line"
done

# ── 7. nvidia-smi test ────────────────────────────────────────────────────────
if [[ $HAS_NVIDIA -eq 1 ]]; then
    print_section "NVIDIA driver test"
    print_step "nvidia-smi"
    if nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1 | grep -q .; then
        print_ok "$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)"
        record_ok
    else
        print_warn "nvidia-smi not responding — reboot required to load new modules"
        print_info "Run: sudo reboot"
        record_warn
    fi
fi

if [[ -f /var/run/reboot-required ]]; then
    print_warn "*** REBOOT REQUIRED to activate new kernel modules ***"
fi

print_summary "DKMS Rebuild Summary"
