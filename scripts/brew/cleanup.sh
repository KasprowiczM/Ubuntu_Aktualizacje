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

REAL_USER="${SUDO_USER:-${USER}}"

# Heal any root-owned files in the brew tree before cleanup. Brew refuses to
# remove files it can't unlink; repeated cleanups otherwise hit the same
# "Permission denied" stragglers (typically pipx __pycache__).
_brew_heal_perms() {
    [[ -z "${BREW_PREFIX:-}" ]] && return 0
    local target="${BREW_PREFIX}/Cellar"
    [[ -d "$target" ]] || return 0
    if [[ $EUID -eq 0 ]]; then
        find "$target" -not -user "${REAL_USER}" -print0 2>/dev/null | \
            xargs -0r chown -h "${REAL_USER}:${REAL_USER}" 2>/dev/null || true
    elif command -v sudo >/dev/null 2>&1; then
        # Use sudo (askpass-aware) to fix perms — quick, scoped to Cellar.
        sudo find "$target" -not -user "${REAL_USER}" -exec chown -h "${REAL_USER}:${REAL_USER}" {} + 2>/dev/null || true
    fi
}

print_step "brew: heal Cellar permissions"
_brew_heal_perms
print_ok

print_step "brew cleanup --prune=7"
if run_silent_as_user "${BREW_BIN}" cleanup --prune=7; then
    print_ok
    json_add_item id="brew:cleanup" action="cleanup" result="ok"
    json_count_ok
else
    # One retry after a second heal pass — the first cleanup pass may have
    # changed which files are stale.
    _brew_heal_perms
    if run_silent_as_user "${BREW_BIN}" cleanup --prune=7; then
        print_ok "after permission heal"
        json_add_item id="brew:cleanup" action="cleanup" result="ok"
        json_count_ok
    else
        print_warn "brew cleanup still non-zero (manual chown may be needed)"
        json_add_item id="brew:cleanup" action="cleanup" result="warn"
        json_add_diag warn BREW-CLEANUP-WARN "brew cleanup non-zero after heal pass"
        json_count_warn
    fi
fi
exit 0
