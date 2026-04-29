#!/usr/bin/env bash
# =============================================================================
# scripts/drivers/apply.sh — Native NVIDIA + firmware update.
#
# Honours UPGRADE_NVIDIA env (set by update-all.sh --nvidia).
# Skips NVIDIA APT upgrade by default (held). Runs fwupd refresh + reports
# available firmware updates (does NOT auto-apply firmware — that's manual).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

export INVENTORY_SILENT=1
json_init apply drivers
json_register_exit_trap "${JSON_OUT:-}"

print_header "Drivers & firmware — apply"

require_sudo
detect_gpu

UPGRADE_NVIDIA="${UPGRADE_NVIDIA:-0}"
EXIT_RC=0

# ── 1. NVIDIA driver (apt) ────────────────────────────────────────────────────
if [[ "${UPGRADE_NVIDIA}" -eq 0 ]]; then
    json_add_diag info NVIDIA-HOLD "NVIDIA APT upgrade skipped (use --nvidia)"
else
    print_step "apt-get update (NVIDIA)"
    if sudo apt-get update -q >> "${LOG_FILE}" 2>&1; then
        print_ok
        nv_pkg=$(dpkg -l 'nvidia-driver-*' 2>/dev/null | awk '/^ii/{print $2}' | head -1)
        if [[ -z "$nv_pkg" ]]; then
            json_add_diag warn NVIDIA-NO-DRIVER "no nvidia-driver-* package found"
            json_count_warn
        else
            inst=$(apt_pkg_version "$nv_pkg")
            cand=$(apt_pkg_candidate "$nv_pkg")
            print_step "apt-get install --only-upgrade ${nv_pkg}"
            if sudo apt-get install -y -q --only-upgrade \
                    -o Dpkg::Options::="--force-confdef" \
                    -o Dpkg::Options::="--force-confold" \
                    "$nv_pkg" >> "${LOG_FILE}" 2>&1; then
                new=$(apt_pkg_version "$nv_pkg")
                print_ok
                json_add_item id="drivers:nvidia:${nv_pkg}" action="upgrade" \
                    from="${inst}" to="${new}" result="ok"
                json_count_ok
            else
                print_warn "non-zero (DKMS?)"
                json_add_item id="drivers:nvidia:${nv_pkg}" action="upgrade" \
                    from="${inst}" to="${cand}" result="failed"
                json_add_diag warn NVIDIA-DKMS "NVIDIA upgrade failed; check DKMS for kernel $(uname -r)"
                json_count_warn
                [[ $EXIT_RC -eq 0 ]] && EXIT_RC=1
            fi
        fi
    else
        print_error "apt-get update failed"
        json_add_diag error APT-UPDATE-FAIL "cannot refresh APT before NVIDIA upgrade"
        json_count_err
        EXIT_RC=20
    fi
fi

# ── 2. nvidia-smi sanity ──────────────────────────────────────────────────────
if [[ "${HAS_NVIDIA:-0}" -eq 1 ]]; then
    if has_cmd nvidia-smi && nvidia-smi >/dev/null 2>&1; then
        smi=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)
        json_add_item id="drivers:nvidia-smi" action="health" result="ok" details="${smi}"
        json_count_ok
    else
        json_add_item id="drivers:nvidia-smi" action="health" result="failed"
        json_add_diag warn NVIDIA-SMI-DOWN "nvidia-smi not responsive — reboot or DKMS rebuild may be needed"
        json_count_warn
        [[ $EXIT_RC -eq 0 ]] && EXIT_RC=1
    fi
fi

# ── 3. Firmware: refresh metadata + report (do NOT auto-apply) ────────────────
if has_cmd fwupdmgr; then
    print_step "fwupdmgr refresh"
    if sudo fwupdmgr refresh --force >> "${LOG_FILE}" 2>&1; then
        print_ok
        json_add_item id="drivers:firmware:refresh" action="refresh" result="ok"
        json_count_ok
    else
        print_warn "refresh non-zero"
        json_add_item id="drivers:firmware:refresh" action="refresh" result="warn"
        json_count_warn
    fi

    chk=$(fwupdmgr get-updates 2>&1 || true)
    echo "$chk" >> "${LOG_FILE}"
    if echo "$chk" | grep -qiE "No upgrades for|No updates available"; then
        json_add_diag info FIRMWARE-CURRENT "fwupd reports no updates"
    elif echo "$chk" | grep -qiE "upgrade available|updates available"; then
        json_add_diag warn FIRMWARE-AVAILABLE "firmware updates available — apply manually with: sudo fwupdmgr update"
        json_add_advisory "Run: sudo fwupdmgr update"
        json_count_warn
    fi
else
    json_add_diag info FIRMWARE-NO-FWUPD "fwupdmgr not installed"
fi

# ── 4. ubuntu-drivers recommendations (informational) ─────────────────────────
if has_cmd ubuntu-drivers; then
    rec=$(ubuntu-drivers devices 2>/dev/null | grep -E "(driver|recommended)" | head -5 || true)
    if [[ -n "$rec" ]]; then
        json_add_diag info UBUNTU-DRIVERS-RECS "$(echo "$rec" | head -3 | tr '\n' '; ')"
    fi
fi

# ── 5. Reboot indicator ───────────────────────────────────────────────────────
[[ -f /var/run/reboot-required ]] && json_set_needs_reboot 1

exit $EXIT_RC
