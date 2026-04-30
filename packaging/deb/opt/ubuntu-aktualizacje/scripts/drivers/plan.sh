#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init plan drivers
json_register_exit_trap "${JSON_OUT:-}"

UPGRADE_NVIDIA="${UPGRADE_NVIDIA:-0}"
detect_gpu

# NVIDIA candidate
if [[ "${HAS_NVIDIA:-0}" -eq 1 && "${UPGRADE_NVIDIA}" -eq 1 ]]; then
    nv_pkg=$(dpkg -l 'nvidia-driver-*' 2>/dev/null | awk '/^ii/{print $2}' | head -1)
    if [[ -n "$nv_pkg" ]]; then
        inst=$(apt_pkg_version "$nv_pkg")
        cand=$(apt_pkg_candidate "$nv_pkg")
        if [[ -n "$cand" && "$cand" != "(none)" && "$cand" != "$inst" ]]; then
            json_add_item id="drivers:nvidia:upgrade" action="upgrade" \
                from="${inst}" to="${cand}" result="noop"
        fi
    fi
elif [[ "${HAS_NVIDIA:-0}" -eq 1 ]]; then
    json_add_diag info NVIDIA-HOLD-POLICY "NVIDIA upgrade requires --nvidia flag"
fi

# Firmware — stable per-device id (sanitised device name)
if has_cmd fwupdmgr; then
    chk=$(fwupdmgr get-updates 2>&1 || true)
    current_dev=""
    while IFS= read -r line; do
        # Device header lines: "├─Dell TB16 Dock:" or "└─UEFI dbx:"
        if [[ "$line" =~ ^[[:space:]]*[│├└─]+(.+):$ ]]; then
            current_dev=$(echo "${BASH_REMATCH[1]}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')
            continue
        fi
        if echo "$line" | grep -qE 'New version'; then
            ver=$(echo "$line" | awk '{print $NF}')
            dev="${current_dev:-unknown}"
            json_add_item id="drivers:firmware:${dev}" action="upgrade" \
                to="${ver}" result="noop"
        fi
    done <<< "$chk"
fi
exit 0
