# CLAUDE.md — Ubuntu_Aktualizacje

Cel: jednokomendowy pakiet aktualizacyjny Ubuntu 24.04 dla Dell Precision 5520 (mk-uP5520).
Obsługuje APT, Snap, Homebrew, npm, pip/pipx, Flatpak, sterowniki NVIDIA i firmware.

## Stack
- Bash (`update-all.sh`, `scripts/update-*.sh`, `lib/*.sh`)
- Konfiguracja pakietów w `config/*.list` (jedyne źródło prawdy – nie hardcoduj pakietów w skryptach)
- CI GitHub Actions (`.github/workflows/validate.yml`)

## Komendy
```bash
./update-all.sh                        # pełna aktualizacja (full profile, NVIDIA held)
                                       # sudo password ONCE — askpass dla wszystkich faz
bin/ascendo apps detect                # raport: tracked/detected/missing (kolorowa tabela)
bin/ascendo apps add <pkg> --category <cat>   # dodaj do config/*.list
bin/ascendo apps install-missing       # zainstaluj wszystko z .list co brak na dysku
bin/ascendo profile list               # dostępne szablony profili (dev/media/minimal)
bin/ascendo profile import <name> [--dry-run]  # zaimportuj szablon do config/*.list
bin/ascendo health --json              # post-run audit: failed units, dmesg, disk, reboot
bin/ascendo settings export <file>     # tar.gz konfiguracji do przeniesienia
bin/ascendo settings import <file>     # przywróć konfigurację z tar.gz
bin/ascendo exclusions {list|add|remove} <cat:pkg>   # per-user opt-out z apply
bash packaging/build-deb.sh            # buduje dist/ascendo_<ver>_all.deb
bash scripts/maintenance/prune-logs.sh --keep 50 --days 30  # log retention
curl -X POST http://127.0.0.1:8765/auth/generate-token       # opt-in token auth
curl http://127.0.0.1:8765/metrics                           # Prometheus
curl http://127.0.0.1:8765/runs/<id>/report.md               # MD raport
./update-all.sh --profile quick        # tylko check (read-only sweep, ~15s)
./update-all.sh --profile safe         # bez drivers/firmware
./update-all.sh --dry-run              # podgląd bez wykonania
./update-all.sh --only brew --phase apply
ORCH_QUIET=1 ./update-all.sh ...       # zakneblowany output (tylko sumaryczny)
bash -n update-all.sh && bash -n scripts/*/*.sh && bash -n lib/*.sh
python3 tests/validate_phase_json.py   # walidacja sidecarów JSON v1
bats tests/bash/test_json_emit.bats    # testy emittera (jeśli bats zainstalowany)
bash lib/git-push.sh push main
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_dev_sync_safety.py -v
bash scripts/preflight.sh              # read-only host/recovery readiness
bash scripts/verify-state.sh           # repo/dev-sync/systemd verification

# Dashboard (Etap 2)
pip install --user fastapi uvicorn pydantic
python3 -m app.backend                 # http://127.0.0.1:8765
bash systemd/user/install-dashboard.sh # instaluje user-service

# Snapshot / scheduler / pluginy (Etap 3)
bash scripts/snapshot/create.sh "before apt apply"
bash scripts/scheduler/install.sh --calendar "Sun *-*-* 03:00:00" --profile safe
bash scripts/scheduler/install.sh --status
bash scripts/scheduler/install.sh --remove
```

## Dev Sync
- GitHub przechowuje pliki śledzone.
- Proton/rclone przechowuje tylko prywatny overlay ignorowany przez Git (`.env.local`, `.dev_sync_config.json`, lokalne klucze, lokalne ustawienia agentów).
- Nie wysyłaj do Proton plików odtwarzalnych: `APPS.md`, `logs/`, backupów configów, cache, dependency/build output.
- Używaj `bash dev-sync-export.sh --dry-run --verbose` przed realnym exportem.
- `dev-sync` pozostaje oddzielony od `update-all.sh`.
- Fresh clone flow: `bash scripts/preflight.sh`, `bash dev-sync/provider_setup.sh`, `bash scripts/restore-from-proton.sh --dry-run --verbose`, `bash scripts/bootstrap.sh --skip-sync`, `bash scripts/verify-state.sh`.
- `config/restore-manifest.json` definiuje prywatny overlay i pliki odtwarzalne.

## Profile Agentów
- `default` — `gpt-5.3-codex`, `medium`
- `orchestrator` — `gpt-5.3-codex`, `high`
- `advisor` — `gpt-5.4`, `high`, `read-only`
- `worker-fast` — `gpt-5.4-mini`, `medium`
- `worker-tests` — `gpt-5.4-mini`, `medium`

Konfiguracja profili jest projektowa: `.codex.local/config.toml` i `.codex.local/agents/*.toml`.

## PLANNING RULE (NIEZMIENIALNA)
Nie wprowadzaj żadnych zmian w kodzie, dopóki nie poznasz kodu i wymagań na tyle, aby mieć co najmniej 95% pewności, co trzeba zbudować. W trybie planowania eksploruj kod, zadawaj pytania i kilkukrotnie weryfikuj założenia.

## Kontrola kontekstu i logów
- Monitoruj wypełnienie kontekstu; przy ~60% podsumuj historię roboczą.
- Nie wklejaj długich logów do kontekstu — zapisuj do pliku i czytaj `head`/`tail`/`grep`.
- Nie commituj `APPS.md` ani `.env.local`.

## Referencje (Progressive Disclosure)
- @RUN.md — **uruchomienie + weryfikacja od zera (CLI, dashboard, scheduler, snapshot)**
- @docs/agents/hybrid-mode.md — **hybrid CLI/dashboard, 3 ścieżki tego samego use-case**
- @docs/agents/architecture.md — architektura skryptów, menedżery pakietów, quirks systemu
- @docs/agents/contract.md — **5-fazowy kontrakt skryptów + JSON sidecar (schema v1)**
- @docs/agents/workflow.md — workflow agentów, profile modeli, delegowanie
- @docs/agents/style_guide.md — zasady stylu kodu Bash
- @docs/agents/testing_rules.md — walidacja i testowanie zmian
- @docs/agents/security.md — bezpieczeństwo, sekrety, autoryzacja
- @docs/agents/handoff.md — kompresja kontekstu, przekazywanie pracy między sesjami
- @docs/last-run-review.md — ostatni pełny run, status pakietów i znane ostrzeżenia
- @app/README.md — dashboard (FastAPI + vanilla SPA), REST API, instalacja
