#!/usr/bin/env bash
# pip/pipx cleanup is a no-op — pip cache prune available but rarely needed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/json.sh"

json_init cleanup pip
json_register_exit_trap "${JSON_OUT:-}"
json_add_diag info PIP-CLEANUP-NOOP "no cleanup action for pip/pipx"
exit 0
