#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init check drivers
json_register_exit_trap "${JSON_OUT:-}"

print_header "Drivers & firmware — check"
detect_gpu

# NVIDIA driver presence + smi
if [[ "${HAS_NVIDIA:-0}" -eq 1 ]]; then
    nv_pkg=$(dpkg -l 'nvidia-driver-*' 2>/dev/null | awk '/^ii/{print $2}' | head -1)
    nv_ver=$(dpkg -l 'nvidia-driver-*' 2>/dev/null | awk '/^ii/{print $3}' | head -1)
    json_add_item id="drivers:nvidia:installed" action="present" \
        from="${nv_pkg}" to="${nv_ver}" result="ok"
    if has_cmd nvidia-smi && nvidia-smi >/dev/null 2>&1; then
        smi=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)
        json_add_diag info NVIDIA-SMI "${smi}"
    else
        json_add_diag warn NVIDIA-SMI-DOWN "nvidia-smi not responsive"
        json_count_warn
    fi
fi

# Firmware
if has_cmd fwupdmgr; then
    chk=$(fwupdmgr get-updates 2>&1 || true)
    if echo "$chk" | grep -qiE "No upgrades for|No updates available"; then
        json_add_diag info FIRMWARE-CURRENT "fwupd reports no updates"
    elif echo "$chk" | grep -qiE "upgrade available|updates available"; then
        json_add_diag warn FIRMWARE-AVAILABLE "fwupd has firmware updates available"
        json_count_warn
    fi
else
    json_add_diag info FIRMWARE-NO-FWUPD "fwupdmgr not installed"
fi

if [[ -f /var/run/reboot-required ]]; then
    json_set_needs_reboot 1
    json_add_diag warn REBOOT-PENDING "kernel/driver update awaiting reboot"
fi
exit 0
