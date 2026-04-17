# Security Rules

- Nie commituj `APPS.md` ani `.env.local`.
- Nie ujawniaj tokenów/secrets z logów lub env.
- Nie dodawaj destrukcyjnych poleceń systemowych bez jawnej potrzeby i potwierdzenia.
- Aktualizacje sterowników/GPU traktuj ostrożnie; respektuj obecny workflow flag `--nvidia` i `--no-drivers`.
