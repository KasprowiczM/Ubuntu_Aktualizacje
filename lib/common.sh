#!/usr/bin/env bash
# =============================================================================
# lib/common.sh — Shared library: colors, logging, status helpers
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Log file setup ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/update_${TIMESTAMP}.log}"

mkdir -p "${LOG_DIR}"

# ── Internal log (both file and screen) ───────────────────────────────────────
_log_raw() {
    local level="$1"; shift
    local msg="$*"
    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "${ts}  [${level}]  ${msg}" >> "${LOG_FILE}"
}

# ── Public print helpers ───────────────────────────────────────────────────────
print_header() {
    local title="$1"
    local line; line="$(printf '═%.0s' $(seq 1 60))"
    echo
    echo -e "${BOLD}${BLUE}${line}${RESET}"
    echo -e "${BOLD}${BLUE}  ${title}${RESET}"
    echo -e "${BOLD}${BLUE}${line}${RESET}"
    echo
    _log_raw "INFO" "======== ${title} ========"
}

print_section() {
    local title="$1"
    echo
    echo -e "${BOLD}${CYAN}── ${title} ──────────────────────────────${RESET}"
    _log_raw "INFO" "--- ${title} ---"
}

print_step() {
    # Usage: print_step "Updating APT package list"
    echo -ne "  ${DIM}▶${RESET}  $* ... "
    _log_raw "STEP" "$*"
}

print_ok() {
    echo -e "${GREEN}✔${RESET}"
    _log_raw "OK  " "${1:-done}"
}

print_warn() {
    echo -e "${YELLOW}⚠  $*${RESET}"
    _log_raw "WARN" "$*"
}

print_error() {
    echo -e "${RED}✘  $*${RESET}"
    _log_raw "ERR " "$*"
}

print_info() {
    echo -e "     ${DIM}$*${RESET}"
    _log_raw "INFO" "$*"
}

print_skipped() {
    echo -e "${DIM}⊘  (skipped)${RESET}"
    _log_raw "SKIP" "${1:-skipped}"
}

print_result() {
    # Usage: print_result $? "optional context"
    if [[ "$1" -eq 0 ]]; then
        print_ok "${2:-}"
    else
        print_error "failed (exit $1) ${2:-}"
    fi
}

# ── Run a command silently, capture output to log ─────────────────────────────
# Returns the command's exit code.
run_silent() {
    local cmd=("$@")
    _log_raw "RUN " "${cmd[*]}"
    local output
    output=$("${cmd[@]}" 2>&1)
    local rc=$?
    if [[ -n "${output}" ]]; then
        echo "${output}" >> "${LOG_FILE}"
    fi
    return $rc
}

# ── Run with sudo silently ─────────────────────────────────────────────────────
sudo_silent() {
    run_silent sudo "$@"
}

# ── Run a command as the invoking (non-root) user ─────────────────────────────
# When the master script is run via "sudo ./update-all.sh", sub-scripts inherit
# EUID=0.  Tools like brew and npm refuse to run as root, so we drop back to
# SUDO_USER for those commands.  Falls through to a normal run when not root.
REAL_USER="${SUDO_USER:-${USER}}"
_real_user_home() { getent passwd "${REAL_USER}" | cut -d: -f6; }

run_as_user() {
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
        sudo -u "${SUDO_USER}" HOME="$(_real_user_home)" "$@"
    else
        "$@"
    fi
}

run_silent_as_user() {
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
        run_silent sudo -u "${SUDO_USER}" HOME="$(_real_user_home)" "$@"
    else
        run_silent "$@"
    fi
}

# ── Require root or sudo ───────────────────────────────────────────────────────
require_sudo() {
    if [[ $EUID -eq 0 ]]; then return 0; fi
    if [[ "${UPDATE_ALL_SUDO_READY:-0}" == "1" ]]; then
        sudo -n true 2>/dev/null || { print_error "sudo session not available"; exit 1; }
        return 0
    fi
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}  Sudo password required for privileged operations:${RESET}"
        sudo -v || { print_error "sudo authentication failed"; exit 1; }
    fi
    # Keep sudo alive during the script
    (while true; do sudo -n true; sleep 50; done) &
    SUDO_KEEP_ALIVE_PID=$!
    trap 'kill ${SUDO_KEEP_ALIVE_PID} 2>/dev/null' EXIT
}

# ── Check if a command exists ─────────────────────────────────────────────────
has_cmd() { command -v "$1" &>/dev/null; }

# ── Summary counters ──────────────────────────────────────────────────────────
SUMMARY_OK=0
SUMMARY_WARN=0
SUMMARY_ERR=0

record_ok()   { SUMMARY_OK=$((SUMMARY_OK + 1));     }
record_warn() { SUMMARY_WARN=$((SUMMARY_WARN + 1)); }
record_err()  { SUMMARY_ERR=$((SUMMARY_ERR + 1));   }

print_summary() {
    local title="${1:-Update Summary}"
    echo
    echo -e "${BOLD}${BLUE}── ${title} ───────────────────────────────${RESET}"
    echo -e "  ${GREEN}✔  OK      : ${SUMMARY_OK}${RESET}"
    [[ $SUMMARY_WARN -gt 0 ]] && echo -e "  ${YELLOW}⚠  Warnings: ${SUMMARY_WARN}${RESET}"
    [[ $SUMMARY_ERR  -gt 0 ]] && echo -e "  ${RED}✘  Errors  : ${SUMMARY_ERR}${RESET}"
    echo -e "  ${DIM}Log       : ${LOG_FILE}${RESET}"
    echo
    _log_raw "INFO" "Summary: OK=${SUMMARY_OK} WARN=${SUMMARY_WARN} ERR=${SUMMARY_ERR}"
}
