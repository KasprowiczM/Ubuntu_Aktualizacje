#!/usr/bin/env bash
# =============================================================================
# scripts/update-pip.sh — Update pip (user) and pipx packages
#
# Reads from: config/pip-packages.list   (pip --user installs)
#             config/pipx-packages.list  (pipx isolated installs)
#
# Uses Homebrew Python when available, falls back to system python3.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

CONFIG_PIP="${SCRIPT_DIR}/config/pip-packages.list"
CONFIG_PIPX="${SCRIPT_DIR}/config/pipx-packages.list"

print_header "Python — pip & pipx Package Updates"

detect_package_managers

# Resolve full path to pipx (must run as user, not root)
PIPX_BIN=$(command -v pipx 2>/dev/null || true)

# ── Resolve Python / pip ──────────────────────────────────────────────────────
PY3=""
PIP3=""

# Prefer brew Python (check brew prefix first, then generic symlink, then system)
for candidate in \
    "${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}/bin/python3" \
    "/usr/bin/python3"; do
    if [[ -x "$candidate" ]]; then
        PY3="$candidate"
        break
    fi
done

if [[ -n "$PY3" ]]; then
    PIP3="${PY3} -m pip"
    PY_VER=$("$PY3" --version 2>/dev/null)
    print_info "Python: ${PY3} (${PY_VER})"
else
    print_warn "Python3 not found — skipping pip"
fi

# ── 1. pip: update pip itself ─────────────────────────────────────────────────
if [[ -n "$PIP3" ]]; then
    print_section "Updating pip itself"
    print_step "pip install --upgrade pip"
    # Brew's Python is PEP-668 externally managed — pip cannot self-upgrade.
    # The pip bundled with brew is upgraded automatically by `brew upgrade python@...`.
    if [[ "${PY3}" == "${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"* ]]; then
        _py_minor=$("$PY3" --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
        print_ok "managed by brew — upgrade via: brew upgrade python@${_py_minor}"
    elif $PIP3 install --quiet --upgrade pip 2>/dev/null; then
        print_ok; record_ok
    else
        print_warn "pip self-upgrade failed (may be externally managed)"; record_warn
    fi

    # ── 2. pip: update all user packages ──────────────────────────────────────
    print_section "Upgrading pip user packages"
    outdated=$($PIP3 list --user --outdated --format=columns 2>/dev/null | tail -n +3)
    if [[ -z "$outdated" ]]; then
        print_info "All pip user packages up to date"
    else
        print_info "Outdated packages:"
        echo "$outdated" | while IFS= read -r l; do print_info "  $l"; done
        # Upgrade each
        echo "$outdated" | awk '{print $1}' | while read -r pkg; do
            print_step "pip upgrade ${pkg}"
            if $PIP3 install --quiet --user --upgrade "$pkg" 2>/dev/null; then
                print_ok; record_ok
            else
                print_warn "Failed: ${pkg}"; record_warn
            fi
        done
    fi

    # ── 3. pip: install missing from config ───────────────────────────────────
    print_section "Installing configured pip packages"
    if [[ -f "$CONFIG_PIP" ]]; then
        pip_user_names="$($PIP3 list --user --format=json 2>/dev/null | python3 -c '
import sys, json
try:
    for row in json.load(sys.stdin):
        print(row.get("name","").lower())
except Exception:
    pass
' || true)"
        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            base_pkg="${pkg%%==*}"  # strip version specifier for check
            if echo "$pip_user_names" | grep -qi "^${base_pkg}$"; then
                print_info "${pkg}: already installed"
            else
                print_step "pip install --user ${pkg}"
                if $PIP3 install --quiet --user "$pkg" 2>/dev/null; then
                    print_ok; record_ok
                else
                    print_warn "Failed: ${pkg}"; record_warn
                fi
            fi
        done < <(parse_config_names "$CONFIG_PIP")
    fi

    # ── 4. pip: current user packages ────────────────────────────────────────
    print_section "Installed pip user packages"
    while IFS= read -r l; do
        print_info "$l"
    done < <($PIP3 list --user 2>/dev/null | tail -n +3 | head -30)
fi

# ── 5. pipx section ───────────────────────────────────────────────────────────
print_section "pipx packages"

if [[ -z "${PIPX_BIN}" ]]; then
    print_warn "pipx not installed"
    print_info "Install with: ${PIP3:-pip3} install --user pipx  OR  brew install pipx"
    record_warn
else
    PIPX_VER=$(run_as_user "${PIPX_BIN}" --version 2>/dev/null)
    print_info "pipx: ${PIPX_VER}"

    # Upgrade all — must run as user to avoid root-owned pycache in brew Cellar
    print_step "pipx upgrade-all"
    pipx_out=$(run_as_user "${PIPX_BIN}" upgrade-all 2>&1) && pipx_rc=0 || pipx_rc=$?
    echo "$pipx_out" >> "${LOG_FILE}"
    echo "$pipx_out"
    if [[ $pipx_rc -ne 0 ]]; then
        print_warn "pipx upgrade-all returned non-zero"
        record_warn
    elif echo "$pipx_out" | grep -qE "(upgraded|already at latest)"; then
        print_ok; record_ok
    else
        print_ok "done"; record_ok
    fi

    # Install missing from config
    print_section "Installing configured pipx packages"
    if [[ -f "$CONFIG_PIPX" ]]; then
        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            base_pkg="${pkg%%==*}"
            print_step "pipx install ${pkg}"
            if run_as_user "${PIPX_BIN}" list 2>/dev/null | grep -q "$base_pkg"; then
                print_info "(already installed)"
            else
                if run_as_user "${PIPX_BIN}" install "$pkg" >> "${LOG_FILE}" 2>&1; then
                    print_ok; record_ok
                else
                    print_warn "Failed: ${pkg}"; record_warn
                fi
            fi
        done < <(parse_config_names "$CONFIG_PIPX")
    fi

    # List all
    print_section "Installed pipx packages"
    while IFS= read -r l; do
        print_info "$l"
    done < <(run_as_user "${PIPX_BIN}" list 2>/dev/null | grep "package " || true)
fi

print_summary "Python Update Summary"

# ── 6. Update inventory ───────────────────────────────────────────────────────
if [[ "${INVENTORY_SILENT:-0}" != "1" ]]; then
    print_section "Updating APPS.md"
    print_step "update-inventory.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && print_ok || print_warn "inventory update failed"
fi
