"""Live inventory scanner — structured listing of installed packages per category.

Powers the Overview charts and the expandable Categories view. Wraps the
existing scan helpers from ``lib/detect.sh`` via subprocess where it makes
sense, and re-implements the rest in pure Python for speed (no shell
spawn for every package).

Returned shape per item:

    {
      "name":       "firefox",
      "installed":  "131.0",
      "candidate":  "132.0",       # may be None
      "status":     "outdated",    # ok | outdated | missing | unknown
      "in_config":  true,
      "source":     "ubuntu-archive | flathub | brew-formula | …",
    }

Cache: results are memoised for 60s per category. POST /inventory/refresh
clears the cache.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from . import config


@dataclass
class InvCacheEntry:
    fetched_at: float
    items: list[dict]


_CACHE: dict[str, InvCacheEntry] = {}
_CACHE_LOCK = threading.Lock()
_CACHE_TTL_SEC = 60


def _cached(category: str, fetcher) -> list[dict]:
    now = time.time()
    with _CACHE_LOCK:
        e = _CACHE.get(category)
        if e and now - e.fetched_at < _CACHE_TTL_SEC:
            return e.items
    items = fetcher()
    with _CACHE_LOCK:
        _CACHE[category] = InvCacheEntry(fetched_at=now, items=items)
    return items


def invalidate(category: str | None = None) -> None:
    with _CACHE_LOCK:
        if category:
            _CACHE.pop(category, None)
        else:
            _CACHE.clear()


def _read_config_list(rel: str) -> set[str]:
    p = config.repo_root() / rel
    if not p.exists():
        return set()
    out = set()
    for line in p.read_text(encoding="utf-8").splitlines():
        s = line.split("#", 1)[0].strip()
        if s:
            out.add(s.split()[0])
    return out


def _classify(installed: str | None, candidate: str | None) -> str:
    if not installed:
        return "missing"
    if candidate and candidate not in ("(none)", "", "unknown") and candidate != installed:
        return "outdated"
    return "ok"


def _run(cmd: list[str], *, timeout: int = 30) -> str:
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return res.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


# ── APT ───────────────────────────────────────────────────────────────────────

def scan_apt() -> list[dict]:
    return _cached("apt", _scan_apt_inner)


def _scan_apt_inner() -> list[dict]:
    cfg = _read_config_list("config/apt-packages.list")
    items: list[dict] = []

    # Snapshot of currently installed manual-set packages
    out = _run(["apt-mark", "showmanual"])
    installed_set = {l.strip() for l in out.splitlines() if l.strip()}

    # Outdated: parse `apt list --upgradable -a` for from→to
    upg = _run(["apt", "list", "--upgradable"])
    upg_map: dict[str, tuple[str, str]] = {}
    for line in upg.splitlines()[1:]:  # skip "Listing..." header
        # Format: pkg/release version arch [upgradable from: oldver]
        if not line or "/" not in line:
            continue
        pkg = line.split("/", 1)[0]
        new = (line.split() + [""])[1]
        old_m = re.search(r"upgradable from:\s*([^\s\]]+)", line)
        old = old_m.group(1) if old_m else ""
        upg_map[pkg] = (old, new)

    # Build per-package items: union of config + installed (skip noise)
    candidates = sorted(cfg | installed_set)
    for pkg in candidates:
        installed = _run(["dpkg-query", "-W", "-f=${Version}", pkg]).strip() or None
        if pkg in upg_map:
            installed = upg_map[pkg][0] or installed
            cand = upg_map[pkg][1] or None
        else:
            cand = installed if installed else None
        items.append({
            "name":      pkg,
            "installed": installed,
            "candidate": cand,
            "status":    _classify(installed, cand),
            "in_config": pkg in cfg,
            "source":    "apt",
        })
    return items


# ── snap ──────────────────────────────────────────────────────────────────────

def scan_snap() -> list[dict]:
    return _cached("snap", _scan_snap_inner)


def _scan_snap_inner() -> list[dict]:
    cfg = {p.split()[0] for p in _read_config_list("config/snap-packages.list")}
    items: list[dict] = []
    out = _run(["snap", "list"])
    seen = set()
    if not out:
        return items
    base_or_runtime = re.compile(
        r"^(bare|core|core\d*|gnome-\d.*|gtk-common-themes|kf\d+-.*|mesa-.*|snapd|snapd-.*)$"
    )
    for line in out.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 4:
            continue
        name, ver = parts[0], parts[1]
        if base_or_runtime.match(name):
            continue
        seen.add(name)
        items.append({
            "name": name,
            "installed": ver,
            "candidate": None,
            "status": "ok",
            "in_config": name in cfg,
            "source": f"snap/{parts[3] if len(parts) >= 4 else ''}",
        })

    # Outdated: snap refresh --list (queries store)
    out2 = _run(["snap", "refresh", "--list"])
    for line in out2.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 2:
            continue
        name, new_ver = parts[0], parts[1]
        for it in items:
            if it["name"] == name:
                it["candidate"] = new_ver
                it["status"] = "outdated"
                break

    # Missing-from-config items
    for c in cfg:
        if c not in seen:
            items.append({
                "name": c, "installed": None, "candidate": None,
                "status": "missing", "in_config": True, "source": "snap",
            })
    return items


# ── flatpak ───────────────────────────────────────────────────────────────────

def scan_flatpak() -> list[dict]:
    return _cached("flatpak", _scan_flatpak_inner)


def _scan_flatpak_inner() -> list[dict]:
    cfg = _read_config_list("config/flatpak-packages.list")
    items: list[dict] = []
    out = _run(["flatpak", "list", "--app", "--columns=application,version,branch"])
    seen = set()
    for line in out.splitlines():
        parts = line.split("\t")
        if not parts or not parts[0]:
            continue
        app = parts[0]
        ver = parts[1] if len(parts) > 1 else ""
        seen.add(app)
        items.append({
            "name": app,
            "installed": ver or None,
            "candidate": None,
            "status": "ok",
            "in_config": app in cfg,
            "source": "flathub",
        })
    upd = _run(["flatpak", "remote-ls", "--updates"])
    for line in upd.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        # second column is application id in this format
        app_id = parts[1]
        for it in items:
            if it["name"] == app_id:
                it["status"] = "outdated"
                break
    for c in cfg:
        if c not in seen:
            items.append({
                "name": c, "installed": None, "candidate": None,
                "status": "missing", "in_config": True, "source": "flathub",
            })
    return items


# ── brew ──────────────────────────────────────────────────────────────────────

def _brew_bin() -> str | None:
    for b in ("/home/linuxbrew/.linuxbrew/bin/brew", "/usr/local/bin/brew"):
        if Path(b).exists():
            return b
    return None


def scan_brew() -> list[dict]:
    return _cached("brew", _scan_brew_inner)


def _scan_brew_inner() -> list[dict]:
    bb = _brew_bin()
    if not bb:
        return []
    cfg_f = _read_config_list("config/brew-formulas.list")
    cfg_c = _read_config_list("config/brew-casks.list")
    items: list[dict] = []

    # All installed formulas with versions
    out = _run([bb, "list", "--formula", "--versions"])
    installed_f: dict[str, str] = {}
    for line in out.splitlines():
        parts = line.split()
        if parts:
            installed_f[parts[0]] = parts[-1]
    # All installed casks
    out_c = _run([bb, "list", "--cask"])
    installed_c = {l.strip() for l in out_c.splitlines() if l.strip()}

    # Outdated JSON
    raw = _run([bb, "outdated", "--json=v2"])
    outdated_f: dict[str, str] = {}
    outdated_c: dict[str, str] = {}
    if raw:
        try:
            d = json.loads(raw)
            for f in d.get("formulae", []):
                outdated_f[f["name"]] = f.get("current_version", "")
            for c in d.get("casks", []):
                outdated_c[c["name"]] = c.get("current_version", "")
        except Exception:
            pass

    for name, ver in sorted(installed_f.items()):
        cand = outdated_f.get(name)
        items.append({
            "name": name, "installed": ver, "candidate": cand,
            "status": _classify(ver, cand),
            "in_config": name in cfg_f, "source": "brew-formula",
        })
    for f in cfg_f - installed_f.keys():
        items.append({
            "name": f, "installed": None, "candidate": None,
            "status": "missing", "in_config": True, "source": "brew-formula",
        })
    for name in sorted(installed_c):
        cand = outdated_c.get(name)
        items.append({
            "name": name, "installed": "(installed)", "candidate": cand,
            "status": _classify("(installed)", cand),
            "in_config": name in cfg_c, "source": "brew-cask",
        })
    for c in cfg_c - installed_c:
        items.append({
            "name": c, "installed": None, "candidate": None,
            "status": "missing", "in_config": True, "source": "brew-cask",
        })
    return items


# ── npm ───────────────────────────────────────────────────────────────────────

def _npm_bin() -> str | None:
    for b in ("/home/linuxbrew/.linuxbrew/bin/npm", "/usr/bin/npm"):
        if Path(b).exists():
            return b
    return None


def scan_npm() -> list[dict]:
    return _cached("npm", _scan_npm_inner)


def _scan_npm_inner() -> list[dict]:
    nb = _npm_bin()
    if not nb:
        return []
    cfg = _read_config_list("config/npm-globals.list")
    items: list[dict] = []
    raw = _run([nb, "list", "-g", "--depth=0", "--json"])
    installed: dict[str, str] = {}
    if raw:
        try:
            d = json.loads(raw)
            for name, info in (d.get("dependencies") or {}).items():
                installed[name] = info.get("version", "")
        except Exception:
            pass
    out_raw = _run([nb, "outdated", "-g", "--json"])
    outdated: dict[str, str] = {}
    if out_raw:
        try:
            d = json.loads(out_raw)
            for name, info in d.items():
                outdated[name] = info.get("latest", "")
        except Exception:
            pass
    for name, ver in sorted(installed.items()):
        cand = outdated.get(name)
        items.append({
            "name": name, "installed": ver, "candidate": cand,
            "status": _classify(ver, cand),
            "in_config": name in cfg, "source": "npm",
        })
    for c in cfg - installed.keys():
        items.append({
            "name": c, "installed": None, "candidate": None,
            "status": "missing", "in_config": True, "source": "npm",
        })
    return items


# ── pip + pipx ────────────────────────────────────────────────────────────────

def _py_bin() -> str | None:
    for b in ("/home/linuxbrew/.linuxbrew/bin/python3", "/usr/bin/python3"):
        if Path(b).exists():
            return b
    return None


def scan_pip() -> list[dict]:
    return _cached("pip", _scan_pip_inner)


def _scan_pip_inner() -> list[dict]:
    py = _py_bin()
    if not py:
        return []
    cfg_pip = {p.split("==")[0] for p in _read_config_list("config/pip-packages.list")}
    cfg_pipx = {p.split("==")[0] for p in _read_config_list("config/pipx-packages.list")}
    items: list[dict] = []

    raw = _run([py, "-m", "pip", "list", "--user", "--format=json"])
    inst: dict[str, str] = {}
    if raw:
        try:
            for x in json.loads(raw):
                inst[x["name"].lower()] = x["version"]
        except Exception:
            pass
    raw2 = _run([py, "-m", "pip", "list", "--user", "--outdated", "--format=json"])
    outdated: dict[str, str] = {}
    if raw2:
        try:
            for x in json.loads(raw2):
                outdated[x["name"].lower()] = x["latest_version"]
        except Exception:
            pass
    for name, ver in sorted(inst.items()):
        cand = outdated.get(name)
        items.append({
            "name": name, "installed": ver, "candidate": cand,
            "status": _classify(ver, cand),
            "in_config": name in cfg_pip, "source": "pip-user",
        })
    for c in cfg_pip - inst.keys():
        items.append({
            "name": c, "installed": None, "candidate": None,
            "status": "missing", "in_config": True, "source": "pip-user",
        })

    # pipx
    pipx_bin = "pipx"
    raw3 = _run([pipx_bin, "list", "--json"])
    if raw3:
        try:
            d = json.loads(raw3)
            for name, body in (d.get("venvs") or {}).items():
                ver = ""
                try:
                    ver = (body.get("metadata", {}).get("main_package", {}) or {}).get("package_version", "")
                except Exception:
                    pass
                items.append({
                    "name": name, "installed": ver or "(installed)", "candidate": None,
                    "status": "ok",
                    "in_config": name in cfg_pipx, "source": "pipx",
                })
        except Exception:
            pass
    seen_pipx = {it["name"] for it in items if it["source"] == "pipx"}
    for c in cfg_pipx - seen_pipx:
        items.append({
            "name": c, "installed": None, "candidate": None,
            "status": "missing", "in_config": True, "source": "pipx",
        })
    return items


# ── Aggregate ─────────────────────────────────────────────────────────────────

CATEGORY_SCANNERS = {
    "apt":     scan_apt,
    "snap":    scan_snap,
    "flatpak": scan_flatpak,
    "brew":    scan_brew,
    "npm":     scan_npm,
    "pip":     scan_pip,
}


def scan_category(category: str) -> list[dict]:
    fn = CATEGORY_SCANNERS.get(category)
    if not fn:
        raise KeyError(f"unknown category: {category}")
    return fn()


def scan_all() -> dict[str, list[dict]]:
    return {cat: fn() for cat, fn in CATEGORY_SCANNERS.items()}


def summary() -> dict[str, Any]:
    """Aggregated counts per category for the Overview dashboard charts."""
    out: dict[str, Any] = {"categories": {}, "totals": {"ok": 0, "outdated": 0, "missing": 0}}
    for cat, fn in CATEGORY_SCANNERS.items():
        try:
            items = fn()
        except Exception:
            items = []
        ok       = sum(1 for x in items if x["status"] == "ok")
        outdated = sum(1 for x in items if x["status"] == "outdated")
        missing  = sum(1 for x in items if x["status"] == "missing")
        unknown  = sum(1 for x in items if x["status"] not in {"ok","outdated","missing"})
        out["categories"][cat] = {
            "ok": ok, "outdated": outdated, "missing": missing, "unknown": unknown,
            "total": len(items),
        }
        out["totals"]["ok"]       += ok
        out["totals"]["outdated"] += outdated
        out["totals"]["missing"]  += missing
    return out
