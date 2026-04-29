# Handoff

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
