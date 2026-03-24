# CLAUDE.md — Ubuntu_Aktualizacje

Project context for Claude Code sessions in this repo.

---

## What this project is

A single-command Ubuntu 24.04 update suite for Dell Precision 5520 (mk-uP5520).
Covers APT, Snap, Homebrew (Linuxbrew), npm, pip/pipx, Flatpak, NVIDIA drivers, and firmware.
After every run it regenerates `APPS.md` — a machine-specific package inventory (gitignored).

---

## Key architecture rules

| Rule | Why |
|------|-----|
| `config/*.list` are the **source of truth** | Scripts read from them; never hardcode package names in scripts |
| `APPS.md` is **always gitignored** | Machine-specific; `APPS.md.example` is the committed template |
| `INVENTORY_SILENT=1` is exported by `update-all.sh` | Prevents sub-scripts from regenerating `APPS.md` individually |
| `UPGRADE_NVIDIA` env var controls NVIDIA apt | Default `0` (held); set to `1` via `--nvidia` flag |
| `run_silent_as_user` / `run_as_user` for brew/npm | Brew and npm refuse to run as root; these helpers drop to `$SUDO_USER` |

---

## Entry points

```
update-all.sh           ← master (run this)
scripts/update-*.sh     ← individual groups
setup.sh                ← first-run bootstrap / migration
```

### update-all.sh flags

| Flag | Effect |
|------|--------|
| _(none)_ | Full update, NVIDIA packages held during apt |
| `--nvidia` | Also upgrade NVIDIA driver via apt (DKMS may fail on mainline kernels) |
| `--no-drivers` | Skip `update-drivers.sh` entirely |
| `--dry-run` | Print what would run, don't execute |
| `--no-notify` | Suppress desktop notification |
| `--only <group>` | Run one group: apt \| snap \| brew \| npm \| pip \| flatpak \| drivers \| inventory |

---

## Library files

| File | Provides |
|------|----------|
| `lib/common.sh` | Colors, `print_*` helpers, `run_silent`, `run_silent_as_user`, `run_as_user`, `require_sudo`, counters |
| `lib/detect.sh` | `detect_package_managers`, `detect_gpu`, `scan_*`, `apt_pkg_version`, `brew_*`, `npm_*` helpers |
| `lib/repos.sh` | Idempotent APT repo setup (keyed by ID) |
| `lib/git-push.sh` | Push to GitHub using token from `.env.local` |

---

## Known system quirks (mk-uP5520)

- **Kernel 6.17.0-19-generic** is a standard Ubuntu kernel. NVIDIA 570 DKMS loads correctly. If ever switching to a mainline kernel (6.19.x+), DKMS will need a rebuild — use `scripts/rebuild-dkms.sh`.
- **`nvidia-driver-570`** (570.211.01) is installed and `nvidia-smi` works (Quadro M1200, driver 570.211.01). Default run holds NVIDIA packages via `apt-mark hold` to prevent unintended upgrades.
- **Brew runs under user `mk`**, not root. `SUDO_USER=mk` when running via `sudo ./update-all.sh`. All brew/npm calls use `run_as_user()` / `run_silent_as_user()` to drop back.
- **npm** is provided by brew node (v25.8.1), not system apt. `NPM_BIN` is set in `detect_package_managers()`.
- **MEGA duplicate APT source**: both `megaio.sources` and `meganz.list` exist in `/etc/apt/sources.list.d/`. `apt-get update` prints harmless warnings but succeeds (exit 0). To fix: `sudo rm /etc/apt/sources.list.d/meganz.list` (keep the `.sources` file which is the newer format).

---

## Common tasks

```bash
# Full update (safe, NVIDIA held):
./update-all.sh

# Update + attempt NVIDIA driver upgrade:
./update-all.sh --nvidia

# Only update brew formulas/casks:
./update-all.sh --only brew

# Regenerate APPS.md only:
./scripts/update-inventory.sh

# Rebuild NVIDIA DKMS for current kernel:
./scripts/rebuild-dkms.sh

# Validate shell syntax on all scripts:
bash -n update-all.sh && bash -n scripts/*.sh && bash -n lib/*.sh

# Push to GitHub:
bash lib/git-push.sh push main
```

---

## Adding packages

```bash
# APT:       echo "package-name  # description" >> config/apt-packages.list
# Snap:      echo "snap-name"                    >> config/snap-packages.list
# Brew:      echo "formula"                      >> config/brew-formulas.list
# Brew cask: echo "cask-name"                    >> config/brew-casks.list
# npm:       echo "package"                      >> config/npm-globals.list
# pip:       echo "package"                      >> config/pip-packages.list
# pipx:      echo "tool"                         >> config/pipx-packages.list
# Flatpak:   echo "org.Example.App"              >> config/flatpak-packages.list
```

---

## Log files

Written to `./logs/` (gitignored). Format:
- `master_YYYYMMDD_HHMMSS.log` — full `update-all.sh` run
- `update_YYYYMMDD_HHMMSS.log` — individual script run

---

## What NOT to do

- Don't commit `APPS.md` — it's machine-specific and gitignored
- Don't commit `.env.local` — it contains the GitHub PAT
- Don't add `ubuntu-drivers autoinstall` — it selects the "recommended" driver (535) which downgrades the explicitly-managed driver-570 and can fail DKMS on mainline kernels
- Don't run brew/npm as root — always use `run_as_user()` / `run_silent_as_user()`

---

## CI

`.github/workflows/validate.yml` runs on push to `main` when `config/`, `scripts/`, or `lib/` change:
1. Config `.list` file syntax check
2. `bash -n` on all `.sh` files
3. Required files presence check
4. `APPS.md` gitignore check
5. Secret scan (no PAT tokens committed)
