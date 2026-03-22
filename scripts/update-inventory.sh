#!/usr/bin/env bash
# =============================================================================
# scripts/update-inventory.sh — Regenerate APPS.md with current package versions
#
# Run after all update scripts to capture the post-update state.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

APPS_MD="${SCRIPT_DIR}/APPS.md"
BREW="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}/bin/brew"
NOW="$(date '+%Y-%m-%d %H:%M:%S')"

print_header "Updating APPS.md Inventory"

print_step "Generating inventory"

# Helper: get apt package version
apt_ver() { dpkg -l "$1" 2>/dev/null | awk '/^ii/{print $3}' | head -1; }

# Helper: get brew formula version
brew_ver() { "${BREW}" list --versions "$1" 2>/dev/null | awk '{print $2}'; }

# Helper: get snap version
snap_ver() { snap list "$1" 2>/dev/null | awk 'NR==2{print $2}'; }

# ── Build APPS.md ─────────────────────────────────────────────────────────────
{
cat << HEREDOC
# APPS.md — Software Inventory

> **Host:** $(hostname)
> **OS:** $(lsb_release -ds 2>/dev/null)
> **Kernel:** $(uname -r)
> **Last updated:** ${NOW}
> **Hardware:** $(sudo dmidecode -s system-manufacturer 2>/dev/null || echo "Dell Inc.") $(sudo dmidecode -s system-product-name 2>/dev/null || echo "Precision 5520")
> **GPU:** $(lspci 2>/dev/null | grep -i nvidia | head -1 | sed 's/.*: //' || echo "NVIDIA Quadro M1200 Mobile")

---

## Table of Contents

1. [APT — OS & Core Packages](#apt--os--core-packages)
2. [APT — Third-Party Applications](#apt--third-party-applications)
3. [Snap Packages](#snap-packages)
4. [Homebrew Formulas](#homebrew-formulas)
5. [Homebrew Casks](#homebrew-casks)
6. [npm Global Packages](#npm-global-packages)
7. [Drivers & Firmware](#drivers--firmware)
8. [Manually Installed / /opt](#manually-installed--opt)

---

## APT — OS & Core Packages

| Package | Version | Source |
|---------|---------|--------|
HEREDOC

# OS meta packages
for pkg in ubuntu-desktop ubuntu-desktop-minimal ubuntu-standard ubuntu-minimal; do
    ver=$(apt_ver "$pkg"); [[ -n "$ver" ]] && echo "| \`$pkg\` | $ver | Ubuntu |"
done

cat << 'HEREDOC'

## APT — Third-Party Applications

| Application | Package | Version | Source/Repo |
|-------------|---------|---------|-------------|
HEREDOC

declare -A APT_APPS=(
    ["Brave Browser"]="brave-browser|brave-browser-release.sources"
    ["Google Chrome"]="google-chrome-stable|google-chrome.list"
    ["VS Code"]="code|vscode.sources"
    ["Docker CE"]="docker-ce|docker.sources"
    ["Docker CLI"]="docker-ce-cli|docker.sources"
    ["Docker Compose Plugin"]="docker-compose-plugin|docker.sources"
    ["Docker Buildx Plugin"]="docker-buildx-plugin|docker.sources"
    ["containerd.io"]="containerd.io|docker.sources"
    ["NVIDIA Container Toolkit"]="nvidia-container-toolkit|nvidia-container-toolkit.list"
    ["MegaSync"]="megasync|meganz.list"
    ["Proton Mail"]="proton-mail|protonvpn-stable.sources"
    ["ProtonVPN (GTK)"]="proton-vpn-gtk-app|protonvpn-stable.sources"
    ["ProtonVPN Daemon"]="proton-vpn-daemon|protonvpn-stable.sources"
    ["Grub Customizer"]="grub-customizer|PPA danielrichter2007"
    ["Remote Desktop Manager"]="remotedesktopmanager|devolutions.net"
    ["Rclone"]="rclone|ubuntu-repo"
    ["Node.js (system)"]="nodejs|ubuntu-repo"
    ["npm (system)"]="npm|ubuntu-repo"
    ["NVIDIA Driver 580"]="nvidia-driver-580|ubuntu-repo"
    ["Git"]="git|ubuntu-repo"
    ["curl"]="curl|ubuntu-repo"
    ["wget"]="wget|ubuntu-repo"
    ["build-essential"]="build-essential|ubuntu-repo"
    ["BleachBit"]="bleachbit|ubuntu-repo"
    ["Midnight Commander"]="mc|ubuntu-repo"
    ["Remmina"]="remmina|ubuntu-repo"
)
for app in "${!APT_APPS[@]}"; do
    IFS='|' read -r pkg repo <<< "${APT_APPS[$app]}"
    ver=$(apt_ver "$pkg")
    [[ -n "$ver" ]] && echo "| $app | \`$pkg\` | $ver | $repo |"
done | sort

cat << 'HEREDOC'

## Snap Packages

| Application | Version | Revision | Channel | Publisher |
|-------------|---------|----------|---------|-----------|
HEREDOC

snap list 2>/dev/null | tail -n +2 | awk '{print $1, $2, $3, $4, $5}' | \
while IFS=' ' read -r name ver rev chan pub; do
    case "$name" in
        bare|core*|gnome-*|gtk-common*|kf5-*|mesa-*|snapd|snapd-desktop-*)
            echo "| \`$name\` *(runtime)* | $ver | $rev | $chan | $pub |" ;;
        *)
            echo "| **$name** | $ver | $rev | $chan | $pub |" ;;
    esac
done

cat << 'HEREDOC'

## Homebrew Formulas

> Linuxbrew prefix: `/home/linuxbrew/.linuxbrew`
> Node.js/npm managed by brew — **use brew versions, not system apt ones**.

| Formula | Version | Description |
|---------|---------|-------------|
HEREDOC

"${BREW}" list --formula --versions 2>/dev/null | sort | while IFS=' ' read -r name ver; do
    desc=$("${BREW}" info "$name" 2>/dev/null | sed -n '2p' | sed 's/^: //' || echo "")
    echo "| \`$name\` | $ver | $desc |"
done

cat << 'HEREDOC'

## Homebrew Casks

| Application | Version | Description |
|-------------|---------|-------------|
HEREDOC

"${BREW}" list --cask 2>/dev/null | while read -r cask; do
    ver=$(ls "/home/linuxbrew/.linuxbrew/Caskroom/${cask}/" 2>/dev/null | tail -1)
    desc=$("${BREW}" info --cask "$cask" 2>/dev/null | head -1 | sed 's/==> //' || echo "")
    echo "| **$cask** | $ver | $desc |"
done

cat << 'HEREDOC'

## npm Global Packages

> Using Homebrew Node.js: `/home/linuxbrew/.linuxbrew/bin/node`

| Package | Version |
|---------|---------|
HEREDOC

BREW_NPM="/home/linuxbrew/.linuxbrew/bin/npm"
if [[ -x "${BREW_NPM}" ]]; then
    "${BREW_NPM}" list -g --depth=0 2>/dev/null | tail -n +2 | while IFS= read -r l; do
        pkg=$(echo "$l" | awk '{print $2}' | tr -d '├─└─ ')
        echo "| \`$pkg\` | (see brew node) |"
    done
else
    echo "| *npm not available* | — |"
fi

cat << 'HEREDOC'

## Drivers & Firmware

### NVIDIA

| Component | Version / Status |
|-----------|-----------------|
HEREDOC

nvidia_drv=$(apt_ver "nvidia-driver-580")
nvidia_ct=$(apt_ver "nvidia-container-toolkit")
nvidia_smi_out=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "not loaded (reboot required)")
echo "| NVIDIA Driver 580 (apt) | $nvidia_drv |"
echo "| NVIDIA Container Toolkit | $nvidia_ct |"
echo "| nvidia-smi GPU | $nvidia_smi_out |"
echo "| Running kernel | $(uname -r) |"

cat << 'HEREDOC'

### Firmware (fwupd)

| Device | Current Version |
|--------|----------------|
HEREDOC

fwupdmgr get-devices 2>/dev/null | awk '
/├─|└─/ { device=$0; gsub(/^[│├└─ ]+/, "", device); gsub(/:$/, "", device) }
/Current version:/ { ver=$NF; print "| " device " | " ver " |" }
' | head -10

cat << 'HEREDOC'

### Dell BIOS

| Property | Value |
|----------|-------|
HEREDOC

echo "| BIOS Version | $(sudo dmidecode -s bios-version 2>/dev/null || echo 'N/A') |"
echo "| BIOS Release Date | $(sudo dmidecode -s bios-release-date 2>/dev/null || echo 'N/A') |"
echo "| System | $(sudo dmidecode -s system-product-name 2>/dev/null || echo 'Dell Precision 5520') |"

cat << 'HEREDOC'

## Manually Installed / /opt

| Application | Location | Version |
|-------------|----------|---------|
HEREDOC

# /opt apps
[[ -d "/opt/brave.com/brave" ]] && echo "| Brave Browser | \`/opt/brave.com/brave\` | $(brave-browser --version 2>/dev/null | awk '{print $NF}' || echo 'see apt') |"
[[ -d "/opt/google/chrome" ]] && echo "| Google Chrome | \`/opt/google/chrome\` | $(google-chrome --version 2>/dev/null | awk '{print $NF}' || echo 'see apt') |"
[[ -d "/opt/megasync" ]] && echo "| MegaSync | \`/opt/megasync\` | $(megasync --version 2>/dev/null || echo 'see apt') |"
[[ -x "/usr/local/bin/docker" ]] && echo "| Docker (symlink) | \`/usr/local/bin/docker\` | $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',') |"
[[ -x "/home/linuxbrew/.linuxbrew/bin/claude" ]] && echo "| Claude Code CLI | \`/home/linuxbrew/.linuxbrew/bin/claude\` | $(claude --version 2>/dev/null | head -1 || echo 'see brew cask') |"

cat << 'HEREDOC'

---

## APT Sources (Third-Party Repos)

| Repo/PPA | File |
|----------|------|
| Brave Browser | `/etc/apt/sources.list.d/brave-browser-release.sources` |
| Google Chrome | `/etc/apt/sources.list.d/google-chrome.list` |
| VS Code | `/etc/apt/sources.list.d/vscode.sources` |
| Docker CE | `/etc/apt/sources.list.d/docker.sources` |
| NVIDIA Container Toolkit | `/etc/apt/sources.list.d/nvidia-container-toolkit.list` |
| MegaSync | `/etc/apt/sources.list.d/meganz.list` |
| ProtonVPN | `/etc/apt/sources.list.d/protonvpn-stable.sources` |
| Grub Customizer PPA | `/etc/apt/sources.list.d/danielrichter2007-ubuntu-grub-customizer-noble.sources` |

---

*Auto-generated by `scripts/update-inventory.sh` — do not edit manually.*
HEREDOC

} > "${APPS_MD}"

print_ok
record_ok
print_info "Written to: ${APPS_MD}"
print_info "Size: $(wc -l < "${APPS_MD}") lines"

print_summary "Inventory Update Summary"
