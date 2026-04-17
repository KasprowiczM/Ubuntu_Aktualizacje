# Architektura Projektu

## Cel
Repo utrzymuje przewidywalny workflow aktualizacji Ubuntu 24.04 dla hosta `mk-uP5520`, z pełnym logowaniem i automatycznym raportem stanu (`APPS.md`).

## Główne zasady
| Zasada | Znaczenie praktyczne |
|---|---|
| `config/*.list` to źródło prawdy | pakiety i repozytoria konfigurujemy w listach, nie w kodzie |
| `update-all.sh` to jedyny master entrypoint | wszystkie grupy aktualizacji uruchamiane są w stałej kolejności |
| `APPS.md` jest lokalny (gitignored) | raport ma charakter per-maszyna i nie trafia do repo |
| `INVENTORY_SILENT=1` podczas runa master | subskrypty nie regenerują `APPS.md` wielokrotnie |
| sudo autoryzowane raz na starcie runa master | hasło podajesz raz; sesja sudo jest utrzymywana w tle |
| brew/npm/pipx działają jako użytkownik, nie root | operacje user-space są wykonywane przez `run_as_user` / `run_silent_as_user` |

## Wejścia i przepływ
- `update-all.sh`: orchestrator grup:
  1. `apt`
  2. `snap`
  3. `brew`
  4. `npm`
  5. `pip`
  6. `flatpak`
  7. `drivers`
  8. `inventory`
- `scripts/update-*.sh`: moduły per menedżer/system.
- `setup.sh`: bootstrap/migracja (`migrate`, `discover`, `update-config`, `check`, `rollback`).

## Biblioteki
- `lib/common.sh`: logowanie, summary counters, helpery sudo, helpery user-context.
- `lib/detect.sh`: detekcja OS/hardware/managerów, helpery do policy/wersji pakietów, parsery `.list`.
- `lib/repos.sh`: idempotentne dodawanie repo APT przez ID z `config/apt-repos.list`.
- `lib/git-push.sh`: pomocniczy push z tokenem z `.env.local`.

## Aktualny stan krytycznych ścieżek
- NVIDIA:
  - domyślnie pakiety NVIDIA są holdowane w APT (`--nvidia` wyłącza ten tryb ochronny),
  - `update-drivers.sh` nie używa `ubuntu-drivers autoinstall`,
  - przy `--nvidia` upgrade dotyczy wykrytego `nvidia-driver-*`.
- MEGA:
  - canonical source to `megaio.sources`,
  - legacy `meganz.list` jest usuwany automatycznie podczas ensure repo.
- Homebrew cleanup:
  - skrypt naprawia ownership pod `${BREW_PREFIX}/Cellar`,
  - przy błędzie uprawnień robi retry cleanup po naprawie ownera.

## Dodawanie/zmiana pakietów
- edytuj odpowiedni plik `config/*.list`,
- format: `nazwa-pakietu  # komentarz`,
- następnie uruchom:
  - `./update-all.sh --dry-run`,
  - `bash -n update-all.sh && bash -n scripts/*.sh && bash -n lib/*.sh`.
