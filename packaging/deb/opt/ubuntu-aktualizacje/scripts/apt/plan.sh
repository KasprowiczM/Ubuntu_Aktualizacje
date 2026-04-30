#!/usr/bin/env bash
# =============================================================================
# scripts/apt/plan.sh — Compute APT upgrade plan (no mutation)
#
# Produces JSON sidecar with the exact set of packages that an apt-get upgrade
# (and dist-upgrade) would touch, based on the current cached state.
#
# Exit codes: 0 ok, 1 warn (e.g. nothing-to-do but stale lists), 10 missing tool.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/detect.sh
source "${SCRIPT_DIR}/lib/detect.sh"
# shellcheck source=lib/json.sh
source "${SCRIPT_DIR}/lib/json.sh"

json_init plan apt
json_register_exit_trap "${JSON_OUT:-}"

print_header "APT — plan"

if ! has_cmd apt-get; then
    json_add_diag error MISSING-TOOL "apt-get not found"
    json_count_err
    exit 10
fi

UPGRADE_NVIDIA="${UPGRADE_NVIDIA:-0}"

# Use a simulated dist-upgrade. Doesn't need root if cache is readable.
sim=$(apt-get -s -q dist-upgrade 2>/dev/null || true)
if [[ -z "$sim" ]]; then
    json_add_diag warn APT-SIM-EMPTY "apt-get -s dist-upgrade returned no output"
    json_count_warn
    exit 1
fi

# Parse "Inst <pkg> [oldver] (newver source)" lines
plan_count=0
while IFS= read -r line; do
    [[ "$line" == "Inst "* ]] || continue
    # Inst sshd [1:9.6p1-3ubuntu13.5] (1:9.6p1-3ubuntu13.6 Ubuntu:24.04/...) []
    pkg=$(echo "$line" | awk '{print $2}')
    old=$(echo "$line" | grep -oP '\[\K[^]]+' | head -1 || true)
    new=$(echo "$line" | grep -oP '\(\K[^ )]+' | head -1 || true)
    json_add_item id="apt:upgrade:${pkg}" action="upgrade" \
        from="${old:-}" to="${new:-}" result="noop"
    plan_count=$((plan_count + 1))
done <<< "$sim"

# Removals
while IFS= read -r line; do
    [[ "$line" == "Remv "* ]] || continue
    pkg=$(echo "$line" | awk '{print $2}')
    json_add_item id="apt:remove:${pkg}" action="remove" result="noop"
    plan_count=$((plan_count + 1))
done <<< "$sim"

# NVIDIA hold awareness
if [[ "$UPGRADE_NVIDIA" -ne 1 ]]; then
    nvidia_in_plan=$(echo "$sim" | grep -E '^(Inst|Remv) (nvidia|libnvidia)' || true)
    if [[ -n "$nvidia_in_plan" ]]; then
        json_add_advisory "NVIDIA packages will be held during apply (use --nvidia to upgrade)"
        json_add_diag info APT-NVIDIA-PLAN "$(echo "$nvidia_in_plan" | wc -l | awk '{print $1}') NVIDIA packages would change but are held"
    fi
fi

print_info "${plan_count} planned action(s)"
json_add_diag info APT-PLAN-SIZE "${plan_count} actions planned"

if [[ $plan_count -eq 0 ]]; then
    json_count_ok
    print_ok "no changes planned"
fi

exit 0
