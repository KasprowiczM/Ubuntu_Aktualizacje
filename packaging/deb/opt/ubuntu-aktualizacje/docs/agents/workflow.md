# Workflow Agentów

## Źródło konfiguracji
Profile agentów są zdefiniowane lokalnie w:
- `.codex.local/config.toml`
- `.codex.local/agents/*.toml`

Uruchamiaj sesję z:

```bash
CODEX_HOME=.codex.local codex ...
```

## Profile używane w projekcie
- `default` (`gpt-5.3-codex`, `medium`): codzienne zadania implementacyjne.
- `orchestrator` (`gpt-5.3-codex`, `high`): planowanie i integracja wyników.
- `advisor` (`gpt-5.4`, `high`, `read-only`): audyt architektury/ryzyk, bez edycji.
- `worker-fast` (`gpt-5.4-mini`, `medium`): szybkie, ograniczone zmiany kodu.
- `worker-tests` (`gpt-5.4-mini`, `medium`): testy i aktualizacje dokumentacji.

## Zalecany przebieg pracy
1. Orchestrator analizuje zadanie i wyznacza krytyczną ścieżkę.
2. Zadania analityczne deleguj do `advisor`.
3. Zadania mechaniczne/testowe deleguj do workerów.
4. Zmiany i walidację końcową scala orchestrator.

## Zasady operacyjne
- Obowiązuje `PLANNING RULE` (95% pewności przed implementacją).
- Przy dużej sesji streszczaj kontekst przy ~60% i zapisuj stan do `docs/agents/handoff.md`.
- Priorytet walidacji po zmianach:
  - `bash -n update-all.sh && bash -n scripts/*.sh && bash -n lib/*.sh`
  - `./update-all.sh --dry-run`
  - opcjonalnie `./update-all.sh --only <group>` dla modyfikowanej grupy.

## Kryteria jakości review
- najpierw błędy funkcjonalne/regresje,
- potem ryzyka bezpieczeństwa (sudo, sekrety, destrukcyjne komendy),
- na końcu spójność z architekturą (`config/*.list` jako SoT, user-context dla brew/npm/pipx).
