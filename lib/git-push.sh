#!/usr/bin/env bash
# =============================================================================
# lib/git-push.sh — GitHub push helper using GITHUB_TOKEN from .env.local
#
# Loads GITHUB_TOKEN from .env.local (gitignored) and configures
# the git remote URL temporarily for push operations.
#
# Usage:
#   source lib/git-push.sh && git_push [branch]
#   bash lib/git-push.sh push [branch]
#   bash lib/git-push.sh status
#
# Token file: .env.local (gitignored via .env* pattern in .gitignore)
# Format:     GITHUB_TOKEN=<GitHub PAT>
#
# SECURITY: Token is only in memory during the push. It is never written
# to any config file, never logged, and never committed.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.local"

# ── Load token ────────────────────────────────────────────────────────────────
_load_github_token() {
    if [[ -f "$ENV_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$ENV_FILE"
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
    local repo_path; repo_path=$(echo "$clean_url" | sed 's|https://github.com/||' | sed 's|\.git$||')
    local token_url="https://x-access-token:${GITHUB_TOKEN}@github.com/${repo_path}.git"

    echo "Pushing to: https://github.com/${repo_path}.git (branch: ${branch})"

    # Temporarily set remote URL with token, push, restore
    git -C "$SCRIPT_DIR" remote set-url origin "$token_url"
    git -C "$SCRIPT_DIR" push -u origin "$branch"
    local rc=$?
    git -C "$SCRIPT_DIR" remote set-url origin "$clean_url"  # restore clean URL

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
