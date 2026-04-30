#!/usr/bin/env bash
# =============================================================================
# app/install.sh — Bootstrap dashboard dependencies in a project-local venv.
#
# Why a venv: brew Python on this host is PEP-668 externally-managed (cannot
# pip install --user fastapi). The venv at app/.venv is gitignored and used
# both for ad-hoc runs and by the systemd user service.
#
# Idempotent: re-running re-uses the existing venv and upgrades pinned deps.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${SCRIPT_DIR}/app"
VENV="${APP_DIR}/.venv"
PY="${PYTHON3:-python3}"

if ! command -v "$PY" >/dev/null 2>&1; then
    echo "python3 not found in PATH" >&2; exit 1
fi

PY_VER=$("$PY" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PY_MAJ=$("$PY" -c 'import sys; print(sys.version_info.major)')
PY_MIN=$("$PY" -c 'import sys; print(sys.version_info.minor)')
if [[ $PY_MAJ -lt 3 || ( $PY_MAJ -eq 3 && $PY_MIN -lt 11 ) ]]; then
    echo "python3 >= 3.11 required (found ${PY_VER}); set PYTHON3 env to override" >&2
    exit 1
fi

if [[ ! -d "$VENV" ]]; then
    echo "── creating venv at ${VENV}"
    "$PY" -m venv "$VENV"
fi

echo "── upgrading pip in venv"
"${VENV}/bin/python" -m pip install --quiet --upgrade pip

echo "── installing dashboard dependencies (fastapi, uvicorn, pydantic, httpx)"
"${VENV}/bin/python" -m pip install --quiet --upgrade \
    "fastapi>=0.115" \
    "uvicorn>=0.30" \
    "pydantic>=2.7" \
    "httpx>=0.27"

# Smoke test imports
"${VENV}/bin/python" - <<'PY'
import fastapi, uvicorn, pydantic, httpx
print(f"  fastapi  {fastapi.__version__}")
print(f"  uvicorn  {uvicorn.__version__}")
print(f"  pydantic {pydantic.VERSION}")
print(f"  httpx    {httpx.__version__}")
PY

echo
echo "✔ dashboard dependencies ready in ${VENV}"
echo
echo "Run ad-hoc:"
echo "  ${VENV}/bin/python -m app.backend"
echo
echo "Or install as user-service:"
echo "  bash systemd/user/install-dashboard.sh"
