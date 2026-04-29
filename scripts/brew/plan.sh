#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init plan brew
json_register_exit_trap "${JSON_OUT:-}"

detect_package_managers
if [[ "${HAS_BREW:-0}" -ne 1 ]]; then
    json_add_diag info BREW-MISSING "homebrew not installed"
    exit 0
fi

n=0
# brew outdated --json=v2 gives full from->to
out=$(run_as_user "${BREW_BIN}" outdated --json=v2 2>/dev/null || echo '{}')
n_out=$(echo "$out" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    items = []
    for f in d.get('formulae', []):
        items.append(('formula', f.get('name',''), (f.get('installed_versions') or [''])[0], f.get('current_version','')))
    for c in d.get('casks', []):
        items.append(('cask', c.get('name',''), (c.get('installed_versions') or [''])[0], c.get('current_version','')))
    for kind, name, frm, to in items:
        print(f'{kind}|{name}|{frm}|{to}')
except Exception:
    pass
" 2>/dev/null)
while IFS='|' read -r kind name frm to; do
    [[ -z "$kind" || -z "$name" ]] && continue
    json_add_item id="brew:upgrade:${kind}:${name}" action="upgrade" \
        from="${frm}" to="${to}" result="noop"
    n=$((n + 1))
done <<< "$n_out"

json_add_diag info BREW-PLAN-SIZE "${n} brew upgrade(s) planned"
exit 0
