# Style Guide (Project)

## Bash i skrypty
- Zachowuj zgodność z istniejącym stylem Bash i układem skryptów.
- Nie hardcoduj list pakietów w skryptach; źródłem prawdy są `config/*.list`.
- Preferuj małe, lokalne zmiany zamiast szerokich refaktorów bez potrzeby.

## Edycje
- Nie usuwaj istniejącej logiki bezpieczeństwa (`set -euo pipefail`, walidacje wejścia) bez wyraźnego powodu.
- Zachowuj nazewnictwo funkcji i helperów z `lib/common.sh` / `lib/detect.sh`.
