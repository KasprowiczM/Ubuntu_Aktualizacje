# Codex Workflow

1. `orchestrator`: analizuje zadanie, dzieli na etapy, decyduje co delegować.
2. `advisor` (read-only): ocenia architekturę, ryzyka, review i plan testów.
3. `worker-fast` / `worker-tests`: realizują wąskie zadania implementacyjne.
4. `orchestrator`: scala wynik, wykonuje końcową walidację, publikuje zwięzłe podsumowanie.

Zasada: deleguj tylko prace niezależne; zadania krytyczne dla następnego kroku wykonuj lokalnie.
