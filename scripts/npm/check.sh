#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"
source "${SCRIPT_DIR}/lib/progress.sh"

json_init check npm
json_register_exit_trap "${JSON_OUT:-}"

print_header "npm — check"
detect_package_managers
if [[ -z "${NPM_BIN:-}" ]]; then
    json_add_diag info NPM-MISSING "npm not found"
    exit 0
fi

# Outdated count
out=$(run_as_user "${NPM_BIN}" outdated -g --json 2>/dev/null || echo '{}')
n=$(echo "$out" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for name, info in d.items():
        print(f\"{name}|{info.get('current','')}|{info.get('latest','')}\")
except Exception:
    pass
" 2>/dev/null)

count=0; detail=""
while IFS='|' read -r name cur lat; do
    [[ -z "$name" ]] && continue
    json_add_item id="npm:upgrade:${name}" action="upgrade" \
        from="${cur}" to="${lat}" result="noop"
    detail+="${name}: ${cur} → ${lat}"$'\n'
    count=$((count + 1))
done <<< "$n"
print_found npm "$count" "$detail"
json_add_diag info NPM-OUTDATED "${count} npm global(s) outdated"
exit 0
