#!/usr/bin/env bash
# =============================================================================
# scripts/update-apt.sh — Update & upgrade all APT-managed packages
#
# Reads package list from: config/apt-packages.list
# Reads repo list from:    config/apt-repos.list
#
# Covers: Ubuntu OS, Brave, Chrome, VSCode, Docker, MegaSync, ProtonVPN,
#         Proton Mail, RDM, Grub Customizer, NVIDIA driver, Rclone, and
#         any other apt-managed package on the system.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/repos.sh"

CONFIG_APT="${SCRIPT_DIR}/config/apt-packages.list"
CONFIG_REPOS="${SCRIPT_DIR}/config/apt-repos.list"

print_header "APT — System & Application Updates"

require_sudo

UPGRADE_NVIDIA="${UPGRADE_NVIDIA:-0}"

# ── Helper: ensure configured third-party repos exist on every run ───────────
_ensure_configured_repos() {
    [[ ! -f "$CONFIG_REPOS" ]] && return 0
    print_section "Ensuring configured APT repositories"
    local failed=0
    while IFS= read -r repo_id; do
        [[ -z "$repo_id" ]] && continue
        if ! setup_repo "$repo_id"; then
            print_error "Repository setup failed: ${repo_id}"
            failed=1
        fi
    done < <(parse_config_names "$CONFIG_REPOS")
    if [[ $failed -ne 0 ]]; then
        print_error "One or more configured APT repositories failed; aborting fail-closed."
        exit 1
    fi
}

declare -a NVIDIA_TEMP_HELD=()

_installed_nvidia_packages() {
    # Match packages actually present in dpkg (any status: ii, iF, iU, hi, etc.)
    dpkg -l 'nvidia-*' 'libnvidia-*' 2>/dev/null | awk '/^[iuh][iUFHWt]/{print $2}'
}

_temporarily_hold_nvidia() {
    mapfile -t _current_holds < <(apt-mark showhold 2>/dev/null || true)
    mapfile -t _nvidia_pkgs < <(_installed_nvidia_packages)
    [[ ${#_nvidia_pkgs[@]} -eq 0 ]] && return 0

    local pkg held already_held
    for pkg in "${_nvidia_pkgs[@]}"; do
        already_held=0
        for held in "${_current_holds[@]}"; do
            [[ "$pkg" == "$held" ]] && already_held=1 && break
        done
        [[ $already_held -eq 1 ]] && continue
        if sudo apt-mark hold "$pkg" >> "${LOG_FILE}" 2>&1; then
            NVIDIA_TEMP_HELD+=("$pkg")
        fi
    done
}

_restore_nvidia_holds() {
    [[ ${#NVIDIA_TEMP_HELD[@]} -eq 0 ]] && return 0
    sudo apt-mark unhold "${NVIDIA_TEMP_HELD[@]}" >> "${LOG_FILE}" 2>&1 || true
    NVIDIA_TEMP_HELD=()
}

_apt_exit_cleanup() {
    _restore_nvidia_holds
    [[ -n "${SUDO_KEEP_ALIVE_PID:-}" ]] && kill "${SUDO_KEEP_ALIVE_PID}" 2>/dev/null || true
}

# ── 0. Manage NVIDIA hold state ───────────────────────────────────────────────

# Detect half-configured nvidia packages (iF state) — warn upfront so the
# repeated dpkg reconfigure failures below are expected, not surprising.
_broken_nvidia=$(dpkg -l 'nvidia-*' 'libnvidia-*' 2>/dev/null | awk '/^iF/{print $2}' | tr '\n' ' ')
if [[ -n "${_broken_nvidia// }" ]]; then
    print_warn "nvidia-dkms is in a broken dpkg state (iF) — each apt command will attempt DKMS rebuild and fail"
    print_info "Broken packages: ${_broken_nvidia}"
    print_info "Fix: sudo apt install gcc-14 && sudo dpkg --configure -a"
fi

if [[ "${UPGRADE_NVIDIA}" -eq 0 ]]; then
    print_info "NVIDIA packages held (use --nvidia to upgrade)"
    _temporarily_hold_nvidia
    trap _apt_exit_cleanup EXIT
fi

# ── 1. Refresh all apt sources ────────────────────────────────────────────────
_ensure_configured_repos

print_section "Refreshing package lists"

print_step "apt-get update"
_apt_out=$(sudo apt-get -o DPkg::Lock::Timeout=600 update -q 2>&1) && _apt_rc=0 || _apt_rc=$?
_log_raw "RUN " "sudo apt-get -o DPkg::Lock::Timeout=600 update -q"
[[ -n "${_apt_out}" ]] && echo "${_apt_out}" >> "${LOG_FILE}"
if [[ $_apt_rc -eq 0 ]]; then
    print_ok; record_ok
    # Detect duplicate APT source files (causes repeated harmless warnings)
    if echo "${_apt_out}" | grep -q "configured multiple times"; then
        _dup=$(echo "${_apt_out}" | grep -oP '/etc/apt/sources\.list\.d/\S+' | sort -u | paste -sd' and ')
        print_warn "Duplicate APT source files: ${_dup}"
        print_info "Fix: sudo rm /etc/apt/sources.list.d/meganz.list  (keep megaio.sources)"
    fi
else
    print_error "apt-get update failed — cannot guarantee package freshness"
    record_err
    print_info "Check repo configuration and network, then rerun update-all.sh"
    print_summary "APT Update Summary"
    exit 1
fi

# ── 2. Safe upgrade (keep existing config files) ─────────────────────────────
print_section "Upgrading packages"

APT_OPTS=(
    -y -q
    -o DPkg::Lock::Timeout=600
    -o Dpkg::Options::="--force-confdef"
    -o Dpkg::Options::="--force-confold"
    -o APT::Get::Show-Versions=true
)

print_step "apt-get upgrade"
if sudo_silent apt-get upgrade "${APT_OPTS[@]}"; then
    print_ok; record_ok
    _upgrade_rc=0
else
    _upgrade_rc=1
    if grep -qiE "nvidia-dkms|dkms.*nvidia" "${LOG_FILE}" 2>/dev/null; then
        print_warn "upgrade had NVIDIA DKMS build failure — run with --nvidia flag to attempt repair"
    else
        print_warn "upgrade returned non-zero — some packages may be held"
    fi
    record_warn
fi

print_step "apt-get dist-upgrade (metapackages & kernel)"
if sudo_silent apt-get dist-upgrade "${APT_OPTS[@]}"; then
    print_ok; record_ok
    _dist_rc=0
else
    _dist_rc=1
    if grep -qiE "nvidia-dkms|dkms.*nvidia" "${LOG_FILE}" 2>/dev/null; then
        print_warn "dist-upgrade had NVIDIA DKMS failure — run with --nvidia to attempt repair"
    else
        print_warn "dist-upgrade returned non-zero"
    fi
    record_warn
fi

if [[ "${_upgrade_rc:-0}" -ne 0 && "${_dist_rc:-0}" -ne 0 ]]; then
    print_error "Both apt-get upgrade and dist-upgrade failed"
    record_err
fi

# ── 3. Cleanup ────────────────────────────────────────────────────────────────
print_section "Cleaning up"

print_step "Remove orphaned packages"
if sudo_silent apt-get autoremove -y -q; then
    print_ok; record_ok
else
    if grep -qiE "nvidia-dkms|dkms.*nvidia" "${LOG_FILE}" 2>/dev/null; then
        print_warn "autoremove had NVIDIA DKMS failure (expected on mainline kernels)"
    else
        print_warn "autoremove non-zero"
    fi
    record_warn
fi

print_step "Clean package cache"
sudo_silent apt-get autoclean -q && print_ok || { print_warn "autoclean non-zero"; record_warn; }

# ── Restore NVIDIA hold state ─────────────────────────────────────────────────
_restore_nvidia_holds
[[ -n "${SUDO_KEEP_ALIVE_PID:-}" ]] && trap 'kill "${SUDO_KEEP_ALIVE_PID}" 2>/dev/null; true' EXIT || trap - EXIT

# ── 4. Feed/candidate health for key desktop apps ────────────────────────────
print_section "Desktop app feed health"
for pkg in code antigravity; do
    if ! apt_installed "$pkg"; then
        continue
    fi
    inst_ver=$(apt_pkg_version "$pkg")
    cand_ver=$(apt_pkg_candidate "$pkg")
    src_line=$(apt_pkg_source_line "$pkg")

    if [[ -z "$src_line" ]]; then
        if [[ -n "$cand_ver" && "$cand_ver" != "(none)" ]]; then
            print_info "${pkg}: up to date (${inst_ver})"
            continue
        fi
        print_warn "${pkg}: installed (${inst_ver}) but no active APT feed detected"
        print_info "  run setup.sh or verify ${CONFIG_REPOS} and source files in /etc/apt/sources.list.d/"
        record_warn
        continue
    fi

    if [[ -n "$cand_ver" && "$cand_ver" != "(none)" && "$cand_ver" != "$inst_ver" ]]; then
        print_info "${pkg}: update available ${inst_ver} → ${cand_ver}"
    else
        print_info "${pkg}: up to date (${inst_ver})"
    fi
done

# ── 5. Targeted verify/retry for key desktop apps ────────────────────────────
print_section "Targeted desktop app verification"
for pkg in code antigravity; do
    apt_installed "$pkg" || continue
    inst_ver=$(apt_pkg_version "$pkg")
    cand_ver=$(apt_pkg_candidate "$pkg")
    if [[ -z "$cand_ver" || "$cand_ver" == "(none)" || "$cand_ver" == "$inst_ver" ]]; then
        continue
    fi

    print_step "apt-get install --only-upgrade ${pkg} (${inst_ver} → ${cand_ver})"
    if sudo_silent apt-get install -y -q --only-upgrade "$pkg"; then
        new_ver=$(apt_pkg_version "$pkg")
        if [[ "$new_ver" == "$cand_ver" ]]; then
            print_ok "${inst_ver} → ${new_ver}"
            record_ok
        else
            print_warn "${pkg}: expected ${cand_ver}, got ${new_ver}"
            record_warn
        fi
    else
        print_warn "${pkg}: targeted upgrade failed"
        record_warn
    fi
done

# ── 6. Version report (from config) ──────────────────────────────────────────
print_section "Key package versions (from config/apt-packages.list)"

if [[ -f "$CONFIG_APT" ]]; then
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        ver=$(apt_pkg_version "$pkg")
        if [[ -n "$ver" ]]; then
            print_info "${pkg}: ${ver}"
        else
            print_warn "${pkg}: NOT INSTALLED"
            record_warn
        fi
    done < <(parse_config_names "$CONFIG_APT")
else
    print_warn "Config file not found: ${CONFIG_APT}"
fi

# ── 7. Reboot check ───────────────────────────────────────────────────────────
if [[ -f /var/run/reboot-required ]]; then
    echo
    print_warn "*** REBOOT REQUIRED ***"
    [[ -f /var/run/reboot-required.pkgs ]] && \
        print_info "  Packages: $(paste -sd', ' /var/run/reboot-required.pkgs)"
fi

print_summary "APT Update Summary"

if [[ "${SUMMARY_ERR:-0}" -gt 0 ]]; then
    exit 1
fi

# ── Update inventory (skipped when called from update-all.sh) ─────────────────
if [[ "${INVENTORY_SILENT:-0}" != "1" ]]; then
    print_section "Updating APPS.md"
    print_step "update-inventory.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && print_ok || print_warn "inventory update failed"
fi
