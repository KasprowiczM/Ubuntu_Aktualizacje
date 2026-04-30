#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init cleanup flatpak
json_register_exit_trap "${JSON_OUT:-}"

if ! has_cmd flatpak; then
    json_add_diag info FLATPAK-MISSING "flatpak not installed"
    exit 0
fi

if flatpak uninstall --unused --noninteractive >> "${LOG_FILE}" 2>&1; then
    json_add_item id="flatpak:uninstall-unused" action="cleanup" result="ok"
    json_count_ok
else
    json_add_item id="flatpak:uninstall-unused" action="cleanup" result="warn"
    json_count_warn
fi
exit 0
