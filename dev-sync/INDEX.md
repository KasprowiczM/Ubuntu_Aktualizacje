# Dev Sync File Index

- `dev_sync_core.py` - config, provider abstraction, path safety, Git classification, export/import, verification.
- `dev_sync_export.py` - CLI for private overlay export.
- `dev_sync_import.py` - CLI for overlay restore.
- `dev_sync_verify_git.py` - checks clean tracked state and upstream push status.
- `dev_sync_verify_full.py` - checks reconstruction from GitHub plus provider overlay.
- `dev_sync_prune_excluded.py` - creates and applies quarantine plans for stale/generated provider files.
- `dev_sync_purge_quarantine.py` - deletes reviewed quarantine only with `--apply`.
- `dev_sync_proton_status.py` - macOS File Provider status helper; not the primary Ubuntu/rclone verification path.
- `provider_setup.sh` - interactive provider config writer.
- `dev-sync-*.sh` - shell wrappers for Python CLIs.
