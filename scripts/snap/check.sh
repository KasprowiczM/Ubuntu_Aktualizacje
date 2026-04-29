#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/json.sh"

json_init check snap
json_register_exit_trap "${JSON_OUT:-}"

print_header "Snap — check"

if ! has_cmd snap; then
    json_add_diag info SNAP-MISSING "snapd not installed — category not applicable"
    exit 0
fi

CONFIG_SNAP="${SCRIPT_DIR}/config/snap-packages.list"
EXIT_RC=0

# Outdated (uses snap refresh --list which queries the store)
if mapfile -t outdated < <(_snap_cmd refresh --list 2>/dev/null | tail -n +2); then
    if [[ ${#outdated[@]} -gt 0 && -n "${outdated[0]}" ]]; then
        for line in "${outdated[@]}"; do
            [[ -z "$line" ]] && continue
            name=$(echo "$line" | awk '{print $1}')
            new=$(echo "$line" | awk '{print $2}')
            json_add_item id="snap:upgrade:${name}" action="upgrade" \
                to="${new}" result="noop"
        done
        json_add_diag info SNAP-OUTDATED "${#outdated[@]} snap(s) have updates"
    else
        json_add_diag info SNAP-CURRENT "all snaps up to date"
    fi
fi

# Disabled revisions to clean
disabled=$(snap list --all 2>/dev/null | awk '$NF ~ /disabled/ {print $1, $3}' || true)
if [[ -n "$disabled" ]]; then
    n=$(echo "$disabled" | wc -l | awk '{print $1}')
    json_add_diag info SNAP-DISABLED "${n} disabled snap revision(s) to clean"
fi

# Configured snaps installed?
if [[ -f "$CONFIG_SNAP" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        pkg=$(echo "$line" | awk '{print $1}')
        if snap_installed "$pkg"; then
            json_add_item id="snap:configured:${pkg}" action="present" \
                to="$(snap_version "$pkg")" result="ok"
            json_count_ok
        else
            json_add_item id="snap:configured:${pkg}" action="present" result="failed"
            json_add_diag warn SNAP-MISSING-CONFIG "configured snap not installed: ${pkg}"
            json_count_warn
            EXIT_RC=1
        fi
    done < <(parse_config_lines "$CONFIG_SNAP")
fi

exit $EXIT_RC
