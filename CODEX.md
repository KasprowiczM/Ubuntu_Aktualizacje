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

## Referencje
- @AGENTS.md - główny indeks reguł roboczych
- @CLAUDE.md - kontekst projektu i zasady domenowe
- @docs/agents/workflow.md - szczegółowy workflow orchestrator/advisor/workers
- @docs/agents/architecture.md - architektura i quirks systemu
