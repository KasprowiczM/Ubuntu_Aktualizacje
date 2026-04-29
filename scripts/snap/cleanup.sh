#!/usr/bin/env bash
# scripts/snap/cleanup.sh — Remove disabled snap revisions
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init cleanup snap
json_register_exit_trap "${JSON_OUT:-}"

if ! has_cmd snap; then
    json_add_diag info SNAP-MISSING "snapd not installed"
    exit 0
fi

require_sudo

removed=0
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    rev=$(echo "$line" | awk '{print $2}')
    if sudo snap remove "$name" --revision="$rev" >> "${LOG_FILE}" 2>&1; then
        json_add_item id="snap:remove-rev:${name}-${rev}" action="remove" \
            from="${rev}" result="ok"
        json_count_ok
        removed=$((removed + 1))
    else
        json_add_item id="snap:remove-rev:${name}-${rev}" action="remove" result="failed"
        json_add_diag warn SNAP-REMOVE-FAIL "failed to remove ${name} revision ${rev}"
        json_count_warn
    fi
done < <(snap list --all 2>/dev/null | awk '$NF ~ /disabled/ {print $1, $3}')

json_add_diag info SNAP-CLEANUP-DONE "${removed} disabled snap revision(s) removed"
exit 0
