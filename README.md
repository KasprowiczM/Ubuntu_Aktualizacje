# Ubuntu_Aktualizacje

Automated Ubuntu 24.04 maintenance for this machine (Dell Precision 5520), with one master command, consistent logs, and machine-local inventory generation.

[![Validate Config](https://github.com/KasprowiczM/Ubuntu_Aktualizacje/actions/workflows/validate.yml/badge.svg)](https://github.com/KasprowiczM/Ubuntu_Aktualizacje/actions/workflows/validate.yml)

## Overview

This project is a Bash-based update suite focused on predictable, auditable updates across:
- APT
- Snap
- Homebrew
- npm
- pip / pipx
- Flatpak
- NVIDIA drivers and `fwupd`

Core behavior:
- one entrypoint: `./update-all.sh`
- one master log per run: `logs/master_YYYYMMDD_HHMMSS.log`
- inventory refresh at the end of master run: `APPS.md` (gitignored)
- package configuration in `config/*.list` (single source of truth)

Technical details and agent docs:
- [AGENTS.md](AGENTS.md)
- [CLAUDE.md](CLAUDE.md)
- [CODEX.md](CODEX.md)
- [docs/agents/architecture.md](docs/agents/architecture.md)
- [docs/agents/workflow.md](docs/agents/workflow.md)

## Quick Start

Run full update:

```bash
./update-all.sh
```

Common options:

```bash
./update-all.sh --dry-run
./update-all.sh --only apt
./update-all.sh --no-drivers
./update-all.sh --nvidia
./update-all.sh --no-notify
```

`--only` groups:
- `apt`
- `snap`
- `brew`
- `npm`
- `pip`
- `flatpak`
- `drivers`
- `inventory`

Validation after changes:

```bash
bash -n update-all.sh && bash -n scripts/*.sh && bash -n lib/*.sh
```

## What Gets Updated

| Group | Script | What it does |
|---|---|---|
| APT | `scripts/update-apt.sh` | Ensures configured third-party repos, updates package lists, runs `upgrade` + `dist-upgrade`, cleanup, key package report. Holds NVIDIA packages by default unless `--nvidia`. |
| Snap | `scripts/update-snap.sh` | Runs `snap refresh`, retries with `--ignore-running` when needed, reports configured snaps, removes disabled revisions. |
| Homebrew | `scripts/update-brew.sh` | `brew update`, upgrades formulas/casks, cleanup, `brew doctor`, and configured package report. Runs brew as invoking user (not root). |
| npm | `scripts/update-npm.sh` | Updates installed global packages, installs missing from config, and enforces latest versions for priority AI CLIs. |
| pip/pipx | `scripts/update-pip.sh` | Updates `pip` user packages and `pipx` apps, installs missing from config. |
| Flatpak | `scripts/update-flatpak.sh` | Updates metadata and apps, installs missing configured apps, removes unused runtimes. |
| Drivers/Firmware | `scripts/update-drivers.sh` | NVIDIA status checks and optional NVIDIA APT upgrade (`--nvidia`), `ubuntu-drivers` recommendations, `fwupd` checks, kernel/reboot status. |
| Inventory | `scripts/update-inventory.sh` | Rebuilds `APPS.md` from detected system state (APT/Snap/Brew/npm/Drivers/Firmware/Flatpak/Sources). |

## Architecture

Project layout:

- `update-all.sh` — master orchestrator
- `scripts/update-*.sh` — per-manager update units
- `lib/common.sh` — logging, summary counters, sudo helpers, user-context helpers
- `lib/detect.sh` — manager/package/system detection + config parsing helpers
- `lib/repos.sh` — idempotent APT repo setup by repo ID
- `config/*.list` — package/repo configuration
- `setup.sh` — bootstrap, discovery, drift check, and rollback for config files
- `systemd/` — weekly timer installation assets

Important runtime rules:
- `INVENTORY_SILENT=1` is set by master run to avoid repeated `APPS.md` regeneration by sub-scripts.
- Master script authenticates sudo once at start and keeps sudo credentials alive during run.
- Homebrew/npm/pipx operations use non-root user context via helper wrappers.
- MEGA repository is maintained as `megaio.sources`; legacy `meganz.list` is removed automatically if present.

## Migration

`setup.sh` modes:

```bash
./setup.sh                  # migrate/install from config
./setup.sh --discover       # scan machine -> rewrite config/*.list
./setup.sh --update-config  # merge-style discovery update
./setup.sh --check          # show config vs installed drift
./setup.sh --rollback       # restore latest config backups
```

Useful flags:

```bash
./setup.sh --nvidia
./setup.sh --no-brew --no-snaps --no-npm
./setup.sh --non-interactive
```

Automated weekly run (systemd):

```bash
./systemd/install-timer.sh
./systemd/install-timer.sh --status
./systemd/install-timer.sh --remove
```

Timer runs `update-all.sh --no-drivers` on schedule.

## Git & GitHub

Manual workflow:

```bash
git status
git add <files>
git commit -m "message"
git push origin main
```

Helper workflow (token from `.env.local`):

```bash
bash lib/git-push.sh status
bash lib/git-push.sh push main
bash lib/git-push.sh commit "Update configs" main
```

CI validation (`.github/workflows/validate.yml`) checks:
- config syntax in `config/*.list`
- shell syntax (`bash -n`)
- required files presence
- `APPS.md` is gitignored
- basic secret/token pattern scan

## Troubleshooting

- `apt-get update` fails on MEGA source conflict:
  - keep `/etc/apt/sources.list.d/megaio.sources`
  - remove legacy `/etc/apt/sources.list.d/meganz.list`
  - current scripts do this automatically during APT repo ensure step
- NVIDIA DKMS issues after kernel changes:
  - run `./scripts/rebuild-dkms.sh`
  - use `./update-all.sh --nvidia` only when you intend to upgrade NVIDIA packages
- Homebrew cleanup permission warnings:
  - script auto-repairs ownership under `${BREW_PREFIX}/Cellar` and retries cleanup
- inventory refresh only:
  - run `./scripts/update-inventory.sh`
