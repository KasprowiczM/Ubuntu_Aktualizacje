#!/usr/bin/env bash
# =============================================================================
# lib/detect.sh — System detection & scanning library
#
# Provides functions to detect OS, hardware, package managers, and
# enumerate currently installed packages across all managers.
#
# Usage: source lib/detect.sh
# =============================================================================

# ── OS Detection ──────────────────────────────────────────────────────────────

detect_os() {
    OS_ID=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    OS_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    OS_PRETTY=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    KERNEL_VER=$(uname -r)
    ARCH=$(uname -m)
    export OS_ID OS_VERSION OS_CODENAME OS_PRETTY KERNEL_VER ARCH
}

assert_ubuntu() {
    detect_os
    if [[ "$OS_ID" != "ubuntu" ]]; then
        print_error "This script requires Ubuntu. Found: ${OS_ID}"
        exit 1
    fi
    if [[ "$OS_VERSION" != "24.04" ]]; then
        print_warn "Designed for Ubuntu 24.04, running on ${OS_VERSION}. Proceeding..."
    fi
}

# ── Hardware Detection ────────────────────────────────────────────────────────

detect_hardware() {
    HW_VENDOR=$(sudo dmidecode -s system-manufacturer 2>/dev/null | tr -d '\n' || echo "Unknown")
    HW_MODEL=$(sudo dmidecode -s system-product-name 2>/dev/null | tr -d '\n' || echo "Unknown")
    HW_CHASSIS=$(hostnamectl 2>/dev/null | grep "Chassis" | awk '{print $NF}' || echo "unknown")
    CPU_MODEL=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | sed 's/.*: //' || echo "Unknown")
    RAM_GB=$(awk '/MemTotal/{printf "%.0f", $2/1048576}' /proc/meminfo 2>/dev/null || echo "?")
    export HW_VENDOR HW_MODEL HW_CHASSIS CPU_MODEL RAM_GB
}

# ── GPU / Driver Detection ────────────────────────────────────────────────────

detect_gpu() {
    GPU_INFO=$(lspci 2>/dev/null | grep -iE "(vga|3d|display)" || echo "Unknown")
    HAS_NVIDIA=0
    HAS_AMD=0
    HAS_INTEL_GPU=0

    if echo "$GPU_INFO" | grep -qi nvidia;   then HAS_NVIDIA=1; fi
    if echo "$GPU_INFO" | grep -qi "amd\|radeon\|amdgpu"; then HAS_AMD=1; fi
    if echo "$GPU_INFO" | grep -qi "intel";  then HAS_INTEL_GPU=1; fi

    NVIDIA_DRIVER_VER=$(dpkg -l 'nvidia-driver-*' 2>/dev/null | awk '/^ii/{print $2}' | head -1 | grep -oP '\d+' | head -1 || echo "")
    export GPU_INFO HAS_NVIDIA HAS_AMD HAS_INTEL_GPU NVIDIA_DRIVER_VER
}

# ── Package Manager Detection ─────────────────────────────────────────────────

detect_package_managers() {
    HAS_APT=0;  has_cmd apt-get   && HAS_APT=1
    HAS_SNAP=0; has_cmd snap      && HAS_SNAP=1
    HAS_BREW=0
    HAS_FLATPAK=0; has_cmd flatpak && HAS_FLATPAK=1
    HAS_CARGO=0;   has_cmd cargo   && HAS_CARGO=1
    HAS_PIPX=0;    has_cmd pipx    && HAS_PIPX=1

    # Homebrew may not be in PATH yet — check known locations
    for brew_candidate in \
        "${HOMEBREW_PREFIX:-}/bin/brew" \
        "/home/linuxbrew/.linuxbrew/bin/brew" \
        "/usr/local/bin/brew"; do
        if [[ -x "$brew_candidate" ]]; then
            HAS_BREW=1
            BREW_BIN="$brew_candidate"
            BREW_PREFIX=$(dirname "$(dirname "$brew_candidate")")
            eval "$("$brew_candidate" shellenv 2>/dev/null)" || true
            break
        fi
    done

    # npm: prefer brew npm over system apt npm
    NPM_BIN=""
    if [[ -n "${BREW_BIN:-}" ]]; then
        candidate="$(dirname "$BREW_BIN")/npm"
        [[ -x "$candidate" ]] && NPM_BIN="$candidate"
    fi
    [[ -z "$NPM_BIN" ]] && has_cmd npm && NPM_BIN="$(command -v npm)"

    export HAS_APT HAS_SNAP HAS_BREW HAS_FLATPAK HAS_CARGO HAS_PIPX
    export BREW_BIN BREW_PREFIX NPM_BIN
}

# ── APT Scanning ──────────────────────────────────────────────────────────────

# Returns manually-installed apt packages (non-automatic)
scan_apt_manual() {
    apt-mark showmanual 2>/dev/null | sort
}

# Returns packages from external/third-party repos (not ubuntu/debian stock)
scan_apt_external() {
    # Packages that have no standard ubuntu candidate → came from external sources
    comm -13 \
        <(apt-cache pkgnames 2>/dev/null | sort) \
        <(dpkg -l 2>/dev/null | awk '/^ii/{print $2}' | sed 's/:amd64//' | sort) \
        2>/dev/null || true
}

# Returns version of an installed apt package (empty if not installed)
apt_pkg_version() {
    dpkg -l "$1" 2>/dev/null | awk '/^ii/{print $3}' | head -1
}

# Returns true if apt package is installed
apt_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q '^ii'
}

# Returns list of ALL externally-managed packages with their source repo
scan_apt_with_sources() {
    dpkg -l 2>/dev/null | awk '/^ii/{print $2}' | while read -r pkg; do
        src=$(apt-cache policy "$pkg" 2>/dev/null | grep '^\s*\*\*\*' -A1 | tail -1 | awk '{print $2, $3}' || echo "")
        echo "${pkg}|${src}"
    done
}

# ── Snap Scanning ─────────────────────────────────────────────────────────────

scan_snaps_user() {
    # Returns user-visible snaps (excludes base/runtime snaps)
    snap list 2>/dev/null | tail -n +2 | while read -r name ver rev chan pub notes; do
        case "$name" in
            bare|core|core[0-9]*|gnome-[0-9]*|gtk-common*|kf5-*|mesa-*|snapd|snapd-*) continue ;;
        esac
        echo "${name}|${ver}|${rev}|${chan}|${pub}"
    done
}

scan_snaps_all() {
    snap list 2>/dev/null | tail -n +2 | while read -r name ver rev chan pub notes; do
        echo "${name}|${ver}|${rev}|${chan}|${pub}"
    done
}

snap_installed() {
    snap list "$1" &>/dev/null
}

snap_version() {
    snap list "$1" 2>/dev/null | awk 'NR==2{print $2}'
}

# ── Homebrew Scanning ─────────────────────────────────────────────────────────

scan_brew_formulas() {
    [[ -z "${BREW_BIN:-}" ]] && return
    "${BREW_BIN}" list --formula --versions 2>/dev/null
}

scan_brew_casks() {
    [[ -z "${BREW_BIN:-}" ]] && return
    "${BREW_BIN}" list --cask 2>/dev/null | while read -r cask; do
        ver=$(ls "${BREW_PREFIX}/Caskroom/${cask}/" 2>/dev/null | sort -V | tail -1)
        echo "${cask}|${ver}"
    done
}

brew_formula_installed() {
    [[ -z "${BREW_BIN:-}" ]] && return 1
    "${BREW_BIN}" list --formula "$1" &>/dev/null
}

brew_cask_installed() {
    [[ -z "${BREW_BIN:-}" ]] && return 1
    "${BREW_BIN}" list --cask "$1" &>/dev/null
}

brew_formula_version() {
    [[ -z "${BREW_BIN:-}" ]] && return
    "${BREW_BIN}" list --versions "$1" 2>/dev/null | awk '{print $2}'
}

brew_cask_version() {
    [[ -z "${BREW_BIN:-}" ]] && return
    ls "${BREW_PREFIX}/Caskroom/$1/" 2>/dev/null | sort -V | tail -1
}

# ── npm Scanning ──────────────────────────────────────────────────────────────

scan_npm_globals() {
    [[ -z "${NPM_BIN:-}" ]] && return
    "${NPM_BIN}" list -g --depth=0 --json 2>/dev/null | \
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    deps = data.get('dependencies', {})
    for name, info in sorted(deps.items()):
        print(f\"{name}|{info.get('version','?')}\")
except: pass
" 2>/dev/null || \
    "${NPM_BIN}" list -g --depth=0 2>/dev/null | tail -n +2 | \
        sed 's/[├└─ ]*//' | awk '{print $1}' | \
        awk -F@ '{name=$0; ver=$NF; sub(/@[^@]*$/,"",name); print name "|" ver}'
}

npm_pkg_installed() {
    [[ -z "${NPM_BIN:-}" ]] && return 1
    "${NPM_BIN}" list -g --depth=0 "$1" 2>/dev/null | grep -q "$1"
}

npm_pkg_version() {
    [[ -z "${NPM_BIN:-}" ]] && return
    "${NPM_BIN}" list -g --depth=0 "$1" 2>/dev/null | grep "$1" | \
        grep -oP '[\d]+\.[\d]+\.[\d]+.*' | head -1
}

# ── Flatpak Scanning ──────────────────────────────────────────────────────────

scan_flatpaks() {
    has_cmd flatpak || return
    flatpak list --app --columns=name,application,version,branch 2>/dev/null
}

# ── Config File Parsing ───────────────────────────────────────────────────────

# Parse a .list config file → prints non-comment, non-empty lines
# First word only (strips inline comments and flags)
parse_config_names() {
    local file="$1"
    [[ ! -f "$file" ]] && return
    grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' | awk '{print $1}'
}

# Parse a .list config file → prints full line (preserving flags)
parse_config_lines() {
    local file="$1"
    [[ ! -f "$file" ]] && return
    grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' | sed 's/#.*//' | awk '{$1=$1};1'
}

# ── /opt & Manual Installs Scanning ──────────────────────────────────────────

scan_opt_apps() {
    [[ ! -d /opt ]] && return
    find /opt -maxdepth 2 -name "*.sh" -o -name "*.AppImage" -o -type f -executable 2>/dev/null | \
        grep -v "\.so" | head -20
    ls /opt/ 2>/dev/null | while read -r d; do
        [[ -d "/opt/$d" ]] && echo "/opt/$d"
    done
}

# ── Docker Detection ──────────────────────────────────────────────────────────

detect_docker() {
    HAS_DOCKER=0
    DOCKER_VER=""
    if has_cmd docker; then
        HAS_DOCKER=1
        DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1)
    fi
    export HAS_DOCKER DOCKER_VER
}

# ── Firmware Detection ────────────────────────────────────────────────────────

scan_firmware_devices() {
    has_cmd fwupdmgr || return
    fwupdmgr get-devices 2>/dev/null | awk '
        /[├└]─/ { dev=$0; gsub(/^[│├└─ ]+/,"",dev); gsub(/:$/,"",dev) }
        /Current version:/ { print dev "|" $NF }
    ' | grep -v "^|" | head -20
}

firmware_updates_available() {
    has_cmd fwupdmgr || return 1
    fwupdmgr get-updates 2>/dev/null | grep -qiE "upgrade|update" && return 0 || return 1
}
