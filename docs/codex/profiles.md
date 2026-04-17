# Codex Profiles

- `default`: codzienna praca na plikach (`gpt-5.3-codex`, medium).
- `orchestrator`: planowanie/delegowanie (`gpt-5.3-codex`, high).
- `advisor`: analiza read-only (`gpt-5.4`, high, read-only).
- `worker-fast`: szybkie zmiany (`gpt-5.4-mini`, medium).
- `worker-tests`: testy i docs (`gpt-5.4-mini`, medium).

Wszystkie profile i agenci są projektowe, gdy sesja startuje z `CODEX_HOME=.codex.local`.
