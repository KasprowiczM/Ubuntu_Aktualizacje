# Workflow i Profiling

Ten projekt wykorzystuje centralną architekturę i orkiestrację opartą o narzędzia Gemini i Antigravity, z jasno zarysowanymi regułami co do ról modeli (Progressive Disclosure).

## Profile Systemowe
- **Domyślny (low-Pro)** -> `gemini-3.1-pro` + `standard reasoning`: Podstawowy profil codzienny używany przez terminal dla prostych operacji i modyfikacji.
- **Orchestrator** -> `gemini-3.1-pro` + `high reasoning`: Ośrodek centralny planujący prace, analizujący problem z lotu ptaka, oraz ten, który dzieli i deleguje mniejsze taski na niższe instancje.
- **Advisor** -> `gemini-3.1-pro` + `high reasoning` + `read-only`: Typowy architekt w trybie audytu. W tym trybie włączone są restrykcje chroniące przed manipulacją środowiskiem. Nie odpisuje on kodem; opiniuje go na podstawie listowania repozytorium.
- **Flash-Worker** -> `gemini-3-flash`: Szybki agent do masowych poleceń i edycji trywialnych fragmentów kodu na niższych warstwach, np. wyliczanie typów czy masowe testy.

## Workflow i Runtime
- Operuj poprzez przełączanie pomiędzy profilami zdefiniowanymi w `.gemini/settings.json`.
- Wykorzystuj podsumowania (pseudo compression) w obrębie limitu ok. 60% kontekstu. Jeżeli projekt staje się bardzo zawiły w pojedynczej rozmowie roboczej, przekazuj aktualny stan wiedzy i wnioski do `docs/agents/handoff.md`, usuwając resztę historii.
- Wszystkie procesy decyzyjne oraz workflow opierają się na `PLANNING RULE` (patrz plik główny) — wymagana jest min. 95% pewność przed wejściem z planowania w edycję.

## Review i Raportowanie Ryzyk
- Orchestrator zawsze musi sprawdzać rezultaty operacji (nawet od Flash Workera) analizując ewentualne ostrzeżenia z wykonania procesów.
- Audyt zmian polegać powinien na weryfikacji powiązań pomiędzy komponentami i upewnieniu się, że logika uprawnień skryptów, jak te dot. GPU, pozostała zgodna ze stylem (np. użycie helperów `run_as_user`).
