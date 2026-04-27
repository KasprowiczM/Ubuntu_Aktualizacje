# Dev Sync

`dev-sync` backs up the private overlay for `Ubuntu_Aktualizacje` while GitHub remains the source of truth for tracked project files.

## Commands

| Command | Purpose |
|---|---|
| `bash dev-sync/provider_setup.sh` | Create `.dev_sync_config.json` for Proton/rclone or a local provider path. |
| `bash dev-sync-export.sh --dry-run --verbose` | Show Git-ignored private overlay files selected for provider backup. |
| `bash dev-sync-export.sh` | Copy selected Git-ignored private overlay files to the provider. |
| `bash dev-sync-import.sh --dry-run --verbose` | Preview restore from provider. |
| `bash dev-sync-import.sh` | Restore private overlay files, skipping Git-tracked files for local providers. |
| `bash dev-sync-verify-git.sh` | Verify tracked files are clean and pushed to upstream. |
| `bash dev-sync-verify-full.sh` | Verify Git-tracked files plus provider overlay reconstruct local state. |
| `bash dev-sync-prune-excluded.sh` | Plan stale/generated provider cleanup. |
| `bash dev-sync-purge-quarantine.sh --apply` | Permanently delete reviewed quarantine. |

## Provider Policy

Use `rclone` for Proton Drive on Ubuntu unless you have an explicit local provider folder. Export uses copy semantics, never destructive mirror semantics. Cleanup is plan-first and quarantine-first.

Only Git-ignored files are eligible for provider export. Nonignored untracked
files are treated as project content and should be committed to GitHub or
explicitly ignored.

## Private Overlay Examples

- `.env.local`
- `.dev_sync_config.json`
- local key files such as `github`
- ignored local Claude settings

## Rebuildable Files Not Synced

- `APPS.md`
- `logs/`
- `config/*.bak_*`
- `.codex.local/tmp/`
- dependency, build, test, and cache outputs

See `config/dev-sync-excludes.txt` for project-specific exclusions.
