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
install -m 0644 "${SCRIPT_DIR}/systemd/user/ascendo-ubuntu-dashboard.service" \
    "${DEST}/ascendo-ubuntu-dashboard.service"
systemctl --user daemon-reload
systemctl --user disable ascendo-ubuntu-dashboard.service || true
systemctl --user stop ascendo-ubuntu-dashboard.service || true
# Stop and disable legacy service if active
systemctl --user disable ubuntu-aktualizacje-dashboard.service >/dev/null 2>&1 || true
systemctl --user stop ubuntu-aktualizacje-dashboard.service >/dev/null 2>&1 || true
rm -f "${DEST}/ubuntu-aktualizacje-dashboard.service"
sleep 1

# 3. Install Ascendo icon + desktop entries (user-level, no root)
#    Two .desktop entries:
#      ascendo-ubuntu.desktop          → "Ascendo - Unified Updates"           opens default browser
#      ascendo-ubuntu-desktop.desktop  → "Ascendo - Unified Updates (Desktop)"  standalone window
#    Both call the ascendo-ubuntu-launch shim (installed below).
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
APPS_DIR="${HOME}/.local/share/applications"
BIN_DIR="${HOME}/.local/bin"
mkdir -p "$ICON_DIR" "$APPS_DIR" "$BIN_DIR"
install -m 0644 "${SCRIPT_DIR}/share/icons/hicolor/scalable/apps/ascendo-ubuntu.svg" \
    "${ICON_DIR}/ascendo-ubuntu.svg"
install -m 0644 "${SCRIPT_DIR}/share/applications/ascendo-ubuntu.desktop" \
    "${APPS_DIR}/ascendo-ubuntu.desktop"
install -m 0644 "${SCRIPT_DIR}/share/applications/ascendo-ubuntu-desktop.desktop" \
    "${APPS_DIR}/ascendo-ubuntu-desktop.desktop"
install -m 0755 "${SCRIPT_DIR}/share/bin/ascendo-ubuntu-launch" \
    "${BIN_DIR}/ascendo-ubuntu-launch"
# Drop the old (pre-rebrand) desktop file and legacy ascendo files if they linger
rm -f "${APPS_DIR}/ubuntu-aktualizacje.desktop" "${APPS_DIR}/ascendo.desktop" "${APPS_DIR}/ascendo-desktop.desktop" "${BIN_DIR}/ascendo-launch" "${ICON_DIR}/ascendo.svg"
# Warn the user if ~/.local/bin isn't on $PATH (the .desktop entries call
# `ascendo-ubuntu-launch` by name; if $PATH is missing it, GNOME spawns nothing).
case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *) echo "ℹ ${BIN_DIR} is not on \$PATH — add it (e.g. in ~/.profile) so the launcher resolves." ;;
esac
command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "${APPS_DIR}" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 \
    && gtk-update-icon-cache -t "${HOME}/.local/share/icons/hicolor" >/dev/null 2>&1 || true

# 4. Verify port
if ss -lntp 2>/dev/null | grep -q ":8766"; then
    echo
    echo "✔ Dashboard listening at http://127.0.0.1:8766"
    echo "✔ Ascendo icons installed in app menu:"
    echo "    • Ascendo - Unified Updates           — opens dashboard in your default browser"
    echo "    • Ascendo - Unified Updates (Desktop) — opens dashboard in a standalone window"
else
    echo
    echo "⚠ Dashboard not listening on :8766 — check journalctl --user -u ascendo-ubuntu-dashboard.service"
fi
