# Ubuntu_Aktualizacje

**Professional system update & inventory management for Ubuntu 24.04**

> Developed for: Dell Precision 5520 · Ubuntu 24.04.4 LTS · mk-uP5520

---

## Overview

`Ubuntu_Aktualizacje` (Polish: "Ubuntu Updates") is a single-command update suite that keeps every package manager, driver, and firmware component on your Ubuntu system up to date — silently, with color-coded status output and full logging.

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
├── setup.sh                    ← Migration/bootstrap for a new machine
├── APPS.md                     ← Auto-generated software inventory
├── README.md                   ← This file
│
├── scripts/
│   ├── update-apt.sh           ← APT: OS + all third-party repos
│   ├── update-snap.sh          ← Snap packages
│   ├── update-brew.sh          ← Homebrew formulas + casks
│   ├── update-npm.sh           ← npm global packages (via brew node)
│   ├── update-drivers.sh       ← NVIDIA driver, firmware (fwupd)
│   └── update-inventory.sh     ← Regenerates APPS.md
│
├── lib/
│   └── common.sh               ← Shared library (colors, logging, helpers)
│
└── logs/                       ← Timestamped run logs (auto-created)
    └── update_YYYYMMDD_HHMMSS.log
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
./update-all.sh --only apt       # Run only one group: apt|snap|brew|npm|drivers
```

### Run individual scripts
```bash
./scripts/update-apt.sh          # APT packages only
./scripts/update-snap.sh         # Snap packages only
./scripts/update-brew.sh         # Homebrew only
./scripts/update-npm.sh          # npm globals only
./scripts/update-drivers.sh      # NVIDIA + firmware only
./scripts/update-inventory.sh    # Refresh APPS.md only
```

---

## What Gets Updated

| Group | Script | What it covers |
|-------|--------|----------------|
| **APT** | `update-apt.sh` | Ubuntu OS, Brave, Chrome, VSCode, Docker, MegaSync, ProtonVPN, ProtonMail, RDM, Grub Customizer, NVIDIA driver 580, Rclone |
| **Snap** | `update-snap.sh` | Firefox, Thunderbird, KeePassXC, htop, snap-store, firmware-updater |
| **Homebrew** | `update-brew.sh` | gemini-cli, opencode, qwen-code, node, ripgrep, python@3.14, gcc, openssl@3, claude-code (cask), codex (cask) |
| **npm** | `update-npm.sh` | Global npm packages via brew Node.js |
| **Drivers** | `update-drivers.sh` | NVIDIA driver 580 (apt), NVIDIA Container Toolkit, ubuntu-drivers autoinstall, Dell BIOS/Intel/GPU firmware (fwupd) |
| **Inventory** | `update-inventory.sh` | Regenerates `APPS.md` with current versions |

---

## Package Managers & Repositories

### APT Sources

| Application | Repository |
|-------------|-----------|
| Brave Browser | `brave-browser-release.sources` |
| Google Chrome | `google-chrome.list` |
| VS Code | `vscode.sources` (Microsoft) |
| Docker CE | `docker.sources` |
| NVIDIA Container Toolkit | `nvidia-container-toolkit.list` |
| MegaSync | `meganz.list` |
| ProtonVPN / Proton Mail | `protonvpn-stable.sources` |
| Grub Customizer | PPA: `danielrichter2007/grub-customizer` |

### Homebrew (Linuxbrew)
- Prefix: `/home/linuxbrew/.linuxbrew`
- Node.js version used: v25.x (brew) — **not** the system apt nodejs 18.x
- Casks: `claude-code`, `codex`

### Snap
- Managed by `snapd` — auto-updates are also enabled by default
- User-visible snaps: Firefox, Thunderbird, KeePassXC, htop

---

## Logs

Every run writes a timestamped log to `./logs/`:

```
logs/
├── master_20260322_141500.log   ← update-all.sh run
├── update_20260322_141503.log   ← individual script run
└── setup_20260322_130000.log    ← setup.sh run
```

Logs contain: timestamps, all commands run, stdout/stderr of each operation, and a final summary.

---

## APPS.md — Inventory File

`APPS.md` is auto-generated after every full update. It contains:
- All APT packages (OS + third-party) with versions
- All snap packages with revision and channel
- All Homebrew formulas and casks with versions
- npm global packages
- NVIDIA driver version
- Firmware versions (Dell BIOS, Intel CPU microcode, GPU vBIOS)
- APT source list

**Do not edit `APPS.md` manually** — it is overwritten on each run.

---

## Hardware Notes (Dell Precision 5520)

- **GPU:** NVIDIA Quadro M1200 Mobile (GM107GLM) + Intel HD 630
- **Driver:** NVIDIA 580 series via Ubuntu HWE repository
- **Firmware:** Managed by `fwupd` — Dell BIOS updates, Intel CPU microcode
- **Kernel:** Running mainline 6.19.x — NVIDIA modules may require reboot after kernel updates

> **NVIDIA note:** `nvidia-smi` requires a reboot after kernel updates. The NVIDIA driver (580) is installed via apt — if a new kernel is installed, the system must reboot to load the new kernel modules.

---

## Migration to a New Machine

### Prerequisites on the new machine
- Ubuntu 24.04 LTS (fresh install recommended)
- `git`, `curl`, `sudo` access

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/Ubuntu_Aktualizacje.git
cd Ubuntu_Aktualizacje

# 2. Run the setup script
chmod +x setup.sh
./setup.sh

# Optional flags:
# --nvidia           Install NVIDIA driver 580 (for NVIDIA GPU systems)
# --skip-brew        Skip Homebrew installation
# --skip-snaps       Skip Snap package installation
# --non-interactive  No prompts (for automation/CI)
```

### What `setup.sh` does

1. Verifies Ubuntu 24.04
2. Installs APT prerequisites (`curl`, `git`, `gpg`, `build-essential`, etc.)
3. Adds all third-party APT repositories with proper GPG keys
4. Installs all APT applications (Brave, Chrome, VSCode, Docker, MegaSync, ProtonVPN, etc.)
5. Installs Homebrew (Linuxbrew) and configures shell PATH
6. Installs Homebrew formulas: `gemini-cli`, `opencode`, `qwen-code`, `node`, `ripgrep`, `python@3.14`, etc.
7. Installs Homebrew casks: `claude-code`, `codex`
8. Installs Snap packages: Firefox, Thunderbird, KeePassXC, htop
9. Adds user to the `docker` group
10. Makes all scripts executable
11. Optionally runs `update-all.sh` for initial update
12. Generates initial `APPS.md`

### Manual steps after `setup.sh`

```bash
# Apply PATH changes
source ~/.bashrc

# Log out/in for docker group to take effect
# Or: newgrp docker

# Install Remote Desktop Manager manually (not in public repo):
# Download from: https://devolutions.net/remote-desktop-manager/home/linuxdownload
# sudo dpkg -i remotedesktopmanager_amd64.deb && sudo apt-get install -f

# Apply firmware updates (review first):
# fwupdmgr get-updates
# fwupdmgr update
```

---

## Scheduling (Optional — cron/systemd)

To run updates automatically, add a cron job:

```bash
# Edit crontab
crontab -e

# Run every Sunday at 3:00 AM
0 3 * * 0 cd /path/to/Ubuntu_Aktualizacje && ./update-all.sh --no-drivers >> /dev/null 2>&1
```

Or use a systemd timer for better logging integration.

> **Driver/firmware updates are excluded from cron** by design — these should be reviewed manually before applying, especially firmware updates which can brick hardware if interrupted.

---

## Troubleshooting

### APT errors after adding repos
```bash
sudo apt-get update --fix-missing
sudo apt-get install -f
```

### Homebrew issues
```bash
brew doctor
brew cleanup
```

### NVIDIA driver not loading
```bash
# Check kernel modules
lsmod | grep nvidia
# Rebuild if needed
sudo dkms status
# Usually just needs a reboot
sudo reboot
```

### Snap refresh fails (snap-store must be closed)
```bash
sudo snap refresh --ignore-running
```

### fwupd firmware updates fail
```bash
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates
sudo fwupdmgr update
```

---

## Contributing

This project is designed for the specific hardware and software stack on `mk-uP5520`. To adapt for a different machine:

1. Edit `scripts/update-apt.sh` — update the `KEY_PKGS` array
2. Edit `scripts/update-inventory.sh` — update the `APT_APPS` map
3. Edit `setup.sh` — update `APT_APPS` and `BREW_FORMULAS` arrays
4. Update `APPS.md` manually once, then let `update-inventory.sh` take over

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
