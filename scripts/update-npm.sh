#!/usr/bin/env bash
# =============================================================================
# scripts/update-npm.sh — Update npm itself and all global packages
#
# Reads package list from: config/npm-globals.list
#
# Strategy:
#   1. npm itself is managed by Homebrew (node formula) → updated via update-brew.sh
#   2. This script updates ALL currently installed global packages
#   3. It also installs any packages listed in config/npm-globals.list that are missing
#   4. Reports what changed
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

CONFIG_NPM="${SCRIPT_DIR}/config/npm-globals.list"
MIGRATE_BREW_AI_CLIS="${MIGRATE_BREW_AI_CLIS:-1}"

# Keep these CLIs on the earliest generally-available channel.
PRIORITY_AI_CLI_PKGS=(
    "@anthropic-ai/claude-code"
    "@google/gemini-cli"
    "@openai/codex"
)

print_header "npm — Global Package Updates"

detect_package_managers

if [[ -z "${NPM_BIN:-}" ]]; then
    print_warn "npm not found — skipping"
    print_info "Install Homebrew node to enable npm: brew install node"
    exit 0
fi

NODE_VER=$("$(dirname "${NPM_BIN}")/node" --version 2>/dev/null || echo "unknown")
NPM_VER=$("${NPM_BIN}" --version 2>/dev/null || echo "unknown")

print_info "npm  : ${NPM_BIN} (v${NPM_VER})"
print_info "node : $(dirname "${NPM_BIN}")/node (${NODE_VER})"

# ── 0. One-time migration: brew-managed AI CLIs → npm ────────────────────────
print_section "Manager migration (brew -> npm) for AI CLIs"
if [[ "${MIGRATE_BREW_AI_CLIS}" == "1" && "${HAS_BREW:-0}" -eq 1 ]]; then
    _brew_remove_if_present() {
        local kind="$1"
        local name="$2"
        local check_arg uninstall_arg
        if [[ "$kind" == "cask" ]]; then
            check_arg="--cask"
            uninstall_arg="--cask"
        else
            check_arg="--formula"
            uninstall_arg="--formula"
        fi

        if run_as_user "${BREW_BIN}" list "${check_arg}" "$name" >/dev/null 2>&1; then
            print_step "brew uninstall ${uninstall_arg} ${name}"
            if run_silent_as_user "${BREW_BIN}" uninstall "${uninstall_arg}" "$name"; then
                print_ok; record_ok
            else
                print_warn "Failed to uninstall brew ${kind}: ${name}"
                record_warn
            fi
        fi
    }

    _brew_remove_if_present cask "claude-code"
    _brew_remove_if_present cask "claude-code@latest"
    _brew_remove_if_present formula "gemini-cli"
    _brew_remove_if_present cask "codex"
    _brew_remove_if_present formula "codex"
else
    print_info "Migration disabled (MIGRATE_BREW_AI_CLIS=${MIGRATE_BREW_AI_CLIS}) or brew not installed"
fi

# ── 1. Audit currently installed globals ─────────────────────────────────────
print_section "Currently installed global packages"

# Build map of name → current_version
declare -A INSTALLED_GLOBALS
while IFS='|' read -r name ver; do
    [[ -z "$name" ]] && continue
    INSTALLED_GLOBALS["$name"]="$ver"
    print_info "  ${name}@${ver}"
done < <(scan_npm_globals)

GLOBAL_COUNT="${#INSTALLED_GLOBALS[@]}"
[[ "$GLOBAL_COUNT" -eq 0 ]] && print_info "  (none — only npm is installed globally)"

# ── 2. Check for outdated globals ─────────────────────────────────────────────
print_section "Checking for outdated packages"

outdated_json=$(run_as_user "${NPM_BIN}" outdated -g --json 2>/dev/null) || true
[[ -n "$outdated_json" && "$outdated_json" != "{}" ]] && echo "$outdated_json" >> "${LOG_FILE}"

outdated_count=$(echo "$outdated_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(len(d))
except: print(0)
" 2>/dev/null || echo 0)

if [[ "$outdated_count" -eq 0 ]]; then
    print_info "All global packages are up to date"
else
    print_info "${outdated_count} package(s) have updates:"
    echo "$outdated_json" | python3 -c "
import sys, json
try:
    for name, info in json.load(sys.stdin).items():
        print(f\"  {name}: {info.get('current','?')} → {info.get('latest','?')}\")
except: pass
" 2>/dev/null | while IFS= read -r l; do print_info "$l"; done
fi

# ── 3. Update all installed global packages (single pass) ────────────────────
print_section "Updating installed global packages"

if [[ "$GLOBAL_COUNT" -gt 0 ]]; then
    print_step "npm update -g"
    if run_silent_as_user "${NPM_BIN}" update -g; then
        print_ok; record_ok
    else
        print_warn "npm update -g returned non-zero"
        record_warn
    fi
else
    print_info "No packages to update"
fi

# ── 4. Install missing packages from config ───────────────────────────────────
print_section "Installing missing packages from config"

if [[ -f "$CONFIG_NPM" ]]; then
    WANT_PKGS=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        WANT_PKGS+=("$pkg")
    done < <(parse_config_names "$CONFIG_NPM")

    if [[ ${#WANT_PKGS[@]} -eq 0 ]]; then
        print_info "No packages listed in config/npm-globals.list"
    else
        for pkg in "${WANT_PKGS[@]}"; do
            print_step "npm install -g ${pkg}"
            if npm_pkg_installed "$pkg"; then
                print_info "(already installed — $(npm_pkg_version "$pkg"))"
            else
                if run_silent_as_user "${NPM_BIN}" install -g "$pkg"; then
                    print_ok; record_ok
                else
                    print_warn "Failed: ${pkg}"; record_warn
                fi
            fi
        done
    fi
fi

# ── 5. Force latest for priority AI CLIs ──────────────────────────────────────
print_section "Forcing latest versions for priority AI CLIs"
for pkg in "${PRIORITY_AI_CLI_PKGS[@]}"; do
    print_step "npm install -g ${pkg}@latest"
    if run_silent_as_user "${NPM_BIN}" install -g "${pkg}@latest"; then
        print_ok; record_ok
    else
        print_warn "Failed to install/update ${pkg}@latest"
        record_warn
    fi
done

# ── 6. Final state ────────────────────────────────────────────────────────────
print_section "Final global package state"
run_as_user "${NPM_BIN}" list -g --depth=0 2>/dev/null | tail -n +2 | while IFS= read -r l; do
    print_info "${l}"
done

# ── 7. npm audit ──────────────────────────────────────────────────────────────
print_section "Security audit (global)"
audit_out=$(run_as_user "${NPM_BIN}" audit --global 2>/dev/null || true)
if echo "$audit_out" | grep -q "found 0 vulnerabilities"; then
    print_info "No vulnerabilities found"
elif [[ -n "$audit_out" ]]; then
    print_warn "npm audit output (check log for details)"
    echo "$audit_out" >> "${LOG_FILE}"
fi

print_summary "npm Update Summary"

# ── Update inventory (skipped when called from update-all.sh) ─────────────────
if [[ "${INVENTORY_SILENT:-0}" != "1" ]]; then
    print_section "Updating APPS.md"
    print_step "update-inventory.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && print_ok || print_warn "inventory update failed"
fi
