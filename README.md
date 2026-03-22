# Ubuntu_Aktualizacje

**Professional system update & inventory management for Ubuntu 24.04**

> Developed for: Dell Precision 5520 · Ubuntu 24.04.4 LTS · mk-uP5520
> GitHub: [KasprowiczM/Ubuntu_Aktualizacje](https://github.com/KasprowiczM/Ubuntu_Aktualizacje)

---

## Overview

`Ubuntu_Aktualizacje` (Polish: "Ubuntu Updates") is a single-command update suite that keeps every package manager, driver, and firmware component on your Ubuntu system up to date — silently, with color-coded output and full logging.

**One command to update everything:**
```bash
./update-all.sh
```

After every run, `APPS.md` is automatically regenerated with current package versions.

---

## Project Structure

```
Ubuntu_Aktualizacje/
├── update-all.sh               ← Master script (run this)
├── setup.sh                    ← Migration/bootstrap + --discover + --rollback
├── APPS.md                     ← GITIGNORED — machine-specific, auto-generated
├── APPS.md.example             ← Committed format reference
├── README.md                   ← This file
│
├── config/                     ← Source of truth — what should be installed
│   ├── apt-packages.list       ← APT packages
│   ├── apt-repos.list          ← Third-party APT repo IDs
│   ├── snap-packages.list      ← Snap packages (with optional flags)
│   ├── brew-formulas.list      ← Homebrew formulas
│   ├── brew-casks.list         ← Homebrew casks
│   ├── npm-globals.list        ← npm global packages
│   ├── pip-packages.list       ← pip user packages
│   ├── pipx-packages.list      ← pipx isolated tools
│   └── flatpak-packages.list   ← Flatpak apps
│
├── scripts/
│   ├── update-apt.sh           ← APT: OS + all third-party repos
│   ├── update-snap.sh          ← Snap packages
│   ├── update-brew.sh          ← Homebrew formulas + casks
│   ├── update-npm.sh           ← npm global packages + audit
│   ├── update-pip.sh           ← pip user packages + pipx tools
│   ├── update-flatpak.sh       ← Flatpak applications
│   ├── update-drivers.sh       ← NVIDIA driver, firmware (fwupd)
│   ├── update-inventory.sh     ← Regenerates APPS.md
│   ├── rebuild-dkms.sh         ← Rebuild DKMS modules (NVIDIA on new kernels)
│   └── notify.sh               ← Desktop notification helper
│
├── lib/
│   ├── common.sh               ← Shared library (colors, logging, helpers)
│   ├── detect.sh               ← Universal scanner (OS, hardware, all pkg managers)
│   ├── repos.sh                ← APT repository setup functions
│   └── git-push.sh             ← GitHub push helper (uses .env.local token)
│
├── systemd/
│   ├── ubuntu-aktualizacje.service  ← systemd service template
│   ├── ubuntu-aktualizacje.timer    ← Weekly timer (Sunday 03:00)
│   └── install-timer.sh             ← Install/remove/status the timer
│
├── .github/
│   └── workflows/
│       └── validate.yml        ← CI: syntax check, config validation, secret scan
│
└── logs/                       ← Timestamped run logs (gitignored)
```

---

## Quick Start

### Run a full update
```bash
./update-all.sh
```

### Options
```bash
./update-all.sh --no-drivers     # Skip driver & firmware updates
./update-all.sh --dry-run        # Preview what would run
./update-all.sh --no-notify      # Suppress desktop notification
./update-all.sh --only apt       # Run only one group
```

**Groups for `--only`:** `apt` | `snap` | `brew` | `npm` | `pip` | `flatpak` | `drivers` | `inventory`

### Run individual scripts
```bash
./scripts/update-apt.sh
./scripts/update-snap.sh
./scripts/update-brew.sh
./scripts/update-npm.sh
./scripts/update-pip.sh
./scripts/update-flatpak.sh
./scripts/update-drivers.sh
./scripts/rebuild-dkms.sh        # Rebuild NVIDIA modules for current kernel
./scripts/update-inventory.sh    # Refresh APPS.md only
```

---

## What Gets Updated

| Group | Script | Covers |
|-------|--------|--------|
| **APT** | `update-apt.sh` | Ubuntu OS, Brave, Chrome, VSCode, Docker, MegaSync, ProtonVPN, ProtonMail, RDM, Grub Customizer, NVIDIA driver, Rclone |
| **Snap** | `update-snap.sh` | Firefox, Thunderbird, KeePassXC, htop; auto-removes disabled revisions |
| **Homebrew** | `update-brew.sh` | gemini-cli, opencode, qwen-code, node, ripgrep, python@3.14, gcc, claude-code (cask), codex (cask) |
| **npm** | `update-npm.sh` | All global npm packages via brew Node.js; installs from config; runs `npm audit` |
| **pip** | `update-pip.sh` | pip user packages + pipx isolated tools; upgrades all outdated |
| **Flatpak** | `update-flatpak.sh` | All Flatpak apps; cleans unused runtimes |
| **Drivers** | `update-drivers.sh` | NVIDIA 580 (apt), NVIDIA Container Toolkit, ubuntu-drivers autoinstall, Dell/Intel/GPU firmware (fwupd) |
| **Inventory** | `update-inventory.sh` | Regenerates `APPS.md` with full current state |

---

## Config Files — Adding New Packages

**Everything is config-driven.** To add a new package:

```bash
# Add an APT package:
echo "package-name  # description" >> config/apt-packages.list

# Add a snap:
echo "snap-name  # description" >> config/snap-packages.list

# Add a brew formula:
echo "formula-name  # description" >> config/brew-formulas.list

# Add an npm global:
echo "package-name  # description" >> config/npm-globals.list

# Add a pip package:
echo "package-name  # description" >> config/pip-packages.list

# Add a pipx tool:
echo "tool-name  # description" >> config/pipx-packages.list

# Add a Flatpak app (use app ID):
echo "org.example.App  # description" >> config/flatpak-packages.list
```

---

## Migration to a New Machine

### Prerequisites
- Ubuntu 24.04 LTS (fresh install)
- `git`, `curl`, `sudo` access

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/KasprowiczM/Ubuntu_Aktualizacje.git
cd Ubuntu_Aktualizacje

# 2. Run setup
chmod +x setup.sh
./setup.sh

# Optional flags:
# --nvidia           Install NVIDIA driver (auto-detected)
# --no-brew          Skip Homebrew
# --no-snaps         Skip Snap packages
# --non-interactive  No prompts (CI/automation)
```

### setup.sh modes

```bash
./setup.sh                  # Migrate: install from config/
./setup.sh --discover       # Scan this machine → write config files
./setup.sh --check          # Show installed vs missing (no changes)
./setup.sh --rollback       # Restore config files from latest backup
```

### Capturing a new machine's state

```bash
# On the machine you want to capture:
./setup.sh --discover

# Review generated config files:
cat config/apt-packages.list
cat config/brew-formulas.list
# etc.

# Commit and push:
bash lib/git-push.sh push main
```

---

## Git & GitHub

### Setup (first time)

```bash
git remote set-url origin https://github.com/KasprowiczM/Ubuntu_Aktualizacje.git
git branch -M main
```

### Pushing with a GitHub Personal Access Token

Token is stored in `.env.local` (gitignored — **never committed**):

```bash
# Create .env.local in the project root:
echo "GITHUB_TOKEN=github_pat_xxxx..." > .env.local
```

Then push:
```bash
# Using the helper (reads token from .env.local):
bash lib/git-push.sh push

# Or manually:
source .env.local
git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/KasprowiczM/Ubuntu_Aktualizacje.git"
git push -u origin main
git remote set-url origin https://github.com/KasprowiczM/Ubuntu_Aktualizacje.git  # restore clean URL
```

### lib/git-push.sh usage

```bash
bash lib/git-push.sh push [branch]           # Push current branch
bash lib/git-push.sh commit "message" [branch]  # Stage + commit + push
bash lib/git-push.sh status                  # Show remote and branch
```

### Keeping APPS.md out of git

`APPS.md` is machine-specific and is **always gitignored** (via `.env*` + `APPS.md` entries in `.gitignore`). Use `APPS.md.example` as a format reference. The file is regenerated on every machine by `update-inventory.sh`.

---

## Automated Weekly Updates (systemd timer)

```bash
# Install weekly timer (Sunday 03:00, skips drivers):
./systemd/install-timer.sh

# Check timer status:
./systemd/install-timer.sh --status

# Run manually now:
sudo systemctl start ubuntu-aktualizacje@mk.service

# View logs:
journalctl -u ubuntu-aktualizacje@mk.service

# Remove timer:
./systemd/install-timer.sh --remove
```

The timer runs `update-all.sh --no-drivers` to avoid unattended firmware updates. Driver/firmware updates should be reviewed and applied manually.

---

## NVIDIA / DKMS

When running a mainline kernel (e.g. 6.19.x), NVIDIA modules may need rebuilding:

```bash
# Check DKMS status:
./scripts/rebuild-dkms.sh --status

# Rebuild for current kernel:
./scripts/rebuild-dkms.sh

# Rebuild for all installed kernels:
./scripts/rebuild-dkms.sh --all-kernels
```

After rebuild, a reboot is needed to load the new modules.

---

## Logs

Every run writes a timestamped log to `./logs/`:

```
logs/
├── master_20260322_141500.log    ← update-all.sh run
├── update_20260322_141503.log    ← individual script run
├── setup_20260322_130000.log     ← setup.sh run
└── systemd_update.log            ← automated timer runs
```

---

## GitHub Actions CI

On every push to `main` (when `config/`, `scripts/`, or `lib/` changes), the workflow at `.github/workflows/validate.yml` runs:

1. **Config syntax validation** — checks all `.list` files for invalid lines
2. **Shell syntax check** — `bash -n` on all `.sh` files
3. **Required files check** — verifies all expected files exist
4. **APPS.md gitignore check** — ensures machine inventory is never committed
5. **Secret scan** — checks for accidentally committed GitHub tokens

---

## Hardware Notes (Dell Precision 5520)

- **GPU:** NVIDIA Quadro M1200 Mobile + Intel HD 630
- **Driver:** NVIDIA 580 via Ubuntu HWE repository
- **Firmware:** Dell BIOS, Intel CPU microcode via `fwupd`
- **Note:** `nvidia-smi` requires reboot after kernel updates (DKMS rebuild needed for mainline kernels)

---

## Troubleshooting

```bash
# APT broken after adding repos:
sudo apt-get update --fix-missing && sudo apt-get install -f

# Homebrew issues:
brew doctor && brew cleanup

# Snap refresh fails (snap-store must close):
sudo snap refresh --ignore-running

# NVIDIA not loading after kernel update:
./scripts/rebuild-dkms.sh && sudo reboot

# fwupd firmware update:
sudo fwupdmgr refresh --force && sudo fwupdmgr update

# Push to GitHub (no SSH key):
bash lib/git-push.sh push main
```

---

## Requirements

| Requirement | Version |
|-------------|---------|
| Ubuntu | 24.04 LTS |
| bash | ≥ 5.0 |
| sudo | any |
| git | any |
| Homebrew | ≥ 4.0 (auto-installed by setup.sh) |
| snapd | ≥ 2.60 (pre-installed on Ubuntu) |

---

*Maintained by mk · Dell Precision 5520 · Ubuntu 24.04*
*GitHub: [KasprowiczM/Ubuntu_Aktualizacje](https://github.com/KasprowiczM/Ubuntu_Aktualizacje)*
