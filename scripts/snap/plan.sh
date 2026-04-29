#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init plan snap
json_register_exit_trap "${JSON_OUT:-}"

print_header "Snap — plan"

if ! has_cmd snap; then
    json_add_diag info SNAP-MISSING "snapd not installed"
    exit 0
fi

# `snap refresh --list` is the canonical "what would refresh do" query.
n=0
if mapfile -t outdated < <(_snap_cmd refresh --list 2>/dev/null | tail -n +2); then
    for line in "${outdated[@]}"; do
        [[ -z "$line" ]] && continue
        name=$(echo "$line" | awk '{print $1}')
        new=$(echo "$line" | awk '{print $2}')
        old=$(snap_version "$name" 2>/dev/null || echo "")
        json_add_item id="snap:upgrade:${name}" action="refresh" \
            from="${old}" to="${new}" result="noop"
        n=$((n + 1))
    done
fi
json_add_diag info SNAP-PLAN-SIZE "${n} snap refresh action(s) planned"
exit 0
