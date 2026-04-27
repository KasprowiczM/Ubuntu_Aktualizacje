#!/usr/bin/env bash
# =============================================================================
# scripts/restore-from-proton.sh — Restore private overlay through dev-sync
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

DRY_RUN=0
VERBOSE=0
SKIP_PREFLIGHT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --verbose) VERBOSE=1 ;;
        --skip-preflight) SKIP_PREFLIGHT=1 ;;
        -h|--help)
            cat <<'EOF'
Usage: bash scripts/restore-from-proton.sh [--dry-run] [--verbose] [--skip-preflight]

Restores only Git-ignored private overlay files through dev-sync. Git-tracked
files remain authoritative from GitHub and are not restored from Proton/rclone.
EOF
            exit 0 ;;
        *) print_error "Unknown argument: $1"; exit 2 ;;
    esac
    shift
done

print_header "Restore From Proton/dev-sync"
acquire_project_lock "restore-from-proton"

if [[ ! -f "${SCRIPT_DIR}/.dev_sync_config.json" ]]; then
    print_warn "Missing .dev_sync_config.json"
    print_info "Run: bash dev-sync/provider_setup.sh"
    exit 2
fi

if [[ $SKIP_PREFLIGHT -eq 0 ]]; then
    preflight_args=()
    [[ $VERBOSE -eq 1 ]] && preflight_args+=(--verbose)
    bash "${SCRIPT_DIR}/dev-sync-restore-preflight.sh" "${preflight_args[@]}"
fi

args=()
[[ $DRY_RUN -eq 1 ]] && args+=(--dry-run)
[[ $VERBOSE -eq 1 ]] && args+=(--verbose)

bash "${SCRIPT_DIR}/dev-sync-import.sh" "${args[@]}"

if [[ $DRY_RUN -eq 0 ]]; then
    verify_args=()
    [[ $VERBOSE -eq 1 ]] && verify_args+=(--verbose)
    bash "${SCRIPT_DIR}/dev-sync-verify-full.sh" "${verify_args[@]}"
fi
