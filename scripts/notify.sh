#!/usr/bin/env bash
# =============================================================================
# scripts/notify.sh — Desktop notification helper
#
# Sends a desktop notification after update-all.sh completes.
# Called automatically by the Stop hook in .claude/settings.json,
# or by update-all.sh directly.
#
# Usage: ./scripts/notify.sh [--reboot] [--errors N] [--time "1m 30s"]
# =============================================================================

REBOOT_REQUIRED=0
ERROR_COUNT=0
ELAPSED=""
TITLE="Ubuntu Updates"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --reboot)  REBOOT_REQUIRED=1 ;;
        --errors)  shift; ERROR_COUNT="$1" ;;
        --time)    shift; ELAPSED="$1" ;;
        --title)   shift; TITLE="$1" ;;
    esac
    shift
done

# ── Compose message ───────────────────────────────────────────────────────────
if [[ $REBOOT_REQUIRED -eq 1 ]]; then
    ICON="system-restart"
    URGENCY="normal"
    MSG="System updated successfully."
    [[ -n "$ELAPSED" ]] && MSG+=" (${ELAPSED})"
    MSG+="\n\n⚠ REBOOT REQUIRED to activate new kernel/driver modules."
    TITLE="Ubuntu Updates — Reboot Required"
elif [[ "$ERROR_COUNT" -gt 0 ]]; then
    ICON="dialog-warning"
    URGENCY="normal"
    MSG="Updates completed with ${ERROR_COUNT} warning(s)."
    [[ -n "$ELAPSED" ]] && MSG+=" (${ELAPSED})"
    MSG+="\nCheck logs for details."
else
    ICON="software-update-available"
    URGENCY="low"
    MSG="All packages updated successfully."
    [[ -n "$ELAPSED" ]] && MSG+=" (${ELAPSED})"
fi

# ── Send notification ─────────────────────────────────────────────────────────
# Try multiple notification methods for compatibility

if command -v notify-send &>/dev/null; then
    # GNOME/GTK desktop notification
    notify-send \
        --urgency="$URGENCY" \
        --icon="$ICON" \
        --app-name="Ubuntu_Aktualizacje" \
        --expire-time=10000 \
        "$TITLE" \
        "$MSG" 2>/dev/null || true

elif command -v zenity &>/dev/null && [[ -n "${DISPLAY:-}" ]]; then
    # Fallback: zenity dialog
    zenity --info \
        --title="$TITLE" \
        --text="$MSG" \
        --timeout=10 2>/dev/null || true

else
    # Terminal fallback
    echo ""
    echo "=== ${TITLE} ==="
    echo "$MSG" | sed 's/\\n/\n/g'
    echo ""
fi
