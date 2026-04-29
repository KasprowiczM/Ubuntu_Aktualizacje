#!/usr/bin/env bash
# =============================================================================
# lib/plugins.sh — Discover plugin manifests under plugins/<name>/manifest.toml
#
# Each plugin must provide:
#   plugins/<id>/manifest.toml      with: id, display_name, privilege, risk,
#                                          phases (subset of canonical 5)
#   plugins/<id>/<phase>.sh         executable, follows lib/json.sh contract
#
# `plugins_list_ids` prints one id per line.
# `plugins_phase_script <id> <phase>` echoes script path or returns 1.
# `plugins_validate <id>` exits 0 if manifest passes minimal checks.
# =============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PLUGINS_DIR="${SCRIPT_DIR}/plugins"

plugins_list_ids() {
    [[ ! -d "$PLUGINS_DIR" ]] && return 0
    local d
    for d in "$PLUGINS_DIR"/*/; do
        [[ -f "${d}manifest.toml" ]] || continue
        basename "${d%/}"
    done
}

plugins_phase_script() {
    local id="$1" phase="$2"
    local script="${PLUGINS_DIR}/${id}/${phase}.sh"
    [[ -f "$script" ]] || return 1
    echo "$script"
}

plugins_validate() {
    local id="$1"
    local manifest="${PLUGINS_DIR}/${id}/manifest.toml"
    [[ -f "$manifest" ]] || { echo "missing manifest: ${manifest}" >&2; return 1; }
    if ! python3 - "$manifest" <<'PY'
import sys, tomllib
p = sys.argv[1]
try:
    d = tomllib.loads(open(p, encoding='utf-8').read())
except Exception as exc:
    print(f"invalid toml: {exc}", file=sys.stderr); sys.exit(1)
required = ["id", "display_name", "privilege", "risk", "phases"]
for k in required:
    if k not in d:
        print(f"missing key: {k}", file=sys.stderr); sys.exit(1)
PY
    then
        return 1
    fi
    return 0
}
