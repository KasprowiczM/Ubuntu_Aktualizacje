#!/usr/bin/env bash
# =============================================================================
# scripts/update-brew.sh — Update Homebrew (Linuxbrew) formulas and casks
#
# Covers formulas:
#   • AI/Dev tools: gemini-cli, opencode, qwen-code, node, ripgrep
#   • Languages:    python@3.14, gcc
#   • Libraries:    openssl@3, icu4c, sqlite, readline, ncurses, etc.
#   • All other brew formulas
#
# Covers casks:
#   • claude-code (Anthropic Claude Code CLI)
#   • codex       (OpenAI Codex CLI)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Linuxbrew environment
export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
export HOMEBREW_NO_AUTO_UPDATE=1          # We update manually below
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_ENV_HINTS=1
BREW="${HOMEBREW_PREFIX}/bin/brew"

if [[ ! -x "${BREW}" ]]; then
    print_error "Homebrew not found at ${BREW}"
    exit 1
fi

print_header "Homebrew — Formula & Cask Updates"

# ── 1. Update Homebrew itself (fetch new formulae/taps) ───────────────────────
print_section "Updating Homebrew"

print_step "brew update"
if run_silent "${BREW}" update; then
    print_ok
    record_ok
else
    print_warn "brew update returned non-zero (may be a network issue)"
    record_warn
fi

# ── 2. Show what will be upgraded ─────────────────────────────────────────────
print_section "Checking outdated packages"

outdated_formulas=$("${BREW}" outdated --formula 2>/dev/null || true)
outdated_casks=$("${BREW}" outdated --cask 2>/dev/null || true)

if [[ -z "$outdated_formulas" && -z "$outdated_casks" ]]; then
    print_info "Everything is up to date"
else
    [[ -n "$outdated_formulas" ]] && { print_info "Outdated formulas:"; echo "$outdated_formulas" | while IFS= read -r l; do print_info "  $l"; done; }
    [[ -n "$outdated_casks"   ]] && { print_info "Outdated casks:";   echo "$outdated_casks"   | while IFS= read -r l; do print_info "  $l"; done; }
fi

# ── 3. Upgrade all formulas ───────────────────────────────────────────────────
print_section "Upgrading formulas"

print_step "brew upgrade (all formulas)"
if run_silent "${BREW}" upgrade --formula; then
    print_ok
    record_ok
else
    print_warn "Some formulas failed to upgrade — check log for details"
    record_warn
fi

# ── 4. Upgrade casks ──────────────────────────────────────────────────────────
print_section "Upgrading casks"

CASKS=("claude-code" "codex")
for cask in "${CASKS[@]}"; do
    print_step "brew upgrade --cask ${cask}"
    if "${BREW}" list --cask "$cask" &>/dev/null; then
        if run_silent "${BREW}" upgrade --cask "$cask"; then
            print_ok
            record_ok
        else
            # Not-an-error if already up to date (exit 0), but cask may print warnings
            already_latest=$("${BREW}" info --cask "$cask" 2>/dev/null | grep "Already installed" || true)
            if [[ -n "$already_latest" ]]; then
                print_skipped "already latest"
                record_ok
            else
                print_warn "cask ${cask} upgrade returned non-zero"
                record_warn
            fi
        fi
    else
        print_skipped "not installed"
    fi
done

# ── 5. Cleanup old versions ───────────────────────────────────────────────────
print_section "Cleaning up old versions"

print_step "brew cleanup"
if run_silent "${BREW}" cleanup --prune=7; then
    print_ok
    record_ok
else
    print_warn "cleanup returned non-zero"
    record_warn
fi

# ── 6. Doctor check ───────────────────────────────────────────────────────────
print_section "Brew health check"

print_step "brew doctor"
doctor_out=$("${BREW}" doctor 2>&1 || true)
echo "$doctor_out" >> "${LOG_FILE}"
if echo "$doctor_out" | grep -q "Your system is ready to brew"; then
    print_ok "system is ready to brew"
    record_ok
else
    print_warn "brew doctor found issues — check log"
    echo "$doctor_out" | grep -E "^Warning:" | head -5 | while IFS= read -r l; do print_info "  $l"; done
    record_warn
fi

# ── 7. Current versions ───────────────────────────────────────────────────────
print_section "Key formula & cask versions"

KEY_FORMULAS=("gemini-cli" "opencode" "qwen-code" "node" "ripgrep" "python@3.14" "gcc" "openssl@3")
for f in "${KEY_FORMULAS[@]}"; do
    ver=$("${BREW}" list --versions "$f" 2>/dev/null | awk '{print $2}')
    [[ -n "$ver" ]] && print_info "${f}: ${ver}"
done
for c in "${CASKS[@]}"; do
    ver=$(ls "${HOMEBREW_PREFIX}/Caskroom/${c}/" 2>/dev/null | tail -1)
    [[ -n "$ver" ]] && print_info "${c} (cask): ${ver}"
done

print_summary "Homebrew Update Summary"
