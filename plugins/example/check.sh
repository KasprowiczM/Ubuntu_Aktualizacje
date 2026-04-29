#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init check plugin:example
json_register_exit_trap "${JSON_OUT:-}"
json_add_diag info PLUGIN-EXAMPLE "example plugin check ran"
exit 0
