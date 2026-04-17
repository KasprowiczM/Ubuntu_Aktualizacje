#!/usr/bin/env bash
# =============================================================================
# lib/repos.sh — APT repository setup functions
#
# Each function is keyed by the repo ID in config/apt-repos.list.
# Call: setup_repo <repo_id>
#
# Each _setup_repo_<id>() function must be idempotent (safe to re-run).
# =============================================================================

# Source common only if not already loaded
[[ -z "${SCRIPT_DIR:-}" ]] && SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Dispatcher ────────────────────────────────────────────────────────────────

setup_repo() {
    local repo_id="${1//[^a-z0-9_-]/}"   # sanitize
    local fn="_setup_repo_${repo_id//-/_}"
    if declare -f "$fn" &>/dev/null; then
        "$fn"
    else
        print_warn "No setup function for repo '${repo_id}' — skipping"
        return 1
    fi
}

# ── Helper ────────────────────────────────────────────────────────────────────

_add_signed_repo() {
    # Usage: _add_signed_repo <name> <key_url> <key_dest> <list_file> <repo_line>
    local name="$1" key_url="$2" key_dest="$3" list_file="$4" repo_line="$5"
    if [[ -f "$list_file" ]]; then
        print_info "${name}: repo file already exists — skipping"
        return 0
    fi
    sudo install -d -m 0755 "$(dirname "$key_dest")" "$(dirname "$list_file")" \
        >> "${LOG_FILE:-/dev/null}" 2>&1 || true
    print_step "Add ${name} repo"
    if curl -fsSL "$key_url" 2>/dev/null | sudo gpg --batch --yes --dearmor -o "$key_dest" >> "${LOG_FILE:-/dev/null}" 2>&1; then
        echo "$repo_line" | sudo tee "$list_file" >> "${LOG_FILE:-/dev/null}"
        print_ok
        record_ok
    else
        print_error "Failed to fetch GPG key for ${name} from ${key_url}"
        record_err
        return 1
    fi
}

# ── Brave Browser ─────────────────────────────────────────────────────────────

_setup_repo_brave() {
    _add_signed_repo "Brave Browser" \
        "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
        "/usr/share/keyrings/brave-browser-archive-keyring.gpg" \
        "/etc/apt/sources.list.d/brave-browser-release.sources" \
        "Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg"
}

# ── Google Chrome ─────────────────────────────────────────────────────────────

_setup_repo_chrome() {
    local keyfile="/usr/share/keyrings/google-linux-signing-key.gpg"
    local listfile="/etc/apt/sources.list.d/google-chrome.list"
    if [[ -f "$listfile" ]]; then
        print_info "Google Chrome: repo already exists — skipping"; return 0
    fi
    print_step "Add Google Chrome repo"
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub 2>/dev/null | \
        sudo gpg --batch --yes --dearmor -o "$keyfile" >> "${LOG_FILE:-/dev/null}" 2>&1 || true
    echo "deb [arch=amd64 signed-by=${keyfile}] https://dl.google.com/linux/chrome/deb/ stable main" | \
        sudo tee "$listfile" >> "${LOG_FILE:-/dev/null}"
    print_ok; record_ok
}

# ── VS Code ───────────────────────────────────────────────────────────────────

_setup_repo_vscode() {
    _add_signed_repo "VS Code" \
        "https://packages.microsoft.com/keys/microsoft.asc" \
        "/usr/share/keyrings/microsoft-archive-keyring.gpg" \
        "/etc/apt/sources.list.d/vscode.sources" \
        "Types: deb
URIs: https://packages.microsoft.com/repos/vscode
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft-archive-keyring.gpg"
}

# ── Docker CE ─────────────────────────────────────────────────────────────────

_setup_repo_docker() {
    local keyfile="/usr/share/keyrings/docker-archive-keyring.gpg"
    local listfile="/etc/apt/sources.list.d/docker.sources"
    if [[ -f "$listfile" ]]; then
        print_info "Docker: repo already exists — skipping"; return 0
    fi
    print_step "Add Docker repo"
    local codename; codename=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg 2>/dev/null | \
        sudo gpg --batch --yes --dearmor -o "$keyfile" >> "${LOG_FILE:-/dev/null}" 2>&1 || true
    printf "Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: amd64\nSigned-By: %s\n" \
        "$codename" "$keyfile" | sudo tee "$listfile" >> "${LOG_FILE:-/dev/null}"
    print_ok; record_ok
}

# ── NVIDIA Container Toolkit ──────────────────────────────────────────────────

_setup_repo_nvidia_container_toolkit() {
    local keyfile="/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
    local listfile="/etc/apt/sources.list.d/nvidia-container-toolkit.list"
    if [[ -f "$listfile" ]]; then
        print_info "NVIDIA Container Toolkit: repo already exists — skipping"; return 0
    fi
    print_step "Add NVIDIA Container Toolkit repo"
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey 2>/dev/null | \
        sudo gpg --batch --yes --dearmor -o "$keyfile" >> "${LOG_FILE:-/dev/null}" 2>&1 || true
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list 2>/dev/null | \
        sed "s#deb https://#deb [signed-by=${keyfile}] https://#g" | \
        sudo tee "$listfile" >> "${LOG_FILE:-/dev/null}"
    print_ok; record_ok
}

# ── MegaSync ──────────────────────────────────────────────────────────────────

_setup_repo_megasync() {
    local os_ver; os_ver=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    local keyfile="/etc/apt/keyrings/meganz-archive-keyring.gpg"
    local sourcesfile="/etc/apt/sources.list.d/megaio.sources"
    local legacy_list="/etc/apt/sources.list.d/meganz.list"

    _add_signed_repo "MegaSync" \
        "https://mega.nz/linux/repo/xUbuntu_${os_ver}/Release.key" \
        "${keyfile}" \
        "${sourcesfile}" \
        "Types: deb
URIs: https://mega.nz/linux/repo/xUbuntu_${os_ver}/
Suites: ./
Signed-By: ${keyfile}"

    # Legacy meganz.list duplicates megaio.sources and can break apt with
    # "Conflicting values set for option Signed-By". Keep only megaio.sources.
    if [[ -f "${legacy_list}" ]]; then
        print_step "Remove legacy MegaSync list (${legacy_list})"
        if sudo rm -f "${legacy_list}" >> "${LOG_FILE:-/dev/null}" 2>&1; then
            print_ok
            record_ok
        else
            print_warn "Could not remove ${legacy_list} — apt may still fail"
            record_warn
        fi
    fi
}

# ── ProtonVPN ─────────────────────────────────────────────────────────────────

_setup_repo_protonvpn() {
    _add_signed_repo "ProtonVPN" \
        "https://repo.protonvpn.com/debian/public_key.asc" \
        "/usr/share/keyrings/protonvpn-stable-keyring.gpg" \
        "/etc/apt/sources.list.d/protonvpn-stable.sources" \
        "Types: deb
URIs: https://repo.protonvpn.com/debian
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/protonvpn-stable-keyring.gpg"
}

# ── Antigravity Desktop ───────────────────────────────────────────────────────

_setup_repo_antigravity() {
    local keyfile="/etc/apt/keyrings/antigravity-repo-key.gpg"
    local listfile="/etc/apt/sources.list.d/antigravity.list"
    if [[ -f "$listfile" ]]; then
        print_info "Antigravity: repo already exists — skipping"; return 0
    fi

    # Keep setup deterministic and safe: only generate source file if key exists.
    # If key is missing, leave clear manual instructions rather than guessing key URL.
    if [[ ! -f "$keyfile" ]]; then
        print_warn "Antigravity: key not found at ${keyfile}"
        print_info "Create key file first, then rerun setup:"
        print_info "  sudo install -d -m 0755 /etc/apt/keyrings"
        print_info "  sudo tee ${listfile} >/dev/null <<'EOF'"
        print_info "  deb [arch=amd64 signed-by=${keyfile}] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main"
        print_info "  EOF"
        return 1
    fi

    print_step "Add Antigravity repo"
    echo "deb [arch=amd64 signed-by=${keyfile}] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
        sudo tee "$listfile" >> "${LOG_FILE:-/dev/null}"
    print_ok; record_ok
}

# ── Grub Customizer PPA ───────────────────────────────────────────────────────

_setup_repo_grub_customizer_ppa() {
    local listfile
    listfile=$(ls /etc/apt/sources.list.d/danielrichter2007* 2>/dev/null | head -1)
    if [[ -n "$listfile" ]]; then
        print_info "Grub Customizer PPA: already configured — skipping"; return 0
    fi
    print_step "Add Grub Customizer PPA"
    if sudo add-apt-repository -y ppa:danielrichter2007/grub-customizer >> "${LOG_FILE:-/dev/null}" 2>&1; then
        print_ok; record_ok
    else
        print_warn "PPA add failed (may not be available for this Ubuntu version)"
        record_warn
    fi
}

# ── Devolutions (Remote Desktop Manager) ─────────────────────────────────────
# RDM is distributed as .deb download only — no public apt repo.
# setup.sh handles this separately with a manual download prompt.

_setup_repo_devolutions() {
    print_info "Remote Desktop Manager: no public apt repo — download from:"
    print_info "  https://devolutions.net/remote-desktop-manager/home/linuxdownload"
    print_info "  sudo dpkg -i remotedesktopmanager_amd64.deb && sudo apt-get install -f"
}
