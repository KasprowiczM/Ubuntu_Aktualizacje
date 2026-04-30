#!/usr/bin/env bash
# =============================================================================
# lib/host_profile.sh — Per-host overlay for config/*.list files.
#
# Layout (all optional):
#   config/host-profiles/<hostname>/apt-packages.list
#   config/host-profiles/<hostname>/snap-packages.list
#   ...
#
# When present, host-profile entries are MERGED with the base list:
#   - lines starting with "-" remove a base entry (e.g. "-megasync")
#   - other lines append (deduplicated)
#
# Usage from phase scripts:
#   source lib/host_profile.sh
#   host_profile_resolve apt-packages.list   # prints effective list to stdout
#
# Falls through to the base list when no overlay exists.
# =============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HOST_PROFILES_DIR="${SCRIPT_DIR}/config/host-profiles"

host_profile_dir() {
    local h="${HOSTNAME:-$(hostname)}"
    echo "${HOST_PROFILES_DIR}/${h}"
}

host_profile_has_overlay() {
    local list="$1"
    [[ -f "$(host_profile_dir)/${list}" ]]
}

# Resolve effective list contents:
#   - reads <repo>/config/<list>
#   - applies overlay from <repo>/config/host-profiles/<host>/<list> if any
#   - prints result (one entry per line, comments stripped)
host_profile_resolve() {
    local list="$1"
    local base="${SCRIPT_DIR}/config/${list}"
    local overlay; overlay="$(host_profile_dir)/${list}"

    python3 - "$base" "$overlay" <<'PY'
import sys
from pathlib import Path

base_p, ov_p = sys.argv[1], sys.argv[2]

def load(path):
    p = Path(path)
    if not p.exists():
        return []
    out = []
    for line in p.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        # Strip inline comments
        s = s.split("#", 1)[0].strip()
        if s:
            out.append(s.split()[0])
    return out

base = load(base_p)
overlay = load(ov_p) if Path(ov_p).exists() else []

remove = {x[1:] for x in overlay if x.startswith("-")}
add    = [x for x in overlay if not x.startswith("-")]

seen = set()
result = []
for x in base + add:
    if x in remove:
        continue
    if x in seen:
        continue
    seen.add(x)
    result.append(x)

for x in result:
    print(x)
PY
}

host_profile_describe() {
    local d; d=$(host_profile_dir)
    if [[ -d "$d" ]]; then
        echo "Host overlay: ${d}"
        local f
        for f in "$d"/*.list; do
            [[ -f "$f" ]] || continue
            echo "  $(basename "$f"): $(grep -cvE '^[[:space:]]*(#|$)' "$f") entries"
        done
    else
        echo "No host overlay (would be at: ${d})"
    fi
}
