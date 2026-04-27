# Machine Onboarding

## Supported Baseline

The scripts are designed for Ubuntu systems and are currently validated most
directly on Ubuntu 24.04-class hosts. `scripts/preflight.sh` warns when the
release is outside the explicitly known set.

## Onboarding Checklist

1. Install Git and clone the repository.
2. Run `bash scripts/preflight.sh`.
3. Configure dev-sync provider with `bash dev-sync/provider_setup.sh`.
4. Preview private overlay restore with `bash scripts/restore-from-proton.sh --dry-run --verbose`.
5. Restore overlay with `bash scripts/restore-from-proton.sh --verbose`.
6. Run `bash scripts/bootstrap.sh --skip-sync`.
7. Run `bash scripts/verify-state.sh`.
8. Install the weekly timer only after manual verification: `bash systemd/install-timer.sh`.

## Hardware-Specific Decisions

| Area | Policy |
|---|---|
| NVIDIA | Held during APT updates unless `./update-all.sh --nvidia` is used. Previous manual holds are preserved. |
| Firmware | `update-drivers.sh` checks fwupd metadata and reports available updates; firmware application stays manual. |
| Systemd timer | Runs `update-all.sh --no-drivers`; APT can still update normal OS packages such as kernels and microcode. |
| Secrets | Stored in provider overlay, never Git. |

## Post-Onboarding Verification

```bash
bash scripts/verify-state.sh
./update-all.sh --dry-run
./setup.sh --check --non-interactive
```
