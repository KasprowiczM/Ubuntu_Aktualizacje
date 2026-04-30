#!/usr/bin/env bash
# =============================================================================
# scripts/update-brew.sh — Update Homebrew (Linuxbrew) formulas and casks
#
# Reads formula list from: config/brew-formulas.list
# Reads cask list from:    config/brew-casks.list
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

CONFIG_FORMULAS="${SCRIPT_DIR}/config/brew-formulas.list"
CONFIG_CASKS="${SCRIPT_DIR}/config/brew-casks.list"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_ENV_HINTS=1

print_header "Homebrew — Formula & Cask Updates"

detect_package_managers

if [[ $HAS_BREW -eq 0 ]]; then
    print_warn "Homebrew not found — skipping (run setup.sh to install)"
    exit 0
fi

# ── 1. Update Homebrew itself ──────────────────────────────────────────────────
print_section "Updating Homebrew"

print_step "brew update"
if run_silent_as_user "${BREW_BIN}" update; then
    print_ok; record_ok
else
    print_warn "brew update returned non-zero (network issue?)"
    record_warn
fi

# ── 2. Show outdated ──────────────────────────────────────────────────────────
print_section "Outdated packages"

outdated_f=$(run_as_user "${BREW_BIN}" outdated --formula 2>/dev/null || true)
outdated_c=$(run_as_user "${BREW_BIN}" outdated --cask   2>/dev/null || true)

if [[ -z "$outdated_f" && -z "$outdated_c" ]]; then
    print_info "Everything is up to date"
else
    [[ -n "$outdated_f" ]] && echo "$outdated_f" | while IFS= read -r l; do print_info "  formula: $l"; done
    [[ -n "$outdated_c" ]] && echo "$outdated_c" | while IFS= read -r l; do print_info "  cask:    $l"; done
fi

# ── 3. Upgrade all formulas ───────────────────────────────────────────────────
print_section "Upgrading formulas"

print_step "brew upgrade --formula"
if run_silent_as_user "${BREW_BIN}" upgrade --formula; then
    print_ok; record_ok
else
    print_warn "Some formulas failed to upgrade"
    record_warn
fi

# ── 4. Upgrade all installed casks ────────────────────────────────────────────
print_section "Upgrading casks"

print_step "brew upgrade --cask --greedy"
if run_silent_as_user "${BREW_BIN}" upgrade --cask --greedy; then
    print_ok; record_ok
else
    print_warn "Some casks failed to upgrade"
    record_warn
fi

# ── 5. Cleanup ────────────────────────────────────────────────────────────────
print_section "Cleanup"

# Fix root-owned files in brew Cellar before cleanup.
# When update-all.sh is run via "sudo ./update-all.sh", brew formula installs
# that implicitly invoke Python can leave __pycache__ files owned by root.
# brew cleanup (running as SUDO_USER via run_silent_as_user) cannot delete
# root-owned files, so old kegs persist indefinitely and produce a WARN on
# every run.  Chown them back first while we still have root.
if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && -n "${BREW_PREFIX:-}" ]]; then
    find "${BREW_PREFIX}/Cellar" -not -user "${SUDO_USER}" -print0 2>/dev/null | \
        xargs -0r chown "${SUDO_USER}" 2>/dev/null || true
fi

print_step "brew cleanup (keep last 7 days)"
if run_silent_as_user "${BREW_BIN}" cleanup --prune=7; then
    print_ok
    record_ok
else
    _retried_cleanup=0
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && -n "${BREW_PREFIX:-}" ]]; then
        if grep -qi "Could not cleanup old kegs! Fix your permissions on:" "${LOG_FILE}" 2>/dev/null; then
            _retried_cleanup=1
            print_info "Retrying brew cleanup after fixing Cellar ownership"
            chown -R "${SUDO_USER}:${SUDO_USER}" "${BREW_PREFIX}/Cellar" >> "${LOG_FILE}" 2>&1 || true
            if run_silent_as_user "${BREW_BIN}" cleanup --prune=7; then
                print_ok "done (after ownership repair)"
                record_ok
            else
                print_warn "cleanup non-zero (after retry)"
                record_warn
            fi
        fi
    fi
    if [[ "${_retried_cleanup}" -eq 0 ]]; then
        print_warn "cleanup non-zero"
        record_warn
    fi
fi

# ── 6. Brew doctor ────────────────────────────────────────────────────────────
print_section "Health check"

print_step "brew doctor"
doc=$(run_as_user "${BREW_BIN}" doctor 2>&1 || true)
echo "$doc" >> "${LOG_FILE}"
if echo "$doc" | grep -q "Your system is ready to brew"; then
    print_ok; record_ok
else
    print_warn "brew doctor found issues"
    echo "$doc" | grep "^Warning:" | head -3 | while IFS= read -r l; do print_info "  $l"; done
    record_warn
fi

# ── 7. Version report (from config) ──────────────────────────────────────────
print_section "Formula versions (from config)"

if [[ -f "$CONFIG_FORMULAS" ]]; then
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if brew_formula_installed "$f"; then
            print_info "${f}: $(brew_formula_version "$f")"
        else
            print_warn "${f}: NOT INSTALLED"
            record_warn
        fi
    done < <(parse_config_names "$CONFIG_FORMULAS")
fi

print_section "Cask versions (from config)"
if [[ -f "$CONFIG_CASKS" ]]; then
    while IFS= read -r c; do
        [[ -z "$c" ]] && continue
        if brew_cask_installed "$c"; then
            print_info "${c}: $(brew_cask_version "$c")"
        else
            print_warn "${c}: NOT INSTALLED"
            record_warn
        fi
    done < <(parse_config_names "$CONFIG_CASKS")
fi

print_section "Installed casks (including not in config)"
run_as_user "${BREW_BIN}" list --cask 2>/dev/null | while read -r c; do
    [[ -z "$c" ]] && continue
    print_info "${c}: $(brew_cask_version "$c")"
done

print_summary "Homebrew Update Summary"

# ── Update inventory (skipped when called from update-all.sh) ─────────────────
if [[ "${INVENTORY_SILENT:-0}" != "1" ]]; then
    print_section "Updating APPS.md"
    print_step "update-inventory.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && print_ok || print_warn "inventory update failed"
fi
