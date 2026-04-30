# Handoff

## 2026-05-04 — Final UX polish + profile templates + apt rollback + GH releases (Etap 10 — release v0.5)

### Stan na koniec sesji (oddajemy do użytkowników)

| Obszar | Status |
|---|---|
| **Slogan vertical pod logo** (zgodnie z prośbą) | ✅ powrót do `Ascendo` + tagline w drugiej linii, font 0.7rem |
| **Sudo cache** w status barze po **prawej** | ✅ `<span id="sudo-indicator" style="float:right">` w footer |
| **Theme switcher** auto = monitor icon | ✅ cycle monitor → sun → moon, persist localStorage + settings.ui.theme |
| **Pie chart** czytelny: total + % ok wewnątrz, legend pod | ✅ `renderDonut` przepisany, rounded-cap segments, brak ukrytych napisów |
| **Sync hints PL/EN** każdy guzik z opisem co robi | ✅ `sync.hint_fetch/pull/push/dry/real` |
| **Sync remote name dropdown** z `rclone listremotes` + **Browse…** modal pickera folderów | ✅ `/sync/remotes` + `/sync/browse` (`rclone lsf --dirs-only`) |
| **Categories: drivers + inventory** pokazują dane (nie puste) | ✅ `scan_drivers`: NVIDIA dpkg + smi + fwupd; `scan_inventory_meta`: APPS.md mtime/size |
| **Snap UX** advisory gdy snapd auto-refresh wyprzedził, "running apps" pokazuje konkretny snap | ✅ `SNAP-AUTO-REFRESHED` diag + parser blocked snap name |
| **Help section** pełna dokumentacja, większe czcionki (1rem) | ✅ 11 sekcji + TOC, tabela skryptów, troubleshooting |
| **About section** version + system + Markdown release notes | ✅ `/about` endpoint + render |
| **Hosts edit UI** add/edit/delete `config/hosts.toml` | ✅ form + `/hosts/upsert` + `.bak_<ts>` |
| **AI providers**: Anthropic, OpenAI, Gemini, Ollama, LM Studio, OpenAI-compat | ✅ baseUrl field, lokalne bez api key, /suggestions/test |
| **Cloud sync providers** (Proton/GDrive/Dropbox/OneDrive/WebDAV/S3/local) | ✅ dropdown + browse picker + `/sync/provider/test` |
| **Logs detail viewer** dropdown + per-phase plain log + sidecar links | ✅ `loadLogsList` + inline view-log buttons |
| **Per-package apt rollback** (downgrade) | ✅ `/apt/downgrade` + `↓ rollback` button per row w Categories detail (apt only) |
| **Profile templates** dev-workstation / media-server / minimal-laptop | ✅ `config/profiles/*.list` + `scripts/apps/profile-import.sh` + UI panel w Settings (Preview/Apply) + CLI `ascendo profile {list\|import}` |
| **GH Releases auto-update notifier** | ✅ Settings → Update notifier; `/updates/check` z 4s timeout, settings.updates.check_repo |
| **i18n parity PL+EN** dla wszystkich nowych sekcji | ✅ help/about/sync.hint*/sync.browse*/hosts.f*/profiles_*/updates_* w obu językach |
| **Stale .bak files cleanup** | ✅ usunięte `snap-packages.list.bak_*`, `hosts.toml.bak_*` |

### Nowe pliki (tej sesji)

```
config/profiles/dev-workstation.list                   (curated dev set)
config/profiles/media-server.list                      (headless server)
config/profiles/minimal-laptop.list                    (light footprint)
scripts/apps/profile-import.sh                         (idempotent profile importer)
```

### Zmodyfikowane (tej sesji)

```
app/backend/main.py                                    (+/apt/downgrade, /profiles/templates, /profiles/import, /updates/check, /sync/remotes, /sync/browse)
app/backend/inventory.py                               (scan_drivers, scan_inventory_meta)
app/backend/settings.py                                (ai.base_url, sync.*, updates.check_repo)
app/backend/hosts_edit.py                              (NEW — write hosts.toml)
app/frontend/index.html                                (sidebar, Help, About, profiles panel, updates notifier, downgrade button)
app/frontend/app.js                                    (theme cycle fix, monitor icon, profiles UI, downgrade prompt, browse modal, hosts CRUD)
app/frontend/style.css                                 (sidebar layout, donut redesign, help font 1rem, slogan vertical)
app/frontend/i18n.js                                   (full PL/EN parity)
app/frontend/icons.js                                  (monitor, folder added)
packaging/deb/usr/bin/ubuntu-aktualizacje              (settings/health/exclusions/profile subcommands)
scripts/snap/apply.sh                                  (SNAP-AUTO-REFRESHED diag, blocked-snap parser)
scripts/drivers/check.sh                               (dpkg --compare-versions)
scripts/snapshot/create.sh                             (timeout 300s, askpass-aware)
update-all.sh                                          (--budget, --no-health, CHECK-ONLY banner, detailed summary)
RUN.md / RELEASE_NOTES.md / docs/agents/handoff.md     (this section)
```

### Walidacja końcowa (release-gate)

```text
bash -n na wszystkich .sh                              OK
python3 ast parse na wszystkich .py (10 modułów)       OK
JS parse (icons.js, i18n.js, app.js)                   OK
TestClient: 31 GET endpoints                           31/31 → 200
POST /profiles/import (dry-run)                        200 ok
POST /apt/downgrade                                    schema OK (sudo-gated)
SPA: slogan vertical, sudo float:right                 confirmed
python3 tests/validate_phase_json.py                   PASS (266+)
test_dev_sync_safety.py                                9/9 OK
./update-all.sh --profile quick --no-notify            6/6 ok, post-run health 100/100
ascendo profile import dev-workstation --dry-run       added=22, skipped=10
```

### Jak testować na innym hoście Ubuntu (po dev-sync export)

```bash
# Na nowej maszynie:
git clone https://github.com/KasprowiczM/Ubuntu_Aktualizacje ~/Dev_Env/Ubuntu_Aktualizacje
cd ~/Dev_Env/Ubuntu_Aktualizacje
bash scripts/fresh-machine.sh           # preflight + restore overlay z Proton + setup + dashboard

# Otwórz dashboard:
xdg-open http://127.0.0.1:8765

# Sanity:
./update-all.sh --profile quick --no-notify    # ~15s, czyste 6/6
ascendo profile list                            # dev-workstation, media-server, minimal-laptop
ascendo profile import dev-workstation --dry-run
ascendo health --json
ascendo apps detect
ascendo settings export ~/ascendo-backup.tar.gz

# Dashboard tour:
# Overview → quick check, donut z % ok
# Categories → drivers (3 wiersze, NVIDIA + smi + fwupd), inventory (APPS.md)
# Sync → wybierz provider, Browse… → folder picker
# Suggestions → wybierz Ollama/LM Studio, Test connection
# Settings → Profile templates → Preview, Update notifier → Check now
# Help → 11 sekcji dokumentacji
# About → wersja + 175 linii release notes
```

### Co celowo zostało (nie do release v0.5)

| Priorytet | Zadanie |
|---|---|
| P3 | Frontend Playwright e2e tests |
| P3 | Per-package rollback dla snap/brew (obecnie tylko apt) |
| P3 | Run timeline Gantt SVG |
| P3 | Multi-host PUSH-mode runs (dziś tylko read-only preflight) |
| P3 | Cross-platform: Windows winget, macOS softwareupdate |

---

## 2026-05-03 (late) — Sidebar redesign + verbose progress + NVIDIA fix (Etap 8)

### Stan na koniec sesji

| Obszar | Status |
|---|---|
| **Sidebar layout** zamiast navbar | ✅ `<aside id="sidebar">` po lewej, brand+tagline+nav+hostbadge; main scroll niezależny |
| **Inline SVG icons** per pozycja menu | ✅ `app/frontend/icons.js` (22 ikon Lucide-style); `data-icon=` w nav-link, injectIcons() po bootstrap |
| **Topbar utilities** (theme/lang/font) | ✅ `<header class="topbar">`; ikony cykla: sun↔moon, globe (en↔pl), type (sm↔md↔lg); persist do `/settings` + localStorage |
| **Hamburger** + drawer mobile <768px | ✅ sidebar fixed translateX(-100%) → slide-in; backdrop click zamyka; auto-close po wyborze; box-shadow 4px |
| **Responsive grid** mobile/tablet/desktop | ✅ breakpoints: 1024 (narrow sidebar), 768 (drawer); `.grid` jednokolumnowo; mniejsze cat-actions na mobile |
| **Categories add/remove pakietu** | ✅ Add widget na górze (`<select cat>` + `<input pkg>` + button); Remove button per row w detail expand |
| **NVIDIA detection fix** | ✅ używa `apt_pkg_candidate` + `dpkg --compare-versions` zamiast `madison NR==1`; pokazuje "newer: X [dpkg verdict: X > Y]" gdy candidate faktycznie > installed |
| **NVIDIA candidate older?** | ✅ jasne info "candidate ${cand} (older than installed — no upgrade needed)" gdy security pocket ma starszą |
| **Snap firefox refresh** | ✅ `--ignore-running` fallback działa; dorzuciłem hint "If you're using a snap right now, close it" + `running apps (xxx)` w warn |
| **CHECK-ONLY banner** w CLI | ✅ żółta ramka gdy phases=[check] |

### Nowe pliki

```
app/frontend/icons.js                          (Lucide-style inline SVG, 22 keys)
```

### Zmodyfikowane (tej sesji)

```
app/frontend/index.html                        (sidebar + topbar + cats-add-widget; usunięto stary <header>)
app/frontend/style.css                         (layout-shell grid, sidebar/.topbar, responsive, font-size scale)
app/frontend/app.js                            (injectIcons, bindSidebar, bindSwitchers, bindCatsAddWidget, data-cat-add/rm)
scripts/drivers/check.sh                       (dpkg --compare-versions logic)
scripts/snap/apply.sh                          (running-apps hint)
```

### Walidacja

```
bash -n na wszystkich .sh                                                OK
python3 ast parse na wszystkich .py                                      OK
TestClient: 22 GET endpoints (incl. /icons.js)                           22/22 → 200
SPA: layout-shell + sidebar + topbar + 10 data-icon attrs               present
JS: injectIcons/bindSidebar/bindSwitchers/bindCatsAddWidget defined      present
./update-all.sh --only drivers --phase check --no-notify                 newer: 0ubuntu1.24.04.1 [dpkg verdict: > 0ubuntu0.24.04.2]
python3 tests/validate_phase_json.py                                     PASS
test_dev_sync_safety.py                                                  9/9 OK
dev-sync overlay                                                         8 files
```

### Wyjaśnienie NVIDIA (była niejasność)

User widział "installed 0ubuntu0.24.04.2 → available 0ubuntu1.24.04.1" i myślał, że `.2 > .1` więc instalowany jest nowszy. **Tak nie jest** — Debian-style versioning porównuje całe człony: `0ubuntu0` vs `0ubuntu1` — różnica w przedostatnim segmencie (`0` vs `1`), więc `0ubuntu1.24.04.1 > 0ubuntu0.24.04.2`. Potwierdzone `dpkg --compare-versions`. Teraz CLI pokazuje "[dpkg verdict: X > Y]" żeby było jednoznacznie.

### Snap firefox

`snap refresh` dla firefoxa wymaga zamknięcia browsera lub `--ignore-running`. Master script już ma fallback `--ignore-running`. Jeśli nadal nie idzie:
1. Zamknij Firefoxa.
2. `bin/ascendo --only snap --phase apply`.
3. Lub w UI: Categories → snap → apply.

---

## 2026-05-03 — UX wave 1+2 + AI suggestions + pain-points (Etap 7)

### Stan na koniec sesji

| Obszar | Status |
|---|---|
| Slogan **"unified updates"** w UI header (gradient) + i18n PL/EN | ✅ `app/frontend/index.html` + `style.css` + `i18n.js` |
| **Per-category 5-fazowe przyciski** (check/plan/apply/verify/cleanup + ▶ run all) | ✅ Categories tab; jeden klik = run; sudo modal jeśli mutating |
| **Snapshot stuck-fix** (timeshift hang bez TTY) | ✅ `scripts/snapshot/create.sh` z `timeout`+SUDO_ASKPASS, `update-all.sh` loguje do `<run>/snapshot.log` i nigdy nie blokuje |
| **`config/exclusions.list`** + `lib/exclusions.sh` + filtered list reader | ✅ `parse_config_*_filtered <cat>` używane w apt/snap/brew/npm/pip/flatpak apply |
| Apps tab — **checkbox "skip"** per pakiet | ✅ wraz z `/exclusions` REST endpoints |
| **Settings backup/restore** | ✅ `app/backend/backup.py` + `/backup/{export,import}` + UI buttons + CLI `ascendo settings export/import` |
| **Smart Suggestions panel** (heuristyki + opcjonalny LLM) | ✅ nowa zakładka `Suggestions`, `app/backend/suggestions.py`, AI provider settings (Anthropic/OpenAI, opt-in, read-only) |
| **Post-run health check** (score 0-100 + issues list) | ✅ `scripts/health-check.sh`, JSON do `<run>/health.json`, **Health card** na Overview |
| **ETA from history** | ✅ `app/backend/telemetry.py` + history banner: avg/p90/ok% per profile |
| **`--budget Ns/m/h`** w `update-all.sh` | ✅ stop-early gdy przekroczony |
| **Maintenance windows + battery guard** dla schedulera | ✅ `scripts/scheduler/should-run.sh` jako `ExecStartPre=`, env `UA_REQUIRE_AC=1`, `UA_MAINTENANCE_WINDOW=02:00-05:00`, `UA_RESPECT_FOCUS=1` |
| **CLI `ascendo` rozszerzony** | ✅ + `settings export/import`, `health`, `exclusions {list,add,remove}` |
| **Stuck dashboard runs cleaned** | ✅ `141545Z`, `141641Z` usunięte (były pre-fix snapshot hang) |

### Nowe endpointy

```
/suggestions                  GET    — heuristic + AI advice (read-only)
/suggestions/apply            POST   — write diff with .bak_<ts> backup
/suggestions/dismiss          POST   — persist dismissed-suggestions.json
/health/check                 GET    — last health.json (latest run by default)
/health/run                   POST   — run health-check.sh on demand
/backup/export                GET    — download tar.gz
/backup/import                POST   — upload tar.gz, restores w/ .bak_<ts>
/telemetry/eta                GET    — avg/median/p90/ok% per profile
/exclusions                   GET    — list of cat:pkg + category-skipped
/exclusions/add               POST   — {category, package}
/exclusions/remove            POST   — {category, package}
```

### Nowe pliki

```
config/exclusions.list                         (template, gitignored when populated)
lib/exclusions.sh                              (loader + filter helpers)
scripts/health-check.sh                        (post-run health, JSON)
scripts/scheduler/should-run.sh                (battery / maint window / busy guard)
app/backend/suggestions.py                     (heuristics + LLM provider)
app/backend/health.py                          (facade for health.json)
app/backend/backup.py                          (tar.gz export/import)
app/backend/telemetry.py                       (ETA averages from db)
app/backend/exclusions.py                      (list edit facade)
```

### Zmodyfikowane

```
update-all.sh                                  (--budget, --no-health, post-run health, snapshot non-blocking)
scripts/snapshot/create.sh                     (timeout + SUDO_ASKPASS-aware)
scripts/scheduler/install.sh                   (ExecStartPre=should-run.sh)
scripts/{apt,snap,brew,npm,pip,flatpak}/apply.sh  (parse_config_*_filtered)
lib/detect.sh                                  (parse_config_*_filtered)
app/backend/main.py                            (+10 endpoints)
app/backend/settings.py                        (ai.*, scheduler.maintenance_window, scheduler.require_ac)
app/frontend/{index.html,app.js,style.css,i18n.js}  (slogan, Suggestions, Health card, Backup, Exclusion checkbox, ETA in History, per-category 5-phase buttons)
packaging/deb/usr/bin/ubuntu-aktualizacje      (settings/health/exclusions subcommands)
```

### Walidacje

```text
bash -n na wszystkich .sh                                                OK
python3 -c ast parse na wszystkich .py                                   OK
python3 tests/validate_phase_json.py                                     PASS (266+)
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_dev_sync_safety.py          9/9 OK
TestClient: 18 GET endpoints (incl. /suggestions, /health/check, /telemetry/eta, /exclusions) → 200
TestClient: POST /exclusions/add + /remove + /backup/export + /suggestions/apply → 200
./update-all.sh --profile quick --no-notify                              6/6 ok, 13s, post-run health 100/100
```

### Pain-points adresowane (z sesji-2026-05-03)

| Pain point | Rozwiązanie |
|---|---|
| Strach przed zepsuciem | Snapshot non-blocking + Health card po runie + per-app skip |
| Brak alertu "untracked package pojawił się sam" | Apps tab pokazuje `detected ` z propozycją tracking |
| Update fatigue | ETA z historii (avg, p90, ok%) na History |
| Brak rollbacku per-package | TODO follow-up (apt downgrade UI; przygotowane API) |
| Confidence "to się skończyło" | Health score na Overview + post-run banner z linkiem |
| Strach przed chronić-przed-touchem | exclusions.list + UI checkbox w Apps |
| Long brew runs | `--budget 30m` zatrzymuje czysto i wraca następnym razem |
| Scheduled na baterii? | should-run.sh: defer w `UA_REQUIRE_AC=1` + niskim akku |

### Co zostało nieruszone (do następnej sesji)

| Priorytet | ID | Zadanie |
|---|---|---|
| P1 | B5+ | apt:apply changelog preview ("co się zmieni") przed potwierdzeniem |
| P1 | rollback | UI button "downgrade to previous version" per-pakiet (apt cache .deb files) |
| P2 | gh-releases | Notifier dla nowych Ascendo releases (settings.updates.check_repo wpięte; ale brak workera) |
| P2 | profile templates | Kuratorowane `config/profiles/{dev,media,minimal}.list` + import w wizardzie |
| P3 | telemetry chart | History "duration over time" SVG line chart |
| P3 | per-package failure mining | Heurystyka per-package z sidecar items (już częściowo w suggestions.py) |
| P3 | i18n parity | Klucze `suggest.*`, `health.*`, `backup.*` są w PL/EN; reszta UI nadal hybrydowa |

### Komendy weryfikujące

```bash
git pull
bash scripts/fresh-machine.sh --check-only
./update-all.sh --profile quick --no-notify
bin/ascendo health --json
bin/ascendo exclusions list
bin/ascendo settings export /tmp/test.tar.gz
python3 tests/validate_phase_json.py | tail -3
app/.venv/bin/python -m app.backend &  # otwórz http://127.0.0.1:8765
```

---

## 2026-05-02 — Ascendo brand + i18n + apps (Etap 6)

### Stan na koniec sesji

| Obszar | Status |
|---|---|
| Branding **Ascendo** | ✅ logo.svg + icon.svg + banner.txt w `branding/`, favicon, tytuł SPA, banner CLI, header `<svg>` |
| CLI i18n (EN/PL) | ✅ `lib/i18n.sh` + `i18n/{en,pl}.txt`, `t`/`tn`, `~/.config/ascendo/lang` |
| CLI tabele kolorowe | ✅ `lib/tables.sh` z `@ok @warn @err @skip @info` pillami, unicode box-drawing |
| App registration CLI | ✅ `scripts/apps/{detect,add,remove,list,install-missing}.sh` |
| App registration UI | ✅ `Apps` tab w dashboardzie z tabelą + przyciskami add/remove |
| Backend `/apps/*` + `/i18n/*` | ✅ 3 nowe endpointy w `app/backend/main.py` |
| fresh-machine.sh: język 0-tym krokiem | ✅ pierwszy prompt to EN/PL, potem `t setup.*` przez całą resztę |
| fresh-machine.sh: nigdy nie instaluje | ✅ apps detect read-only przed setupem; install-missing osobno |
| Wizard step 0 = język | ✅ radio EN/PL na górze modala; `applyI18n()` natychmiast |
| Dev-sync TTY pretty output | ✅ box z tabelą + ✔ pill; non-TTY = stary format (CI parser działa) |
| User Journey docs (EN+PL) | ✅ `docs/{en,pl}/user-journey.md` — 6 ścieżek |
| `bin/ascendo` shim z auto-resolve ROOT | ✅ działa z repo i z `/opt/...` po `dpkg -i` |
| `.deb` rebrand | ✅ Package: ascendo, Source: ubuntu-aktualizacje, Version: 0.3.0 |

### Nowe pliki

```
branding/{logo.svg,icon.svg,banner.txt,README.md}
app/frontend/favicon.svg                   (= branding/icon.svg)
lib/i18n.sh                                (catalog loader, t/tn)
lib/tables.sh                              (unicode tables + status pills)
i18n/en.txt                                (EN catalog)
i18n/pl.txt                                (PL catalog)
scripts/apps/detect.sh                     (compare config/*.list ↔ system)
scripts/apps/add.sh                        (append to .list, .bak_<ts>)
scripts/apps/remove.sh                     (remove from .list)
scripts/apps/list.sh                       (show all configured)
scripts/apps/install-missing.sh            (install state=missing items)
docs/en/user-journey.md                    (6 personas EN)
docs/pl/user-journey.md                    (6 personas PL)
bin/ascendo                                (symlink → packaging/.../ubuntu-aktualizacje)
```

### Zmodyfikowane

```
update-all.sh                              (banner + i18n source)
scripts/fresh-machine.sh                   (lang pick step 0, apps detect, t-keys)
dev-sync/dev_sync_export.py                (TTY pretty box, plain CI fallback)
app/backend/main.py                        (+/apps/{detect,add,remove}, /i18n/{lang})
app/frontend/index.html                    (Ascendo brand, Apps tab, wizard step 0)
app/frontend/app.js                        (loadApps, appsAdd/Remove, lang switch in wizard)
app/frontend/style.css                     (.brand, .tbl, .st-pill)
app/frontend/i18n.js                       (apps.*, wizard.* PL+EN)
packaging/deb/DEBIAN/control               (Package: ascendo, 0.3.0)
packaging/deb/usr/bin/ubuntu-aktualizacje  (auto-resolve ROOT, apps subcommand)
.github/workflows/validate.yml             (+15 required files)
README.md                                  (Ascendo header)
RUN.md                                     (Etap 6 changelog)
```

### Walidacje

```text
bash -n na wszystkich .sh                              OK
python3 ast parse na wszystkich .py                    OK
TestClient: 16 GET endpoints (incl. /apps/detect, /i18n/en, /i18n/pl)  → 200
python3 tests/validate_phase_json.py                   266/266 PASS
test_dev_sync_safety.py                                9/9 OK
dev-sync export dry-run                                Files selected: 8
bin/ascendo apps detect                                tracked=38, detected=308, missing=0
bin/ascendo apps list                                  total: 38
i18n: tn apps.summary 38 308 0 (PL)                    "38 śledzonych · 308 wykrytych (poza configiem) · 0 brakuje"
fresh-machine --lang en --check-only --no-service     OK do końca
```

### Ryzyka / co warto sprawdzić

1. **`dpkg-deb --build`** — packaging fizycznie nie testowany na czystej
   maszynie; build-deb.sh ma dobrze zdefiniowane perms ale wymaga
   physical install/uninstall test (tak jak Etap 5).
2. **Wizard language switch** — `applyI18n()` zakłada że i18n.js jest
   zsynchronizowany z `i18n/{en,pl}.txt`; jeśli backend katalog ma klucz
   którego nie ma w i18n.js, dashboard pokaże fallback EN.
3. **Apps detect** — pierwsze uruchomienie na maszynie z dużym `pipx
   list` może być wolne (>2s). Cache nie wpięty — TODO follow-up.
4. **Symlink `bin/ascendo`** — działa tylko z repo. Po `dpkg -i` używamy
   `/usr/bin/ubuntu-aktualizacje` (planowany rename na `/usr/bin/ascendo`).

### Zostało (nie ruszane / niskoryzykowne deferred)

| ID | Zadanie | Effort |
|---|---|---|
| A3 | Snap package (snapcraft.yaml) | 2 dni |
| A4 | AppImage dla Tauri shell | 0.5 dnia |
| A5 | Homebrew tap | 0.5 dnia |
| B6 | Toast/snackbar zamiast `ui.status()` | 0.3 dnia |
| B7 | Mobile-friendly layout | 0.3 dnia |
| C4 | CSP/CORS hardening | 0.2 dnia |
| D3 | Run timeline Gantt view | 1 dzień |
| E1 | Push-mode SSH multi-host runs | 2 dni |
| E2 | Central history aggregation | 2 dni |
| F1 | Fedora/RHEL `dnf` adapter | 2 dni |
| G1 | Frontend Playwright e2e | 1 dzień |
| Apps | Cache `apps detect` (60s TTL) | 0.3 dnia |
| Apps | UI confirm modal for install-missing | 0.3 dnia |
| Brand | Rename `/usr/bin/ubuntu-aktualizacje` → `/usr/bin/ascendo` | 0.2 dnia |
| i18n | Rozszerzyć catalogs do wszystkich `print_*` w lib/common.sh | 0.5 dnia |

### Komendy do następnej sesji

```bash
git pull
bash scripts/fresh-machine.sh --check-only --lang en
bin/ascendo apps detect
bin/ascendo apps list
./update-all.sh --profile quick --no-notify
python3 tests/validate_phase_json.py | tail -3
python3 dev-sync/dev_sync_export.py --dry-run
```

---

## 2026-05-01 — Roadmap implementation (Etap 5)

### Stan na koniec sesji

Z handoffowego roadmapu (P0+P1) zrealizowane i pushed:

| ID | Feature | Status | Commit |
|---|---|---|---|
| A1 | `.deb` package + postinst | ✅ `packaging/build-deb.sh` produkuje dystrybucyjny pakiet, `/usr/bin/ubuntu-aktualizacje` shim z subkomendami |
| A2 | First-run wizard | ✅ modal w dashboardzie + `/onboarding/{state,complete}` endpoints |
| B1 | Run diff view | ✅ `GET /runs/diff?a=X&b=Y` (`app/backend/diff.py`) |
| B2 | Notification routing | ✅ `scripts/notify.sh` rozszerzony o ntfy/Slack/email/Telegram |
| B3 | Snapshot rollback wired | ✅ `scripts/snapshot/restore.sh` + `POST /snapshots/restore` |
| B4 | Markdown report export | ✅ `GET /runs/{id}/report.md` (`app/backend/report.py`) |
| B5 | Per-package live progress (apt:apply) | ✅ awk parser + per-package JSON items |
| C1 | Token auth middleware | ✅ `app/backend/auth.py` + `/auth/{status,generate-token,revoke-token}` |
| C2 | libsecret migration | ✅ już istniało (`scripts/secrets/migrate-to-libsecret.sh`) |
| C3 | Audit log | ✅ `app/backend/audit.py` zapis do `~/.local/state/.../audit.log`, `GET /audit` |
| D1 | Prometheus `/metrics` | ✅ `app/backend/metrics.py`, dep-free text format 0.0.4 |
| D2 | Log retention daemon | ✅ `scripts/maintenance/prune-logs.sh` keep N/days policy |
| D4 | DB migrations versioned | ✅ już istniało (`app/backend/migrations.py` + schema_migrations table) |
| G2 | shellcheck w CI | ✅ nowy step w validate.yml (severity=warning, SC1090/91/2086 ignored) |

### Nowe pliki

```
app/backend/audit.py          (audit log writer)
app/backend/auth.py           (bearer token middleware)
app/backend/metrics.py        (Prometheus exporter)
app/backend/report.py         (Markdown run report)
app/backend/diff.py           (run-vs-run package diff)
scripts/snapshot/restore.sh   (timeshift/etckeeper restore)
scripts/maintenance/prune-logs.sh  (log retention)
packaging/build-deb.sh        (deb builder)
packaging/deb/DEBIAN/control      (deb metadata)
packaging/deb/DEBIAN/postinst     (post-install hint)
packaging/deb/DEBIAN/prerm        (stop user services)
packaging/deb/usr/bin/ubuntu-aktualizacje (CLI shim)
```

### Zmodyfikowane

```
app/backend/main.py           (+13 endpoints, audit hooks, middleware mount)
app/frontend/index.html       (wizard modal)
app/frontend/app.js           (maybeShowWizard, finishWizard)
scripts/notify.sh             (ntfy/Slack/email/Telegram channels)
scripts/apt/apply.sh          (streaming apt-get + per-package items)
.github/workflows/validate.yml (shellcheck step + new required files)
RUN.md                        (Etap 5 changelog)
```

### Walidacje uruchomione

```text
bash -n na wszystkich .sh                          OK
python3 ast parse na wszystkich nowych .py         OK
TestClient: 13 GET endpoints (incl. /metrics, /audit, /auth/status,
            /onboarding/state) → 200                OK
metrics.render() — 36 lines, contains ubuntu_aktualizacje      OK
report.render_run_id() na ostatnim runie — 4171 znaków         OK
python3 tests/validate_phase_json.py               266/266 PASS
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_dev_sync_safety.py  9/9 OK
python3 dev-sync/dev_sync_export.py --dry-run      Files selected: 8
```

### Ryzyka / co zweryfikować

1. **`.deb` packaging** zbudowany konstrukcyjnie ale **nie testowany pełnym
   build/install loop** — wymaga `dpkg-deb` i fizycznej instalacji żeby
   sprawdzić, że `/usr/bin/ubuntu-aktualizacje` resolve'uje się poprawnie
   po `dpkg -i`.
2. **Token auth middleware** dodany do `app.add_middleware(...)`. Gdy plik
   tokenu nie istnieje, middleware jest no-op. Test: `POST /auth/generate-token`
   → kolejny request bez Authorization powinien zwrócić 401.
3. **apt:apply streaming** — `Dpkg::Use-Pty=0` jest wymagane żeby parsować
   `Setting up X` po linijce; testowane lokalnie tylko przez `bash -n`.
   Prawdziwy run apply zweryfikuje czy parser łapie wszystkie pakiety.
4. **Slack webhook payload** — escapes `*` jako Markdown bold; jeśli msg
   zawiera niezamknięte `*`, Slack pokaże mismatch. Best-effort, nie krytyczne.
5. **Log retention** użyty `--dry-run` zwrócił `kept=23, removed=13` — prune
   policy działa, ale przed pierwszym apply warto zerknąć `ls -1dt logs/runs/`.
6. **shellcheck w CI** — severity=warning, ale niektóre stare skrypty mogą
   mieć nieczyste warstwy (np. `[ ` zamiast `[[ `). Pierwszy run CI pokaże
   listę; może wymagać `--exclude=SC2034` itd.

### Zostało (nie ruszane w tej sesji — zwykle za duże lub mniej leverage)

| Priorytet | ID | Zadanie | Effort |
|---|---|---|---|
| P1 | A3 | Snap package (`snapcraft.yaml`) | 2 dni |
| P2 | A4 | AppImage dla Tauri shell | 0.5 dnia |
| P2 | A5 | Homebrew tap | 0.5 dnia |
| P3 | B6 | Toast/snackbar zamiast `ui.status()` | 0.3 dnia |
| P3 | B7 | Mobile-friendly layout | 0.3 dnia |
| P3 | C4 | CSP/CORS hardening | 0.2 dnia |
| P2 | D3 | Run timeline Gantt view | 1 dzień |
| P1 | E1 | Push-mode SSH multi-host runs | 2 dni |
| P2 | E2 | Central history aggregation | 2 dni |
| P3 | E3 | Drift detection między hostami | 1 dzień |
| P2 | F1 | Fedora/RHEL `dnf` adapter | 2 dni |
| P3 | F2-3 | Arch + macOS adapters | 2-3 dni |
| P1 | G1 | Frontend Playwright e2e | 1 dzień |
| P3 | G3 | Coverage reporting | 0.5 dnia |
| P2 | i18n | Klucze PL/EN dla wizard.* (obecnie tylko EN inline) | 0.2 dnia |

### Komendy do następnej sesji

```bash
git pull
bash scripts/fresh-machine.sh --check-only
./update-all.sh --profile quick --no-notify

# Zbuduj .deb (wymaga dpkg-deb)
bash packaging/build-deb.sh
ls -la dist/

# Test endpointów po pull
app/.venv/bin/python -c "
import sys; sys.path.insert(0,'.')
from app.backend.main import app
from fastapi.testclient import TestClient
c = TestClient(app)
print(c.get('/metrics').status_code, c.get('/audit').status_code)
"

# Smoke test prune-logs
bash scripts/maintenance/prune-logs.sh --dry-run

# Włącz token auth (LAN-safe dashboard)
curl -X POST http://127.0.0.1:8765/auth/generate-token | jq .
# Wyłącz:
curl -X POST http://127.0.0.1:8765/auth/revoke-token

# Wyeksportuj raport runa
LATEST=$(ls -t logs/runs/ | head -1)
curl -s "http://127.0.0.1:8765/runs/$LATEST/report.md" | head -40
```

---

## 2026-04-30 — UX/perf overhaul + portability (Etap 4)

### Stan na koniec sesji

Kompletne, przetestowane i pushed (commit `3fd629b` + follow-up):

| Obszar | Status |
|---|---|
| Sudo: jedno hasło na cały run (CLI) | ✅ askpass helper w `$XDG_RUNTIME_DIR/ubuntu-aktualizacje/`, `lib/common.sh::sudo()` wrapper |
| Live progress w konsoli i SSE | ✅ orchestrator tee'uje phase output, apt:apply printuje upgradable preview |
| Inventory speed 85s → 11s | ✅ `apt_inventory_cache_init`, batched `apt-cache policy` |
| `BREW-CLEANUP-WARN` (pipx pycache) | ✅ proaktywny chown Cellar w cleanup.sh |
| `SNAP-STILL-OUTDATED` race | ✅ downgrade do `info SNAP-NEW-REVISION` |
| Dashboard Overview cache | ✅ `ui._loaded[view]`, manual Refresh, auto-invalidate po runu |
| Reboot UX | ✅ banner + `POST /system/reboot?delay=5`; CLI: rich box z systemctl/shutdown |
| dev-sync overlay 3527 → 8 | ✅ Cargo target/, Tauri bundle, *.db*, .gradle/ wykluczone |
| CI guard `overlay ≤ 50 plików` | ✅ nowy step w validate.yml — łapie przyszłe regresje |
| `scripts/fresh-machine.sh` | ✅ one-liner do bring-up nowej maszyny przez `git clone && bash scripts/fresh-machine.sh` |
| Dokumentacja | ✅ RUN.md + last-run-review.md + README.md + CLAUDE.md zaktualizowane |

### Zmienione pliki (sesja 2026-04-30)

```
update-all.sh                          (askpass + reboot box)
lib/common.sh                          (sudo wrapper, require_sudo no-op gdy READY)
lib/orchestrator.sh                    (tee + ORCH_QUIET=1 fallback)
lib/detect.sh                          (apt_inventory_cache_init + cached helpers)
scripts/update-inventory.sh            (wywołuje cache init)
scripts/brew/cleanup.sh                (proactive chown + retry-after-heal)
scripts/snap/verify.sh                 (info zamiast warn)
scripts/apt/apply.sh                   (upgradable list preview)
scripts/fresh-machine.sh               (NEW — one-liner provisioning)
app/backend/main.py                    (POST /system/reboot, /system/cancel-reboot)
app/frontend/index.html                (banner + overview refresh button)
app/frontend/app.js                    (cache map, rebootNow, invalidateCaches)
app/frontend/style.css                 (.reboot-banner)
app/frontend/i18n.js                   (PL+EN reboot strings)
dev-sync/dev_sync_core.py              (Cargo/Tauri/Gradle/db excludes)
.github/workflows/validate.yml         (overlay size guard step)
RUN.md / README.md / CLAUDE.md         (one-liner + komendy)
docs/last-run-review.md                (full session findings table)
```

### Walidacje uruchomione

```text
bash -n na wszystkich .sh                    OK
python3 -c "import ast" dla wszystkich .py   OK
python3 tests/validate_phase_json.py         232/232 PASS
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_dev_sync_safety.py   9/9 OK
./update-all.sh --profile quick --no-notify  6/6 categories, 14.5s
python3 dev-sync/dev_sync_export.py --dry-run   Files selected: 8
bash scripts/fresh-machine.sh --check-only --no-service   wykonane do końca, exit 0
```

### Ryzyka / co warto zweryfikować

1. **Askpass helper na crash** — jeśli `update-all.sh` zostanie zabity SIGKILL
   (kill -9), helper w `$XDG_RUNTIME_DIR/ubuntu-aktualizacje/askpass-*.sh`
   nie zostanie usunięty (trap nie złapie SIGKILL). Po stronie kontener
   katalogu chmod 0700, ale plik zawiera hasło. Mitigation: katalog
   `$XDG_RUNTIME_DIR` wygasa razem z user-session (logout); cleanup helper
   na starcie również usuwa stare pliki — TODO follow-up.
2. **Live `tee` w `set -e` master** — `${PIPESTATUS[0]}` używany do propagacji
   exit code; przetestowane lokalnie, ale nietypowe shells mogą się różnić
   (`bash` z `pipefail` jest OK).
3. **`sudo()` shell function** w `lib/common.sh` — nadpisuje builtin tylko
   gdy SUDO_ASKPASS jest ustawione, więc standalone phase scripts (poza
   master orchestratorem) zachowują standardowe `sudo` → user prompt.
4. **CI overlay guard** — używa heredoc minimal config; jeśli ktoś
   doda nowy `provider=` w przyszłości, step trzeba rozszerzyć.

### Zostało do zrobienia (deferred — nie ruszone)

| Priorytet | Zadanie | Effort |
|---|---|---|
| Medium | Per-package live progress w `scripts/apt/apply.sh` (streaming `apt-get` z `--print-uris` lub `apt-get install` per package) | ~1 dzień |
| Medium | libsecret/`secret-tool` migracja dla `.env.local` + tokenów rclone | ~0.5 dnia |
| Low | Tauri reskin (REST API stable, można zrobić native shell) | 1-2 dni |
| Low | Multi-host scheduler push (hosts.toml + central control panel) | 1-2 dni |
| Low | Migracje DB w `app/backend/db.py` (obecnie `IF NOT EXISTS`) | 0.5 dnia |
| Low | Frontend testy (Playwright) | 1 dzień |

### Roadmap rozwoju aplikacji (recommendations, 2026-04-30)

Pełna analiza repo z perspektywy "co dołożyć żeby było produktem do
dystrybucji / sprzedaży / łatwego onboardowania na nowych komputerach".
Podzielone na **kategorie** z priorytetem (P0 = next sprint, P3 = nice-to-have)
i **effort estimates**. Bazuje na obecnym stanie po commitach `3fd629b`+`d1d0030`.

#### A. Onboarding & dystrybucja (najważniejsze dla "sprzedawalności")

| # | Feature | Priorytet | Effort | Wartość |
|---|---|---|---|---|
| A1 | **Pakiet .deb** dla `update-all.sh` + dashboard. `dpkg-deb -b` z postinst który robi `bash scripts/fresh-machine.sh`. PPA na Launchpad. | P0 | 2-3 dni | enterprise install bez `git clone` |
| A2 | **First-run wizard** w dashboardzie — modal "Welcome → host detection → choose profile → schedule timer → done". Wykrywa fresh state przez brak `~/.config/ubuntu-aktualizacje/onboarded.json`. | P0 | 1 dzień | non-tech userzy |
| A3 | **Snap package** (`snapcraft.yaml`) — auto-update via Canonical Store. Dashboard działa jako classic snap. | P1 | 2 dni | wide distribution |
| A4 | **AppImage** dla Tauri shell (już mamy Cargo target/) — drag & drop instalacja, bez zależności systemowych. | P2 | 0.5 dnia | testing/CI |
| A5 | **Homebrew tap** `brew install KasprowiczM/tap/ubuntu-aktualizacje` — formula sourcing skrypty z GitHub Release tag. | P2 | 0.5 dnia | macOS-comfy operatorzy |

#### B. UI/UX kompletność

| # | Feature | Priorytet | Effort | Wartość |
|---|---|---|---|---|
| B1 | **Run diff view** — w History zaznacz dwa runy → "compare": które pakiety się zmieniły, kernelu, etc. SQL diff na phase_results. | P1 | 1 dzień | audyt zmian |
| B2 | **Notification routing** — obecne `scripts/notify.sh` tylko desktop. Dodać `ntfy.sh`, Slack webhook, email (sendmail), Telegram bot. Konfig w Settings. | P1 | 1 dzień | unattended runs |
| B3 | **Snapshot restore wired** — UI button "Rollback to snapshot" → `timeshift --restore --snapshot ID`. Obecnie tylko create. | P1 | 0.5 dnia | recovery story |
| B4 | **Markdown export** — POST `/runs/{id}/report.md` zwraca self-contained report (run summary + per-phase details + diagnostics). Dla IT/compliance. | P2 | 0.5 dnia | reportowanie |
| B5 | **Per-package live progress w apt:apply** — streaming `apt-get -o Debug::pkgDPkgPM=1`, parsing każdej linii `Setting up xxx`/`Unpacking yyy`, emit do log z licznikiem `[3/47] firefox 131→132`. | P1 | 1 dzień | zaufanie operatora podczas dłużej trwających apply |
| B6 | **Toast/snackbar** zamiast `ui.status()` przy zdarzeniach (run started, sudo cached, snapshot taken). | P3 | 0.3 dnia | polish |
| B7 | **Mobile-friendly layout** — dashboard ma sticky topbar, ale kategorie nie zwijają się na mobile. | P3 | 0.3 dnia | przegląd statusu z telefonu |

#### C. Bezpieczeństwo & wieloużytkownikowość

| # | Feature | Priorytet | Effort | Wartość |
|---|---|---|---|---|
| C1 | **Token auth** dla dashboardu — middleware z bearer token w `~/.config/ubuntu-aktualizacje/auth.token` (chmod 0600). Gdy plik istnieje, wszystkie endpointy wymagają `Authorization: Bearer …`. Zachowuje 127.0.0.1 default ale enable opt-in dla LAN access. | P0 | 0.5 dnia | wystawienie na LAN, multi-host central panel |
| C2 | **libsecret/secret-tool** — `.env.local` + rclone token migracja. `lib/secrets.sh` już ma fallback path. | P1 | 0.5 dnia | portability bez plain-text secrets |
| C3 | **Audit log** — każda akcja mutująca (POST /runs, /sync/export, /system/reboot) zapisuje wpis w `~/.local/state/ubuntu-aktualizacje/audit.log` z user/timestamp/IP/action. | P2 | 0.5 dnia | compliance |
| C4 | **CSP/CORS hardening** — obecnie `*` na static assets; ograniczyć do origin localhost. | P3 | 0.2 dnia | security baseline |

#### D. Observability & operability

| # | Feature | Priorytet | Effort | Wartość |
|---|---|---|---|---|
| D1 | **Prometheus `/metrics`** — exportuje `update_run_duration_seconds`, `update_phase_status{cat,phase}`, `inventory_packages{cat,status}`, `reboot_required`. Pozwala podpiąć Grafana. | P1 | 1 dzień | central monitoring fleet |
| D2 | **Log retention** — obecnie `logs/runs/<id>/` rośnie nieskończenie. Daemon: keep 30 days OR last 50 runs, whichever larger. `scripts/scheduler/install.sh` mógłby instalować drugi timer. | P1 | 0.5 dnia | dyskoochrona |
| D3 | **Run timeline view** — Gantt chart po phase, pokazuje co trwało długo. Pure SVG (mamy już donut/bars). | P2 | 1 dzień | profiling |
| D4 | **DB migrations versioned** — `app/backend/migrations.py` istnieje, ale obecny init używa CREATE IF NOT EXISTS bez sprawdzania schema_version. | P2 | 0.5 dnia | upgrades bez data loss |

#### E. Multi-host / zarządzanie flotą

| # | Feature | Priorytet | Effort | Wartość |
|---|---|---|---|---|
| E1 | **Push-mode SSH runs** — `hosts.toml` już ma read-only preflight; rozszerzyć o "Run profile X on all hosts". Backend SSH z BatchMode=yes, agreguje runy. | P1 | 2 dni | mała flota homelab/SOHO |
| E2 | **Central history aggregation** — pojedynczy panel pokazuje runy z N hostów, kolory wg statusu. SQLite per-host + ETL script lub Postgres central. | P2 | 2 dni | enterprise |
| E3 | **Drift detection** — porównaj `APPS.md` między hostami w klasie ("dev workstation", "media server"); alert gdy się różnią od baseline. | P3 | 1 dzień | compliance |

#### F. Cross-distro parity

| # | Feature | Priorytet | Effort | Wartość |
|---|---|---|---|---|
| F1 | **Fedora/RHEL** — `dnf` zamiast `apt`. `lib/detect.sh` już ma `detect_os`. Dodać `scripts/dnf/{check,plan,apply,verify,cleanup}.sh`. | P2 | 2 dni | rozszerzenie audience |
| F2 | **Arch/Manjaro** — `pacman` + AUR. | P3 | 2 dni | enthusiasts |
| F3 | **macOS** — `brew` już mamy; dodać `mas` (App Store CLI), `softwareupdate`. | P3 | 1 dzień | dev workstations |

#### G. Testowanie & jakość

| # | Feature | Priorytet | Effort | Wartość |
|---|---|---|---|---|
| G1 | **Frontend testy** — Playwright e2e: load dashboard, kliknij Quick check, czekaj na done, sprawdź badge. CI in headless. | P1 | 1 dzień | regresji |
| G2 | **shellcheck** w CI dla wszystkich .sh — obecnie tylko `bash -n`. | P1 | 0.3 dnia | catch shell bugs |
| G3 | **Coverage reporting** dla pythonowych testów. | P3 | 0.5 dnia | metric |

### Top 5 rekomendacji do następnego sprintu (P0 + P1 high-leverage)

1. **A2 first-run wizard** + **C1 token auth** — razem dają "share dashboard URL with team" story.
2. **B5 per-package live progress** — najczęstsze user complaint, mamy plumbing (tee + JSON items).
3. **D1 Prometheus metrics** — fundamenty pod fleet monitoring.
4. **B2 notification routing** (ntfy.sh minimum) — unattended scheduler bez sprawdzania ręcznego.
5. **A1 .deb package** — moment gdy projekt staje się "produktem".

### Komendy do następnej sesji

Pełen quick smoke po pull:
```bash
git pull
bash scripts/fresh-machine.sh --check-only
./update-all.sh --profile quick --no-notify
python3 tests/validate_phase_json.py | tail -5
python3 dev-sync/dev_sync_export.py --dry-run | grep "Files selected"
```

Pełen run z dashboardem:
```bash
bash systemd/user/install-dashboard.sh
xdg-open http://127.0.0.1:8765
# lub CLI:
./update-all.sh --profile safe --snapshot
```

---

## Co zostawić po większej pracy
- Krótka lista: decyzje, zmienione pliki, uruchomione walidacje, otwarte ryzyka.
- Status: co jest gotowe, co wymaga kolejnego kroku.

## Kompresja kontekstu
- Przy ~60% kontekstu wykonuj podsumowanie robocze.
- Zachowuj tylko decyzje i aktualny stan; usuwaj zbędne logi i historyczne rozważania.

---

## Handoff 2026-04-29 — Etapy 1, 2, 3 UKOŃCZONE

### Etap 1 — fazyfikacja + JSON sidecar (gotowe)

**Fundament kontraktu:**
- `schemas/phase-result.schema.json` — JSON Schema draft 2020-12.
- `lib/json.sh` + `lib/_json_emit.py` — emitter bash z helperem Pythona.
- `lib/orchestrator.sh` — wspólny runner + agregator `run.json`.
- `config/categories.toml`, `config/profiles.toml` — taksonomia + profile.

**5 faz × 8 kategorii (`scripts/<cat>/{check,plan,apply,verify,cleanup}.sh`):**
- `apt` — pełen refaktor (NVIDIA hold, fail-closed repo setup, exit 20/30 dla CRITICAL).
- `snap`, `flatpak`, `brew`, `npm`, `pip`, `drivers`, `inventory` — adaptery delegujące do legacy + JSON sidecar.

**`update-all.sh`** — przepisany jako thin orchestrator. Backward-compat 100%
(`--only`, `--dry-run`, `--no-drivers`, `--nvidia`, `--no-notify`). Nowe:
`--profile`, `--phase`, `--run-id`. Outer = phase, inner = category.

**Testy:**
- `tests/validate_phase_json.py` — zero-deps validator (const/enum/required/type/pattern/min/max).
- `tests/bash/test_json_emit.bats` — 7 testów kontraktowych.

### Etap 2 — Dashboard (Plan B: FastAPI + vanilla SPA, gotowe)

Wybór: Plan B z mojej rekomendacji (zamiast Tauri+Rust) — w pełni działający
w jednej sesji, deliverable bez Rust toolchaina. Tauri może być later-stage
re-implementacją UI; backend i kontrakt API są stabilne.

**Backend (`app/backend/`):**
- `main.py` — FastAPI app, REST endpoints + SSE (`/runs/active/stream`).
- `runner.py` — subprocess launcher dla `update-all.sh`, capture event loop
  z `asyncio.get_running_loop()` dla cross-thread queue puts.
- `db.py` — SQLite history, schema `runs` + `phase_results`, WAL.
- `config.py` — ładuje `categories.toml` / `profiles.toml`.
- `__main__.py` — `python3 -m app.backend` na 127.0.0.1:8765.

**Frontend (`app/frontend/`):**
- `index.html` + `style.css` + `app.js` — vanilla, brak build-stepu.
- 5 widoków: Overview, Categories, Run Center, History, Logs.
- Live log SSE, quick-action buttons, nav.

**REST API (gotowe i testowane):**
- `GET /health`, `/categories`, `/profiles`, `/preflight`, `/git/status`
- `GET /runs[?limit=N]`, `POST /runs`, `GET /runs/active`, `POST /runs/active/stop`
- `GET /runs/active/stream` (SSE) — live log
- `GET /runs/{id}`, `GET /runs/{id}/phase/{cat}/{phase}`, `…/log`

**Smoke testy uruchomione lokalnie:**
- 7/7 endpointów GET → 200
- POST /runs odpalił rzeczywisty `update-all.sh --profile quick`, status=ok,
  6 faz w bazie SQLite, sidecary fetchowalne przez API.
- Frontend serwowany z `/` (text/html).

### Etap 3 — Snapshot / Scheduler / Pluginy / Packaging (gotowe)

- `scripts/snapshot/create.sh` — timeshift→etckeeper fallback chain, exit 10
  jeśli żaden provider niedostępny.
- `scripts/snapshot/list.sh` — lista snapshotów z aktywnego providera.
- `scripts/scheduler/install.sh` — generator `ubuntu-aktualizacje@.{service,timer}`
  z konfigurowalnym `--calendar`, `--profile`, `--no-drivers`, `--dry-run`.
  Tryby: install / `--remove` / `--status`.
- `lib/plugins.sh` + `plugins/example/{manifest.toml,check.sh,apply.sh}` —
  scanner manifestów, walidator TOML, hook na phase scripts.
- `systemd/user/ubuntu-aktualizacje-dashboard.service` + `install-dashboard.sh` —
  user-level service, nie wymaga roota.
- `share/applications/ubuntu-aktualizacje.desktop` — wpis menu (xdg-open).
- `app/pyproject.toml` — package metadata, console-script
  `ubuntu-aktualizacje-dashboard`.

### CI

`.github/workflows/validate.yml` rozszerzone:
- Lista `required` zawiera wszystkie nowe pliki Etapów 1/2/3 (~70 wpisów łącznie).
- Step "Phase JSON contract" — emitter smoke + schema validate.
- Step "bats phase emitter tests" — uruchamia bats.
- Step "Plugin manifest scanner smoke test" — `plugins_list_ids` + `plugins_validate`.
- Step "Dashboard backend smoke test" — instaluje fastapi/httpx, hit
  wszystkie endpointy GET.

### Walidacje uruchomione lokalnie

- `bash -n` na wszystkich `scripts/<cat>/*.sh`, `lib/*.sh`, `update-all.sh` → ok
- `bash -n` na `scripts/snapshot/*.sh`, `scripts/scheduler/install.sh`, `lib/plugins.sh` → ok
- `python3 tests/validate_phase_json.py` → 6/6 sidecarów PASS (po quick run)
- `update-all.sh --profile quick --no-notify` → 6/6 kategorii zwraca poprawne sidecary
- Plugin scanner: `plugins_list_ids` zwraca `example`, `plugins_validate example` → 0
- Backend FastAPI: 7 endpointów GET, POST /runs trigger E2E, status=ok

### Pliki dotknięte (Etapy 1+2+3)

```
schemas/phase-result.schema.json                       (NEW)
lib/_json_emit.py                                      (NEW)
lib/json.sh                                            (NEW)
lib/orchestrator.sh                                    (NEW)
lib/plugins.sh                                         (NEW)
config/categories.toml                                 (NEW)
config/profiles.toml                                   (NEW)
scripts/apt/{check,plan,apply,verify,cleanup}.sh       (NEW, full refactor)
scripts/snap/{check,plan,apply,verify,cleanup}.sh      (NEW)
scripts/brew/{check,plan,apply,verify,cleanup}.sh      (NEW)
scripts/npm/{check,plan,apply,verify,cleanup}.sh       (NEW)
scripts/pip/{check,plan,apply,verify,cleanup}.sh       (NEW)
scripts/flatpak/{check,plan,apply,verify,cleanup}.sh   (NEW)
scripts/drivers/{check,plan,apply,verify}.sh           (NEW)
scripts/inventory/apply.sh                             (NEW)
scripts/snapshot/{create,list}.sh                      (NEW)
scripts/scheduler/install.sh                           (NEW)
plugins/example/{manifest.toml,check.sh,apply.sh}      (NEW)
app/backend/{__init__,__main__,main,runner,db,config}.py (NEW)
app/frontend/{index.html,style.css,app.js}             (NEW)
app/pyproject.toml                                     (NEW)
app/README.md                                          (NEW)
systemd/user/{ubuntu-aktualizacje-dashboard.service,install-dashboard.sh} (NEW)
share/applications/ubuntu-aktualizacje.desktop         (NEW)
tests/validate_phase_json.py                           (NEW)
tests/bash/test_json_emit.bats                         (NEW)
docs/agents/contract.md                                (NEW)
update-all.sh                                          (REWRITTEN, backward-compat preserved)
.github/workflows/validate.yml                         (EXTENDED)
CLAUDE.md                                              (UPDATED — komendy + referencje)
docs/agents/handoff.md                                 (UPDATED — this section)
```

### Pełny refaktor 8 kategorii — UKOŃCZONY (2026-04-29 wieczór)

Wszystkie 8 kategorii ma teraz natywne `apply.sh` (bez delegacji do legacy
`scripts/update-<cat>.sh`):

| Kategoria | apply | Per-package items | Notatki |
|-----------|-------|-------------------|---------|
| apt       | ✓     | ✓ (z update-apt) | NVIDIA hold, fail-closed repo, exit 20/30 |
| snap      | ✓     | ✓ (parsing refresh output) | --ignore-running fallback |
| flatpak   | ✓     | ✓ (parsing update output)  | --noninteractive |
| brew      | ✓     | ✓ (z `outdated --json=v2`) | Cellar ownership fix, doctor info |
| npm       | ✓     | ✓ (z `outdated -g --json`) | force @latest dla AI CLIs, audit |
| pip       | ✓     | ✓ (z `pip list --outdated --format=json`) | pip + pipx + brew Python guard |
| drivers   | ✓     | ✓ (NVIDIA from→to)        | + cleanup.sh dla obsolete kernels |
| inventory | ✓     | n/a                       | tylko apply (regen APPS.md) |

Wszystkie 7 kategorii × 2 fazy (check + plan) emitują schema-valid sidecary
(potwierdzone testem `tests/bash/test_phase_contract.bats`).

Legacy `scripts/update-*.sh` może zostać **usunięty** w kolejnym etapie (po
zatwierdzeniu i obserwacji 1-2 produkcyjnych runów). CI required list trzymamy
hybrydową do tego czasu.

### Pozostałe TODO

1. **Tauri/Rust UI** (Plan A) — opcjonalny native skin. Plan B (FastAPI+vanilla)
   jest produkcyjny i używa stabilnego REST API.
2. **Dashboard nie ma autoryzacji HTTP** — chronione przez bind na 127.0.0.1.
   Multi-user: przepiąć na unix socket + permission 0600.
3. ~~Plugin sidecary~~ — **DONE**: schemat akceptuje `category="plugin:<id>"`.
4. **Snapshot integracja**: `--snapshot` flag w `update-all.sh` wywołuje
   `scripts/snapshot/create.sh` przed apply (DONE). Settings UI ma toggle
   `snapshot_before_apply`, ale flag musi być przekazany z `runner.py`
   gdy `settings.snapshot_before_apply == true` — TODO follow-up.
5. ~~`drivers/plan.sh` `${RANDOM}` IDs~~ — **DONE**: stabilne id z device-id.
6. **Tauri/Rust UI** — nie został zbudowany. Plan B (FastAPI+vanilla) jest
   produkcyjny. Tauri opcjonalnie później.
7. **Frontend nie ma testów** — vanilla JS. Smoke przez Playwright/Cypress
   w v2.
8. **Brak migracji DB** — schemat `runs`/`phase_results` jest IF NOT EXISTS.
   Przy zmianie schematu dopisać migrations w `app/backend/db.py`.
9. **Sekrety** — `.env.local` i tokeny rclone nadal w plain text. Migracja
   na libsecret/`secret-tool` to v2.
10. **Legacy `scripts/update-*.sh`** — nadal w repo (CI required list +
    backward-compat). Można usunąć po zatwierdzeniu nowych natywnych apply.

### Następne kroki w kolejności

1. **Code review** całości + merge.
2. ~~Pełen refaktor 6 kategorii~~ — DONE (snap/flatpak/brew/npm/pip/drivers natywne).
3. **Usuń legacy `scripts/update-<cat>.sh`** po 1-2 produkcyjnych runach +
   uaktualnij CI required list.
4. ~~Snapshot wpięty~~ — DONE jako `--snapshot` flag. Auto-apply z settings: TODO.
5. ~~Dashboard Settings screen~~ — DONE (default_profile, snapshot toggle, scheduler).
6. ~~Dashboard Sync screen~~ — DONE (git fetch/pull/push + sync export/status).
7. ~~Plugin schema extension~~ — DONE (`plugin:<id>`).
8. **Honor `settings.snapshot_before_apply` w `runner.py`** — gdy true,
   dodać `--snapshot` do argv przy POST /runs (5 linii zmiany w `app/backend/runner.py`).
9. **Sekrety → libsecret** (`secret-tool store/lookup`).
10. **Tauri reskin** (opcjonalnie).
