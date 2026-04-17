# Architektura Projektu (Ubuntu_Aktualizacje)

## Czym jest ten projekt
Jednokomendowy pakiet aktualizacyjny Ubuntu 24.04 dla środowiska Dell Precision 5520 (mk-uP5520).
Obsługuje APT, Snap, Homebrew (Linuxbrew), npm, pip/pipx, Flatpak, sterowniki NVIDIA i oprogramowanie układowe (firmware).
Po każdym przebiegu generuje `APPS.md` — spersonalizowany wykaz pakietów (plik ten jest gitignored, aby zapobiec wyciekom lokalnym).

## Kluczowe zasady architektury
| Zasada | Powód |
|------|-----|
| `config/*.list` są jedynym źródłem prawdy | Skrypty czytają z nich dane; nie używaj hardcodowania pakietów w kodzie |
| `APPS.md` jest zawsze gitignored | Zawiera system-specific dane maszyny; `APPS.md.example` stanowi szablon repozytorium |
| Eksportowane `INVENTORY_SILENT=1` przez `update-all.sh` | Zapobiega ponownemu generowaniu `APPS.md` przez mniejsze sub-skrypty |
| Flaga `UPGRADE_NVIDIA` kontroluje APT względem NVIDII | Domyślnie `0` (wstrzymane - apt-mark hold); ustawiana na `1` via flaga `--nvidia` |
| Funkcje `run_silent_as_user` i `run_as_user` dla Brew/Npm | Menedżery te nie powinny i nie mogą działać jako `root` — te helpery wykonują drop uprawnień na `$SUDO_USER` |

## Entry points
- `update-all.sh` — plik główny (master) do uruchamiania; przyjmuje flagi np. `--nvidia`, `--dry-run`, `--only <group>`
- `scripts/update-*.sh` — skrypty dla konkretnych paczek i zadań
- `setup.sh` — bootstrap systemu przy pierwszej konfiguracji

## Pliki bibliotek (`lib/`)
- `lib/common.sh`: Kolory, polecenia `print_*`, helpery uprawnień (`run_silent`, `run_as_user`, `require_sudo`).
- `lib/detect.sh`: Detekcja logiki specyficznej dla menedżerów pakietów np. `detect_package_managers`, detekcja GPU.
- `lib/repos.sh`: Idempotentna konfiguracja środowiska (dodawanie repo APT po ID).
- `lib/git-push.sh`: Auto-push za pomocą .env.local PAT tokenu.

## Znane osobliwości i ograniczenia (mk-uP5520)
- **Kernel 6.17.0-20-generic** - domyślny rdzeń Ubuntu. Moduł DKMS dla NVIDIA (570) jest kompatybilny, jednakże mainline kernels (6.19+) wymagają jego ręcznego zrebuildowania po upgradzie za pomocą `scripts/rebuild-dkms.sh`.
- **`nvidia-driver-570`** i `nvidia-smi` działają stabilnie na GPU M1200. Domyślny tryb blokuje je przez hold aby uniknąć złamania sterowników z powodu nowszego polecanego sterownika w systemie (535 jest domyślnie `autoinstall` w Ubuntu - NIE UŻYWAJ TEGO!).
- **`nvidia-container-toolkit`** został wprost wykluczony by zapobiec WARN z powodu braku istnienia jego modułu.
- **Uprawnienia Brew (Cellar)**: Python caches `__pycache__` potrafią być zajęte przez roota. By temu zapobiec, `update-brew.sh` wykonuje automatyczny operacyjny `chown` na korzyść usera `$SUDO_USER` (zazwyczaj mk). Użycie bez helpera `run_as_user` zablokuje generowanie raportu do `APPS.md`.
- **Mega** ma dublujące repozytoria `megaio.sources` i `meganz.list` (ignoruj ostrzeżenia, polecenia naprawy w razie co polegają na usuwaniu *.list, by zostało tylko .sources).

## Dodawanie oprogramowania
By zainstalować lub usunąć nowy program w ekosystemie, należy edytować właściwe pliki `.list` w katalogu `config/` używając formatu `paczka  # komentarz`. Skrypty zajmą się całą resztą.
