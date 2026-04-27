# Dev Sync Scripts README

Operator guide for the `dev-sync` recovery scripts in `Ubuntu_Aktualizacje`.

For command details, see:

- `dev-sync/README.md`
- `dev-sync/QUICK_START.md`
- `dev-sync/INDEX.md`

## Storage Model

GitHub is the source of truth for project files that should be shared and reviewed:

- Bash update scripts and shared libraries
- package-manager config lists in `config/*.list`
- documentation and agent instructions
- CI workflow files
- dev-sync implementation scripts and wrappers
- intentional Graphify/project-map outputs

The configured provider, usually Proton Drive via `rclone` on Ubuntu, stores only the private recovery overlay:

- `.env` / `.env.local` and local env variants
- `.dev_sync_config.json`
- local Claude settings under `.claude/` when ignored by Git
- local key files such as `github` and `github.pub`
- other Git-ignored local-only files that cannot be recreated from GitHub plus normal setup

The overlay is manifest-backed for local filesystem providers. Export writes `.dev_sync_manifest.json` into the provider mirror and import prefers that manifest so stale files are not restored accidentally.

Normal untracked files are not exported to the provider. If `dev-sync-verify-full.sh`
reports them as orphan local files, either commit them to GitHub or add an
intentional ignore rule before expecting provider backup.

## Excluded From Provider Sync

The overlay intentionally excludes files you can rebuild, regenerate, or recommit:

- generated inventory: `APPS.md`
- runtime logs: `logs/`, `*.log`
- setup backups: `config/*.bak_*`
- dependency folders and virtualenvs: `node_modules/`, `.venv/`, `venv/`
- build/cache output: `dist/`, `build/`, `.cache/`
- Python caches: `__pycache__/`, `.pytest_cache/`, `.mypy_cache/`
- Codex runtime cache: `.codex.local/tmp/`
- Graphify cache/cost internals; final `graph.html`, `graph.json`, and reports may be tracked intentionally
- dev-sync runtime files: `dev_sync_logs/`, `dev_sync_quarantine/`, cleanup plans, manifests

## First Setup

```sh
bash dev-sync/provider_setup.sh
```

On Ubuntu, prefer the `rclone` provider for Proton Drive. Configure `rclone` separately; do not commit rclone credentials or Proton tokens.

## Daily Export

```sh
bash dev-sync-export.sh --dry-run --verbose
bash dev-sync-export.sh
bash dev-sync-verify-full.sh
bash dev-sync-prune-excluded.sh
```

Expected result:

- `dev-sync-verify-full.sh` prints `PASS`
- `dev-sync-prune-excluded.sh` reports no cleanup candidates

## GitHub Verification

Use this before relying on GitHub as the tracked-file backup:

```sh
bash dev-sync-verify-git.sh
```

It checks that tracked files are clean, an upstream exists, and the branch is not ahead of upstream.

## Clean Bad Provider Sync

If generated files or stale files are already present in the provider mirror, use a saved cleanup plan:

```sh
bash dev-sync-prune-excluded.sh --plan-out dev_sync_cleanup_plan.json
```

Inspect the JSON plan. Then quarantine exactly the reviewed plan:

```sh
bash dev-sync-prune-excluded.sh --apply-plan dev_sync_cleanup_plan.json
bash dev-sync-verify-full.sh
bash dev-sync-purge-quarantine.sh
```

After verification and manual review:

```sh
bash dev-sync-purge-quarantine.sh --apply
```

Do not directly delete broad directories in provider storage.

## Restore On A New Machine

1. Clone this repo from GitHub.
2. Run `bash dev-sync/provider_setup.sh` if `.dev_sync_config.json` is missing.
3. Confirm the provider destination points at this repo's mirror folder.
4. Restore private overlay:

```sh
bash dev-sync-import.sh --dry-run --verbose
bash dev-sync-import.sh
bash dev-sync-verify-full.sh
```

5. Reinstall normal dependencies through this project's documented setup/update commands.

## Proton Offload Warning

`dev-sync-proton-status.sh` uses macOS `fileproviderctl` and is only meaningful for a local Proton File Provider root. On Ubuntu/rclone, verify with rclone/provider checks and the web UI before deleting local Proton cache/staging files.
