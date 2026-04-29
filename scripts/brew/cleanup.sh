#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init cleanup brew
json_register_exit_trap "${JSON_OUT:-}"

detect_package_managers
if [[ "${HAS_BREW:-0}" -ne 1 ]]; then
    json_add_diag info BREW-MISSING "homebrew not installed"
    exit 0
fi

# Fix root-owned Cellar files first (legacy update-brew.sh does this; replicate here)
if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && -n "${BREW_PREFIX:-}" ]]; then
    find "${BREW_PREFIX}/Cellar" -not -user "${SUDO_USER}" -print0 2>/dev/null | \
        xargs -0r chown "${SUDO_USER}" 2>/dev/null || true
fi

if run_silent_as_user "${BREW_BIN}" cleanup --prune=7; then
    json_add_item id="brew:cleanup" action="cleanup" result="ok"
    json_count_ok
else
    json_add_item id="brew:cleanup" action="cleanup" result="warn"
    json_add_diag warn BREW-CLEANUP-WARN "brew cleanup non-zero (Cellar permission?)"
    json_count_warn
fi
exit 0
