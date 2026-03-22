#!/usr/bin/env bash
# =============================================================================
# scripts/update-npm.sh — Update npm itself and all globally installed packages
#
# Uses the Homebrew-managed Node.js/npm (not the system apt node).
# Brew node is at: /home/linuxbrew/.linuxbrew/bin/node (v25.x)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

BREW_PREFIX="/home/linuxbrew/.linuxbrew"
BREW_NPM="${BREW_PREFIX}/bin/npm"
BREW_NODE="${BREW_PREFIX}/bin/node"

print_header "npm — Global Package Updates"

if [[ ! -x "${BREW_NPM}" ]]; then
    print_warn "Brew npm not found at ${BREW_NPM} — skipping"
    exit 0
fi

NODE_VER=$("${BREW_NODE}" --version 2>/dev/null)
NPM_VER=$("${BREW_NPM}" --version 2>/dev/null)
print_info "Node.js: ${NODE_VER}  |  npm: ${NPM_VER}"

# ── 1. Check for outdated global packages ─────────────────────────────────────
print_section "Checking outdated global npm packages"

outdated=$("${BREW_NPM}" outdated -g --depth=0 2>/dev/null || true)
if [[ -z "$outdated" ]]; then
    print_info "All global npm packages are up to date"
else
    print_info "Outdated packages:"
    echo "$outdated" | while IFS= read -r l; do print_info "  $l"; done
fi

# ── 2. Update all global packages ─────────────────────────────────────────────
print_section "Updating global npm packages"

# Get list of installed global packages (excluding npm itself)
installed=$("${BREW_NPM}" list -g --depth=0 --parseable 2>/dev/null | tail -n +2 | xargs -I{} basename {} 2>/dev/null | grep -v '^npm$' || true)

if [[ -z "$installed" ]]; then
    print_info "No additional global npm packages installed"
else
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        print_step "npm update -g ${pkg}"
        if run_silent "${BREW_NPM}" update -g "$pkg"; then
            ver=$("${BREW_NPM}" list -g --depth=0 "$pkg" 2>/dev/null | grep "$pkg" | awk -F@ '{print $NF}')
            print_ok "${ver}"
            record_ok
        else
            print_warn "failed to update ${pkg}"
            record_warn
        fi
    done <<< "$installed"
fi

# ── 3. Final versions ─────────────────────────────────────────────────────────
print_section "Installed global npm packages"
"${BREW_NPM}" list -g --depth=0 2>/dev/null | tail -n +2 | while IFS= read -r l; do
    print_info "${l}"
done

print_summary "npm Update Summary"
