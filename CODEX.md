# CODEX.md

Codex w tym repo działa jako orkiestrator planujący pracę i delegujący do advisor/worker.

## Profile (zaktualizowane)
- `default` → Sonnet 4.x + medium effort (codzienna praca)
- `orchestrator` → Sonnet 4.x + high effort (planowanie złożonych zadań)
- `advisor` → Opus 4.x + high effort + read-only (architektura/audyt, BEZ pisania kodu)
- `worker-fast` → Haiku 4.x + low effort (boilerplate, testy, formatowanie)

## PLANNING RULE
Zasada 95% pewności obowiązuje z @AGENTS.md.

## Referencje
- @AGENTS.md — główny indeks reguł roboczych
- @CLAUDE.md — kontekst projektu i komendy
- @docs/agents/workflow.md — szczegółowy workflow i delegowanie
- @docs/agents/architecture.md — architektura i quirks systemu
