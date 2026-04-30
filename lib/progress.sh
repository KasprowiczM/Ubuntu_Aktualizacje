#!/usr/bin/env bash
# =============================================================================
# lib/progress.sh — progress bar + per-step verbosity helpers.
#
# Why:
#   The previous output was "snap:check ok" — useless. The user couldn't see
#   what was scanned, what was found, or what's being changed. This module
#   adds a uniform vocabulary that:
#     • prints a clean text progress bar in the console
#     • emits machine-parseable markers ([progress N/M label]) the dashboard
#       SSE consumer turns into a real progress bar
#     • keeps a per-step list so end-of-phase summaries can show package-level
#       detail instead of just totals.
#
# Usage:
#   progress_start "snap refresh"  6      # total=6 steps; label="snap refresh"
#   progress_step  "core22"        ok     # status: ok|warn|err|skip
#   progress_step  "firefox 132"   ok
#   ...
#   progress_done                          # closes the bar; prints summary
#
# Markers emitted to stdout (frontend parses them):
#   PROGRESS|start|<phase>|<total>|<label>
#   PROGRESS|step|<phase>|<n>|<total>|<status>|<message>
#   PROGRESS|done|<phase>|<ok>|<warn>|<err>|<elapsed_s>
# =============================================================================

PROG_TOTAL=0
PROG_DONE=0
PROG_OK=0
PROG_WARN=0
PROG_ERR=0
PROG_LABEL=""
PROG_PHASE=""
PROG_START_TS=0
declare -a PROG_LINES=()

_prog_color() {
    case "$1" in
        ok)   printf '\033[0;32m✔\033[0m' ;;
        warn) printf '\033[1;33m⚠\033[0m' ;;
        err)  printf '\033[0;31m✘\033[0m' ;;
        skip) printf '\033[2m⊘\033[0m' ;;
        *)    printf '·' ;;
    esac
}

_prog_render_bar() {
    local n=$PROG_DONE total=$PROG_TOTAL
    [[ "$total" -le 0 ]] && return
    local width=24
    local filled=$(( n * width / total ))
    [[ $filled -gt $width ]] && filled=$width
    local bar=""
    local i
    for ((i=0; i<width; i++)); do
        if   [[ $i -lt $filled ]]; then bar+="█"
        elif [[ $i -eq $filled ]]; then bar+="▌"
        else                            bar+="░"
        fi
    done
    local pct=$(( total > 0 ? n * 100 / total : 0 ))
    printf '\r  \033[2m[%s]\033[0m %3d%% (%d/%d) %s' "$bar" "$pct" "$n" "$total" "$PROG_LABEL"
}

# progress_start <phase-id> <total> [label]
progress_start() {
    PROG_PHASE="${1:-progress}"
    PROG_TOTAL="${2:-0}"
    PROG_LABEL="${3:-${PROG_PHASE}}"
    PROG_DONE=0; PROG_OK=0; PROG_WARN=0; PROG_ERR=0
    PROG_LINES=()
    PROG_START_TS=$(date +%s)
    printf 'PROGRESS|start|%s|%s|%s\n' "$PROG_PHASE" "$PROG_TOTAL" "$PROG_LABEL"
    if [[ "$PROG_TOTAL" -gt 0 ]]; then
        _prog_render_bar
    else
        printf '  \033[2m▶\033[0m %s ... ' "$PROG_LABEL"
    fi
}

# progress_step <message> <status>
progress_step() {
    local msg="${1:-}" status="${2:-ok}"
    PROG_DONE=$(( PROG_DONE + 1 ))
    case "$status" in
        ok)   PROG_OK=$((PROG_OK + 1)) ;;
        warn) PROG_WARN=$((PROG_WARN + 1)) ;;
        err)  PROG_ERR=$((PROG_ERR + 1)) ;;
    esac
    PROG_LINES+=("${status}|${msg}")
    # Machine-parseable for the dashboard.
    printf 'PROGRESS|step|%s|%s|%s|%s|%s\n' "$PROG_PHASE" "$PROG_DONE" "$PROG_TOTAL" "$status" "$msg"
    # Human render: clear bar line, print step, redraw bar.
    if [[ "$PROG_TOTAL" -gt 0 ]]; then
        printf '\r\033[2K  %s [%d/%d] %s\n' "$(_prog_color "$status")" "$PROG_DONE" "$PROG_TOTAL" "$msg"
        _prog_render_bar
    else
        printf '\n  %s %s' "$(_prog_color "$status")" "$msg"
    fi
}

progress_done() {
    local elapsed=$(( $(date +%s) - PROG_START_TS ))
    if [[ "$PROG_TOTAL" -gt 0 ]]; then
        printf '\r\033[2K'   # clear bar line
    else
        printf '\n'
    fi
    local color=2
    [[ $PROG_WARN -gt 0 ]] && color=33
    [[ $PROG_ERR  -gt 0 ]] && color=31
    [[ $PROG_OK   -gt 0 && $PROG_WARN -eq 0 && $PROG_ERR -eq 0 ]] && color=32
    printf '  \033[1;%dm✔ %s\033[0m  \033[2m%d ok · %d warn · %d err · %ds\033[0m\n' \
        "$color" "$PROG_LABEL" "$PROG_OK" "$PROG_WARN" "$PROG_ERR" "$elapsed"
    printf 'PROGRESS|done|%s|%s|%s|%s|%s\n' "$PROG_PHASE" "$PROG_OK" "$PROG_WARN" "$PROG_ERR" "$elapsed"
}

# print_found <category> <count> <details-multiline>
# Used by check.sh scripts to make the user see *what was found*, not just "ok".
print_found() {
    local cat="$1" n="$2"; shift 2
    # Defensive: strip whitespace/newlines and default to 0 if non-numeric.
    n="${n//[[:space:]]/}"
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
    local details="$*"
    if [[ "$n" -gt 0 ]]; then
        printf '  \033[1;33m●\033[0m  Found \033[1m%d\033[0m %s update(s):\n' "$n" "$cat"
        if [[ -n "$details" ]]; then
            # Indent each line.
            while IFS= read -r ln; do
                [[ -z "$ln" ]] && continue
                printf '       \033[2m%s\033[0m\n' "$ln"
            done <<< "$details"
        fi
    else
        printf '  \033[0;32m✔\033[0m  %s — \033[2mall up to date\033[0m\n' "$cat"
    fi
}
