#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init plan flatpak
json_register_exit_trap "${JSON_OUT:-}"

if ! has_cmd flatpak; then
    json_add_diag info FLATPAK-MISSING "flatpak not installed"
    exit 0
fi

n=0
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    app=$(echo "$line" | awk '{print $2}')
    [[ -z "$app" ]] && continue
    json_add_item id="flatpak:upgrade:${app}" action="upgrade" result="noop"
    n=$((n + 1))
done < <(flatpak remote-ls --updates 2>/dev/null || true)

json_add_diag info FLATPAK-PLAN-SIZE "${n} flatpak update(s) planned"
exit 0
