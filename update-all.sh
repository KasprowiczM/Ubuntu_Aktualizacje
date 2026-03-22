#!/usr/bin/env bash
# =============================================================================
# update-all.sh — Master update script
#
# Runs all sub-scripts in order:
#   1. APT (OS + all apt-managed apps)
#   2. Snap packages
#   3. Homebrew (formulas + casks)
#   4. npm globals (via brew node)
#   5. Drivers & Firmware
#   6. Regenerate APPS.md inventory
#
# Usage:
#   ./update-all.sh              # Full update
#   ./update-all.sh --no-drivers # Skip driver/firmware updates
#   ./update-all.sh --dry-run    # Show what would run, don't execute
#   ./update-all.sh --only apt   # Run only a specific group
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# ── Parse arguments ───────────────────────────────────────────────────────────
NO_DRIVERS=0
DRY_RUN=0
ONLY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-drivers)   NO_DRIVERS=1 ;;
        --dry-run)      DRY_RUN=1 ;;
        --only)         shift; ONLY="$1" ;;
        -h|--help)
            echo "Usage: $0 [--no-drivers] [--dry-run] [--only <apt|snap|brew|npm|drivers>]"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# ── Shared log for the master run ─────────────────────────────────────────────
MASTER_LOG="${LOG_DIR}/master_${TIMESTAMP}.log"
LOG_FILE="${MASTER_LOG}"
export LOG_FILE

START_TIME=$(date +%s)

print_header "Ubuntu System Update — $(date '+%Y-%m-%d %H:%M:%S')"
print_info "Host   : $(hostname)"
print_info "OS     : $(lsb_release -ds 2>/dev/null)"
print_info "Kernel : $(uname -r)"
print_info "Log    : ${MASTER_LOG}"
[[ $DRY_RUN -eq 1 ]] && print_warn "DRY RUN MODE — scripts will not actually run"
echo

# ── Script runner ─────────────────────────────────────────────────────────────
STEP=0
STEPS_OK=0
STEPS_FAIL=0
declare -A STEP_STATUS

run_script() {
    local name="$1"
    local script="${SCRIPT_DIR}/scripts/$2"
    local skip_cond="${3:-0}"

    STEP=$((STEP + 1))

    if [[ -n "$ONLY" && "$name" != "$ONLY" ]]; then
        echo -e "${DIM}  [${STEP}] ${name} — skipped (--only ${ONLY})${RESET}"
        return
    fi

    if [[ "$skip_cond" == "1" ]]; then
        echo -e "${DIM}  [${STEP}] ${name} — skipped${RESET}"
        STEP_STATUS[$name]="SKIPPED"
        return
    fi

    echo -e "\n${BOLD}${BLUE}╔══ [${STEP}] ${name} ══${RESET}"

    if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "${DIM}     Would run: ${script}${RESET}"
        STEP_STATUS[$name]="DRY-RUN"
        return
    fi

    if [[ ! -f "$script" ]]; then
        print_error "Script not found: ${script}"
        STEP_STATUS[$name]="MISSING"
        STEPS_FAIL=$((STEPS_FAIL + 1))
        return
    fi

    local step_start; step_start=$(date +%s)

    # Run the sub-script; it sources common.sh and writes to the shared LOG_FILE
    if bash "$script"; then
        local step_end; step_end=$(date +%s)
        local elapsed=$(( step_end - step_start ))
        echo -e "${BOLD}${BLUE}╚══ ${name} done in ${elapsed}s ══${RESET}"
        STEP_STATUS[$name]="OK"
        STEPS_OK=$((STEPS_OK + 1))
    else
        local step_end; step_end=$(date +%s)
        local elapsed=$(( step_end - step_start ))
        echo -e "${BOLD}${RED}╚══ ${name} FAILED after ${elapsed}s ══${RESET}"
        STEP_STATUS[$name]="FAILED"
        STEPS_FAIL=$((STEPS_FAIL + 1))
    fi
}

# ── Authenticate sudo upfront (avoid mid-run password prompts) ─────────────────
if [[ $DRY_RUN -eq 0 ]]; then
    echo -e "${YELLOW}  Authenticating sudo (needed for APT/drivers)...${RESET}"
    sudo -v || { echo -e "${RED}  sudo failed — aborting${RESET}"; exit 1; }
    # Keep sudo alive for the duration
    (while true; do sudo -n true; sleep 50; done) &
    SUDO_KEEP_PID=$!
    trap 'kill ${SUDO_KEEP_PID} 2>/dev/null; exit' INT TERM EXIT
fi

# ── Run scripts in order ───────────────────────────────────────────────────────
run_script "apt"     "update-apt.sh"
run_script "snap"    "update-snap.sh"
run_script "brew"    "update-brew.sh"
run_script "npm"     "update-npm.sh"
run_script "drivers" "update-drivers.sh" "${NO_DRIVERS}"
run_script "inventory" "update-inventory.sh"

# ── Final summary ─────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))
TOTAL_MINS=$(( TOTAL_TIME / 60 ))
TOTAL_SECS=$(( TOTAL_TIME % 60 ))

echo
echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${BLUE}  COMPLETE — ${TOTAL_MINS}m ${TOTAL_SECS}s${RESET}"
echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════${RESET}"
echo

for name in "${!STEP_STATUS[@]}"; do
    status="${STEP_STATUS[$name]}"
    case "$status" in
        OK)      echo -e "  ${GREEN}✔${RESET}  ${name}" ;;
        FAILED)  echo -e "  ${RED}✘${RESET}  ${name}" ;;
        SKIPPED) echo -e "  ${DIM}⊘${RESET}  ${name} (skipped)" ;;
        DRY-RUN) echo -e "  ${DIM}○${RESET}  ${name} (dry-run)" ;;
        MISSING) echo -e "  ${RED}?${RESET}  ${name} (script missing)" ;;
    esac
done

echo
echo -e "  ${DIM}Log: ${MASTER_LOG}${RESET}"
echo

# Reboot notice
if [[ -f /var/run/reboot-required ]]; then
    echo -e "${YELLOW}  ⚠  REBOOT REQUIRED — run: sudo reboot${RESET}"
    echo
fi

[[ $STEPS_FAIL -gt 0 ]] && exit 1 || exit 0
