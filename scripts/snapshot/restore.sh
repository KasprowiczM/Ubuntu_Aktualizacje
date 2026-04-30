#!/usr/bin/env bash
# =============================================================================
# scripts/snapshot/restore.sh — Restore from a previously-created snapshot.
#
# Usage:
#   bash scripts/snapshot/restore.sh <snapshot-id>
#
# Resolves the active snapshot provider (timeshift > etckeeper) and runs its
# restore command.  Honours SUDO_ASKPASS when set so the dashboard can call
# this without a TTY.  Exits non-zero on any failure so the caller can show
# the error.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

SNAP_ID="${1:-}"
[[ -z "$SNAP_ID" ]] && { print_error "usage: $0 <snapshot-id>"; exit 2; }

print_header "Snapshot restore — ${SNAP_ID}"

if command -v timeshift >/dev/null 2>&1; then
    print_step "timeshift --restore --snapshot ${SNAP_ID}"
    if sudo timeshift --restore --snapshot "${SNAP_ID}" --yes 2>&1; then
        print_ok
        exit 0
    else
        print_error "timeshift restore failed"
        exit 20
    fi
fi

if command -v etckeeper >/dev/null 2>&1; then
    print_warn "timeshift unavailable — falling back to etckeeper /etc-only restore"
    print_step "etckeeper vcs reset --hard ${SNAP_ID}"
    if sudo etckeeper vcs reset --hard "${SNAP_ID}" 2>&1; then
        print_ok "restored /etc to ${SNAP_ID} (system files NOT restored)"
        exit 0
    else
        print_error "etckeeper restore failed"
        exit 20
    fi
fi

print_error "no snapshot provider available (install timeshift or etckeeper)"
exit 10
