# CLAUDE.md — Ubuntu_Aktualizacje

Cel: jednokomendowy pakiet aktualizacyjny Ubuntu 24.04 dla Dell Precision 5520 (mk-uP5520).
Obsługuje APT, Snap, Homebrew, npm, pip/pipx, Flatpak, sterowniki NVIDIA i firmware.

## Stack
- Bash (`update-all.sh`, `scripts/update-*.sh`, `lib/*.sh`)
- Konfiguracja pakietów w `config/*.list` (jedyne źródło prawdy – nie hardcoduj pakietów w skryptach)
- CI GitHub Actions (`.github/workflows/validate.yml`)

## Komendy
```bash
./update-all.sh                        # pełna aktualizacja (NVIDIA held)
./update-all.sh --dry-run              # podgląd bez wykonania
./update-all.sh --only brew            # tylko brew
bash -n update-all.sh && bash -n scripts/*.sh && bash -n lib/*.sh  # walidacja składni
bash lib/git-push.sh push main         # push do GitHub
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_dev_sync_safety.py -v
```

## Dev Sync
- GitHub przechowuje pliki śledzone.
- Proton/rclone przechowuje tylko prywatny overlay ignorowany przez Git (`.env.local`, `.dev_sync_config.json`, lokalne klucze, lokalne ustawienia agentów).
- Nie wysyłaj do Proton plików odtwarzalnych: `APPS.md`, `logs/`, backupów configów, cache, dependency/build output.
- Używaj `bash dev-sync-export.sh --dry-run --verbose` przed realnym exportem.
- `dev-sync` pozostaje oddzielony od `update-all.sh`.

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
- @docs/agents/architecture.md — architektura skryptów, menedżery pakietów, quirks systemu
- @docs/agents/workflow.md — workflow agentów, profile modeli, delegowanie
- @docs/agents/style_guide.md — zasady stylu kodu Bash
- @docs/agents/testing_rules.md — walidacja i testowanie zmian
- @docs/agents/security.md — bezpieczeństwo, sekrety, autoryzacja
- @docs/agents/handoff.md — kompresja kontekstu, przekazywanie pracy między sesjami
