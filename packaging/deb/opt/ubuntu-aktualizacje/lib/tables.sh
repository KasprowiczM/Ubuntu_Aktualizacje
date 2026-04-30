#!/usr/bin/env bash
# =============================================================================
# lib/tables.sh — pretty unicode tables + colour-tagged status pills for CLI.
#
# Rows are pipe-separated strings. The first row is the header. To colour a
# cell, prefix the value with one of the @TAG markers below; the renderer
# strips the marker, applies the ANSI sequence, and pads using the *visual*
# (un-coloured) width so columns stay aligned.
#
#   @ok value     → green pill   ✔ value
#   @warn value   → amber pill   ⚠ value
#   @err value    → red pill     ✘ value
#   @skip value   → grey pill    ⊘ value
#   @info value   → blue pill    ⓘ value
#   @dim value    → dim text     value
#   @mono value   → unchanged but treated as code-like (no marker effect)
#
# Public API:
#   table_render <header_pipe> <row_pipe> [<row_pipe> ...]
#   status_cell  ok|warn|err|skip|info <text>      → echoes "@ok text" etc.
#
# Designed to look identical to the dashboard's `.tbl` + `.st-pill` styles.
# =============================================================================

# shellcheck disable=SC2034
ASCENDO_TABLES_LIB_LOADED=1

# Foreground 256-colour codes mirroring the dashboard palette.
_T_OK='\033[38;5;34m'
_T_WARN='\033[38;5;208m'
_T_ERR='\033[38;5;196m'
_T_SKIP='\033[38;5;244m'
_T_INFO='\033[38;5;39m'
_T_DIM='\033[2m'
_T_BOLD='\033[1m'
_T_RST='\033[0m'

# Strip @tag marker → visible text (used for width calculation).
_table_strip_tag() {
    local v="$1"
    case "$v" in
        @ok\ *|@warn\ *|@err\ *|@skip\ *|@info\ *|@dim\ *|@mono\ *|@bold\ *)
            printf '%s' "${v#* }" ;;
        *) printf '%s' "$v" ;;
    esac
}

# Visible (printable) width — strips ANSI and counts ASCII chars.
_table_visible_width() {
    local s="$1"
    # Strip ANSI escapes
    s=$(printf '%s' "$s" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')
    printf '%d' "${#s}"
}

# Render a tagged value with ANSI + glyph; preserve plain when no tag.
_table_format_cell() {
    local v="$1" core
    case "$v" in
        @ok\ *)   core="${v#@ok }";   printf '%b%s %s%b' "$_T_OK"   "✔" "$core" "$_T_RST" ;;
        @warn\ *) core="${v#@warn }"; printf '%b%s %s%b' "$_T_WARN" "⚠" "$core" "$_T_RST" ;;
        @err\ *)  core="${v#@err }";  printf '%b%s %s%b' "$_T_ERR"  "✘" "$core" "$_T_RST" ;;
        @skip\ *) core="${v#@skip }"; printf '%b%s %s%b' "$_T_SKIP" "⊘" "$core" "$_T_RST" ;;
        @info\ *) core="${v#@info }"; printf '%b%s %s%b' "$_T_INFO" "ⓘ" "$core" "$_T_RST" ;;
        @dim\ *)  core="${v#@dim }";  printf '%b%s%b'    "$_T_DIM"  "$core" "$_T_RST" ;;
        @bold\ *) core="${v#@bold }"; printf '%b%s%b'    "$_T_BOLD" "$core" "$_T_RST" ;;
        @mono\ *) core="${v#@mono }"; printf '%s' "$core" ;;
        *) printf '%s' "$v" ;;
    esac
}

# _table_visible_width_of_formatted_cell: width AFTER tag substitution
# (because @ok/etc add a 2-char glyph + space prefix).
_table_visible_width_after_format() {
    local v="$1"
    case "$v" in
        @ok\ *|@warn\ *|@err\ *|@skip\ *|@info\ *)
            local core; core=$(_table_strip_tag "$v")
            printf '%d' $(( $(_table_visible_width "$core") + 2 )) ;;
        @dim\ *|@bold\ *|@mono\ *)
            _table_visible_width "$(_table_strip_tag "$v")" ;;
        *) _table_visible_width "$v" ;;
    esac
}

# Public: render header + rows. Each arg is a pipe-separated row. Cells
# may carry @tag prefixes.
table_render() {
    [[ $# -lt 1 ]] && return 0
    local rows=("$@")
    local IFS='|'
    # First pass: split each row into cells; figure out per-column max width.
    local -a header
    local -a all_rows_cells=()
    local -a col_widths=()
    local row idx cells
    for row in "${rows[@]}"; do
        # shellcheck disable=SC2206
        local -a cells_arr=( $row )
        all_rows_cells+=("${#cells_arr[@]}")  # store cell count
        for ((i=0; i<${#cells_arr[@]}; i++)); do
            local w; w=$(_table_visible_width_after_format "${cells_arr[$i]}")
            local cur="${col_widths[$i]:-0}"
            (( w > cur )) && col_widths[$i]=$w
        done
        # Stash split cells contiguously by encoding length first
    done
    # We re-split below for actual rendering — simpler than tracking offsets.

    local n_cols=${#col_widths[@]}
    [[ $n_cols -eq 0 ]] && return 0

    # Build separator lines using box-drawing.
    local top="┌" mid="├" bot="└" h_top="┬" h_mid="┼" h_bot="┴"
    local i k hd
    for ((i=0; i<n_cols; i++)); do
        hd=""
        for ((k=0; k<col_widths[i]+2; k++)); do hd+="─"; done
        if (( i == 0 )); then
            top+="$hd"; mid+="$hd"; bot+="$hd"
        else
            top+="$h_top$hd"; mid+="$h_mid$hd"; bot+="$h_bot$hd"
        fi
    done
    top+="┐"; mid+="┤"; bot+="┘"

    # Render: top border, header, mid border, body rows, bottom border.
    printf '%s\n' "$top"
    local r=0
    for row in "${rows[@]}"; do
        # shellcheck disable=SC2206
        local -a cells_arr=( $row )
        local out="│"
        for ((i=0; i<n_cols; i++)); do
            local cell="${cells_arr[$i]:-}"
            local visible_w; visible_w=$(_table_visible_width_after_format "$cell")
            local pad=$(( col_widths[i] - visible_w ))
            (( pad < 0 )) && pad=0
            local rendered; rendered=$(_table_format_cell "$cell")
            if (( r == 0 )); then
                # Header row: bold + dim
                out+=$(printf ' %b%s%b%*s ' "$_T_BOLD" "$rendered" "$_T_RST" "$pad" "")
            else
                out+=$(printf ' %s%*s ' "$rendered" "$pad" "")
            fi
            out+="│"
        done
        printf '%s\n' "$out"
        if (( r == 0 )); then printf '%s\n' "$mid"; fi
        r=$((r+1))
    done
    printf '%s\n' "$bot"
}

status_cell() {
    local kind="$1"; shift
    local text="$*"
    case "$kind" in
        ok|warn|err|skip|info) printf '@%s %s' "$kind" "$text" ;;
        *) printf '%s' "$text" ;;
    esac
}
