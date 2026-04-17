# CODEX.md

Codex w tym repo działa jako główny orchestrator planujący pracę, delegujący ją do advisor/worker i integrujący wynik końcowy.

## Profile
- `default` -> `gpt-5.3-codex` + `medium` (domyślny worker dla codziennej pracy)
- `orchestrator` -> `gpt-5.3-codex` + `high` (planowanie i delegowanie)
- `advisor` -> `gpt-5.4` + `high` + `read-only` (architektura/audyt, bez edycji)
- `worker-fast` -> `gpt-5.4-mini` + `medium` (szybkie, proste zmiany)
- `worker-tests` -> `gpt-5.4-mini` + `medium` (testy i dokumentacja)

## Runtime
- Project config i agenci są w `.codex.local/`.
- Uruchamiaj CLI/app z `CODEX_HOME=.codex.local`, aby profile i limity były spójne.

## Rules
- Zasada 95% pewności obowiązuje z @AGENTS.md.
- Kompresuj historię roboczą zanim kontekst przekroczy ~60%.

## Referencje
- @AGENTS.md - główny indeks reguł roboczych
- @CLAUDE.md - kontekst projektu i zasady domenowe
- @docs/agents/workflow.md - szczegółowy workflow orchestrator/advisor/workers
- @docs/agents/architecture.md - architektura i quirks systemu
