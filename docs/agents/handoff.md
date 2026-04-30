# Handoff

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
