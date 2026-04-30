#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init verify drivers
json_register_exit_trap "${JSON_OUT:-}"

detect_gpu
EXIT_RC=0

if [[ "${HAS_NVIDIA:-0}" -eq 1 ]]; then
    if has_cmd nvidia-smi && nvidia-smi >/dev/null 2>&1; then
        smi=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)
        json_add_item id="drivers:nvidia-smi" action="health" result="ok" details="${smi}"
        json_count_ok
    else
        json_add_item id="drivers:nvidia-smi" action="health" result="failed"
        json_add_diag error NVIDIA-SMI-DOWN "nvidia-smi not responsive after apply"
        json_count_err
        EXIT_RC=1
    fi
fi

# Broken NVIDIA dpkg state is a critical post-apply signal
broken=$(dpkg -l 'nvidia-*' 'libnvidia-*' 2>/dev/null | awk '/^iF/{print $2}' || true)
if [[ -n "$broken" ]]; then
    json_add_diag error DPKG-NVIDIA-BROKEN "broken NVIDIA dpkg state after apply: $(echo "$broken" | tr '\n' ' ')"
    json_count_err
    EXIT_RC=1
fi

if [[ -f /var/run/reboot-required ]]; then
    json_set_needs_reboot 1
fi

exit $EXIT_RC
