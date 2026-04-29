#!/usr/bin/env bats
# Tests for lib/orchestrator.sh — DAG runner over phase scripts.

REPO="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    export TMPHOME
    TMPHOME="$(mktemp -d)"
    cd "$TMPHOME"
    # Minimal fake repo to source orchestrator from
    mkdir -p lib scripts/fake logs
    cp "${REPO}/lib/common.sh"        lib/
    cp "${REPO}/lib/json.sh"          lib/
    cp "${REPO}/lib/_json_emit.py"    lib/
    cp "${REPO}/lib/orchestrator.sh"  lib/

    # Fake category script that emits a sidecar
    cat > scripts/fake/check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/json.sh"
json_init check apt
json_register_exit_trap "${JSON_OUT:-}"
json_add_item id="fake:test" action="present" result="ok"
json_count_ok
exit 0
EOF
    chmod +x scripts/fake/check.sh
}

teardown() {
    rm -rf "$TMPHOME"
}

@test "orch_init creates run dir" {
    cd "$TMPHOME"
    SCRIPT_DIR="$TMPHOME"
    source "${TMPHOME}/lib/orchestrator.sh"
    orch_init "test-run-1"
    [ "$ORCH_RUN_ID" = "test-run-1" ]
    [ -d "${TMPHOME}/logs/runs/test-run-1" ]
}

@test "orch_run_phase emits sidecar and tracks status" {
    cd "$TMPHOME"
    SCRIPT_DIR="$TMPHOME"
    source "${TMPHOME}/lib/orchestrator.sh"
    orch_init "test-run-2"
    # Map "fake" → scripts/fake/<phase>.sh resolved by orchestrator
    orch_run_phase fake check
    [ -f "${ORCH_RUN_DIR}/fake/check.json" ]
    [ "${ORCH_STATUS[fake/check]}" = "ok" ]
}

@test "orch_run_phase emits skipped sidecar for missing script" {
    cd "$TMPHOME"
    SCRIPT_DIR="$TMPHOME"
    source "${TMPHOME}/lib/orchestrator.sh"
    orch_init "test-run-3"
    orch_run_phase nonexistent apply
    [ -f "${ORCH_RUN_DIR}/nonexistent/apply.json" ]
    grep -q '"PHASE-SKIPPED"' "${ORCH_RUN_DIR}/nonexistent/apply.json"
}

@test "orch_summary aggregates run.json" {
    cd "$TMPHOME"
    SCRIPT_DIR="$TMPHOME"
    source "${TMPHOME}/lib/orchestrator.sh"
    orch_init "test-run-4"
    orch_run_phase fake check
    orch_summary
    [ -f "${ORCH_RUN_DIR}/run.json" ]
    grep -q '"run_id": "test-run-4"' "${ORCH_RUN_DIR}/run.json"
}

@test "DRY_RUN suppresses apply but still emits skipped sidecar" {
    cd "$TMPHOME"
    SCRIPT_DIR="$TMPHOME"
    cat > scripts/fake/apply.sh <<'EOF'
#!/usr/bin/env bash
echo "DO NOT RUN" > /tmp/should-not-exist-$$
exit 99
EOF
    chmod +x scripts/fake/apply.sh
    source "${TMPHOME}/lib/orchestrator.sh"
    orch_init "test-run-5"
    orch_set_dry_run 1
    orch_run_phase fake apply
    [ -f "${ORCH_RUN_DIR}/fake/apply.json" ]
    grep -q '"dry-run"' "${ORCH_RUN_DIR}/fake/apply.json"
}
