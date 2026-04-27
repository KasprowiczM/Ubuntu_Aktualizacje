# CODEX.md

Codex w tym repo działa jako główny orchestrator planujący pracę, delegujący ją do advisor/worker i integrujący wynik końcowy.

## Profile
- `default` -> `gpt-5.3-codex` + `medium`
- `orchestrator` -> `gpt-5.3-codex` + `high`
- `advisor` -> `gpt-5.4` + `high` + `read-only`
- `worker-fast` -> `gpt-5.4-mini` + `medium`
- `worker-tests` -> `gpt-5.4-mini` + `medium`

## Runtime
- Projektowa konfiguracja i agenci są w `.codex.local/`.
- Uruchamiaj z `CODEX_HOME=.codex.local`, aby używać dokładnie tych profili i limitów.

## Rules
- Zasada 95% pewności obowiązuje z @AGENTS.md.
- Kompresuj historię roboczą zanim kontekst przekroczy ~60%.
- `dev-sync` jest osobnym workflow: GitHub dla plików śledzonych, Proton/rclone tylko dla prywatnego overlay.
- Przed realnym exportem prywatnego overlay uruchom `bash dev-sync-export.sh --dry-run --verbose`.
- Fresh-clone recovery ma iść przez `scripts/preflight.sh`, `dev-sync/provider_setup.sh`, `scripts/restore-from-proton.sh`, `scripts/bootstrap.sh --skip-sync`, `scripts/verify-state.sh`.
- `config/restore-manifest.json` jest deklaratywnym kontraktem: co jest prywatnym overlay, a co jest odtwarzalne/generowane.

## Referencje
- @AGENTS.md - główny indeks reguł roboczych
- @CLAUDE.md - kontekst projektu i zasady domenowe
- @docs/agents/workflow.md - szczegółowy workflow orchestrator/advisor/workers
- @docs/agents/architecture.md - architektura i quirks systemu
