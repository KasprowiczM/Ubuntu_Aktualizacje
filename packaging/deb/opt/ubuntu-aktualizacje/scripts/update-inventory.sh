#!/usr/bin/env bash
# =============================================================================
# scripts/update-inventory.sh — Regenerate APPS.md with current package state
#
# This script is machine-agnostic: it scans what is actually installed on
# THIS machine using lib/detect.sh, not hardcoded lists.
# Called automatically after each update script and by setup.sh.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

APPS_MD="${SCRIPT_DIR}/APPS.md"
NOW="$(date '+%Y-%m-%d %H:%M:%S')"

# Only print header if called directly (not as sub-step from another script)
[[ "${INVENTORY_SILENT:-0}" != "1" ]] && print_header "Updating APPS.md Inventory"
print_step "Scanning installed packages"

# Detect everything
detect_os
detect_hardware
detect_gpu
detect_package_managers
detect_docker

# Bulk-fetch dpkg + apt-cache policy data ONCE upfront. This collapses
# 250+ apt-cache policy invocations (≈30 s) into one call (~2 s).
apt_inventory_cache_init

# ── Build APPS.md ─────────────────────────────────────────────────────────────
{

# ━━━ Header ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<MD
# APPS.md — Software Inventory

> **Host:** $(hostname)
> **OS:** ${OS_PRETTY}
> **Kernel:** ${KERNEL_VER}
> **Architecture:** ${ARCH}
> **Last updated:** ${NOW}
> **Hardware:** ${HW_VENDOR} ${HW_MODEL} (${HW_CHASSIS})
> **CPU:** ${CPU_MODEL}
> **RAM:** ${RAM_GB} GB

---

## Table of Contents

1. [APT Packages](#apt-packages)
2. [Snap Packages](#snap-packages)
3. [Homebrew Formulas](#homebrew-formulas)
4. [Homebrew Casks](#homebrew-casks)
5. [npm Global Packages](#npm-global-packages)
6. [Drivers & Firmware](#drivers--firmware)
7. [Flatpak](#flatpak)
8. [APT Sources](#apt-sources)

---

## APT Packages

> Total manually installed: $(apt-mark showmanual 2>/dev/null | wc -l) packages

### OS Core

| Package | Version |
|---------|---------|
MD

for pkg in ubuntu-desktop ubuntu-desktop-minimal ubuntu-standard ubuntu-minimal; do
    ver=$(apt_pkg_version "$pkg")
    [[ -n "$ver" ]] && echo "| \`$pkg\` | $ver |"
done

# ━━━ APT: packages from config ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<'MD'

### Configured Applications

> Packages listed in `config/apt-packages.list`

| Application | Package | Version | Status |
|-------------|---------|---------|--------|
MD

CONFIG_APT="${SCRIPT_DIR}/config/apt-packages.list"
if [[ -f "$CONFIG_APT" ]]; then
    # Build a display name from package name (capitalize, replace - with space)
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        ver=$(apt_pkg_version "$pkg")
        # Read display label from config comment
        label=$(grep "^${pkg}" "$CONFIG_APT" 2>/dev/null | sed 's/#.*//' | awk '{$1=""; print $0}' | xargs || echo "")
        [[ -z "$label" ]] && label=$(echo "$pkg" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')
        if [[ -n "$ver" ]]; then
            echo "| $label | \`$pkg\` | $ver | ✔ installed |"
        else
            echo "| $label | \`$pkg\` | — | ✘ missing |"
        fi
    done < <(parse_config_names "$CONFIG_APT")
fi

cat <<'MD'

### Third-Party APT Applications (Auto-detected)

> Manual-installed packages with active non-default HTTP(S) APT feed.

| Package | Installed | Candidate | Feed |
|---------|-----------|-----------|------|
MD

third_party_count=0
third_party_rows="$(scan_apt_third_party_manual || true)"
if [[ -n "$third_party_rows" ]]; then
    third_party_count=$(echo "$third_party_rows" | wc -l | awk '{print $1}')
fi
echo "$third_party_rows" | while IFS='|' read -r pkg inst cand src; do
    [[ -z "$pkg" ]] && continue
    [[ -z "$cand" || "$cand" == "(none)" ]] && cand="N/A"
    src_short=$(echo "$src" | awk '{print $2}')
    echo "| \`$pkg\` | $inst | $cand | $src_short |"
done

if [[ "$third_party_count" -eq 0 ]]; then
    echo "| _none detected_ | — | — | — |"
fi

cat <<'MD'

### Tracked Desktop Package Feed Health

| Package | Installed | Candidate | Feed Status |
|---------|-----------|-----------|-------------|
MD

for tracked_pkg in code antigravity; do
    if apt_installed "$tracked_pkg"; then
        inst=$(apt_pkg_version "$tracked_pkg")
        cand=$(apt_pkg_candidate "$tracked_pkg")
        [[ -z "$cand" || "$cand" == "(none)" ]] && cand="N/A"
        src=$(apt_pkg_source_line "$tracked_pkg")
        if [[ -z "$src" ]]; then
            echo "| \`$tracked_pkg\` | $inst | $cand | ⚠ no active feed in apt policy |"
        else
            src_short=$(echo "$src" | awk '{print $2}')
            echo "| \`$tracked_pkg\` | $inst | $cand | $src_short |"
        fi
    fi
done

if ! apt_installed code && ! apt_installed antigravity; then
    echo "| _none tracked installed_ | — | — | — |"
fi

# ━━━ Snap Packages ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<'MD'

---

## Snap Packages

### User Applications

| Application | Version | Revision | Channel | Publisher |
|-------------|---------|----------|---------|-----------|
MD

scan_snaps_user | while IFS='|' read -r name ver rev chan pub; do
    echo "| **$name** | $ver | $rev | $chan | $pub |"
done

cat <<'MD'

### Runtime / Base Snaps

| Snap | Version | Revision |
|------|---------|----------|
MD

snap list 2>/dev/null | tail -n +2 | while read -r name ver rev chan pub notes; do
    case "$name" in
        bare|core|core[0-9]*|gnome-*|gtk-common*|kf5-*|mesa-*|snapd|snapd-*)
            echo "| \`$name\` | $ver | $rev |" ;;
    esac
done

# ━━━ Homebrew ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<MD

---

## Homebrew Formulas

> Prefix: \`${BREW_PREFIX:-not installed}\`
> Node.js from brew is the active version — **not** the system apt nodejs.

MD

if [[ $HAS_BREW -eq 1 ]]; then
    echo "### Configured Formulas"
    echo ""
    echo "| Formula | Version | In Config |"
    echo "|---------|---------|-----------|"

    CONFIG_FORM="${SCRIPT_DIR}/config/brew-formulas.list"
    # First: configured formulas
    if [[ -f "$CONFIG_FORM" ]]; then
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            ver=$(brew_formula_version "$f")
            [[ -n "$ver" ]] && echo "| \`$f\` | $ver | ✔ |" || echo "| \`$f\` | ✘ missing | ✔ |"
        done < <(parse_config_names "$CONFIG_FORM")
    fi

    echo ""
    echo "### All Installed Formulas"
    echo ""
    echo "| Formula | Version |"
    echo "|---------|---------|"
    scan_brew_formulas | sort | while read -r name ver; do
        echo "| \`$name\` | $ver |"
    done
else
    echo "_Homebrew not installed on this machine._"
fi

# ━━━ Homebrew Casks ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<'MD'

---

## Homebrew Casks

| Application | Version | In Config |
|-------------|---------|-----------|
MD

if [[ $HAS_BREW -eq 1 ]]; then
    CONFIG_CASKS="${SCRIPT_DIR}/config/brew-casks.list"
    # Configured casks first
    if [[ -f "$CONFIG_CASKS" ]]; then
        while IFS= read -r cask; do
            [[ -z "$cask" ]] && continue
            ver=$(brew_cask_version "$cask")
            [[ -n "$ver" ]] && echo "| **$cask** | $ver | ✔ |" || echo "| **$cask** | ✘ missing | ✔ |"
        done < <(parse_config_names "$CONFIG_CASKS")
    fi
    # Any other casks not in config
    # MUST use run_as_user: Homebrew 4.x exits 1 when called as root,
    # which kills this script via set -euo pipefail.
    run_as_user "${BREW_BIN}" list --cask 2>/dev/null | while read -r cask; do
        in_config=$(grep -c "^${cask}" "${CONFIG_CASKS:-/dev/null}" 2>/dev/null || echo 0)
        if [[ "$in_config" -eq 0 ]]; then
            ver=$(brew_cask_version "$cask")
            echo "| $cask | $ver | (not in config) |"
        fi
    done
else
    echo "_Homebrew not installed on this machine._"
fi

# ━━━ npm ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<MD

---

## npm Global Packages

> npm binary: \`${NPM_BIN:-not found}\`
> Node.js: \`$( [[ -n "${NPM_BIN:-}" ]] && "$(dirname "${NPM_BIN}")/node" --version 2>/dev/null || echo "N/A")\`

| Package | Version | In Config |
|---------|---------|-----------|
MD

CONFIG_NPM="${SCRIPT_DIR}/config/npm-globals.list"
if [[ -n "${NPM_BIN:-}" ]]; then
    # All installed globals
    declare -A NPM_IN_CONFIG=()
    [[ -f "$CONFIG_NPM" ]] && while IFS= read -r p; do
        [[ -z "$p" ]] && continue; NPM_IN_CONFIG["$p"]=1
    done < <(parse_config_names "$CONFIG_NPM")

    scan_npm_globals | while IFS='|' read -r name ver; do
        flag="${NPM_IN_CONFIG[$name]:-0}"
        mark=$([[ "$flag" == "1" ]] && echo "✔" || echo "—")
        echo "| \`$name\` | $ver | $mark |"
    done

    # Config items not installed
    for pkg in "${!NPM_IN_CONFIG[@]}"; do
        installed=$(scan_npm_globals | grep "^${pkg}|" || true)
        [[ -z "$installed" ]] && echo "| \`$pkg\` | ✘ missing | ✔ |"
    done
else
    echo "_npm not available on this machine._"
fi

# ━━━ Drivers & Firmware ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<'MD'

---

## Drivers & Firmware

### GPU Drivers

| Component | Details |
|-----------|---------|
MD

echo "| GPU detected | $(echo "$GPU_INFO" | head -1 | sed 's/.*: //') |"
echo "| NVIDIA present | $([[ $HAS_NVIDIA -eq 1 ]] && echo 'Yes' || echo 'No') |"

# All installed nvidia packages
dpkg -l 'nvidia-*' 2>/dev/null | awk '/^ii/{print $2, $3}' | while read -r pkg ver; do
    echo "| \`$pkg\` | $ver |"
done || true

dpkg -l 'linux-modules-nvidia*' 2>/dev/null | awk '/^ii/{print $2, $3}' | while read -r pkg ver; do
    echo "| \`$pkg\` *(kernel modules)* | $ver |"
done || true

nv_smi=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "not loaded — reboot may be needed")
echo "| nvidia-smi | $nv_smi |"
echo "| Running kernel | $(uname -r) |"

cat <<'MD'

### Firmware (fwupd)

| Device | Current Version |
|--------|----------------|
MD

scan_firmware_devices | while IFS='|' read -r dev ver; do
    echo "| $dev | $ver |"
done

cat <<'MD'

### System Firmware

| Property | Value |
|----------|-------|
MD

echo "| BIOS Version | $(sudo dmidecode -s bios-version 2>/dev/null || echo 'N/A') |"
echo "| BIOS Date | $(sudo dmidecode -s bios-release-date 2>/dev/null || echo 'N/A') |"
echo "| System | $(sudo dmidecode -s system-product-name 2>/dev/null || echo 'N/A') |"

# ━━━ Flatpak ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<'MD'

---

## Flatpak

MD

if [[ $HAS_FLATPAK -eq 1 ]]; then
    fp_list=$(scan_flatpaks)
    if [[ -n "$fp_list" ]]; then
        echo "| Application | ID | Version | Branch |"
        echo "|-------------|-----|---------|--------|"
        echo "$fp_list" | while IFS=$'\t' read -r name id ver branch; do
            echo "| $name | \`$id\` | $ver | $branch |"
        done
    else
        echo "_No Flatpak applications installed._"
    fi
else
    echo "_Flatpak not installed on this machine._"
fi

# ━━━ APT Sources ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat <<'MD'

---

## APT Sources

| Source File | Content |
|-------------|---------|
MD

for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [[ -f "$f" ]] || continue
    content=$(grep -v '^#' "$f" 2>/dev/null | grep -v '^$' | head -3 | tr '\n' ' ' | sed 's/|/\\|/g' | cut -c1-220 || true)
    [[ -n "$content" ]] && echo "| \`$(basename "$f")\` | $content |"
done

cat <<'MD'

---

*Auto-generated by `scripts/update-inventory.sh` — do not edit manually.*
MD

} > "${APPS_MD}" 2>>"${LOG_FILE}"

print_ok
record_ok
print_info "Written: ${APPS_MD} ($(wc -l < "${APPS_MD}") lines)"

print_summary "Inventory Summary"
