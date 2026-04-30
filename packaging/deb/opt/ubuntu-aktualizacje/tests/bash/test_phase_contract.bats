#!/usr/bin/env bats
# Smoke test that every check/plan phase script emits a schema-valid sidecar.
# (apply/verify/cleanup not exercised here — they need sudo or live state.)

REPO="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    cd "$REPO"
    export TMPDIR
    TMPDIR="$(mktemp -d)"
}
teardown() { rm -rf "$TMPDIR"; }

run_phase() {
    local cat="$1" phase="$2"
    local out="${TMPDIR}/${cat}-${phase}.json"
    local log="${TMPDIR}/${cat}-${phase}.log"
    JSON_OUT="$out" LOG_FILE="$log" bash "scripts/${cat}/${phase}.sh" >/dev/null 2>&1 || true
    [ -f "$out" ]
    python3 "${REPO}/tests/validate_phase_json.py" "$out"
}

@test "apt:check emits valid sidecar"     { run_phase apt check; }
@test "apt:plan emits valid sidecar"      { run_phase apt plan; }
@test "snap:check emits valid sidecar"    { run_phase snap check; }
@test "snap:plan emits valid sidecar"     { run_phase snap plan; }
@test "brew:check emits valid sidecar"    { run_phase brew check; }
@test "brew:plan emits valid sidecar"     { run_phase brew plan; }
@test "npm:check emits valid sidecar"     { run_phase npm check; }
@test "npm:plan emits valid sidecar"      { run_phase npm plan; }
@test "pip:check emits valid sidecar"     { run_phase pip check; }
@test "pip:plan emits valid sidecar"      { run_phase pip plan; }
@test "flatpak:check emits valid sidecar" { run_phase flatpak check; }
@test "flatpak:plan emits valid sidecar"  { run_phase flatpak plan; }
@test "drivers:check emits valid sidecar" { run_phase drivers check; }
@test "drivers:plan emits valid sidecar"  { run_phase drivers plan; }
