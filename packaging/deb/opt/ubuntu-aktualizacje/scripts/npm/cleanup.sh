#!/usr/bin/env bash
# npm has no cleanup; this is a no-op phase that emits an empty sidecar.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init cleanup npm
json_register_exit_trap "${JSON_OUT:-}"
json_add_diag info NPM-CLEANUP-NOOP "npm has no cleanup action"
exit 0
