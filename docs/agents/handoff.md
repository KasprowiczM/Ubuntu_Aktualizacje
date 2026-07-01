# Handoff

## 2026-07-01 (Etap 16) — Remove Gemini CLI from Updates and System

### Gemini CLI Removal
- **Goal**: Fully uninstall `gemini-cli` / `@google/gemini-cli` and exclude it from future global packages update and planning cycles.
- **Actions**:
  1. Ran `npm uninstall -g @google/gemini-cli` to remove it from global npm packages.
  2. Removed `@google/gemini-cli` from [config/npm-globals.list](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/config/npm-globals.list).
  3. Cleaned up comments in [config/brew-formulas.list](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/config/brew-formulas.list).
  4. Updated [scripts/npm/apply.sh](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/scripts/npm/apply.sh), [scripts/npm/plan.sh](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/scripts/npm/plan.sh), and [scripts/update-npm.sh](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/scripts/update-npm.sh) to exclude it from updates, checks, and plan items.
  5. Updated [docs/last-run-review.md](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/docs/last-run-review.md) status table.
- **Verification Status**:
  - Run syntax check: `bash -n` checks pass.
  - Python dev sync safety tests pass.
  - Dry run check: `./update-all.sh --dry-run` runs successfully without any planned action for Gemini CLI.
  - Verification: `bash scripts/verify-state.sh` reports a clean **OVERALL PASS** (0 failures, 0 warnings).
  - Exported dev-sync to Proton Drive.

---

## 2026-06-08 (Etap 15) — Discover-First Installation, Sudo check avoidance, and NVIDIA mismatch grace

### Master Installer Flow & Discovery First
- **Problem**: When a user ran `install.sh` on a new machine, `bootstrap.sh` automatically ran `setup.sh` in migrate mode, forcing all template applications from the original developer's Precision 5520 host onto the new machine.
- **Fix**:
  1. Updated `install.sh` to prompt user: `"Initialize package configuration lists with applications already installed on this host?"` (default `y`).
  2. If accepted, it executes `setup.sh --discover --non-interactive` to scan local package managers and overwrite `config/*.list` files with the local system package inventory.
  3. When bootstrap triggers, it reconciles but installs no new packages since the config lists exactly match what is already installed.
- **Removed Uninstallable Package**: Commented out `proton-mail` from the default `config/apt-packages.list` template, noting that it has no official APT repository and should be manually installed via `.deb`.

### Sudo Prompts during Read-Only Checks
- **Problem**: Running `setup.sh --check` or `update-inventory.sh` triggered a prompt for a `sudo` password because `detect_hardware` and BIOS checks invoked `sudo dmidecode`.
- **Fix**: Modified `lib/detect.sh` and `scripts/update-inventory.sh` to read details directly from `/sys/class/dmi/id/...` if readable by regular users, completely avoiding the sudo requirement for checking phases.

### NVIDIA SMI Version Mismatch Handling
- **Problem**: If the library version differs from the loaded kernel module version (common after driver package upgrades before reboot), `nvidia-smi` fails with `Driver/library version mismatch`. This was reported as a critical error, failing verification.
- **Fix**: Updated `scripts/apt/verify.sh`, `scripts/drivers/check.sh`, and `scripts/drivers/verify.sh` to detect the mismatch string, log it as a warning, and flag `needs_reboot` to true, rather than failing the exit codes.

### Setup script permission pollution
- **Problem**: `setup.sh` recursively executed `chmod +x` on all `.sh` files, modifying permissions of library scripts under `lib/`. This dirtied the working tree and broke `verify-state.sh`.
- **Fix**: Modified the search path in `setup.sh` to explicitly exclude `.git/`, `lib/`, and `.venv/` directories when setting executable bits.

### Verification Status
- Verified all shell script syntax: `bash -n` checks pass.
- Verified state checks locally: `bash scripts/verify-state.sh` reports success (excluding the git dirty check caused by uncommitted changes).
- Ran dry-runs: `./update-all.sh --dry-run` and `./update-all.sh --profile quick` pass cleanly.

---

## 2026-05-29 (Etap 14) — Rebrand GUI/CLI Package Separation & Launcher Fix

### Package Separation & Renaming
- **Core CLI Package**: Retained the package name `ascendo-ubuntu` with architecture `all` (`dist/ascendo-ubuntu_0.4.0_all.deb`).
- **Tauri GUI Package**: Renamed package, binary, and identifier to `ascendo-ubuntu-desktop` (`app/tauri/src-tauri/target/release/bundle/deb/ascendo-ubuntu-desktop_0.4.0_amd64.deb`). This fully resolves the dpkg overwrite collision where both packages attempted to install `/usr/bin/ascendo-ubuntu`.
- **Tauri Installation**: Modified `app/tauri/install-deb.sh` to remove `ascendo-ubuntu` from the legacy package purge list. This prevents the desktop installation from accidentally uninstalling the CLI package.

### Launcher Script Update
- **Problem**: The local user launcher `~/.local/bin/ascendo-ubuntu-launch` and the CLI package's launcher `packaging/deb/usr/bin/ascendo-ubuntu-launch` were outdated, still referencing `ubuntu-aktualizacje-dashboard.service` and looking for the binary name `ascendo-ubuntu` instead of `ascendo-ubuntu-desktop`.
- **Fix**:
  1. Synchronized `packaging/deb/usr/bin/ascendo-ubuntu-launch` with the corrected `share/bin/ascendo-ubuntu-launch` script.
  2. Updated the service target in the launcher from `ubuntu-aktualizacje-dashboard.service` to `ascendo-ubuntu-dashboard.service`.
  3. Added the candidate search path `/usr/bin/ascendo-ubuntu-desktop` and local paths to the `TAURI_CANDIDATES` array.
  4. Executed `systemd/user/install-dashboard.sh` to immediately refresh the local `~/.local/bin/ascendo-ubuntu-launch` file and icons under the user's home folder.

### Documentation & Verification
- Updated `scripts/fresh-machine.sh` to use the correct service name `ascendo-ubuntu-dashboard` instead of the old `ubuntu-aktualizacje-dashboard`.
- Ran full verification: `bash scripts/verify-state.sh` reports a clean **OVERALL PASS** (0 failures).
- Pushed all commits cleanly to the remote GitHub `main` branch.
- Successfully exported the private overlay configurations to Proton Drive using `bash dev-sync-export.sh` (9 overlay files updated and checksum-verified).

---

## 2026-05-29 (Etap 13) — Port Conflict Resolution & Dev-Sync Mount Fix

### Port Collision Fix
- Resolved port conflict with cross-platform version of Ascendo (`Dev_Env/Ascendo` running on default port `8765`).
- Moved this local Ubuntu dashboard web service (`Ubuntu_Aktualizacje`) default port to `8766` across all configuration files, launcher scripts, HTML templates, Tauri files, and systemd user services.
- Successfully verified both services running side-by-side:
  - `127.0.0.1:8765` for the cross-platform Ascendo app.
  - `127.0.0.1:8766` for this local `Ubuntu_Aktualizacje` dashboard.

### Dev-Sync Rclone Mount Fix
- **Problem**: The system-level rclone (`v1.60.1-DEV`) lacked native support for `type = protondrive`, causing the systemd-user unit `rclone-proton.service` to fail with: `didn't find backend called "protondrive"`. This caused the private overlay verification to fail.
- **Fix**:
  1. Installed the modern pre-built rclone binary (`v1.66.0`) locally at `~/.local/bin/rclone` (user-space, zero-root).
  2. Updated the systemd user service `~/.config/systemd/user/rclone-proton.service` to use `%h/.local/bin/rclone mount` instead of `/usr/bin/rclone`.
  3. Reloaded systemd user daemon and restarted the mount service.
- **Result**: The Proton Drive mount successfully activated and `/home/mk/ProtonDrive/Dev_Env/Ubuntu_Aktualizacje` became readable, fully passing the dev-sync consistency audit.

### Dynamic Service Lifecycle Management
- **Requirements Met**:
  1. The dashboard systemd service is explicitly **disabled** from auto-starting at user login/boot (`systemd/user/install-dashboard.sh` runs `systemctl --user disable`).
  2. When the user launches either the Tauri desktop shell or the browser web launcher (`ascendo-ubuntu-launch`), the `ascendo-ubuntu-dashboard.service` is dynamically started.
  3. When either the Tauri window is closed or the launched browser session exits, the service is dynamically stopped.
- **Tauri Implementation**: Refactored `app/tauri/src-tauri/src/main.rs` to try launching the backend via `systemctl --user start ascendo-ubuntu-dashboard.service`. If successful, it manages the service lifecycle, issuing `systemctl --user stop ...` on close window event. If systemd is unavailable, it gracefully falls back to raw Python process spawning and process killing on exit.
- **CLI/Browser Launcher Implementation**: Refactored `share/bin/ascendo-ubuntu-launch` (and its deb packaging copy) to trap exit signals, start the systemd service on launch, run persistent candidate browser applications in the foreground, and automatically stop the service on exit. For web mode, it opens the browser tab and displays a clean, user-friendly `zenity` info dialog, stopping the service automatically when the user clicks "OK" to finish the session.

### Test & Validation Fixes
- **Problem**: `tests/validate_phase_json.py` recursively scanned all `.json` files in `logs/runs/` and crashed on `health.json` (the new health check report) because it did not conform to the `phase-result.schema.json` schema.
- **Fix**: Updated `tests/validate_phase_json.py` to skip `health.json` alongside `run.json` during scanning. All 230+ sidecars now validate successfully.
- Rebuilt the staged Debian package and verified files consistency via `bash packaging/build-deb.sh`.

### Verification Status
- `./update-all.sh --profile quick` syntax check passes successfully.
- `bash scripts/verify-state.sh` reports a **100% CLEAN PASS** (0 failures, 0 warnings).
- Commited and pushed to remote `main` branch: `https://github.com/KasprowiczM/Ubuntu_Aktualizacje.git`.
- Exported overlay state to Proton Drive successfully.

---

## 2026-04-30 (Etap 12) — Inventory false-positive outdated fix + unified title

### Bug

Dashboard Categories/Overview flagged npm packages as outdated whenever
`npm outdated -g --json` returned a row, regardless of direction. Visible
case: `@google/gemini-cli 0.40.0 → 0.1.9` and `npm 11.13.0 → 10.9.8`
(both downgrades — `latest` dist-tag pointed at an older release line, npm
itself installed via brew is newer than the registry's `latest`).

Root cause: `app/backend/inventory.py::_classify` returned `outdated`
whenever `candidate != installed`, without a direction check.

### Fix

- `_ver_key(v)` + `_version_gt(a, b)` — token-based version comparator,
  splits on `.-_+`, separates numeric vs alpha runs.
- `_classify` now requires strict `_version_gt(candidate, installed)`.
- npm/pip/brew scanners null out `candidate` when not strictly newer — the
  table no longer shows a phantom downgrade arrow.

### Audit (other categories)

- **apt** — `apt list --upgradable` is direction-aware, no fix needed.
- **snap** — `snap refresh --list` store-side, OK.
- **flatpak** — `flatpak remote-ls --updates` store-side, OK.
- **drivers** — already used `dpkg --compare-versions … gt …`, OK.
- **inventory** — pseudo-category, no version compare.

### App title rename

`Ubuntu_Aktualizacje` → `Ascendo - Unified Updates` everywhere:

- `app/frontend/index.html` `<title>`
- `app/backend/main.py` FastAPI `title=`
- Repo desktop entries + `packaging/deb/usr/share/applications/`
- `~/.local/share/applications/{ascendo,ascendo-desktop}.desktop`
- `systemd/user/install-dashboard.sh` (banner + comments)
- `scripts/fresh-machine.sh` welcome string
- `app/README.md` heading

### Validation

```bash
python3 -c "from app.backend.inventory import scan_npm; \
  print([(i['name'],i['installed'],i['candidate'],i['status']) \
  for i in scan_npm() if i['status']=='outdated'])"
# []  (was 2 false-positives before fix)

curl -s http://127.0.0.1:8766/inventory/summary | jq .totals
# { ok: 340, outdated: 0, missing: 0 }

curl -s http://127.0.0.1:8766/ | grep -o '<title>[^<]*</title>'
# <title>Ascendo - Unified Updates</title>
```

---

## 2026-04-30 (late) — CRITICAL FIX: apt:apply EXIT trap override, JSON always dropped

**BUG:** `scripts/apt/apply.sh:118` unconditionally overwrote the JSON exit trap registered by `json_register_exit_trap()`, causing `apply.json` to never be written. Symptom: user runs `./update-all.sh full`, sees "all green" in CLI, but `apt list --upgradable` still shows packages outdated—apply silently skipped and never logged.

**FIX:** Composed EXIT trap to call both `_restore_*_holds()` AND `_json_finalize_on_exit()`. Added defensive sidecar synthesis in `lib/orchestrator.sh:orch_run_phase()` that detects missing JSON and forces `status=failed` (exit 30) so silent skips can never happen. Reworked `_temporarily_hold_excluded_apt` to NOT exit 0 when whole apt category is excluded—sets flag, lets main flow clean-exit with proper sidecar.

**Files:** `scripts/apt/apply.sh`, `lib/orchestrator.sh`, `MIGRATION.md` (new concise fresh-machine guide), `CLAUDE.md`.

**Validation:** `bash -n`, `./update-all.sh --profile quick --no-notify` → 6/6 ok, all sidecary present, apt items populated.

---

## 2026-05-04 (late) — Ascendo desktop icon + CLI runs in dashboard history (Etap 11)

### Stan na koniec sesji

| Obszar | Status |
|---|---|
| **Ikona Ubuntu desktop = Ascendo logo** | ✅ `share/icons/hicolor/scalable/apps/ascendo-ubuntu.svg` + `share/applications/ascendo-ubuntu.desktop` (`Name=Ascendo`, `Icon=ascendo`, `StartupWMClass=Ascendo`); poprzednio używało systemowego `software-update-available` |
| **User-level instalator ikony** | ✅ `systemd/user/install-dashboard.sh` instaluje ikonę i `.desktop` do `~/.local/share/{icons,applications}`, woła `update-desktop-database` + `gtk-update-icon-cache`, kasuje stare `ascendo-ubuntu.desktop` |
| **System-wide ikona w `.deb`** | ✅ `packaging/deb/usr/share/icons/hicolor/scalable/apps/ascendo-ubuntu.svg` + `packaging/deb/usr/share/applications/ascendo-ubuntu.desktop`, postinst odświeża bazy |
| **CLI runs widoczne w historii dashboard/web** | ✅ `db.import_disk_runs()` reconciliuje `logs/runs/<id>/run.json` z SQLite; wpięte w startup oraz w `/runs` i `/runs/{id}` |
| **Migracja `004 run_source`** | ✅ kolumna `runs.source` (`'cli'` vs `'dashboard'`); `insert_run` przyjmuje source; UI dorzuca pill **cli** w History |
| **Inferencja profilu z faz** | ✅ tylko `check` → `quick`; brak `drivers` → `safe`; reszta → `full`. `only_cat`/`only_phase` ustawiane gdy single-cat / single-kind |

### Pliki dotknięte

share/icons/hicolor/scalable/apps/ascendo-ubuntu.svg, share/applications/ascendo-ubuntu.desktop, systemd/user/install-dashboard.sh, packaging/deb/usr/share/icons/hicolor/scalable/apps/ascendo-ubuntu.svg, packaging/deb/usr/share/applications/ascendo-ubuntu.desktop, packaging/deb/DEBIAN/postinst, app/backend/migrations.py (+_m004_run_source), app/backend/db.py (import_disk_runs), app/backend/main.py (startup/lazy reconcile), app/frontend/app.js (cli pill).

### Walidacja

bash -n update-all.sh + scripts/*/*.sh + lib/*.sh + systemd/user/*.sh + DEBIAN/postinst OK; python3 ast parse app/backend/{main,runner,db,migrations,config}.py OK; import_disk_runs 28 runs OK; TestClient /runs?limit=10 → 200, mixed source OK.

### Mechanika importu

- `_RUN_ID_RE` parsuje `YYYYMMDDTHHMMSSZ-xxxxxx` → `started_at` ISO 8601.
- `ended_at`, `status`, `needs_reboot`, `phases` z `run.json`.
- `phase_results` upsertowane per faza. Idempotentne.

### Ryzyka

1. Race przy aktywnym CLI runie — `run.json` nie istnieje do finalize. Filesystem-runs pojawią się po końcu.
2. Brak hot-reload — każde przeładowanie History pokazuje nowe CLI runy, ale stronę trzymaną otwartą trzeba odświeżyć.
3. Profil heurystyką — `only_cat` + `profile=null` gdy single-category run (akceptowalne, profil w History informacyjny).

### Komendy do weryfikacji

```bash
systemctl --user restart ascendo-ubuntu-dashboard.service
./update-all.sh --profile quick --no-notify
curl -s 'http://127.0.0.1:8766/runs?limit=5' | jq '.runs[] | {id, source, profile, status}'
```

---

## 2026-05-04 — Final UX polish + profile templates + apt rollback + GH releases (Etap 10 — release v0.5)

### Stan na koniec sesji (oddajemy do użytkowników)

| Obszar | Status |
|---|---|
| **Slogan vertical pod logo** | ✅ `Ascendo` + tagline, font 0.7rem |
| **Sudo cache** w footer po prawej | ✅ `float:right` w status bar |
| **Theme switcher** auto = monitor icon | ✅ cycle monitor → sun → moon, persist localStorage |
| **Pie chart** czytelny | ✅ total + % ok wewnątrz, legend pod |
| **Sync hints PL/EN** | ✅ każdy guzik z tooltipem |
| **Sync remote dropdown + Browse** | ✅ `/sync/remotes` + `/sync/browse` (rclone lsf --dirs-only) |
| **Categories: drivers + inventory** | ✅ NVIDIA scan + APPS.md metadata |
| **Snap UX** | ✅ `SNAP-AUTO-REFRESHED` diag, blocked snap parser |
| **Help section** | ✅ 11 sekcji, 1rem font, TOC, troubleshooting |
| **About section** | ✅ version + system + Markdown release notes |
| **Hosts edit UI** | ✅ Add/Edit/Delete buttons, `.bak_<ts>` before save |
| **AI providers** | ✅ Anthropic/OpenAI/Gemini/Ollama/LM Studio + test |
| **Per-package apt rollback** | ✅ `/apt/downgrade` + ↓ button per row |
| **Profile templates** | ✅ `config/profiles/{dev-workstation,media-server,minimal-laptop}.list`, CLI `ascendo profile {list,import}` |
| **GH Releases notifier** | ✅ Settings → check_repo, 4s timeout |

### Nowe pliki

config/profiles/{dev-workstation,media-server,minimal-laptop}.list, scripts/apps/profile-import.sh.

### Zmodyfikowane (tej sesji)

app/backend/main.py (+/apt/downgrade, /profiles/*, /updates/check, /sync/remotes, /sync/browse), app/backend/inventory.py (scan_drivers, scan_inventory_meta), app/backend/settings.py (ai.base_url, sync.*, updates.*), app/backend/hosts_edit.py (NEW), app/frontend/{index.html, app.js, style.css}, app/frontend/i18n.js (PL/EN parity), app/frontend/icons.js (monitor, folder), packaging/deb/usr/bin/ascendo-ubuntu-ubuntu (settings/health/exclusions/profile subcommands), scripts/snap/apply.sh (SNAP-AUTO-REFRESHED), scripts/drivers/check.sh (dpkg --compare-versions), update-all.sh (--budget, --no-health, CHECK-ONLY banner).

### Walidacja

bash -n all .sh OK; python3 ast parse all .py OK; JS parse OK; TestClient 31 GET endpoints 31/31 → 200; POST /profiles/import (dry-run) 200 ok; `/apt/downgrade` schema OK; slogan vertical + sudo float:right confirmed; python3 tests/validate_phase_json.py PASS; test_dev_sync_safety.py 9/9 OK; `./update-all.sh --profile quick --no-notify` 6/6 ok, post-run health 100/100; `ascendo profile import dev-workstation --dry-run` added=22, skipped=10.

---

## 2026-05-03 (late) — Sidebar redesign + verbose progress + NVIDIA fix (Etap 8)

Sidebar layout redesign: `<aside id="sidebar">` left, brand+tagline+nav+hostbadge; topbar with utilities (theme/lang/font); hamburger + drawer mobile <768px. Inline SVG icons per nav (22 Lucide-style keys). Responsive grid: 1024 (narrow), 768 (drawer), mobile one-column. Categories add/remove widget. NVIDIA detection fixed: uses `apt_pkg_candidate` + `dpkg --compare-versions` instead of `madison NR==1`; shows "newer: X [dpkg verdict: X > Y]" when candidate > installed. Snap firefox with `--ignore-running` fallback, hint added. CHECK-ONLY yellow banner in CLI.

**Files:** app/frontend/icons.js (NEW), app/frontend/{index.html, style.css, app.js} (layout-shell, sidebar, topbar, responsive), scripts/drivers/check.sh (dpkg --compare-versions), scripts/snap/apply.sh (running-apps hint).

**Validation:** bash -n all .sh OK; python3 ast parse all .py OK; TestClient 22 GET endpoints 22/22 → 200; SPA layout+sidebar+topbar+icons confirmed; `./update-all.sh --only drivers --phase check` shows newer + dpkg verdict; python3 tests/validate_phase_json.py PASS; test_dev_sync_safety.py 9/9 OK.

---

## 2026-05-03 — UX wave 1+2 + AI suggestions + pain-points (Etap 7)

Slogan "unified updates" in UI + i18n PL/EN. Per-category 5-phase buttons (check/plan/apply/verify/cleanup + run all). Snapshot stuck-fix: `timeout` + SUDO_ASKPASS. `config/exclusions.list` + `lib/exclusions.sh` with per-package skip checkbox. Settings backup/restore (`/backup/{export,import}` + CLI). Smart Suggestions panel: heuristics + optional LLM, AI provider settings (Anthropic/OpenAI opt-in read-only). Post-run health check (score 0-100 + issues), ETA from history (avg/p90/ok%), `--budget Ns/m/h` w update-all.sh. Maintenance windows + battery guard dla schedulera. CLI `ascendo` extended: settings/health/exclusions. Stuck dashboard runs cleaned.

**New endpoints:** /suggestions, /suggestions/apply, /suggestions/dismiss, /health/{check,run}, /backup/{export,import}, /telemetry/eta, /exclusions*, /settings.

**New files:** config/exclusions.list, lib/exclusions.sh, scripts/health-check.sh, scripts/scheduler/should-run.sh, app/backend/{suggestions,health,backup,telemetry,exclusions}.py.

**Validation:** bash -n all .sh OK; python3 ast parse all .py OK; python3 tests/validate_phase_json.py PASS (266+); test_dev_sync_safety.py 9/9 OK; TestClient 18 GET endpoints 18/18 → 200; POST endpoints (exclusions, backup, suggestions) 200; `./update-all.sh --profile quick --no-notify` 6/6 ok, post-run health 100/100.

---

## 2026-05-02 — Ascendo brand + i18n + apps (Etap 6)

Branding Ascendo: logo.svg + icon.svg + banner.txt + favicon. CLI i18n (EN/PL): `lib/i18n.sh` + `i18n/{en,pl}.txt`, persisted to `~/.config/ascendo/lang`. CLI tables: `lib/tables.sh` with @ok/@warn/@err/@skip/@info pills, unicode box-drawing. App registration: `scripts/apps/{detect,add,remove,list,install-missing}.sh`. Backend `/apps/*` + `/i18n/*` endpoints. fresh-machine.sh: language pick step 0, apps detect read-only before setup. Wizard step 0 = language radio. Dev-sync TTY pretty output (box + table + ✔). User Journey docs (EN+PL). `bin/ascendo-ubuntu` shim auto-resolve ROOT. `.deb` rebrand: Package=ascendo.

**Files:** branding/{logo.svg,icon.svg,banner.txt}, app/frontend/favicon.svg, lib/{i18n.sh,tables.sh}, i18n/{en.txt,pl.txt}, scripts/apps/{detect,add,remove,list,install-missing}.sh, docs/{en,pl}/user-journey.md, bin/ascendo-ubuntu (NEW).

**Validation:** bash -n all .sh OK; python3 ast parse all .py OK; TestClient 16 GET endpoints 16/16 → 200; python3 tests/validate_phase_json.py 266/266 PASS; test_dev_sync_safety.py 9/9 OK; `bin/ascendo-ubuntu apps detect` tracked=38, detected=308, missing=0; i18n tn apps.summary (PL) "38 śledzonych · 308 wykrytych"; fresh-machine --lang en --check-only OK.

---

## 2026-05-01 — Roadmap implementation (Etap 5)

`.deb` package (packaging/build-deb.sh), first-run wizard modal + /onboarding endpoints, run diff view (/runs/diff?a=X&b=Y), notification routing (ntfy/Slack/email/Telegram), snapshot rollback wired (/snapshots/restore), Markdown report export (/runs/{id}/report.md), per-package live progress apt:apply (awk parser, per-item JSON), token auth middleware (+bearer token, /auth/*, SUDO_ASKPASS), libsecret migration (lib/secrets.sh), audit log (/audit, JSONL writer), Prometheus /metrics (text format, 36 lines, ubuntu_aktualizacje_* metrics), log retention daemon (prune-logs.sh, --keep/--days policy), shellcheck in CI (severity=warning, SC1090/91/2086 ignored).

**Files:** app/backend/{audit,auth,metrics,report,diff}.py, scripts/snapshot/restore.sh, scripts/maintenance/prune-logs.sh, packaging/build-deb.sh + DEBIAN/ subdirs.

**Validation:** bash -n all .sh OK; python3 ast parse all .py OK; TestClient 13 GET endpoints 13/13 → 200; metrics.render() 36 lines OK; report.render_run_id() 4171 chars OK; python3 tests/validate_phase_json.py 266/266 PASS; test_dev_sync_safety.py 9/9 OK.

---

## 2026-04-30 — UX/perf overhaul + portability (Etap 4)

Sudo: one password per CLI run via ephemeral askpass helper ($XDG_RUNTIME_DIR/ascendo-ubuntu/askpass-*.sh, chmod 0700). lib/common.sh::sudo() wraps all calls as `sudo -A`. Live progress: orchestrator tee's phase output to console + log; apt:apply prints upgradable preview. Inventory speed 85s → 11s via `apt_inventory_cache_init` (batched apt-cache policy). Brew cleanup proactive chown Cellar before prune. Dashboard Overview cache via ui._loaded[view]. Reboot UX: banner + POST /system/reboot?delay=5. dev-sync overlay 3527 → 8 files (Cargo target/, Tauri bundle, *.db, .gradle/ excluded). CI guard: overlay ≤ 50 files check. scripts/fresh-machine.sh: one-liner bring-up.

**Validation:** bash -n all .sh OK; python3 ast parse all .py OK; ./update-all.sh --profile quick --no-notify 6/6 ok, 14.5s; python3 tests/validate_phase_json.py 232/232 PASS; test_dev_sync_safety.py 9/9 OK.

---

## 2026-04-29 — Etapy 1+2+3 UKOŃCZONE: Fazyfikacja + Dashboard + Snapshot/Scheduler/Pluginy

**Etap 1 — Phase contract:** `schemas/phase-result.schema.json` (JSON Schema), `lib/json.sh` + `lib/_json_emit.py` emitter, `lib/orchestrator.sh` runner/aggregator, `config/{categories,profiles}.toml` taksonomia. 5 faz × 8 kategorii native scripts/\<cat\>/{check,plan,apply,verify,cleanup}.sh. `update-all.sh` rewritten as thin orchestrator, backward-compat 100% (--only, --dry-run, --no-drivers, --nvidia, --no-notify).

**Etap 2 — Dashboard (Plan B: FastAPI + vanilla SPA):** app/backend/{main,runner,db,config}.py REST + SSE, app/frontend/{index.html,style.css,app.js} vanilla (no build), 5 views (Overview/Categories/Run Center/History/Logs), SQLite history, live log SSE. All endpoints tested: GET /health, /categories, /profiles, /preflight, /git/status, /runs*, /runs/active/stream.

**Etap 3 — Snapshot/Scheduler/Pluginy/Packaging:** scripts/snapshot/{create,list}.sh (timeshift→etckeeper fallback), scripts/scheduler/install.sh (systemd timer generator), lib/plugins.sh manifest scanner, systemd/user dashboard service, share/applications .desktop, app/pyproject.toml package metadata.

**CI:** validate.yml extended with ~70 required files, phase contract tests, bats emitter tests, plugin scanner, backend smoke.

**Validation:** bash -n all .sh OK; python3 ast parse all .py OK; python3 tests/validate_phase_json.py 6/6 PASS; ./update-all.sh --profile quick 6/6 categories ok; plugin scanner OK; backend 7 GET endpoints + E2E POST /runs OK.

---

## Co zostawić po większej pracy

- Krótka lista: decyzje, zmienione pliki, uruchomione walidacje, otwarte ryzyka.
- Status: co jest gotowe, co wymaga kolejnego kroku.

## Kompresja kontekstu

- Przy ~60% kontekstu wykonuj podsumowanie robocze.
- Zachowuj tylko decyzje i aktualny stan; usuwaj zbędne logi i historyczne rozważania.
