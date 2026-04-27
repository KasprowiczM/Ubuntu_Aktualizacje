# Dev Sync Quick Start

1. Configure provider:

```sh
bash dev-sync/provider_setup.sh
```

2. Preview what would be copied:

```sh
bash dev-sync-export.sh --dry-run --verbose
```

3. Export private overlay:

```sh
bash dev-sync-export.sh
```

4. Verify GitHub and provider coverage:

```sh
bash dev-sync-verify-git.sh
bash dev-sync-verify-full.sh
```

5. Restore on a new machine:

```sh
git clone <repo-url>
cd Ubuntu_Aktualizacje
bash dev-sync/provider_setup.sh
bash dev-sync-import.sh --dry-run --verbose
bash dev-sync-import.sh
```

Do not use `rclone sync` or manual broad deletion for this overlay. Use the provided prune/quarantine scripts.
