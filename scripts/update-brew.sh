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
if run_silent "${BREW_BIN}" update; then
    print_ok; record_ok
else
    print_warn "brew update returned non-zero (network issue?)"
    record_warn
fi

# ── 2. Show outdated ──────────────────────────────────────────────────────────
print_section "Outdated packages"

outdated_f=$("${BREW_BIN}" outdated --formula 2>/dev/null || true)
outdated_c=$("${BREW_BIN}" outdated --cask   2>/dev/null || true)

if [[ -z "$outdated_f" && -z "$outdated_c" ]]; then
    print_info "Everything is up to date"
else
    [[ -n "$outdated_f" ]] && echo "$outdated_f" | while IFS= read -r l; do print_info "  formula: $l"; done
    [[ -n "$outdated_c" ]] && echo "$outdated_c" | while IFS= read -r l; do print_info "  cask:    $l"; done
fi

# ── 3. Upgrade all formulas ───────────────────────────────────────────────────
print_section "Upgrading formulas"

print_step "brew upgrade --formula"
if run_silent "${BREW_BIN}" upgrade --formula; then
    print_ok; record_ok
else
    print_warn "Some formulas failed to upgrade"
    record_warn
fi

# ── 4. Upgrade casks (from config) ───────────────────────────────────────────
print_section "Upgrading casks"

if [[ -f "$CONFIG_CASKS" ]]; then
    while IFS= read -r cask; do
        [[ -z "$cask" ]] && continue
        print_step "brew upgrade --cask ${cask}"
        if ! brew_cask_installed "$cask"; then
            print_warn "Not installed: ${cask} (run setup.sh)"
            record_warn
            continue
        fi
        current_ver=$(brew_cask_version "$cask")
        if run_silent "${BREW_BIN}" upgrade --cask "$cask"; then
            new_ver=$(brew_cask_version "$cask")
            [[ "$new_ver" != "$current_ver" ]] && print_ok "${current_ver} → ${new_ver}" || print_ok "already latest"
            record_ok
        else
            print_warn "cask ${cask} upgrade failed"
            record_warn
        fi
    done < <(parse_config_names "$CONFIG_CASKS")
fi

# ── 5. Cleanup ────────────────────────────────────────────────────────────────
print_section "Cleanup"

print_step "brew cleanup (keep last 7 days)"
run_silent "${BREW_BIN}" cleanup --prune=7 && print_ok || { print_warn "cleanup non-zero"; record_warn; }

# ── 6. Brew doctor ────────────────────────────────────────────────────────────
print_section "Health check"

print_step "brew doctor"
doc=$("${BREW_BIN}" doctor 2>&1 || true)
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

print_summary "Homebrew Update Summary"

# ── Update inventory (skipped when called from update-all.sh) ─────────────────
if [[ "${INVENTORY_SILENT:-0}" != "1" ]]; then
    print_section "Updating APPS.md"
    print_step "update-inventory.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && print_ok || print_warn "inventory update failed"
fi
