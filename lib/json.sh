#!/usr/bin/env bash
# =============================================================================
# lib/json.sh — Phase-result JSON sidecar emitter (schema v1)
#
# Usage:
#   source lib/json.sh
#   json_init <kind> <category>          # kind: check|plan|apply|verify|cleanup
#   json_add_item id=foo action=upgrade result=ok [from=1 to=2 duration_ms=80]
#   json_add_diag warn CODE-NAME "human readable message"
#   json_count_ok / json_count_warn / json_count_err [N]
#   json_set_needs_reboot 1
#   json_finalize <exit_code> <out_path>
#
# JSON_OUT env (when set, json_finalize-on-trap auto-writes to it). See
# `_json_finalize_on_exit` below.
# =============================================================================

# shellcheck disable=SC2155
[[ -z "${LIB_JSON_DIR:-}" ]] && LIB_JSON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_JSON_EMIT="${LIB_JSON_DIR}/_json_emit.py"

if ! command -v python3 >/dev/null 2>&1; then
    echo "lib/json.sh: python3 is required for JSON sidecar emission" >&2
    return 1 2>/dev/null || exit 1
fi

if [[ ! -f "${_JSON_EMIT}" ]]; then
    echo "lib/json.sh: missing helper ${_JSON_EMIT}" >&2
    return 1 2>/dev/null || exit 1
fi

JSON_BUFDIR=""
JSON_KIND=""
JSON_CATEGORY=""
JSON_OUT_PATH=""
JSON_FINALIZED=0

_json_now_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

json_init() {
    local kind="$1" category="$2"
    if [[ -z "$kind" || -z "$category" ]]; then
        echo "json_init: usage: json_init <kind> <category>" >&2
        return 2
    fi
    JSON_KIND="$kind"
    JSON_CATEGORY="$category"
    JSON_BUFDIR="$(mktemp -d -t ua-json-XXXXXX)"
    JSON_FINALIZED=0
    local started_at; started_at="$(_json_now_utc)"
    local host; host="$(hostname 2>/dev/null || echo unknown)"
    python3 "${_JSON_EMIT}" init \
        --bufdir "${JSON_BUFDIR}" \
        --kind "${kind}" \
        --category "${category}" \
        --host "${host}" \
        --started-at "${started_at}" \
        ${LOG_FILE:+--log-path "${LOG_FILE}"}
    export JSON_BUFDIR JSON_KIND JSON_CATEGORY
}

# json_add_item id=foo action=upgrade result=ok [from=...] [to=...]
#               [duration_ms=N] [details="..."]
json_add_item() {
    [[ -z "${JSON_BUFDIR}" ]] && return 0
    local args=(--bufdir "${JSON_BUFDIR}")
    local kv key val
    for kv in "$@"; do
        key="${kv%%=*}"
        val="${kv#*=}"
        case "$key" in
            id)          args+=(--id "$val") ;;
            action)      args+=(--action "$val") ;;
            result)      args+=(--result "$val") ;;
            from)        args+=(--from "$val") ;;
            to)          args+=(--to "$val") ;;
            duration_ms) args+=(--duration-ms "$val") ;;
            details)     args+=(--details "$val") ;;
            *) echo "json_add_item: unknown key: $key" >&2; return 2 ;;
        esac
    done
    python3 "${_JSON_EMIT}" add-item "${args[@]}"
}

# json_add_diag <level> <code> <msg...>
json_add_diag() {
    [[ -z "${JSON_BUFDIR}" ]] && return 0
    local level="$1" code="$2"; shift 2 || true
    local msg="$*"
    python3 "${_JSON_EMIT}" add-diag \
        --bufdir "${JSON_BUFDIR}" \
        --level "${level}" \
        --code "${code}" \
        --msg "${msg}"
}

json_add_advisory() {
    [[ -z "${JSON_BUFDIR}" ]] && return 0
    local msg="$*"
    python3 "${_JSON_EMIT}" add-advisory \
        --bufdir "${JSON_BUFDIR}" \
        --msg "${msg}"
}

json_count_ok()   { [[ -z "${JSON_BUFDIR}" ]] && return 0; python3 "${_JSON_EMIT}" count --bufdir "${JSON_BUFDIR}" --bucket ok   --n "${1:-1}"; }
json_count_warn() { [[ -z "${JSON_BUFDIR}" ]] && return 0; python3 "${_JSON_EMIT}" count --bufdir "${JSON_BUFDIR}" --bucket warn --n "${1:-1}"; }
json_count_err()  { [[ -z "${JSON_BUFDIR}" ]] && return 0; python3 "${_JSON_EMIT}" count --bufdir "${JSON_BUFDIR}" --bucket err  --n "${1:-1}"; }

json_set_needs_reboot() {
    [[ -z "${JSON_BUFDIR}" ]] && return 0
    python3 "${_JSON_EMIT}" set-flag \
        --bufdir "${JSON_BUFDIR}" \
        --key needs_reboot \
        --value "${1:-0}"
}

json_finalize() {
    [[ -z "${JSON_BUFDIR}" ]] && return 0
    [[ "${JSON_FINALIZED}" == "1" ]] && return 0
    local exit_code="${1:-0}" out_path="${2:-${JSON_OUT_PATH:-}}"
    if [[ -z "${out_path}" ]]; then
        rm -rf "${JSON_BUFDIR}"
        JSON_BUFDIR=""
        JSON_FINALIZED=1
        return 0
    fi
    local ended_at; ended_at="$(_json_now_utc)"
    python3 "${_JSON_EMIT}" finalize \
        --bufdir "${JSON_BUFDIR}" \
        --out "${out_path}" \
        --exit-code "${exit_code}" \
        --ended-at "${ended_at}"
    rm -rf "${JSON_BUFDIR}"
    JSON_BUFDIR=""
    JSON_FINALIZED=1
}

# Convenience: register an EXIT trap that finalizes with the script's exit code
# when JSON_OUT is set (used by phase scripts).
json_register_exit_trap() {
    JSON_OUT_PATH="${1:-${JSON_OUT:-}}"
    [[ -z "${JSON_OUT_PATH}" ]] && return 0
    trap '_json_finalize_on_exit $?' EXIT
}

_json_finalize_on_exit() {
    local rc="${1:-0}"
    json_finalize "${rc}" "${JSON_OUT_PATH}"
}
