#!/usr/bin/env bash
# scripts/drivers/cleanup.sh — Optional cleanup of obsolete kernel images.
# Defensive: only runs autoremove on linux-image-* with the running kernel
# explicitly preserved.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init cleanup drivers
json_register_exit_trap "${JSON_OUT:-}"

if ! has_cmd apt-get; then
    json_add_diag info CLEANUP-NO-APT "apt not available"
    exit 0
fi

require_sudo

running=$(uname -r)
json_add_diag info DRIVERS-CLEANUP-KERNEL "preserving running kernel ${running}"

# Don't run autoremove here — apt:cleanup already handles general autoremove.
# Just report obsolete kernel images that could be cleaned.
obsolete=$(dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/{print $2}' | grep -v "$(uname -r)" | head -5 || true)
if [[ -n "$obsolete" ]]; then
    n=$(echo "$obsolete" | wc -l | awk '{print $1}')
    json_add_diag info DRIVERS-OBSOLETE-KERNELS "${n} obsolete kernel image(s) candidate for removal"
    json_add_advisory "Cleanup runs in apt:cleanup; older kernels removed via autoremove"
fi

exit 0
