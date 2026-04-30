# Security Rules

- Nie commituj `APPS.md` ani `.env.local`.
- Nie ujawniaj tokenów/secrets z logów lub env.
- Nie dodawaj destrukcyjnych poleceń systemowych bez jawnej potrzeby i potwierdzenia.
- Aktualizacje sterowników/GPU traktuj ostrożnie; respektuj obecny workflow flag `--nvidia` i `--no-drivers`.
- Nie commituj `.dev_sync_config.json`, `.dev_sync_manifest.json`, rclone configów, tokenów Proton/rclone ani zawartości `dev_sync_logs/`.
- `dev-sync` używa Proton/rclone tylko dla prywatnego overlay; GitHub pozostaje źródłem prawdy dla plików śledzonych.
- Nie używaj `rclone sync` dla prywatnego overlay bez osobnego review; eksport używa semantyki copy.
- Cleanup providera musi być plan-first/quarantine-first: najpierw plan JSON, potem quarantine, potem osobny purge z `--apply`.
- Nie usuwaj lokalnych kopii Proton Drive ręcznie, jeśli usunięcie może propagować delete do chmury. Najpierw wykonaj weryfikację i użyj bezpiecznego mechanizmu providera.
