# Uruchomienie i weryfikacja Ubuntu_Aktualizacje

Pełen przewodnik dla nowego operatora — od zera do działającego dashboardu.
Wszystkie ścieżki względem `~/Dev_Env/Ubuntu_Aktualizacje`.

## Co nowego (2026-04-30)

- **Sudo: jedno hasło na cały run.** `update-all.sh` pyta o hasło raz, tworzy
  ephemeralny askpass helper (`$XDG_RUNTIME_DIR/ubuntu-aktualizacje/askpass-*.sh`,
  chmod 0700) i eksportuje `SUDO_ASKPASS` dla wszystkich faz. Helper jest
  usuwany przy `EXIT/INT/TERM`. `lib/common.sh` wraps `sudo` → `sudo -A`,
  więc wszystkie sub-sudo (apt, snap, drivers) korzystają automatycznie.
- **Live progress.** Output skryptów fazowych jest teraz teeowany do konsoli
  + log per-faza (`logs/runs/<id>/<cat>/<phase>.log`). Widzisz na żywo:
  apt-get updates, apt list --upgradable preview, snap refresh per package,
  brew cleanup steps. `ORCH_QUIET=1` przywraca poprzednie zachowanie.
- **Inventory 85s → ~11s** (8× szybciej). `lib/detect.sh::apt_inventory_cache_init`
  bulk-fetchuje `dpkg-query` + jedno wywołanie `apt-cache policy` dla całego
  manual setu zamiast 250 wywołań per-package.
- **Brew cleanup** — proaktywnie chownuje `${BREW_PREFIX}/Cellar` przed
  pruningiem (znana awaria pipx pycache).
- **Snap verify** — drobne refreshy między fazami apply/verify już nie
  generują warna (klasyfikacja info `SNAP-NEW-REVISION`).
- **Dashboard Overview** nie odświeża się przy każdej zmianie zakładki —
  tylko raz na sesję, plus przycisk **Refresh** (i automatycznie po końcu
  runu via `ui.invalidateCaches()`).
- **Reboot banner** w dashboardzie + endpoint `POST /system/reboot` z
  potwierdzeniem (5s delay, używa SUDO_ASKPASS). CLI runs kończą się
  rozbudowanym pudełkiem z komendą reboot i listą pakietów.
- **dev-sync overlay**: 3527 → 8 plików (Cargo `target/`, Tauri bundle,
  Gradle, *.db itd. dodane do `DEFAULT_EXCLUDE_PATTERNS`).

---

## 0. Wymagania systemowe

| Komponent | Wymagane | Skąd |
|-----------|----------|------|
| Ubuntu    | 24.04 (testowane), 22.04+/26.04 (eksperymentalne) | host |
| bash, git, awk, sed, grep, find, sort, xargs, flock | required | base system |
| python3 ≥ 3.11 (dla `tomllib`) | required dla orchestratora i dashboardu | apt / brew |
| sudo                | required dla `apply` faz APT/snap/drivers | system |
| timeshift / etckeeper | opcjonalne — pre-apply snapshot | `sudo apt install timeshift` |
| bats-core           | opcjonalne — testy emitter | `sudo apt install bats` |
| fastapi, uvicorn, pydantic | wymagane dla dashboardu | `pip install --user fastapi uvicorn pydantic` |

Sprawdzenie:
```bash
bash scripts/preflight.sh
```

---

## 1. Walidacja kodu (po świeżym clone'ie)

```bash
cd ~/Dev_Env/Ubuntu_Aktualizacje

# 1.1 Składnia bash
bash -n update-all.sh
for f in scripts/*/*.sh lib/*.sh systemd/user/*.sh; do bash -n "$f"; done

# 1.2 Składnia Pythona
python3 -c "import ast; [ast.parse(open(f).read()) for f in [
  'app/backend/main.py','app/backend/runner.py','app/backend/db.py',
  'app/backend/config.py','lib/_json_emit.py','tests/validate_phase_json.py']]"

# 1.3 Plugin scanner
source lib/plugins.sh && plugins_list_ids && plugins_validate example

# 1.4 Test smoke emitter (jeśli bats zainstalowany)
bats tests/bash/test_json_emit.bats

# 1.5 Read-only sweep
./update-all.sh --profile quick --no-notify
python3 tests/validate_phase_json.py logs/runs/*/  # waliduje wszystkie sidecary
```

Spodziewany wynik: każda faza `check` zielona, status `ok` w `logs/runs/<id>/run.json`.

---

## 2. Pełen pipeline z linii poleceń

### 2.1 Profile

```bash
./update-all.sh --profile quick   # tylko check (read-only) — ~10–30s
./update-all.sh --profile safe    # check+plan+apply+verify+cleanup, BEZ drivers
./update-all.sh --profile full    # wszystko (drivers manual-confirm)
```

### 2.2 Dodatkowe flagi

| Flaga              | Co robi |
|--------------------|---------|
| `--dry-run`        | tylko check+plan, nie wykonuje mutujących faz |
| `--no-drivers`     | pomija kategorię drivers |
| `--nvidia`         | dopuszcza upgrade NVIDIA przez APT (default: held) |
| `--snapshot`       | tworzy pre-apply snapshot (timeshift→etckeeper fallback) |
| `--no-notify`      | nie wysyła notyfikacji desktopowej |
| `--only <cat>`     | tylko jedna kategoria (apt, snap, brew, npm, pip, flatpak, drivers, inventory) |
| `--phase <ph>`     | tylko jedna faza (check, plan, apply, verify, cleanup) |
| `--run-id <id>`    | nadpisuje generowany run-id (przydatne dla CI/scheduler) |

### 2.3 Przykłady

```bash
# Bezpieczna nocna aktualizacja z snapshotem
./update-all.sh --profile safe --snapshot

# Dry-run pełnego pipeline'u — pokazuje plan, nic nie zmienia
./update-all.sh --profile full --dry-run

# Tylko apt, tylko plan (zobacz co by zmieniło)
./update-all.sh --only apt --phase plan

# Pełna aktualizacja z NVIDIA i firmware
./update-all.sh --profile full --nvidia

# Po runie — sprawdź sidecar konkretnej fazy
cat logs/runs/<run-id>/apt/apply.json | jq .summary
```

---

## 3. Scheduler (systemd timer)

```bash
# 3.1 Instalacja: niedziela 03:00, profil safe
bash scripts/scheduler/install.sh --calendar "Sun *-*-* 03:00:00" --profile safe

# 3.2 Status / kolejny run
bash scripts/scheduler/install.sh --status

# 3.3 Usunięcie
bash scripts/scheduler/install.sh --remove
```

Logi z runów scheduled: `logs/systemd_update.log` + `logs/runs/<id>/`.

---

## 4. Dashboard (FastAPI + SPA)

### 4.1 Pierwsze uruchomienie ad-hoc

> **Ważne:** brew Python na tej maszynie jest PEP-668 externally-managed
> (`pip install --user` zwraca błąd). Używamy projektowego venv-a w
> `app/.venv/`, gitignored.

```bash
cd ~/Dev_Env/Ubuntu_Aktualizacje

# Zależności w venv (raz, idempotentnie)
bash app/install.sh
# Tworzy app/.venv/, instaluje fastapi/uvicorn/pydantic/httpx

# Start serwera z venv
app/.venv/bin/python -m app.backend
# → INFO: Uvicorn running on http://127.0.0.1:8765
```

W innym terminalu lub przeglądarce:
```bash
xdg-open http://127.0.0.1:8765
```

Czego oczekiwać:
- header z hostem,
- 6 widoków: Overview / Categories / Run Center / History / Logs / Sync,
- przyciski **Quick check** / **Safe update** / **Full update** / **Full dry-run**.

### 4.2 Instalacja jako user-service (autostart po loginie)

```bash
# Instalator: bootstrapuje venv (jeśli brak) + instaluje user-unit
bash systemd/user/install-dashboard.sh

# Sprawdzenie
systemctl --user status ubuntu-aktualizacje-dashboard.service
journalctl --user -u ubuntu-aktualizacje-dashboard.service -f

# Sanity check portu
ss -lntp | grep 8765
```

Service używa `%h/Dev_Env/Ubuntu_Aktualizacje/app/.venv/bin/python` —
tj. nigdy nie tknie systemowego/brew Pythona.

Po instalacji wpis menu Ubuntu (`share/applications/ubuntu-aktualizacje.desktop`):
```bash
install -m 0644 share/applications/ubuntu-aktualizacje.desktop \
        ~/.local/share/applications/
update-desktop-database ~/.local/share/applications/
```
W Activities pojawi się ikona "Ubuntu_Aktualizacje" otwierająca dashboard w przeglądarce.

### 4.3 Sprawdzenie endpointów (curl)

```bash
curl -s http://127.0.0.1:8765/health        | jq .
curl -s http://127.0.0.1:8765/categories    | jq '.categories[].id'
curl -s http://127.0.0.1:8765/profiles      | jq '.profiles[].id'
curl -s http://127.0.0.1:8765/preflight     | jq '.items[] | "\(.tool): \(.present)"'
curl -s http://127.0.0.1:8765/git/status    | jq .
curl -s http://127.0.0.1:8765/sync/status   | jq .
curl -s http://127.0.0.1:8765/runs?limit=5  | jq '.runs[].id'

# Trigger run (POST):
curl -s -X POST http://127.0.0.1:8765/runs \
     -H 'content-type: application/json' \
     -d '{"profile":"quick","dry_run":false}' | jq .
# → {"run_id":"…", "started_at":"…"}

# Live log (Server-Sent Events):
curl -N http://127.0.0.1:8765/runs/active/stream
```

### 4.4 Smoke test backendu (automatyczny)

```bash
bash app/install.sh   # zapewnia venv + httpx
app/.venv/bin/python - <<'PY'
import sys; sys.path.insert(0, '.')
from app.backend.main import app
from fastapi.testclient import TestClient
c = TestClient(app)
for ep in ('/health','/categories','/profiles','/preflight','/runs','/runs/active',
          '/git/status','/sync/status','/settings'):
    r = c.get(ep); assert r.status_code == 200, f'{ep}: {r.status_code}'
    print(f'{ep:24s} OK')
print('all GET endpoints OK')
PY
```

### 4.5 Sudo password — apply phases potrzebują autoryzacji

Dashboard nie ma TTY, więc legacy `sudo -v` cache nie propaguje się przez
granicę dashboard → update-all.sh subprocess (TTY tickets). Stosujemy
**SUDO_ASKPASS**:

1. UI wykrywa, że żądana akcja to `apply`/`cleanup` (np. profile=safe/full).
2. Otwiera modal **Authenticate sudo** z polem hasła.
3. Hasło → POST `/sudo/auth` (body JSON), backend weryfikuje przez
   `sudo -S -v`, trzyma w pamięci procesu (NIE na dysku, NIE w DB).
4. Przy POST `/runs` z mutującą fazą backend tworzy ephemeral askpass
   helper w `$XDG_RUNTIME_DIR/ubuntu-aktualizacje/askpass-*.sh` (chmod 0700,
   embed hasła jako shell literal), eksportuje `SUDO_ASKPASS=...`.
5. update-all.sh czyta `SUDO_ASKPASS`, używa `sudo -A`. Wszystkie sub-sudo
   wywołania (apt, snap…) dziedziczą env automatycznie.
6. Po zakończeniu runu helper jest unlinked, hasło pozostaje w pamięci na
   kolejny run (do POST `/sudo/invalidate` lub restart serwisu).

**Bezpieczeństwo:** hasło nigdy nie trafia do logów ani DB. Helper file
żyje tylko podczas runu, w katalogu 0700. Backend bind 127.0.0.1.

curl odpowiednik:
```bash
curl -X POST -H 'content-type: application/json' \
     -d '{"password":"YOUR_PASSWORD"}' http://127.0.0.1:8765/sudo/auth
# → {"cached": true, "detail": "password verified and stored in memory"}

curl -X POST http://127.0.0.1:8765/sudo/invalidate     # gdy chcesz wymazać
```

curl odpowiednik:
```bash
curl -X POST -H 'content-type: application/json' \
     -d '{"password":"YOUR_PASSWORD"}' http://127.0.0.1:8765/sudo/auth
# → {"cached": true, "detail": "sudo cache warmed"}
```

### 4.6 Multi-host — read-only SSH preflight

Dashboard ma widok **Hosts** który po SSH (read-only) pobiera info z
zdalnych instancji Ubuntu_Aktualizacje:

```bash
cp config/hosts.toml.example config/hosts.toml
# edytuj — dodaj entries z ssh_alias matching ~/.ssh/config
```

Każdy host musi być w `~/.ssh/config` z kluczem (BatchMode=yes — żadnych
prompts). Mutating runs są celowo **wyłączone** — odpalaj `update-all.sh`
z dashboardu lokalnego hosta lub przez systemd timer per-host.

### 4.7 Tauri native skin (opcjonalny native binary)

```bash
cd app/tauri
bash build.sh                  # cargo tauri build → .deb + .AppImage
sudo apt install ./src-tauri/target/release/bundle/deb/ubuntu-aktualizacje_*.deb
ubuntu-aktualizacje            # native window with embedded backend
```

Skin spawnuje `app/.venv/bin/python -m app.backend` jako sidecar i otwiera
webview na `127.0.0.1:8765`. Cały kontrakt REST + SPA jest reużyty.
Build wymaga Rust + libwebkit2gtk — patrz `app/tauri/README.md`.

### 4.8 Inventory — live scan zainstalowanych pakietów

**Backend**: `app/backend/inventory.py` skanuje rzeczywisty stan systemu w 6
kategoriach (apt, snap, brew, npm, pip, flatpak), zwraca strukturalne JSON
z polami `name, installed, candidate, status, in_config, source`. Cache 60s
w pamięci procesu.

**Endpointy** (curl):
```bash
curl -s http://127.0.0.1:8765/inventory/summary | jq .
# {totals: {ok:334, outdated:2, missing:0}, categories: {apt:{...}, snap:{...}, ...}}

curl -s http://127.0.0.1:8765/inventory/apt | jq '.items[] | select(.status=="outdated")'

curl -s -X POST http://127.0.0.1:8765/inventory/refresh   # invalidate cache
```

**UI**:
- **Overview** zawiera teraz Inventory section: SVG donut z totalem ok/outdated/missing,
  bar chart per kategoria (ok = zielony, outdated = żółty, missing = czerwony),
  oraz lista wszystkich dostępnych aktualizacji w postaci tabeli (Cat / Pakiet /
  Zainstalowana / Dostępna / Źródło). Przycisk **Refresh** przeładowuje cache.
- **Categories** (lista): każda kategoria ma kolumny Total / OK / Outdated /
  Missing. Klik wiersza → expand → pełna tabela pakietów z wersjami i statusem.
  Sort: outdated → missing → ok (alphabetical w grupie).

**Pierwszy scan** trwa ~14s (apt-mark showmanual + dpkg-query per pakiet,
snap refresh --list, brew outdated --json, npm outdated -g --json, pip list,
pipx list). Kolejne wywołania przez 60s są z cache (instant).

### 4.9 Settings — persistent preferences

Widok **Settings** w UI lub `PUT /settings`:
- `default_profile` (quick/safe/full)
- `snapshot_before_apply` (bool)
- `notifications.desktop` (bool)
- `scheduler.{enabled, calendar, profile, no_drivers}` — może instalować
  systemd timer przyciskiem **Install/Update timer** (woła
  `scripts/scheduler/install.sh`).

Plik: `~/.config/ubuntu-aktualizacje/settings.json`

---

## 5. Snapshot (timeshift / etckeeper)

```bash
# Ad-hoc snapshot
bash scripts/snapshot/create.sh "before manual upgrade"

# Lista snapshotów
bash scripts/snapshot/list.sh

# Pre-apply jako część pełnego runu
./update-all.sh --profile safe --snapshot
# → snapshot id zapisany w logs/runs/<id>/snapshot.id
```

Jeśli `timeshift` brakuje, fallback do `etckeeper commit` (snapshot tylko `/etc`).
Jeśli oba brakują — exit 10, run kontynuuje **bez** snapshotu (informacja w logu).

---

## 6. Dev-sync (overlay prywatny)

Niezależny od `update-all.sh`. Sterowany z dashboardu (Sync screen) lub CLI:
```bash
bash dev-sync-export.sh --dry-run --verbose   # zawsze najpierw dry-run
bash dev-sync-export.sh                       # realny eksport
bash dev-sync-verify-full.sh                  # weryfikacja zgodności
bash dev-sync-verify-git.sh                   # tracked files clean?
```

---

## 7. Pluginy

```bash
# Lista wykrytych pluginów
source lib/plugins.sh && plugins_list_ids

# Walidacja manifestu
plugins_validate example

# Każdy plugin: plugins/<id>/{manifest.toml, check.sh, apply.sh}
# Sidecar emituje category="plugin:<id>" (rozszerzona schema v1)
```

---

## 8. Troubleshooting

### Dashboard nie startuje
- Sprawdź port: `ss -lntp | grep 8765`
- Inny port: `UA_DASHBOARD_PORT=9000 python3 -m app.backend`
- Zależności: `python3 -c "import fastapi, uvicorn, pydantic"` musi przejść.

### "a run is already in progress" (HTTP 409)
- Aktywny run blokuje kolejny. Sprawdź `GET /runs/active`, czekaj lub `POST /runs/active/stop`.
- Stale lock: `ls -la "${XDG_RUNTIME_DIR:-/tmp}/ubuntu-aktualizacje.lock"`. Po crashu można usunąć ręcznie po sprawdzeniu, że żaden proces nie używa pliku.

### Sidecar nie waliduje się
```bash
python3 tests/validate_phase_json.py logs/runs/<id>/<cat>/<phase>.json
```
Komunikat `FAIL` mówi gdzie. Najczęstsze: zły `category`, niewalidne `code` (regex `^[A-Z][A-Z0-9_-]{1,40}$`).

### NVIDIA DKMS się sypie
- Domyślnie pakiety NVIDIA są **held**. Tylko `--nvidia` próbuje upgrade.
- Po upgrade kernel/driver: `bash scripts/rebuild-dkms.sh && reboot`.

### `apt-get update` failuje
- Zwykle duplikat `*.list` vs `*.sources` (np. MegaSync) — auto-fix w `lib/repos.sh`.
- `sudo rm /etc/apt/sources.list.d/meganz.list` (zachowaj `megaio.sources`).

### Frontend ładuje się pusty
- Cache przeglądarki: `Ctrl+Shift+R`.
- Console (F12) → szukaj 4xx/5xx.
- `curl http://127.0.0.1:8765/` musi zwrócić HTML.

### `pip install` failuje na PEP 668
```bash
pipx install fastapi uvicorn pydantic   # alternatywa
# albo brew Python (zarządzany przez brew, bez PEP 668 limit)
/home/linuxbrew/.linuxbrew/bin/python3 -m pip install fastapi uvicorn pydantic
```

---

## 9. CI / pre-commit checks

```bash
# Wszystko co CI sprawdza, lokalnie:
find . -name "*.sh" -not -path "./.git/*" | xargs -I{} bash -n {}
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_dev_sync_safety.py -v
python3 tests/validate_phase_json.py
bats tests/bash/test_json_emit.bats   # gdy zainstalowany
```

---

## 10. Diagram flow: od kliknięcia w UI do sidecara

```
Browser  ──POST /runs──▶  FastAPI (app/backend/main.py)
                              │
                              ▼ runner.start(loop=…)
                          subprocess.Popen("update-all.sh --profile …")
                              │
                              ▼ outer loop = phase, inner = category
                          orch_run_phase(cat, phase)
                              │
                              ▼ exec scripts/<cat>/<phase>.sh
                          source lib/json.sh
                          json_init <kind> <category>
                          json_register_exit_trap "$JSON_OUT"
                          … operacje, json_count_*, json_add_item …
                          (trap on EXIT) → json_finalize $? "$JSON_OUT"
                              │
                              ▼ logs/runs/<id>/<cat>/<phase>.json (schema v1)
                          orchestrator agreguje run.json
                              │
                              ▼ runner._reader → reader thread → asyncio.Queue
                          SSE /runs/active/stream → Browser (live log)
                              │
                              ▼ runner._finalize_db → SQLite
                          dashboard.history (Overview / History / Logs)
```

---

## 11. Bezpieczeństwo

- Backend bind tylko na `127.0.0.1`. **Nigdy** nie wystawiaj na sieć zewnętrzną.
- Brak autoryzacji HTTP (zaufanie do lokalnego usera). Multi-user host:
  edytuj `systemd/user/ubuntu-aktualizacje-dashboard.service` na unix socket
  + permission 0600.
- POST `/runs` uruchamia `update-all.sh` z uprawnieniami użytkownika.
  Sudo pyta interaktywnie/cache jak w CLI.
- POST `/sync/export?dry_run=false` modyfikuje dysk w lokalizacji Proton —
  preferuj `dry_run=true` jako test.
- Push `/git/push` używa konfiguracji `.git/config`. Nie obchodzi GPG sign.
