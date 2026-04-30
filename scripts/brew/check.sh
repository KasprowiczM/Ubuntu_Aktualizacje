#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"
source "${SCRIPT_DIR}/lib/progress.sh"

json_init check brew
json_register_exit_trap "${JSON_OUT:-}"

print_header "Homebrew — check"
detect_package_managers

if [[ "${HAS_BREW:-0}" -ne 1 ]]; then
    json_add_diag info BREW-MISSING "homebrew not installed — category not applicable"
    exit 0
fi

# Outdated formulas
print_step "brew outdated --formula"
out_f=$(run_as_user "${BREW_BIN}" outdated --formula --verbose 2>/dev/null || true)
print_ok
print_step "brew outdated --cask"
out_c=$(run_as_user "${BREW_BIN}" outdated --cask --verbose 2>/dev/null || true)
print_ok

n_f=0; n_c=0; detail=""
if [[ -n "$out_f" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        pkg=$(echo "$line" | awk '{print $1}')
        # Verbose format: "name (current) < new"
        json_add_item id="brew:upgrade:formula:${pkg}" action="upgrade" result="noop"
        detail+="formula ${line}"$'\n'
        n_f=$((n_f + 1))
    done <<< "$out_f"
fi
if [[ -n "$out_c" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        pkg=$(echo "$line" | awk '{print $1}')
        json_add_item id="brew:upgrade:cask:${pkg}" action="upgrade" result="noop"
        detail+="cask    ${line}"$'\n'
        n_c=$((n_c + 1))
    done <<< "$out_c"
fi
print_found brew "$((n_f + n_c))" "$detail"
json_add_diag info BREW-OUTDATED "${n_f} formula(s) and ${n_c} cask(s) outdated"

# brew doctor (informational)
if doc=$(run_as_user "${BREW_BIN}" doctor 2>&1); then
    if echo "$doc" | grep -q "Your system is ready to brew"; then
        json_add_diag info BREW-DOCTOR-OK "brew doctor: ready"
    fi
else
    n_warn=$(echo "$doc" | grep -c '^Warning:' || true)
    json_add_diag warn BREW-DOCTOR-WARN "brew doctor found ${n_warn} warning(s)"
    json_count_warn
fi
exit 0
