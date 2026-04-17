# AGENTS.md

Cel projektu: utrzymanie jednego, przewidywalnego workflow aktualizacji Ubuntu 24.04 dla tej maszyny, z bezpiecznym audytem zmian.

## Stack
- Bash (`update-all.sh`, `scripts/update-*.sh`)
- Konfiguracja pakietów przez listy w `config/*.list`
- CI GitHub Actions dla walidacji składni i bezpieczeństwa repo

## Minimalne komendy robocze
```bash
./update-all.sh
./update-all.sh --dry-run
bash -n update-all.sh && bash -n scripts/*.sh && bash -n lib/*.sh
```

## Hierarchia Modeli
- **Sonnet (domyślny orkiestrator)** — codzienne zadania, effort medium, thinking ≤10k tokenów.
- **Advisor (Opus)** — analiza/architektura/audyt; bez pisania kodu. `/subagent advisor`
- **Worker (Haiku)** — boilerplate, testy, komentarze. `/subagent worker-haiku`

## PLANNING RULE (NIEZMIENIALNA)
Nie wprowadzaj żadnych zmian w kodzie, dopóki nie poznasz kodu i wymagań na tyle, aby mieć co najmniej 95% pewności, co trzeba zbudować. Zawsze zadawaj pytania doprecyzowujące i kilkukrotnie weryfikuj swoje założenia, zanim przejdziesz z trybu planowania do implementacji. Ta zasada dotyczy wszystkich profili.

## Referencje
- @CLAUDE.md — główny kontekst projektu i komendy
- @docs/agents/architecture.md — architektura skryptów, działanie menedżerów pakietów
- @docs/agents/workflow.md — workflow agentów i zasady profili
- @docs/agents/style_guide.md — zasady stylu kodu Basha
- @docs/agents/testing_rules.md — zasady walidacji i testowania zmian
- @docs/agents/security.md — polityki bezpieczeństwa, sekrety i autoryzacja
- @docs/agents/handoff.md — kompresja kontekstu i przekazanie pracy między sesjami
