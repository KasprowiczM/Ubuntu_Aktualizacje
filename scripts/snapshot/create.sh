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
# Emits JSON sidecar (kind=apply, category=… via UA_SNAPSHOT_FOR env or
# generic "snapshot" if not set).
#
# Usage:
#   scripts/snapshot/create.sh "<comment>"
#   UA_SNAPSHOT_FOR=apt scripts/snapshot/create.sh "before apt apply"
#
# Outputs to stdout: snapshot id (timeshift name or etckeeper commit hash).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

COMMENT="${1:-Ubuntu_Aktualizacje pre-apply}"

snapshot_id=""

if command -v timeshift >/dev/null 2>&1; then
    print_step "timeshift --create"
    if out=$(sudo timeshift --create --comments "${COMMENT}" --tags O 2>&1); then
        echo "$out" >> "${LOG_FILE:-/dev/null}"
        snapshot_id=$(echo "$out" | grep -oE 'snapshot.* > .*' | awk '{print $NF}' | head -1)
        [[ -z "$snapshot_id" ]] && snapshot_id="timeshift-$(date +%Y%m%d_%H%M%S)"
        print_ok
        echo "$snapshot_id"
        exit 0
    else
        print_warn "timeshift snapshot failed"
        echo "$out" >&2
    fi
fi

if command -v etckeeper >/dev/null 2>&1; then
    print_step "etckeeper commit"
    if sudo etckeeper commit "${COMMENT}" >> "${LOG_FILE:-/dev/null}" 2>&1; then
        snapshot_id=$(sudo git -C /etc rev-parse HEAD 2>/dev/null || echo "etckeeper-unknown")
        print_ok
        echo "$snapshot_id"
        exit 0
    fi
fi

print_error "no snapshot provider available (timeshift / etckeeper)"
exit 10
