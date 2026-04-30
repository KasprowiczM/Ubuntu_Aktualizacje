# Handoff

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
| **Ikona Ubuntu desktop = Ascendo logo** | ✅ `share/icons/hicolor/scalable/apps/ascendo.svg` + `share/applications/ubuntu-aktualizacje.desktop` (`Name=Ascendo`, `Icon=ascendo`, `StartupWMClass=Ascendo`); poprzednio używało systemowego `software-update-available` |
| **User-level instalator ikony** | ✅ `systemd/user/install-dashboard.sh` instaluje ikonę i `.desktop` do `~/.local/share/{icons,applications}`, woła `update-desktop-database` + `gtk-update-icon-cache`, kasuje stare `ubuntu-aktualizacje.desktop` |
| **System-wide ikona w `.deb`** | ✅ `packaging/deb/usr/share/icons/hicolor/scalable/apps/ascendo.svg` + `packaging/deb/usr/share/applications/ascendo.desktop`, postinst odświeża bazy |
| **CLI runs widoczne w historii dashboard/web** | ✅ `db.import_disk_runs()` reconciliuje `logs/runs/<id>/run.json` z SQLite; wpięte w startup oraz w `/runs` i `/runs/{id}` |
| **Migracja `004 run_source`** | ✅ kolumna `runs.source` (`'cli'` vs `'dashboard'`); `insert_run` przyjmuje source; UI dorzuca pill **cli** w History |
| **Inferencja profilu z faz** | ✅ tylko `check` → `quick`; brak `drivers` → `safe`; reszta → `full`. `only_cat`/`only_phase` ustawiane gdy single-cat / single-kind |

### Pliki dotknięte

share/icons/hicolor/scalable/apps/ascendo.svg, share/applications/ubuntu-aktualizacje.desktop, systemd/user/install-dashboard.sh, packaging/deb/usr/share/icons/hicolor/scalable/apps/ascendo.svg, packaging/deb/usr/share/applications/ascendo.desktop, packaging/deb/DEBIAN/postinst, app/backend/migrations.py (+_m004_run_source), app/backend/db.py (import_disk_runs), app/backend/main.py (startup/lazy reconcile), app/frontend/app.js (cli pill).

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
systemctl --user restart ubuntu-aktualizacje-dashboard.service
./update-all.sh --profile quick --no-notify
curl -s 'http://127.0.0.1:8765/runs?limit=5' | jq '.runs[] | {id, source, profile, status}'
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

app/backend/main.py (+/apt/downgrade, /profiles/*, /updates/check, /sync/remotes, /sync/browse), app/backend/inventory.py (scan_drivers, scan_inventory_meta), app/backend/settings.py (ai.base_url, sync.*, updates.*), app/backend/hosts_edit.py (NEW), app/frontend/{index.html, app.js, style.css}, app/frontend/i18n.js (PL/EN parity), app/frontend/icons.js (monitor, folder), packaging/deb/usr/bin/ubuntu-aktualizacje (settings/health/exclusions/profile subcommands), scripts/snap/apply.sh (SNAP-AUTO-REFRESHED), scripts/drivers/check.sh (dpkg --compare-versions), update-all.sh (--budget, --no-health, CHECK-ONLY banner).

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

Branding Ascendo: logo.svg + icon.svg + banner.txt + favicon. CLI i18n (EN/PL): `lib/i18n.sh` + `i18n/{en,pl}.txt`, persisted to `~/.config/ascendo/lang`. CLI tables: `lib/tables.sh` with @ok/@warn/@err/@skip/@info pills, unicode box-drawing. App registration: `scripts/apps/{detect,add,remove,list,install-missing}.sh`. Backend `/apps/*` + `/i18n/*` endpoints. fresh-machine.sh: language pick step 0, apps detect read-only before setup. Wizard step 0 = language radio. Dev-sync TTY pretty output (box + table + ✔). User Journey docs (EN+PL). `bin/ascendo` shim auto-resolve ROOT. `.deb` rebrand: Package=ascendo.

**Files:** branding/{logo.svg,icon.svg,banner.txt}, app/frontend/favicon.svg, lib/{i18n.sh,tables.sh}, i18n/{en.txt,pl.txt}, scripts/apps/{detect,add,remove,list,install-missing}.sh, docs/{en,pl}/user-journey.md, bin/ascendo (NEW).

**Validation:** bash -n all .sh OK; python3 ast parse all .py OK; TestClient 16 GET endpoints 16/16 → 200; python3 tests/validate_phase_json.py 266/266 PASS; test_dev_sync_safety.py 9/9 OK; `bin/ascendo apps detect` tracked=38, detected=308, missing=0; i18n tn apps.summary (PL) "38 śledzonych · 308 wykrytych"; fresh-machine --lang en --check-only OK.

---

## 2026-05-01 — Roadmap implementation (Etap 5)

`.deb` package (packaging/build-deb.sh), first-run wizard modal + /onboarding endpoints, run diff view (/runs/diff?a=X&b=Y), notification routing (ntfy/Slack/email/Telegram), snapshot rollback wired (/snapshots/restore), Markdown report export (/runs/{id}/report.md), per-package live progress apt:apply (awk parser, per-item JSON), token auth middleware (+bearer token, /auth/*, SUDO_ASKPASS), libsecret migration (lib/secrets.sh), audit log (/audit, JSONL writer), Prometheus /metrics (text format, 36 lines, ubuntu_aktualizacje_* metrics), log retention daemon (prune-logs.sh, --keep/--days policy), shellcheck in CI (severity=warning, SC1090/91/2086 ignored).

**Files:** app/backend/{audit,auth,metrics,report,diff}.py, scripts/snapshot/restore.sh, scripts/maintenance/prune-logs.sh, packaging/build-deb.sh + DEBIAN/ subdirs.

**Validation:** bash -n all .sh OK; python3 ast parse all .py OK; TestClient 13 GET endpoints 13/13 → 200; metrics.render() 36 lines OK; report.render_run_id() 4171 chars OK; python3 tests/validate_phase_json.py 266/266 PASS; test_dev_sync_safety.py 9/9 OK.

---

## 2026-04-30 — UX/perf overhaul + portability (Etap 4)

Sudo: one password per CLI run via ephemeral askpass helper ($XDG_RUNTIME_DIR/ubuntu-aktualizacje/askpass-*.sh, chmod 0700). lib/common.sh::sudo() wraps all calls as `sudo -A`. Live progress: orchestrator tee's phase output to console + log; apt:apply prints upgradable preview. Inventory speed 85s → 11s via `apt_inventory_cache_init` (batched apt-cache policy). Brew cleanup proactive chown Cellar before prune. Dashboard Overview cache via ui._loaded[view]. Reboot UX: banner + POST /system/reboot?delay=5. dev-sync overlay 3527 → 8 files (Cargo target/, Tauri bundle, *.db, .gradle/ excluded). CI guard: overlay ≤ 50 files check. scripts/fresh-machine.sh: one-liner bring-up.

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
