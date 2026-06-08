#!/usr/bin/env bash
# =============================================================================
# install.sh — One-liner master installer for Ubuntu_Aktualizacje / Ascendo
#
# Usage:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/KasprowiczM/Ubuntu_Aktualizacje/main/install.sh)"
#   or locally:
#   bash install.sh
# =============================================================================
set -euo pipefail

# ── Colors & Branding ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

print_header() {
    echo -e "${BOLD}${BLUE}============================================================${RESET}"
    echo -e "${BOLD}${BLUE}  Ascendo — Master Installer${RESET}"
    echo -e "${BOLD}${BLUE}============================================================${RESET}"
}

print_section() {
    echo
    echo -e "${BOLD}${CYAN}── $* ──────────────────────────────────────────────────${RESET}"
}

print_ok() { echo -e "  ${GREEN}✔${RESET} $*"; }
print_warn() { echo -e "  ${YELLOW}⚠  $*${RESET}"; }
print_error() { echo -e "  ${RED}✘  $*${RESET}"; }
print_info() { echo -e "     $*"; }

# Stdin-redirected pipe guard helper for interactive prompt
prompt_user() {
    local prompt_msg="$1"
    local default_val="$2"
    local response
    echo -ne "  ${YELLOW}?${RESET} ${prompt_msg} [${default_val}]: " >/dev/tty
    read -r response </dev/tty
    echo "${response:-$default_val}"
}

prompt_confirm() {
    local prompt_msg="$1"
    local default_yn="$2" # y or n
    local response
    local options="[y/N]"
    [[ "$default_yn" =~ ^[yY]$ ]] && options="[Y/n]"

    echo -ne "  ${YELLOW}?${RESET} ${prompt_msg} ${options}: " >/dev/tty
    read -r response </dev/tty
    response="${response:-$default_yn}"
    if [[ "$response" =~ ^[yY]$ || "$response" =~ ^[yY][eE][sS]$ ]]; then
        return 0
    else
        return 1
    fi
}

# ── 1. OS Verification ──────────────────────────────────────────────────────
print_header

if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
        print_error "This project is designed for Ubuntu. Found: ${NAME:-unknown}"
        if ! prompt_confirm "Do you want to proceed anyway?" "n"; then
            exit 1
        fi
    fi
else
    print_warn "/etc/os-release not readable. Could not verify OS."
fi

# ── 2. Clone Repository (if not already cloned) ──────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IN_REPO=0

if [[ -f "${SCRIPT_DIR}/update-all.sh" && -f "${SCRIPT_DIR}/setup.sh" ]]; then
    IN_REPO=1
    PROJECT_DIR="$SCRIPT_DIR"
fi

if [[ $IN_REPO -eq 0 ]]; then
    print_section "Repository Clone"
    print_info "Not currently inside the project repository."
    
    DEFAULT_CLONE_DIR="${HOME}/Dev_Env/Ubuntu_Aktualizacje"
    CLONE_DIR=$(prompt_user "Enter target directory for cloning" "$DEFAULT_CLONE_DIR")
    
    # Expand tilde
    CLONE_DIR="${CLONE_DIR/#\~/$HOME}"
    
    # Check if target directory already has the repo
    if [[ -f "${CLONE_DIR}/update-all.sh" && -f "${CLONE_DIR}/setup.sh" ]]; then
        print_ok "Found existing repository at: ${CLONE_DIR}"
        PROJECT_DIR="$CLONE_DIR"
    else
        print_info "Installing Git prerequisite..."
        if ! command -v git &>/dev/null; then
            sudo apt-get update -q && sudo apt-get install -y git
        fi
        
        print_info "Cloning project repository..."
        mkdir -p "$(dirname "${CLONE_DIR}")"
        git clone https://github.com/KasprowiczM/Ubuntu_Aktualizacje.git "${CLONE_DIR}"
        PROJECT_DIR="$CLONE_DIR"
        print_ok "Project cloned to: ${PROJECT_DIR}"
    fi
    cd "$PROJECT_DIR"
else
    print_ok "Running from project repository: ${PROJECT_DIR}"
fi

# ── 3. Normal vs Developer Environment Selection ─────────────────────────────
print_section "Installation Mode"
DEV_MODE=0
if prompt_confirm "Do you want to set up the Developer environment (enables Proton Drive / dev-sync)? " "n"; then
    DEV_MODE=1
    print_ok "Developer mode selected."
else
    print_ok "Normal user mode selected (standard updates only)."
fi

# ── 4. Prerequisites Installation ───────────────────────────────────────────
print_section "Installing Prerequisites"
PREREQS=(
    curl wget git gpg ca-certificates apt-transport-https
    software-properties-common gnupg lsb-release
    build-essential file procps python3
)

if [[ $DEV_MODE -eq 1 ]]; then
    PREREQS+=(rclone)
fi

print_info "Updating package lists..."
sudo apt-get update -q

print_info "Installing dependencies: ${PREREQS[*]}"
sudo apt-get install -y "${PREREQS[@]}"
print_ok "Prerequisites installed successfully."

# ── 5. Developer Sync Setup (Proton Drive) ───────────────────────────────────
if [[ $DEV_MODE -eq 1 ]]; then
    print_section "Developer Private Overlay Sync"
    print_info "Starting dev-sync provider configuration..."
    
    # Run provider setup
    bash "${PROJECT_DIR}/dev-sync/provider_setup.sh"
    
    if [[ -f "${PROJECT_DIR}/.dev_sync_config.json" ]]; then
        if prompt_confirm "Do you want to restore the private overlay from Proton Drive now?" "y"; then
            print_info "Restoring overlay..."
            # Run restore. If working tree is dirty (e.g. testing locally), warn but allow continue
            bash "${PROJECT_DIR}/scripts/restore-from-proton.sh" --verbose || {
                print_warn "Overlay restore reported issues. Check your provider/local modifications."
            }
        fi
    else
        print_warn ".dev_sync_config.json not found. Skipping overlay restore."
    fi
fi

# ── 6. Run Bootstrap / Reconcile Packages ────────────────────────────────────
print_section "Running System Bootstrap"

# For first-time installs on new machines, build the inventory first to avoid forcing template apps
if prompt_confirm "Initialize package configuration lists with applications already installed on this host?" "y"; then
    print_info "Scanning system and building package lists..."
    bash "${PROJECT_DIR}/setup.sh" --discover --non-interactive
fi

print_info "Reconciling all system package managers and lists..."
bash "${PROJECT_DIR}/scripts/bootstrap.sh" --skip-sync
print_ok "System bootstrapped successfully."

# ── 7. Post-Installation Orchestration ───────────────────────────────────────
print_section "Post-Installation Config"

# 7a. Build Inventory
if prompt_confirm "Do you want to build the applications inventory (APPS.md)?" "y"; then
    print_info "Generating APPS.md..."
    bash "${PROJECT_DIR}/scripts/update-inventory.sh"
    print_ok "Inventory generated."
fi

# 7b. Dry-Run Update Plan
if prompt_confirm "Do you want to run a dry-run update to verify the system?" "y"; then
    print_info "Running dry-run update..."
    "${PROJECT_DIR}/update-all.sh" --dry-run || true
fi

# 7c. Dashboard User Service
if prompt_confirm "Do you want to install and enable the dashboard systemd user service?" "y"; then
    print_info "Configuring dashboard service..."
    bash "${PROJECT_DIR}/systemd/user/install-dashboard.sh"
    print_ok "Dashboard service configured."
fi

# ── 8. Summary & Next Steps ──────────────────────────────────────────────────
print_section "Installation Complete"
echo -e "  ${BOLD}${GREEN}╔═══════════════════════════════════════════════════════╗${RESET}"
echo -e "  ${BOLD}${GREEN}║   Ascendo has been installed successfully!           ║${RESET}"
echo -e "  ${BOLD}${GREEN}╚═══════════════════════════════════════════════════════╝${RESET}"
echo
print_info "Project Directory : ${PROJECT_DIR}"
print_info "Main Entrypoint   : ${PROJECT_DIR}/update-all.sh"
echo
echo -e "  ${BOLD}Useful commands:${RESET}"
echo -e "    • Run full update    :  ${PROJECT_DIR}/update-all.sh"
echo -e "    • Dry-run check      :  ${PROJECT_DIR}/update-all.sh --dry-run"
echo -e "    • Start Dashboard    :  xdg-open http://127.0.0.1:8766"
echo -e "    • Service Status     :  systemctl --user status ascendo-ubuntu-dashboard"
echo
