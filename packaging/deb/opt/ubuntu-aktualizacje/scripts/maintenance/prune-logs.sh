#!/usr/bin/env bash
# =============================================================================
# scripts/maintenance/prune-logs.sh — Bound logs/runs/ growth.
#
# Policy: keep at least N most-recent run directories AND every run from the
# last D days, whichever yields the larger set.  Plain `logs/*.log` files
# follow the same date cutoff.
#
# Defaults: keep last 50 runs OR last 30 days.
#
# Usage:
#   bash scripts/maintenance/prune-logs.sh             # apply defaults
#   bash scripts/maintenance/prune-logs.sh --keep 100 --days 60
#   bash scripts/maintenance/prune-logs.sh --dry-run
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS_RUNS="${SCRIPT_DIR}/logs/runs"
LOGS_DIR="${SCRIPT_DIR}/logs"

KEEP=50
DAYS=30
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep)    shift; KEEP="$1" ;;
        --days)    shift; DAYS="$1" ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) sed -n '4,16p' "$0"; exit 0 ;;
        *) echo "unknown: $1" >&2; exit 2 ;;
    esac
    shift
done

[[ -d "$LOGS_RUNS" ]] || { echo "no logs/runs directory — nothing to prune"; exit 0; }

mapfile -t ALL_RUNS < <(ls -1dt "${LOGS_RUNS}"/*/ 2>/dev/null | sed 's:/*$::')
KEEP_SET=()
for ((i=0; i < ${#ALL_RUNS[@]} && i < KEEP; i++)); do
    KEEP_SET+=("${ALL_RUNS[$i]}")
done

CUTOFF_TS=$(date -d "${DAYS} days ago" +%s 2>/dev/null || echo 0)
for d in "${ALL_RUNS[@]}"; do
    mtime=$(stat -c %Y "$d" 2>/dev/null || echo 0)
    if (( mtime >= CUTOFF_TS )); then
        case " ${KEEP_SET[*]} " in *" $d "*) ;; *) KEEP_SET+=("$d") ;; esac
    fi
done

removed=0
kept=0
for d in "${ALL_RUNS[@]}"; do
    case " ${KEEP_SET[*]} " in
        *" $d "*)
            kept=$((kept+1)) ;;
        *)
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "would remove $d"
            else
                rm -rf -- "$d"
            fi
            removed=$((removed+1)) ;;
    esac
done

old_master=()
mapfile -t old_master < <(find "$LOGS_DIR" -maxdepth 1 -name 'update_*.log' -type f -mtime +${DAYS} 2>/dev/null || true)
for f in "${old_master[@]}"; do
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "would remove $f"
    else
        rm -f -- "$f"
    fi
    removed=$((removed+1))
done

echo "prune-logs: kept=${kept}, removed=${removed} (keep=${KEEP}, days=${DAYS}, dry_run=${DRY_RUN})"
