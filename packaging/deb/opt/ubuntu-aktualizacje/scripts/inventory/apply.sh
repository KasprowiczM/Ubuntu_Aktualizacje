#!/usr/bin/env bash
# scripts/inventory/apply.sh — Regenerate APPS.md (delegates to legacy)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/json.sh"

# Inventory itself runs the underlying script silently to avoid recursion
unset INVENTORY_SILENT
json_init apply inventory
json_register_exit_trap "${JSON_OUT:-}"

legacy="${SCRIPT_DIR}/scripts/update-inventory.sh"
rc=0
bash "$legacy" >> "${LOG_FILE}" 2>&1 || rc=$?

if [[ -f "${SCRIPT_DIR}/APPS.md" ]]; then
    lines=$(wc -l < "${SCRIPT_DIR}/APPS.md")
    json_add_item id="inventory:apps-md" action="generate" \
        to="${lines} lines" result="ok"
    json_count_ok
else
    json_add_item id="inventory:apps-md" action="generate" result="failed"
    json_add_diag error INVENTORY-MISSING "APPS.md was not generated"
    json_count_err
    exit 20
fi

if [[ $rc -ne 0 ]]; then
    json_add_diag warn INVENTORY-LEGACY-WARN "legacy update-inventory.sh returned ${rc}"
    json_count_warn
    exit 1
fi
exit 0
