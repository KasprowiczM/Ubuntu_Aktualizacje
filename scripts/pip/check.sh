#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"
source "${SCRIPT_DIR}/lib/progress.sh"

json_init check pip
json_register_exit_trap "${JSON_OUT:-}"

print_header "Python — check"
detect_package_managers

PY3=""
for c in "${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}/bin/python3" /usr/bin/python3; do
    [[ -x "$c" ]] && PY3="$c" && break
done
if [[ -z "$PY3" ]]; then
    json_add_diag info PIP-MISSING "python3 not found"
    exit 0
fi

# pip user outdated
out=$($PY3 -m pip list --user --outdated --format=json 2>/dev/null || echo '[]')
n=$(echo "$out" | python3 -c "
import json, sys
d=json.loads(sys.stdin.read() or '[]')
for x in d:
    print(f\"{x['name']}|{x['version']}|{x['latest_version']}\")
")
count_pip=0; detail=""
while IFS='|' read -r name cur lat; do
    [[ -z "$name" ]] && continue
    json_add_item id="pip:upgrade:${name}" action="upgrade" \
        from="${cur}" to="${lat}" result="noop"
    detail+="${name}: ${cur} → ${lat}"$'\n'
    count_pip=$((count_pip + 1))
done <<< "$n"
print_found pip "$count_pip" "$detail"
json_add_diag info PIP-OUTDATED "${count_pip} pip user package(s) outdated"

# pipx outdated detection — pipx list --json
PIPX_BIN=$(command -v pipx 2>/dev/null || true)
count_pipx=0
if [[ -n "$PIPX_BIN" ]]; then
    plist=$(run_as_user "${PIPX_BIN}" list --json 2>/dev/null || echo '{}')
    # No 'outdated' subcommand pre v1.x; emit informational diag with pipx version count
    n_pipx=$(echo "$plist" | python3 -c "
import json, sys
try:
    d=json.loads(sys.stdin.read() or '{}')
    print(len(d.get('venvs',{})))
except Exception:
    print(0)
")
    json_add_diag info PIPX-COUNT "${n_pipx} pipx venv(s) installed"
fi
exit 0
