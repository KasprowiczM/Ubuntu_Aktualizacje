#!/usr/bin/env bash
# =============================================================================
# scripts/snapshot/create.sh — Create a pre-apply snapshot via timeshift.
#
# Strategy:
#   • Prefer `timeshift --create` (rsync mode) when available.
#   • Fallback to `etckeeper commit` for /etc-only snapshot when timeshift
#     is missing.
#   • If neither is available, exits 10 (precondition failed).
#
# Hardening (2026-05-03):
#   • Hard timeout on every snapshot provider so a hung timeshift cannot
#     stall the whole update run (the dashboard reproduced this twice).
#   • All sudo calls go through SUDO_ASKPASS when set, so non-TTY callers
#     (dashboard) authenticate without a prompt.
#
# Usage:
#   scripts/snapshot/create.sh "<comment>"
#
# Outputs to stdout: snapshot id (timeshift name or etckeeper commit hash).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

COMMENT="${1:-Ascendo pre-apply}"
SNAPSHOT_TIMEOUT="${UA_SNAPSHOT_TIMEOUT:-300}"   # 5 minutes default

snapshot_id=""
have_timeout=0
command -v timeout >/dev/null 2>&1 && have_timeout=1

# wrap_to_with_timeout cmd …  → run with timeout when available, else direct.
_run_bounded() {
    if [[ "$have_timeout" == "1" ]]; then
        timeout --kill-after=10 "${SNAPSHOT_TIMEOUT}" "$@"
    else
        "$@"
    fi
}

if command -v timeshift >/dev/null 2>&1; then
    print_step "timeshift --create"
    if out=$(_run_bounded sudo timeshift --create --comments "${COMMENT}" --tags O 2>&1); then
        echo "$out" >> "${LOG_FILE:-/dev/null}"
        snapshot_id=$(echo "$out" | grep -oE 'snapshot.* > .*' | awk '{print $NF}' | head -1)
        [[ -z "$snapshot_id" ]] && snapshot_id="timeshift-$(date +%Y%m%d_%H%M%S)"
        print_ok
        echo "$snapshot_id"
        exit 0
    else
        rc=$?
        if [[ $rc -eq 124 || $rc -eq 137 ]]; then
            print_warn "timeshift snapshot timed out after ${SNAPSHOT_TIMEOUT}s — falling back"
        else
            print_warn "timeshift snapshot failed (exit $rc)"
        fi
        echo "$out" >&2
    fi
fi

if command -v etckeeper >/dev/null 2>&1; then
    print_step "etckeeper commit"
    if _run_bounded sudo etckeeper commit "${COMMENT}" >> "${LOG_FILE:-/dev/null}" 2>&1; then
        snapshot_id=$(sudo git -C /etc rev-parse HEAD 2>/dev/null || echo "etckeeper-unknown")
        print_ok
        echo "$snapshot_id"
        exit 0
    fi
fi

print_error "no snapshot provider available (timeshift / etckeeper)"
exit 10
