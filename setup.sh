#!/usr/bin/env bash
# =============================================================================
# setup.sh — Migration & bootstrap script
#
# Run this on a FRESH Ubuntu 24.04 system after cloning the repo:
#
#   git clone https://github.com/YOUR_USERNAME/Ubuntu_Aktualizacje.git
#   cd Ubuntu_Aktualizacje
#   chmod +x setup.sh && ./setup.sh
#
# What it does:
#   1.  Verifies Ubuntu 24.04
#   2.  Installs APT prerequisites (curl, git, wget, gpg, etc.)
#   3.  Adds all third-party APT repositories (Brave, Chrome, VSCode, Docker,
#       NVIDIA Container Toolkit, MegaSync, ProtonVPN)
#   4.  Installs all APT applications
#   5.  Installs Homebrew (Linuxbrew)
#   6.  Installs all Homebrew formulas and casks
#   7.  Installs Snap packages
#   8.  Configures ~/.bashrc / ~/.profile PATH entries for Linuxbrew
#   9.  Installs NVIDIA driver 580 (optional)
#   10. Runs update-all.sh to bootstrap to latest versions
#   11. Generates initial APPS.md
# =============================================================================
set -euo pipefail

# ── Bootstrap colors (before common.sh is available) ──────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"
SETUP_LOG="${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
export LOG_FILE="${SETUP_LOG}"

step()  { echo -ne "  ${BOLD}▶${RESET}  $* ... "; }
ok()    { echo -e "${GREEN}✔${RESET}"; echo "OK: $*" >> "${SETUP_LOG}"; }
warn()  { echo -e "${YELLOW}⚠  $*${RESET}"; echo "WARN: $*" >> "${SETUP_LOG}"; }
fail()  { echo -e "${RED}✘  $*${RESET}"; echo "FAIL: $*" >> "${SETUP_LOG}"; }
info()  { echo -e "     $*"; echo "INFO: $*" >> "${SETUP_LOG}"; }
header(){ echo; echo -e "${BOLD}${BLUE}══ $* ══${RESET}"; echo; }
has()   { command -v "$1" &>/dev/null; }
s()     { sudo "$@" >> "${SETUP_LOG}" 2>&1; }  # sudo silent

# ── Flags ─────────────────────────────────────────────────────────────────────
INSTALL_NVIDIA=0
SKIP_BREW=0
SKIP_SNAPS=0
NON_INTERACTIVE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --nvidia)          INSTALL_NVIDIA=1 ;;
        --skip-brew)       SKIP_BREW=1 ;;
        --skip-snaps)      SKIP_SNAPS=1 ;;
        --non-interactive) NON_INTERACTIVE=1 ;;
        -h|--help)
            echo "Usage: $0 [--nvidia] [--skip-brew] [--skip-snaps] [--non-interactive]"
            exit 0 ;;
    esac
    shift
done

# ── Intro ─────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║   Ubuntu_Aktualizacje — Migration & Setup Script   ║${RESET}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════╝${RESET}"
echo
info "Log: ${SETUP_LOG}"
echo

# ── 1. Check Ubuntu version ───────────────────────────────────────────────────
header "1. System Check"

OS_ID=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
OS_VER=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')

step "Ubuntu 24.04 check"
if [[ "$OS_ID" != "ubuntu" ]]; then
    fail "Not Ubuntu (found: ${OS_ID}). This script targets Ubuntu 24.04."
    exit 1
fi
if [[ "$OS_VER" != "24.04" ]]; then
    warn "Expected Ubuntu 24.04, found ${OS_VER}. Proceeding — some packages may differ."
else
    ok "Ubuntu ${OS_VER}"
fi

# ── 2. Sudo ───────────────────────────────────────────────────────────────────
step "Authenticate sudo"
sudo -v || { fail "sudo required"; exit 1; }
(while true; do sudo -n true; sleep 50; done) &
SUDO_PID=$!
trap 'kill ${SUDO_PID} 2>/dev/null' EXIT INT TERM
ok

# ── 3. APT prerequisites ───────────────────────────────────────────────────────
header "2. APT Prerequisites"

PREREQUISITES=(
    curl wget git gpg ca-certificates apt-transport-https
    software-properties-common gnupg lsb-release
    build-essential file procps
)

step "apt-get update"
s apt-get update -q && ok || warn "update had issues"

step "Install prerequisites: ${PREREQUISITES[*]}"
s apt-get install -y -q "${PREREQUISITES[@]}" && ok || { fail "prerequisite install failed"; exit 1; }

# ── 4. Add third-party APT repositories ───────────────────────────────────────
header "3. Third-Party APT Repositories"

# Helper: add a signed repo
add_repo() {
    local name="$1" keyurl="$2" keyfile="$3" repofile="$4" repoentry="$5"
    step "Add ${name} repo"
    if [[ -f "$repofile" ]]; then
        info "(already exists)"
        return
    fi
    curl -fsSL "$keyurl" | sudo gpg --dearmor -o "$keyfile" >> "${SETUP_LOG}" 2>&1
    echo "$repoentry" | sudo tee "$repofile" >> "${SETUP_LOG}"
    ok
}

# Brave Browser
add_repo "Brave Browser" \
    "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
    "/usr/share/keyrings/brave-browser-archive-keyring.gpg" \
    "/etc/apt/sources.list.d/brave-browser-release.sources" \
    "Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg"

# Google Chrome
step "Add Google Chrome repo"
if [[ ! -f "/etc/apt/sources.list.d/google-chrome.list" ]]; then
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | \
        sudo gpg --dearmor -o /usr/share/keyrings/google-linux-signing-key.gpg >> "${SETUP_LOG}" 2>&1
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-signing-key.gpg] \
https://dl.google.com/linux/chrome/deb/ stable main" | \
        sudo tee /etc/apt/sources.list.d/google-chrome.list >> "${SETUP_LOG}"
    ok
else
    info "(already exists)"
fi

# VS Code
step "Add VS Code repo"
if [[ ! -f "/etc/apt/sources.list.d/vscode.sources" ]]; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
        sudo gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg >> "${SETUP_LOG}" 2>&1
    echo "Types: deb
URIs: https://packages.microsoft.com/repos/vscode
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft-archive-keyring.gpg" | \
        sudo tee /etc/apt/sources.list.d/vscode.sources >> "${SETUP_LOG}"
    ok
else
    info "(already exists)"
fi

# Docker CE
step "Add Docker repo"
if [[ ! -f "/etc/apt/sources.list.d/docker.sources" ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >> "${SETUP_LOG}" 2>&1
    echo "Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(lsb_release -cs)
Components: stable
Architectures: amd64
Signed-By: /usr/share/keyrings/docker-archive-keyring.gpg" | \
        sudo tee /etc/apt/sources.list.d/docker.sources >> "${SETUP_LOG}"
    ok
else
    info "(already exists)"
fi

# NVIDIA Container Toolkit
step "Add NVIDIA Container Toolkit repo"
if [[ ! -f "/etc/apt/sources.list.d/nvidia-container-toolkit.list" ]]; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg >> "${SETUP_LOG}" 2>&1
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >> "${SETUP_LOG}"
    ok
else
    info "(already exists)"
fi

# MegaSync
step "Add MegaSync repo"
if [[ ! -f "/etc/apt/sources.list.d/meganz.list" ]]; then
    curl -fsSL https://mega.nz/linux/repo/xUbuntu_24.04/Release.key | \
        sudo gpg --dearmor -o /usr/share/keyrings/meganz-archive-keyring.gpg >> "${SETUP_LOG}" 2>&1
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/meganz-archive-keyring.gpg] \
https://mega.nz/linux/repo/xUbuntu_24.04/ ./" | \
        sudo tee /etc/apt/sources.list.d/meganz.list >> "${SETUP_LOG}"
    ok
else
    info "(already exists)"
fi

# ProtonVPN
step "Add ProtonVPN repo"
if [[ ! -f "/etc/apt/sources.list.d/protonvpn-stable.sources" ]]; then
    curl -fsSL https://repo.protonvpn.com/debian/public_key.asc | \
        sudo gpg --dearmor -o /usr/share/keyrings/protonvpn-stable-keyring.gpg >> "${SETUP_LOG}" 2>&1
    echo "Types: deb
URIs: https://repo.protonvpn.com/debian
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/protonvpn-stable-keyring.gpg" | \
        sudo tee /etc/apt/sources.list.d/protonvpn-stable.sources >> "${SETUP_LOG}"
    ok
else
    info "(already exists)"
fi

# Remote Desktop Manager (Devolutions)
step "Add Remote Desktop Manager repo"
if ! dpkg -l remotedesktopmanager &>/dev/null; then
    RDM_DEB_URL="https://cdn.devolutions.net/download/Linux/RDM/$(curl -s https://devolutions.net/remote-desktop-manager/release-notes/linux/ 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)/remotedesktopmanager_amd64.deb"
    warn "Remote Desktop Manager requires manual .deb download from: https://devolutions.net/remote-desktop-manager/home/linuxdownload"
    info "Run: sudo dpkg -i remotedesktopmanager_amd64.deb && sudo apt-get install -f"
else
    info "(already installed)"
fi

# Grub Customizer PPA
step "Add Grub Customizer PPA"
if [[ ! -f "/etc/apt/sources.list.d/danielrichter2007-ubuntu-grub-customizer-noble.sources" ]]; then
    s add-apt-repository -y ppa:danielrichter2007/grub-customizer && ok || warn "PPA add failed"
else
    info "(already exists)"
fi

step "apt-get update (after adding repos)"
s apt-get update -q && ok || warn "update had issues"

# ── 5. Install APT applications ───────────────────────────────────────────────
header "4. Install APT Applications"

APT_APPS=(
    brave-browser
    google-chrome-stable
    code
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    nvidia-container-toolkit
    megasync
    proton-vpn-gnome-desktop proton-mail
    grub-customizer
    rclone
    mc bleachbit remmina
    git curl wget unzip zip
    build-essential
)

# Optional: NVIDIA driver
if [[ $INSTALL_NVIDIA -eq 1 ]]; then
    APT_APPS+=(nvidia-driver-580)
fi

for pkg in "${APT_APPS[@]}"; do
    step "apt install ${pkg}"
    if dpkg -l "$pkg" &>/dev/null; then
        info "(already installed)"
    else
        if s apt-get install -y -q \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            "$pkg"; then
            ok
        else
            warn "Failed to install ${pkg} — may need manual intervention"
        fi
    fi
done

# ── 6. Install Homebrew (Linuxbrew) ───────────────────────────────────────────
if [[ $SKIP_BREW -eq 0 ]]; then
    header "5. Homebrew (Linuxbrew)"

    BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
    if [[ -x "${BREW_BIN}" ]]; then
        info "Homebrew already installed at /home/linuxbrew/.linuxbrew"
    else
        step "Install Homebrew"
        NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
            >> "${SETUP_LOG}" 2>&1 && ok || { fail "Homebrew install failed"; exit 1; }
    fi

    # PATH setup
    BREW_SHELL_CONFIG='
# Homebrew (Linuxbrew)
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'

    for rcfile in ~/.bashrc ~/.profile ~/.zshrc; do
        [[ -f "$rcfile" ]] || continue
        if ! grep -q "linuxbrew" "$rcfile" 2>/dev/null; then
            step "Add brew PATH to ${rcfile}"
            echo "${BREW_SHELL_CONFIG}" >> "$rcfile" && ok || warn "Failed to update ${rcfile}"
        fi
    done

    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

    # Install Brew formulas
    header "5a. Homebrew Formulas"

    BREW_FORMULAS=(
        node gcc python@3.14 ripgrep
        gemini-cli opencode qwen-code
        openssl@3 curl git
    )
    BREW_CASKS=(claude-code codex)

    for formula in "${BREW_FORMULAS[@]}"; do
        step "brew install ${formula}"
        if "${BREW_BIN}" list --formula "$formula" &>/dev/null; then
            info "(already installed)"
        else
            run_silent "${BREW_BIN}" install "$formula" && ok || warn "Failed: ${formula}"
        fi
    done

    for cask in "${BREW_CASKS[@]}"; do
        step "brew install --cask ${cask}"
        if "${BREW_BIN}" list --cask "$cask" &>/dev/null; then
            info "(already installed)"
        else
            run_silent "${BREW_BIN}" install --cask "$cask" && ok || warn "Failed cask: ${cask}"
        fi
    done
fi

# ── 7. Snap packages ──────────────────────────────────────────────────────────
if [[ $SKIP_SNAPS -eq 0 ]]; then
    header "6. Snap Packages"

    SNAPS=(
        "firefox"
        "thunderbird"
        "keepassxc"
        "htop"
    )

    for snap_pkg in "${SNAPS[@]}"; do
        step "snap install ${snap_pkg}"
        if snap list "$snap_pkg" &>/dev/null; then
            info "(already installed)"
        else
            s snap install "$snap_pkg" && ok || warn "Failed snap: ${snap_pkg}"
        fi
    done
fi

# ── 8. PATH and shell configuration ───────────────────────────────────────────
header "7. Shell Path Configuration"

SCRIPTS_PATH_CONFIG="
# Ubuntu_Aktualizacje scripts
export PATH=\"${SCRIPT_DIR}:\$PATH\""

for rcfile in ~/.bashrc ~/.zshrc; do
    [[ -f "$rcfile" ]] || continue
    if ! grep -q "Ubuntu_Aktualizacje" "$rcfile" 2>/dev/null; then
        step "Add scripts to PATH in ${rcfile}"
        echo "${SCRIPTS_PATH_CONFIG}" >> "$rcfile" && ok || warn "Failed"
    else
        info "Already in ${rcfile}"
    fi
done

# ── 9. Docker post-install (no sudo) ─────────────────────────────────────────
header "8. Docker Post-Install"

step "Add ${USER} to docker group"
if groups "${USER}" 2>/dev/null | grep -q docker; then
    info "Already in docker group"
else
    s usermod -aG docker "${USER}" && ok || warn "Failed"
    warn "Log out and back in (or run: newgrp docker) for docker to work without sudo"
fi

# ── 10. Make scripts executable ───────────────────────────────────────────────
header "9. Script Permissions"

step "chmod +x all scripts"
chmod +x "${SCRIPT_DIR}/update-all.sh" \
         "${SCRIPT_DIR}/scripts/"*.sh && ok || warn "chmod failed"

# ── 11. Run initial update + inventory ───────────────────────────────────────
header "10. Initial Update & Inventory"

if [[ $NON_INTERACTIVE -eq 0 ]]; then
    echo -e "${YELLOW}  Run full update now? (recommended) [y/N]:${RESET} "
    read -r RUN_UPDATE
else
    RUN_UPDATE="y"
fi

if [[ "${RUN_UPDATE,,}" == "y" ]]; then
    step "Running update-all.sh"
    bash "${SCRIPT_DIR}/update-all.sh" && ok || warn "Some updates failed — check logs"
else
    step "Generate initial APPS.md"
    source "${SCRIPT_DIR}/lib/common.sh"
    bash "${SCRIPT_DIR}/scripts/update-inventory.sh" && ok || warn "Inventory failed"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║   Setup complete!                                ║${RESET}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
echo
info "To apply PATH changes, run:  source ~/.bashrc"
info "To update all apps:          ./update-all.sh"
info "To update only APT:          ./scripts/update-apt.sh"
info "Log:                         ${SETUP_LOG}"
[[ $INSTALL_NVIDIA -eq 0 ]] && \
    info "Note: NVIDIA driver was NOT installed. Re-run with --nvidia flag if needed."
echo
