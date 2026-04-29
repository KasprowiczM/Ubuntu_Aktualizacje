// Ubuntu_Aktualizacje — i18n strings (vanilla, no framework).
// Add a key here, then sprinkle `data-i18n="path.to.key"` in index.html.
window.I18N = {
  en: {
    nav: {
      overview:   "Overview",
      categories: "Categories",
      run:        "Run Center",
      history:    "History",
      logs:       "Logs",
      sync:       "Sync",
      hosts:      "Hosts",
      settings:   "Settings",
    },
    overview: {
      title:        "Overview",
      last_run:     "Last run",
      health:       "System health",
      git:          "Git",
      quick:        "Quick actions",
      btn_quick:    "Quick check",
      btn_safe:     "Safe update",
      btn_full:     "Full update",
      btn_dry:      "Full dry-run",
      no_runs:      "no runs yet",
      reboot_pending: "reboot pending",
      reboot_required: "reboot required",
      inventory:    "Inventory",
      refresh:      "Refresh",
      status_donut: "Status (all categories)",
      per_category: "Per category",
      available_updates: "Available updates",
      no_updates:   "Everything is up to date.",
      scanning:     "Scanning…",
    },
    categories: {
      title:    "Categories",
      hint:     "Click a row to expand the full list of installed packages with version and status.",
      col_cat:  "Category",
      col_total: "Total",
      col_ok:    "OK",
      col_outdated: "Outdated",
      col_missing:  "Missing",
      col_priv: "Privilege",
      col_risk: "Risk",
      col_man:  "Manual",
      col_phs:  "Phases",
      col_act:  "Actions",
      yes: "yes", no: "no",
      col_pkg:    "Package",
      col_inst:   "Installed",
      col_cand:   "Candidate",
      col_status: "Status",
      col_source: "Source",
      col_in_cfg: "In config",
      action_check: "check",
      action_apply: "apply",
      no_items: "(no items in this category)",
    },
    run: {
      title:   "Run Center",
      profile: "Profile",
      only:    "Only",
      phase:   "Phase",
      all:     "(all)",
      profile_default: "(profile default)",
      dry_run: "Dry run",
      start:   "Start run",
      stop:    "Stop",
    },
    history: {
      title:   "History",
      started: "Started",
      profile: "Profile",
      status:  "Status",
      phases:  "Phases",
      reboot:  "Reboot",
      run_id:  "Run id",
    },
    logs: {
      title:        "Logs",
      hint_pick:    "Pick a run from",
      hint_history: "History",
      hint_after:   "to inspect per-phase JSON sidecars and logs.",
    },
    sync: {
      title:    "Sync",
      git:      "Git",
      cloud:    "Cloud overlay (dev-sync)",
      btn_fetch: "Fetch",
      btn_pull:  "Pull (ff-only)",
      btn_push:  "Push",
      btn_export_dry: "Export (dry-run)",
      btn_export_real: "Export (real)",
      output:   "Output",
    },
    hosts: {
      title:        "Hosts",
      hint:         "Read-only SSH preflight across machines in",
      btn_refresh:  "Refresh all",
      col_host:     "Host",
      col_hostname: "Hostname",
      col_os:       "OS",
      col_kernel:   "Kernel",
      col_repo:     "Repo",
      col_lastrun:  "Last run",
      col_status:   "Status",
      none_configured: "No hosts configured. Copy",
      adapt:           "and add entries.",
    },
    settings: {
      title:           "Settings",
      defaults:        "Defaults",
      default_profile: "Default profile",
      snapshot:        "Pre-apply snapshot",
      desktop_notif:   "Desktop notifications",
      ui:              "Appearance",
      theme:           "Theme",
      theme_auto:      "auto (system)",
      theme_light:     "light",
      theme_dark:      "dark",
      language:        "Language",
      lang_auto:       "auto (browser)",
      lang_en:         "English",
      lang_pl:         "Polski",
      scheduler:       "Scheduler (systemd timer)",
      scheduler_enabled: "Enabled (status from system)",
      calendar:        "OnCalendar",
      profile:         "Profile",
      skip_drivers:    "Skip drivers in scheduled run",
      btn_save:        "Save settings",
      btn_install_t:   "Install/Update timer",
      btn_remove_t:    "Remove timer",
    },
    sudo: {
      title:    "Authenticate sudo",
      hint:     "Required for apt / snap / drivers apply phases. Password is sent to 127.0.0.1 only and used to warm the OS sudo timestamp.",
      placeholder: "sudo password",
      authenticate: "Authenticate",
      cancel:   "Cancel",
      cached:   "sudo cached",
      not_cached: "sudo not cached",
    },
    footer: { ready: "ready" },
  },
  pl: {
    nav: {
      overview:   "Przegląd",
      categories: "Kategorie",
      run:        "Centrum uruchamiania",
      history:    "Historia",
      logs:       "Logi",
      sync:       "Synchronizacja",
      hosts:      "Hosty",
      settings:   "Ustawienia",
    },
    overview: {
      title:        "Przegląd",
      last_run:     "Ostatnie uruchomienie",
      health:       "Stan systemu",
      git:          "Git",
      quick:        "Szybkie akcje",
      btn_quick:    "Szybki check",
      btn_safe:     "Bezpieczna aktualizacja",
      btn_full:     "Pełna aktualizacja",
      btn_dry:      "Pełna symulacja",
      no_runs:      "brak uruchomień",
      reboot_pending: "wymagany restart",
      reboot_required: "WYMAGANY RESTART",
      inventory:    "Inwentarz",
      refresh:      "Odśwież",
      status_donut: "Status (wszystkie kategorie)",
      per_category: "Per kategoria",
      available_updates: "Dostępne aktualizacje",
      no_updates:   "Wszystko jest aktualne.",
      scanning:     "Skanuję…",
    },
    categories: {
      title:    "Kategorie",
      hint:     "Kliknij wiersz aby rozwinąć pełną listę zainstalowanych pakietów z wersją i statusem.",
      col_cat:  "Kategoria",
      col_total: "Razem",
      col_ok:    "OK",
      col_outdated: "Nieaktualne",
      col_missing:  "Brakujące",
      col_priv: "Uprawnienia",
      col_risk: "Ryzyko",
      col_man:  "Manualne",
      col_phs:  "Fazy",
      col_act:  "Akcje",
      yes: "tak", no: "nie",
      col_pkg:    "Pakiet",
      col_inst:   "Zainstalowana",
      col_cand:   "Dostępna",
      col_status: "Status",
      col_source: "Źródło",
      col_in_cfg: "W konfiguracji",
      action_check: "check",
      action_apply: "apply",
      no_items: "(brak pakietów w tej kategorii)",
    },
    run: {
      title:   "Centrum uruchamiania",
      profile: "Profil",
      only:    "Tylko",
      phase:   "Faza",
      all:     "(wszystkie)",
      profile_default: "(domyślne profilu)",
      dry_run: "Symulacja",
      start:   "Uruchom",
      stop:    "Zatrzymaj",
    },
    history: {
      title:   "Historia",
      started: "Rozpoczęto",
      profile: "Profil",
      status:  "Status",
      phases:  "Fazy",
      reboot:  "Restart",
      run_id:  "Run id",
    },
    logs: {
      title:        "Logi",
      hint_pick:    "Wybierz uruchomienie z",
      hint_history: "Historii",
      hint_after:   "aby zobaczyć JSON sidecary i logi per-faza.",
    },
    sync: {
      title:    "Synchronizacja",
      git:      "Git",
      cloud:    "Chmura (dev-sync)",
      btn_fetch: "Fetch",
      btn_pull:  "Pull (ff-only)",
      btn_push:  "Push",
      btn_export_dry: "Eksport (symulacja)",
      btn_export_real: "Eksport (prawdziwy)",
      output:   "Wynik",
    },
    hosts: {
      title:        "Hosty",
      hint:         "Read-only SSH preflight dla maszyn z",
      btn_refresh:  "Odśwież wszystkie",
      col_host:     "Host",
      col_hostname: "Nazwa hosta",
      col_os:       "OS",
      col_kernel:   "Kernel",
      col_repo:     "Repo",
      col_lastrun:  "Ostatni run",
      col_status:   "Status",
      none_configured: "Brak skonfigurowanych hostów. Skopiuj",
      adapt:           "i dodaj wpisy.",
    },
    settings: {
      title:           "Ustawienia",
      defaults:        "Domyślne",
      default_profile: "Domyślny profil",
      snapshot:        "Snapshot przed apply",
      desktop_notif:   "Powiadomienia desktopowe",
      ui:              "Wygląd",
      theme:           "Motyw",
      theme_auto:      "auto (system)",
      theme_light:     "jasny",
      theme_dark:      "ciemny",
      language:        "Język",
      lang_auto:       "auto (przeglądarka)",
      lang_en:         "English",
      lang_pl:         "Polski",
      scheduler:       "Harmonogram (systemd timer)",
      scheduler_enabled: "Aktywny (status z systemu)",
      calendar:        "OnCalendar",
      profile:         "Profil",
      skip_drivers:    "Pomiń drivers w zaplanowanym uruchomieniu",
      btn_save:        "Zapisz ustawienia",
      btn_install_t:   "Zainstaluj/zaktualizuj timer",
      btn_remove_t:    "Usuń timer",
    },
    sudo: {
      title:    "Autoryzacja sudo",
      hint:     "Wymagane dla faz apply apt / snap / drivers. Hasło jest wysyłane tylko do 127.0.0.1 i używane do rozgrzania OS-level sudo timestamp.",
      placeholder: "hasło sudo",
      authenticate: "Autoryzuj",
      cancel:   "Anuluj",
      cached:   "sudo zapisane",
      not_cached: "sudo nie zapisane",
    },
    footer: { ready: "gotowy" },
  },
};

// Helpers
window.tr = function tr(path) {
  const lang = window.UI_LANG || "en";
  const dict = window.I18N[lang] || window.I18N.en;
  let cur = dict;
  for (const part of path.split(".")) {
    if (cur && typeof cur === "object" && part in cur) cur = cur[part];
    else { cur = undefined; break; }
  }
  if (cur === undefined && lang !== "en") {
    // fallback to English
    let en = window.I18N.en;
    for (const part of path.split(".")) {
      if (en && typeof en === "object" && part in en) en = en[part];
      else { en = undefined; break; }
    }
    return en !== undefined ? en : path;
  }
  return cur !== undefined ? cur : path;
};

// Apply translation to all elements with [data-i18n="path.to.key"]
window.applyI18n = function applyI18n(root) {
  root = root || document;
  root.querySelectorAll("[data-i18n]").forEach(el => {
    const key = el.getAttribute("data-i18n");
    el.textContent = window.tr(key);
  });
  root.querySelectorAll("[data-i18n-placeholder]").forEach(el => {
    el.setAttribute("placeholder", window.tr(el.getAttribute("data-i18n-placeholder")));
  });
  document.documentElement.lang = window.UI_LANG === "pl" ? "pl" : "en";
};

window.detectLanguage = function detectLanguage() {
  const stored = (window.SETTINGS_CACHE && window.SETTINGS_CACHE.ui && window.SETTINGS_CACHE.ui.language) || "auto";
  if (stored === "en" || stored === "pl") return stored;
  const browser = (navigator.language || "en").toLowerCase();
  return browser.startsWith("pl") ? "pl" : "en";
};

window.applyTheme = function applyTheme(themePref) {
  const root = document.documentElement;
  let mode = themePref;
  if (mode === "auto" || !mode) {
    mode = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
  root.setAttribute("data-theme", mode);
};
