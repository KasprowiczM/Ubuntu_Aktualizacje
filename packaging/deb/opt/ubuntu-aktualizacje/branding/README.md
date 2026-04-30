# Ascendo — branding

| Asset | File | Use |
|---|---|---|
| Square mark | `icon.svg`   | favicon, `.desktop` icon, app shortcut |
| Wordmark    | `logo.svg`   | dashboard header, README hero |
| ASCII banner | `banner.txt` | CLI splash (`update-all.sh`, `fresh-machine.sh`) |

**Name origin:** Latin *ascendō* — "I ascend". Conveys version-rising,
status-improving, system-going-up.

**Palette:**

- Primary green:  `#22c55e` (success / "ok")
- Primary blue:   `#0ea5e9` (action / "info")
- Warning:        `#f59e0b`
- Error:          `#ef4444`
- Slate text:     `#0f172a`
- Slate dim:      `#64748b`
- Surface (dark): `#0b1220`

The same palette feeds CLI `lib/common.sh` ANSI codes and the dashboard's
CSS custom properties so terminal and browser stay visually consistent.
