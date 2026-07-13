#!/usr/bin/env bash
# Same intel as check; pip plan == outdated list. Provided as separate phase
# for orchestrator symmetry.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PIP_PHASE="plan"
exec bash "${SCRIPT_DIR}/scripts/pip/check.sh" "$@"
