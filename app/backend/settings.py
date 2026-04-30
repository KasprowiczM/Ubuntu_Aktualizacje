"""Persistent dashboard settings (JSON in $XDG_CONFIG_HOME)."""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

DEFAULTS: dict[str, Any] = {
    "default_profile": "safe",
    "snapshot_before_apply": False,
    "scheduler": {
        "enabled": False,
        "calendar": "Sun *-*-* 03:00:00",
        "profile": "safe",
        "no_drivers": True,
        # Maintenance window guard (HH:MM-HH:MM, 24h). Blank = no restriction.
        "maintenance_window": "",
        # Defer if on battery / low battery.
        "require_ac": False,
    },
    "notifications": {
        "desktop": True,
    },
    # Optional AI provider for Smart Suggestions enrichment.
    "ai": {
        "provider": "",     # "" | "anthropic" | "openai"
        "api_key": "",
        "model": "",
    },
    # GitHub releases auto-update notifier (opt-in, read-only).
    "updates": {
        "check_repo": "",   # e.g. "user/ascendo" — empty disables check
    },
}


def settings_path() -> Path:
    base = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    p = base / "ubuntu-aktualizacje" / "settings.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def _merge(defaults: dict, overrides: dict) -> dict:
    out = dict(defaults)
    for k, v in overrides.items():
        if k in out and isinstance(out[k], dict) and isinstance(v, dict):
            out[k] = _merge(out[k], v)
        else:
            out[k] = v
    return out


def load() -> dict[str, Any]:
    p = settings_path()
    if not p.exists():
        return dict(DEFAULTS)
    try:
        return _merge(DEFAULTS, json.loads(p.read_text(encoding="utf-8")))
    except Exception:
        return dict(DEFAULTS)


def save(data: dict[str, Any]) -> dict[str, Any]:
    merged = _merge(DEFAULTS, data)
    p = settings_path()
    tmp = p.with_suffix(".json.partial")
    tmp.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, p)
    return merged
