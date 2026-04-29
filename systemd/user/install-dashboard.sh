#!/usr/bin/env bash
# Install the user-level dashboard service. Runs without root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${HOME}/.config/systemd/user"

# 1. Bootstrap venv if missing (PEP-668 safe)
if [[ ! -x "${SCRIPT_DIR}/app/.venv/bin/python" ]]; then
    echo "── bootstrapping venv (PEP-668 safe)"
    bash "${SCRIPT_DIR}/app/install.sh"
fi

# 2. Install user unit
mkdir -p "$DEST"
install -m 0644 "${SCRIPT_DIR}/systemd/user/ubuntu-aktualizacje-dashboard.service" \
    "${DEST}/ubuntu-aktualizacje-dashboard.service"
systemctl --user daemon-reload
systemctl --user enable --now ubuntu-aktualizacje-dashboard.service
sleep 1
systemctl --user status ubuntu-aktualizacje-dashboard.service --no-pager || true

# 3. Verify port
if ss -lntp 2>/dev/null | grep -q ":8765"; then
    echo
    echo "✔ Dashboard listening at http://127.0.0.1:8765"
else
    echo
    echo "⚠ Dashboard not listening on :8765 — check journalctl --user -u ubuntu-aktualizacje-dashboard.service"
fi
