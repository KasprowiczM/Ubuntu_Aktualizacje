#!/usr/bin/env bash
# =============================================================================
# scripts/apps/detect.sh — Compare installed apps with config/*.list lists.
#
# Output: a colour-coded table grouped by category. For every package we
# show one of three states:
#   tracked     — listed in config/<cat>-*.list and currently installed
#   detected    — installed but NOT in any list (candidate for `apps add`)
#   missing     — listed in config but NOT installed (candidate for install)
#
# Read-only.  Never installs or removes anything.
#
# Flags:
#   --json        emit machine-readable JSON instead of the human table
#   --category C  restrict scan to one category (apt|snap|brew|brew-cask|npm|pipx|flatpak)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/i18n.sh
source "${SCRIPT_DIR}/lib/i18n.sh"
# shellcheck source=lib/tables.sh
source "${SCRIPT_DIR}/lib/tables.sh"
# shellcheck source=lib/detect.sh
source "${SCRIPT_DIR}/lib/detect.sh"

JSON=0
ONLY_CAT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)     JSON=1 ;;
        --category) shift; ONLY_CAT="${1:-}" ;;
        -h|--help)  sed -n '4,18p' "$0"; exit 0 ;;
        *) echo "unknown: $1" >&2; exit 2 ;;
    esac
    shift
done

detect_package_managers
apt_inventory_cache_init 2>/dev/null || true

# Helpers — populate two arrays per category: CFG=in config, INST=installed
declare -A CAT_CFG=()    # "<cat>:<pkg>" → 1
declare -A CAT_INST=()   # "<cat>:<pkg>" → version

_load_cfg_list() {
    local cat="$1" file="$2"
    [[ -f "$file" ]] || return 0
    local pkg
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        CAT_CFG["$cat:$pkg"]=1
    done < <(grep -vE '^[[:space:]]*(#|$)' "$file" | awk '{print $1}')
}

_load_cfg_list apt        "${SCRIPT_DIR}/config/apt-packages.list"
_load_cfg_list snap       "${SCRIPT_DIR}/config/snap-packages.list"
_load_cfg_list brew       "${SCRIPT_DIR}/config/brew-formulas.list"
_load_cfg_list brew-cask  "${SCRIPT_DIR}/config/brew-casks.list"
_load_cfg_list npm        "${SCRIPT_DIR}/config/npm-globals.list"
_load_cfg_list pipx       "${SCRIPT_DIR}/config/pipx-apps.list"
_load_cfg_list flatpak    "${SCRIPT_DIR}/config/flatpak-apps.list"

# Installed scanners (best-effort, silent on missing managers)
if has_cmd dpkg-query; then
    while IFS= read -r p; do
        [[ -n "$p" ]] && CAT_INST["apt:$p"]=installed
    done < <(apt-mark showmanual 2>/dev/null)
fi
if has_cmd snap; then
    while read -r name _; do
        [[ "$name" == "Name" || -z "$name" ]] && continue
        CAT_INST["snap:$name"]=installed
    done < <(snap list 2>/dev/null)
fi
if [[ -n "${BREW_BIN:-}" ]]; then
    while IFS= read -r f; do
        [[ -n "$f" ]] && CAT_INST["brew:$f"]=installed
    done < <(run_as_user "${BREW_BIN}" list --formula 2>/dev/null)
    while IFS= read -r c; do
        [[ -n "$c" ]] && CAT_INST["brew-cask:$c"]=installed
    done < <(run_as_user "${BREW_BIN}" list --cask 2>/dev/null)
fi
if [[ -n "${NPM_BIN:-}" ]]; then
    while IFS='|' read -r name _; do
        [[ -n "$name" ]] && CAT_INST["npm:$name"]=installed
    done < <(scan_npm_globals 2>/dev/null)
fi
if has_cmd pipx; then
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*package[[:space:]]+([^[:space:]]+) ]] && \
            CAT_INST["pipx:${BASH_REMATCH[1]}"]=installed
    done < <(pipx list 2>/dev/null || true)
fi
if has_cmd flatpak; then
    while read -r app _; do
        [[ -z "$app" || "$app" == "Application" ]] && continue
        CAT_INST["flatpak:$app"]=installed
    done < <(flatpak list --app --columns=application 2>/dev/null)
fi

# Build the union of keys we know about, group by category
declare -A SEEN=()
declare -a ROWS=()
declare -i n_track=0 n_detected=0 n_missing=0

_emit_row() {
    local cat="$1" pkg="$2" state="$3" suggest="$4"
    case "$state" in
        tracked)   ROWS+=("$cat|$pkg|@ok $(t apps.state.tracked)|$suggest")   ; n_track=$((n_track+1)) ;;
        detected)  ROWS+=("$cat|$pkg|@warn $(t apps.state.untracked)|$suggest"); n_detected=$((n_detected+1)) ;;
        missing)   ROWS+=("$cat|$pkg|@err $(t apps.state.missing)|$suggest")  ; n_missing=$((n_missing+1)) ;;
    esac
}

for key in "${!CAT_CFG[@]}" "${!CAT_INST[@]}"; do
    [[ -n "${SEEN[$key]:-}" ]] && continue
    SEEN[$key]=1
    cat="${key%%:*}"; pkg="${key#*:}"
    [[ -n "$ONLY_CAT" && "$cat" != "$ONLY_CAT" ]] && continue
    in_cfg="${CAT_CFG[$key]:-}"
    in_inst="${CAT_INST[$key]:-}"
    if [[ -n "$in_cfg" && -n "$in_inst" ]]; then
        _emit_row "$cat" "$pkg" tracked "—"
    elif [[ -n "$in_inst" && -z "$in_cfg" ]]; then
        suggest=$(printf "$(t apps.action.add)" "$pkg" "$cat")
        _emit_row "$cat" "$pkg" detected "$suggest"
    elif [[ -n "$in_cfg" && -z "$in_inst" ]]; then
        _emit_row "$cat" "$pkg" missing "$(t apps.action.install)"
    fi
done

if [[ $JSON -eq 1 ]]; then
    python3 - "$n_track" "$n_detected" "$n_missing" "${ROWS[@]:-}" <<'PY'
import json, sys
n_track, n_detected, n_missing = (int(x) for x in sys.argv[1:4])
rows = [r for r in sys.argv[4:] if r]
items = []
for r in rows:
    cat, pkg, state, sug = r.split("|", 3)
    # strip @tag prefixes
    raw_state = state.split(" ", 1)[1] if state.startswith("@") else state
    items.append({"category": cat, "package": pkg, "state": raw_state.strip(), "suggested": sug})
print(json.dumps({
    "summary": {"tracked": n_track, "detected": n_detected, "missing": n_missing},
    "items": items,
}, indent=2, ensure_ascii=False))
PY
    exit 0
fi

# Human view: sort rows by (category asc, state risk desc, package asc)
print_header "Ascendo — $(t apps.title)"

# Sort: missing first, then detected, then tracked.
state_rank() { case "$1" in *missing*) echo 0;; *detected*|*untracked*) echo 1;; *) echo 2;; esac; }

# Read the rows back, attach numeric rank, sort, render.
TMP=$(mktemp)
for r in "${ROWS[@]:-}"; do
    [[ -z "$r" ]] && continue
    IFS='|' read -r c p s a <<<"$r"
    rank=$(state_rank "$s")
    printf '%s\t%s\t%s\n' "$c" "$rank" "$r" >> "$TMP"
done
sort -t$'\t' -k1,1 -k2,2n -k3,3 "$TMP" -o "$TMP"
mapfile -t SORTED < <(cut -f3- "$TMP")
rm -f "$TMP"

table_render \
    "$(t apps.col_cat)|$(t apps.col_name)|$(t apps.col_state)|$(t apps.col_action)" \
    "${SORTED[@]:-no-data|—|—|—}"

echo
printf "  $(t apps.summary)\n" "$n_track" "$n_detected" "$n_missing"
echo
[[ $n_detected -eq 0 && $n_missing -eq 0 ]] && echo "  $(t apps.no_changes)"
