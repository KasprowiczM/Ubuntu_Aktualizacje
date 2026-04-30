#!/usr/bin/env bash
# scripts/snapshot/list.sh — List snapshots from active provider.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if command -v timeshift >/dev/null 2>&1; then
    sudo timeshift --list 2>/dev/null || true
elif command -v etckeeper >/dev/null 2>&1; then
    sudo git -C /etc log --oneline -20 2>/dev/null || true
else
    print_warn "no snapshot provider installed"
    exit 10
fi
