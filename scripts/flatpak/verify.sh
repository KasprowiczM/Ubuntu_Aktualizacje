#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init verify flatpak
json_register_exit_trap "${JSON_OUT:-}"

if ! has_cmd flatpak; then
    json_add_diag info FLATPAK-MISSING "flatpak not installed"
    exit 0
fi

CONFIG_FLATPAK="${SCRIPT_DIR}/config/flatpak-packages.list"
EXIT_RC=0

if [[ -f "$CONFIG_FLATPAK" ]]; then
    installed=$(flatpak list --app --columns=application 2>/dev/null || true)
    while IFS= read -r app_id; do
        [[ -z "$app_id" ]] && continue
        if echo "$installed" | grep -q "^${app_id}$"; then
            json_add_item id="flatpak:installed:${app_id}" action="present" result="ok"
            json_count_ok
        else
            json_add_item id="flatpak:installed:${app_id}" action="present" result="failed"
            json_add_diag warn FLATPAK-MISSING-CONFIG "configured flatpak missing: ${app_id}"
            json_count_warn
            EXIT_RC=1
        fi
    done < <(parse_config_names "$CONFIG_FLATPAK")
fi

upd=$(flatpak remote-ls --updates 2>/dev/null | wc -l | awk '{print $1}' || echo 0)
if [[ "${upd:-0}" -gt 0 ]]; then
    json_add_diag warn FLATPAK-STILL-OUTDATED "${upd} updates still pending after apply"
    json_count_warn
    EXIT_RC=1
fi

exit $EXIT_RC
