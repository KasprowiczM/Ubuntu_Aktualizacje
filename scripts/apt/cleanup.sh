#!/usr/bin/env bash
# =============================================================================
# scripts/apt/cleanup.sh — APT cache & orphan removal (sudo required)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init cleanup apt
json_register_exit_trap "${JSON_OUT:-}"

print_header "APT — cleanup"

if ! has_cmd apt-get; then
    json_add_diag error MISSING-TOOL "apt-get not found"
    json_count_err
    exit 10
fi

require_sudo

print_step "apt-get autoremove"
if sudo apt-get autoremove -y -q >> "${LOG_FILE}" 2>&1; then
    print_ok
    json_add_item id="apt:autoremove" action="cleanup" result="ok"
    json_count_ok
else
    rc=$?
    if grep -qiE "nvidia-dkms|dkms.*nvidia" "${LOG_FILE}" 2>/dev/null; then
        json_add_diag warn APT-DKMS-NVIDIA "autoremove hit NVIDIA DKMS issue (expected on mainline kernel)"
    fi
    json_add_item id="apt:autoremove" action="cleanup" result="warn"
    json_count_warn
    print_warn "autoremove returned ${rc}"
fi

print_step "apt-get autoclean"
if sudo apt-get autoclean -y -q >> "${LOG_FILE}" 2>&1; then
    print_ok
    json_add_item id="apt:autoclean" action="cleanup" result="ok"
    json_count_ok
else
    json_add_item id="apt:autoclean" action="cleanup" result="warn"
    json_count_warn
fi

exit 0
