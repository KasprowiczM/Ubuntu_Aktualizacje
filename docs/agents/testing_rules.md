# Testing Rules

## Minimum po każdej zmianie
- Uruchom kontrolę składni: `bash -n update-all.sh && bash -n scripts/*.sh && bash -n lib/*.sh`.
- Jeśli zmiana dotyczy konkretnej grupy aktualizacji, użyj `./update-all.sh --dry-run` lub `--only <group>`.

## Raportowanie
- Podawaj tylko istotny wynik (pass/fail + 1-2 linie diagnozy).
- Długie logi streszczaj; nie wklejaj pełnych outputów bez potrzeby.
