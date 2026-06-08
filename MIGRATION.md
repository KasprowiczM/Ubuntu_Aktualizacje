# Ascendo — migration to a new Ubuntu machine

Quick guide for installing/testing this project on a fresh Ubuntu 24.04 host.

## TL;DR (one-liner)

For a fresh install, run the master installer:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/KasprowiczM/Ubuntu_Aktualizacje/main/install.sh)"
```

Alternatively, you can manually clone and run:

```bash
git clone https://github.com/KasprowiczM/Ubuntu_Aktualizacje ~/Dev_Env/Ubuntu_Aktualizacje
cd ~/Dev_Env/Ubuntu_Aktualizacje
bash scripts/fresh-machine.sh
```

The installer verifies host conditions, installs prerequisites, prompts to **discover currently installed applications** (building your custom local inventory to avoid forcing uninstalled template apps), restores the private overlay from Proton (if developer mode is chosen), configures the dashboard Python venv, and installs the systemd user service. Flags for `fresh-machine.sh` include: `--check-only`, `--dry-run`, `--no-dashboard`, `--no-service`, `--no-sync`, `--lang en|pl`.

After it finishes:

```bash
xdg-open http://127.0.0.1:8766   # dashboard
./update-all.sh --profile quick  # 15s read-only sweep, no sudo
```

## What `fresh-machine.sh` does, in order

| Step | Action | Skip flag |
|------|--------|-----------|
| 0 | Pick language (EN / PL), persist to `~/.config/ascendo/lang` | `--lang <code>` to bypass prompt |
| 1 | `scripts/preflight.sh` — check tools/versions | n/a |
| 2 | If Proton/rclone present: `scripts/restore-from-proton.sh` (private overlay) | `--no-sync` |
| 3 | `bash setup.sh` — bootstraps repo helpers, configures hosts dir | n/a |
| 4 | `bash app/install.sh` — creates `app/.venv/`, installs FastAPI/uvicorn/pydantic/httpx | `--no-dashboard` |
| 5 | `bash systemd/user/install-dashboard.sh` — user-service + Ascendo icon + .desktop | `--no-service` |
| 6 | `bash scripts/verify-state.sh` — sanity check | n/a |
| 7 | `bin/ascendo-ubuntu apps detect` — read-only diff between `config/*.list` and installed packages | n/a |

It **never installs packages on its own**. Use the dashboard (Apps tab) or
`bin/ascendo-ubuntu apps install-missing` after reviewing the detect report.

## Manual prerequisites (only if preflight reports them)

```bash
sudo apt install -y git python3 python3-venv python3-pip rclone timeshift bats
```

Optional but recommended:

```bash
sudo apt install -y etckeeper                   # snapshot fallback
brew install                                    # if you want Homebrew
```

## Icon / desktop entry

If you previously installed the old `.deb` (`ubuntu-aktualizacje 0.1.0`), it
still ships the legacy icon at `/usr/share/icons/...`. To pick up the new
Ascendo branding:

**Option A — user-level (recommended for testing):**
```bash
bash systemd/user/install-dashboard.sh
# Drops new ascendo icon in ~/.local/share/icons/...
```

**Option B — replace the old system-wide .deb:**
```bash
# Remove whichever legacy .deb is installed (name varies by build vintage):
dpkg -l | grep -E '^ii\s+(ascendo|ubuntu-aktualizacje|ascendo-ubuntu)\b' | awk '{print $2}' \
  | xargs -r sudo apt remove -y

# Build and install the new one (package name is `ascendo-ubuntu`):
bash packaging/build-deb.sh                      # prints "install with: sudo dpkg -i …"
sudo dpkg -i dist/ascendo-ubuntu_*_all.deb
```

> The build script prints the exact install command at the end of its output
> — copy-paste that line. Older builds may produce
> `ubuntu-aktualizacje_<ver>_all.deb` or `ascendo_<ver>_all.deb` instead;
> either filename works as long as you pass the full path to `dpkg -i`.

After either option, log out / log back in (or run
`update-desktop-database ~/.local/share/applications` and
`gtk-update-icon-cache ~/.local/share/icons/hicolor`) so GNOME/Activities
re-reads the desktop database.

## Sanity checks after migration

```bash
./update-all.sh --profile quick --no-notify       # ~15s, all 6 categories should pass
bin/ascendo-ubuntu health --json                          # post-run health audit
bin/ascendo-ubuntu apps detect                            # tracked / detected / missing report
python3 tests/validate_phase_json.py | tail -3     # all sidecars schema-valid

# Dashboard:
systemctl --user status ascendo-ubuntu-dashboard.service
curl -s http://127.0.0.1:8766/health | jq .

# Sudo flow (only if you intend to run apply phases):
curl -s -X POST -H 'content-type: application/json' \
     -d '{"password":"YOUR_PASSWORD"}' \
     http://127.0.0.1:8766/sudo/auth
```

## First real apply run

Pick one:

```bash
./update-all.sh --profile safe --snapshot         # safe: skips drivers, takes pre-apply snapshot
./update-all.sh --profile full                    # full: includes drivers (NVIDIA still held by default)
./update-all.sh --profile full --nvidia           # opt-in to NVIDIA upgrades
```

Or use the dashboard buttons: **Quick check / Safe update / Full update /
Full dry-run** on the Overview tab.

## Profile templates

```bash
ascendo-ubuntu profile list                              # dev-workstation, media-server, minimal-laptop
ascendo-ubuntu profile import dev-workstation --dry-run  # preview
ascendo-ubuntu profile import dev-workstation            # writes diff into config/*.list
```

## Settings export / import (move config between hosts)

```bash
# Source machine:
ascendo-ubuntu settings export ~/ascendo-backup.tar.gz

# Target machine:
scp ~/ascendo-backup.tar.gz target:~/
ssh target 'cd ~/Dev_Env/Ubuntu_Aktualizacje && ascendo-ubuntu settings import ~/ascendo-backup.tar.gz'
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Dashboard 404 on `/` | `bash app/install.sh && systemctl --user restart ascendo-ubuntu-dashboard.service` |
| `apt apply` exits silently with no sidecar | Fixed in v0.5.1 — pull latest, re-run |
| Old icon still showing in menu | See "Icon / desktop entry" section above; log out / log in |
| `pip install` blocked by PEP 668 | Always use `app/.venv/`; never `pip install --user` |
| `sudo` prompts repeatedly | Master script asks once and uses askpass helper for the whole run; if you bypass it, use `sudo -v` first |
| Snapshot timeshift hangs | We bound it to 300s and never block the run; warning shown if fallback to etckeeper kicks in |
| Run shows green but nothing changed | Check `logs/runs/<id>/<cat>/apply.log` AND `apply.json` exists; if json missing → bug, file an issue |

## Full reference

- `RUN.md` — exhaustive operator guide (all flags, all endpoints, all troubleshooting).
- `CLAUDE.md` — project conventions and agent rules.
- `docs/agents/contract.md` — 5-phase JSON sidecar contract (schema v1).
- `docs/agents/hybrid-mode.md` — CLI vs dashboard parity matrix.
