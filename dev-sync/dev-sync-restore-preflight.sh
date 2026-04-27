#!/usr/bin/env bash
# ============================================================
# dev-sync-restore-preflight.sh — Check fresh-clone restore readiness
# ============================================================
# Wrapper script that calls the Python backend
# ============================================================

set -eu
exec python3 "$(dirname "$0")/dev_sync_restore_preflight.py" "$@"
