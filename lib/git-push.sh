#!/usr/bin/env bash
# =============================================================================
# lib/git-push.sh — GitHub push helper using GITHUB_TOKEN from .env.local
#
# Loads GITHUB_TOKEN from .env.local (gitignored) and uses a temporary
# GIT_ASKPASS helper for push operations.
#
# Usage:
#   source lib/git-push.sh && git_push [branch]
#   bash lib/git-push.sh push [branch]
#   bash lib/git-push.sh status
#
# Token file: .env.local (gitignored via .env* pattern in .gitignore)
# Format:     GITHUB_TOKEN=<GitHub PAT>
#
# SECURITY: Token is never written to Git config, never logged, and never
# committed. The temporary askpass helper is removed by trap.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.local"

# ── Load token ────────────────────────────────────────────────────────────────
_load_github_token() {
    if [[ -f "$ENV_FILE" ]]; then
        local line value
        line=$(grep -E '^GITHUB_TOKEN=' "$ENV_FILE" | tail -1 || true)
        if [[ -n "$line" ]]; then
            value="${line#GITHUB_TOKEN=}"
            value="${value%\"}"; value="${value#\"}"
            value="${value%\'}"; value="${value#\'}"
            if [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *" "* ]]; then
                echo "Error: invalid GITHUB_TOKEN value in .env.local" >&2
                return 1
            fi
            GITHUB_TOKEN="$value"
        fi
    fi
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        echo "Error: GITHUB_TOKEN not set. Add it to .env.local:" >&2
        echo "  GITHUB_TOKEN=<GitHub PAT>" >&2
        return 1
    fi
}

# ── Get repo URL (without token) ──────────────────────────────────────────────
_get_clean_remote_url() {
    git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null | \
        sed 's|https://[^@]*@|https://|' | \
        sed 's|https://github.com/|https://github.com/|'
}

# ── Push with token ───────────────────────────────────────────────────────────
git_push() {
    local branch="${1:-main}"

    _load_github_token || return 1

    # Get the clean repo URL
    local clean_url; clean_url=$(_get_clean_remote_url)
    # Extract owner/repo
    local repo_path
    repo_path=$(echo "$clean_url" | sed -E 's#^https://github.com/##; s#^git@github.com:##; s#\.git$##')
    if [[ "$repo_path" == "$clean_url" || "$repo_path" != */* ]]; then
        echo "Error: unsupported origin URL: ${clean_url}" >&2
        return 1
    fi
    local https_url="https://github.com/${repo_path}.git"

    echo "Pushing to: https://github.com/${repo_path}.git (branch: ${branch})"

    local askpass
    askpass=$(mktemp)
    chmod 700 "$askpass"
    cat > "$askpass" << 'EOF'
#!/usr/bin/env bash
case "$1" in
    *Username*) printf '%s\n' "x-access-token" ;;
    *Password*) printf '%s\n' "${GITHUB_TOKEN:?}" ;;
    *) printf '\n' ;;
esac
EOF
    trap 'rm -f "$askpass"' RETURN

    GIT_ASKPASS="$askpass" GITHUB_TOKEN="$GITHUB_TOKEN" \
        git -C "$SCRIPT_DIR" push -u "$https_url" "$branch"
    local rc=$?
    rm -f "$askpass"
    trap - RETURN

    return $rc
}

# ── Commit and push shortcut ──────────────────────────────────────────────────
git_commit_push() {
    local message="${1:-Auto-update: $(date '+%Y-%m-%d %H:%M')}"
    local branch="${2:-main}"

    git -C "$SCRIPT_DIR" add -A
    git -C "$SCRIPT_DIR" diff --cached --quiet && { echo "Nothing to commit."; return 0; }
    git -C "$SCRIPT_DIR" commit -m "$message"
    git_push "$branch"
}

# ── Status (shows remote without token) ──────────────────────────────────────
git_status() {
    echo "Remote: $(_get_clean_remote_url)"
    echo "Branch: $(git -C "$SCRIPT_DIR" branch --show-current 2>/dev/null)"
    echo "Status:"
    git -C "$SCRIPT_DIR" status --short
}

# ── CLI interface ─────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-push}" in
        push)   git_push "${2:-main}" ;;
        commit) git_commit_push "${2:-}" "${3:-main}" ;;
        status) git_status ;;
        *) echo "Usage: $0 [push|commit|status] [branch]"; exit 1 ;;
    esac
fi
