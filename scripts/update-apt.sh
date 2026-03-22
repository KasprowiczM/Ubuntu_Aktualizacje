#!/usr/bin/env bash
# =============================================================================
# scripts/update-apt.sh — Update & upgrade APT packages (OS + all apt sources)
#
# Covers:
#   • Ubuntu core OS packages
#   • Brave Browser          (brave-browser-release.sources)
#   • Google Chrome          (google-chrome.list)
#   • VS Code                (vscode.sources)
#   • Docker CE              (docker.sources)
#   • NVIDIA Container Toolkit (nvidia-container-toolkit.list)
#   • MegaSync               (meganz.list)
#   • ProtonVPN              (protonvpn-stable.sources)
#   • Proton Mail            (protonvpn-stable.sources)
#   • Remote Desktop Manager (remotedesktopmanager)
#   • Grub Customizer        (PPA: danielrichter2007)
#   • NVIDIA drivers         (ubuntu repo: nvidia-driver-580)
#   • Rclone                 (ubuntu repo)
#   • All other apt packages
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "APT — System & Application Updates"

require_sudo

# ── 1. Refresh package lists ──────────────────────────────────────────────────
print_section "Refreshing package lists"

print_step "apt-get update"
if sudo_silent apt-get update -q; then
    print_ok
    record_ok
else
    print_error "apt-get update failed — check /etc/apt/sources.list.d/ for broken repos"
    record_err
fi

# ── 2. Upgrade all APT packages ───────────────────────────────────────────────
print_section "Upgrading packages"

print_step "apt-get upgrade (safe)"
if sudo_silent apt-get upgrade -y -q \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"; then
    print_ok
    record_ok
else
    print_warn "apt-get upgrade returned non-zero — some packages may be on hold"
    record_warn
fi

print_step "apt-get dist-upgrade (kernel/metapackages)"
if sudo_silent apt-get dist-upgrade -y -q \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"; then
    print_ok
    record_ok
else
    print_warn "dist-upgrade returned non-zero"
    record_warn
fi

# ── 3. Auto-remove orphaned packages ─────────────────────────────────────────
print_section "Cleaning up"

print_step "Remove orphaned packages"
if sudo_silent apt-get autoremove -y -q; then
    print_ok
    record_ok
else
    print_warn "autoremove returned non-zero"
    record_warn
fi

print_step "Clean package cache"
if sudo_silent apt-get autoclean -q; then
    print_ok
    record_ok
else
    print_warn "autoclean returned non-zero"
    record_warn
fi

# ── 4. Report what changed ────────────────────────────────────────────────────
print_section "Key package versions"
declare -A KEY_PKGS=(
    [brave-browser]="Brave Browser"
    [google-chrome-stable]="Google Chrome"
    [code]="VS Code"
    [docker-ce]="Docker CE"
    [megasync]="MegaSync"
    [proton-mail]="Proton Mail"
    [proton-vpn-gtk-app]="Proton VPN"
    [remotedesktopmanager]="Remote Desktop Manager"
    [grub-customizer]="Grub Customizer"
    [nvidia-driver-580]="NVIDIA Driver 580"
    [rclone]="Rclone"
    [nodejs]="Node.js (system apt)"
)

for pkg in "${!KEY_PKGS[@]}"; do
    ver=$(dpkg -l "$pkg" 2>/dev/null | awk '/^ii/{print $3}')
    if [[ -n "$ver" ]]; then
        print_info "${KEY_PKGS[$pkg]}: ${ver}"
    fi
done

print_summary "APT Update Summary"
