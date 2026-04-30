#!/usr/bin/env bash
# =============================================================================
# scripts/scheduler/should-run.sh — Pre-flight gate for scheduled runs.
#
# Returns 0 (proceed) or 75 (skip — try again next tick).
# Reasons we may skip:
#   • on battery and battery low                    (UA_REQUIRE_AC=1)
#   • a fullscreen application is active            (UA_RESPECT_FOCUS=1)
#   • outside maintenance window (HH:MM-HH:MM)      (UA_MAINTENANCE_WINDOW)
#   • another updater (apt/snap) is running         (always)
#
# Wire in systemd:
#   ExecStartPre=-${ROOT}/scripts/scheduler/should-run.sh
#
# Each guard is opt-in via env so this file is safe-by-default for all hosts.
# =============================================================================
set -uo pipefail

skip() { echo "$*" >&2; exit 75; }

# 1. Apt/snap currently running? Defer.
if pgrep -x apt-get >/dev/null 2>&1 || pgrep -x dpkg >/dev/null 2>&1; then
    skip "scheduler: apt/dpkg busy — deferring"
fi
if pgrep -x snap >/dev/null 2>&1 && pgrep -f "snap (refresh|install)" >/dev/null 2>&1; then
    skip "scheduler: snap busy — deferring"
fi

# 2. Battery / AC.
if [[ "${UA_REQUIRE_AC:-0}" == "1" ]]; then
    if [[ -f /sys/class/power_supply/AC/online ]]; then
        ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 1)
        [[ "$ac" == "0" ]] && skip "scheduler: on battery — deferring"
    elif [[ -f /sys/class/power_supply/ADP1/online ]]; then
        ac=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 1)
        [[ "$ac" == "0" ]] && skip "scheduler: on battery — deferring"
    fi
    # If a battery exists and capacity < 30, defer regardless.
    for bat in /sys/class/power_supply/BAT*/capacity; do
        [[ -f "$bat" ]] || continue
        cap=$(cat "$bat" 2>/dev/null || echo 100)
        [[ "$cap" =~ ^[0-9]+$ ]] && [[ "$cap" -lt 30 ]] && skip "scheduler: battery low (${cap}%)"
    done
fi

# 3. Maintenance window (HH:MM-HH:MM, e.g. 02:00-05:00, 24h clock).
if [[ -n "${UA_MAINTENANCE_WINDOW:-}" ]]; then
    win="${UA_MAINTENANCE_WINDOW}"
    start="${win%-*}"; end="${win#*-}"
    now_h=$(date +%H); now_m=$(date +%M)
    s_h="${start%:*}"; s_m="${start#*:}"
    e_h="${end%:*}";   e_m="${end#*:}"
    now_min=$((10#$now_h * 60 + 10#$now_m))
    s_min=$((10#$s_h * 60 + 10#$s_m))
    e_min=$((10#$e_h * 60 + 10#$e_m))
    in_window=0
    if [[ $s_min -le $e_min ]]; then
        [[ $now_min -ge $s_min && $now_min -le $e_min ]] && in_window=1
    else
        # Crosses midnight (e.g. 22:00-05:00)
        [[ $now_min -ge $s_min || $now_min -le $e_min ]] && in_window=1
    fi
    [[ $in_window -eq 0 ]] && skip "scheduler: outside maintenance window ${win}"
fi

# 4. Active fullscreen app (best-effort: presence of a process named after a
#    common fullscreen video player is a rough heuristic; don't break for
#    headless servers that lack X).
if [[ "${UA_RESPECT_FOCUS:-0}" == "1" ]]; then
    if pgrep -x -- mpv vlc smplayer >/dev/null 2>&1; then
        skip "scheduler: media player active — deferring"
    fi
fi

exit 0
