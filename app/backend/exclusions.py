"""Exclusion list facade — read/edit config/exclusions.list."""
from __future__ import annotations

import time
from pathlib import Path
from typing import Any

from . import config

_PATH = lambda: config.repo_root() / "config" / "exclusions.list"


def load() -> dict[str, Any]:
    p = _PATH()
    items: list[dict[str, str]] = []
    category_skipped: list[str] = []
    if p.exists():
        for line in p.read_text(encoding="utf-8").splitlines():
            s = line.split("#", 1)[0].strip()
            if not s:
                continue
            if ":" not in s:
                continue
            cat, pkg = s.split(":", 1)
            cat = cat.strip(); pkg = pkg.strip()
            if pkg == "*":
                category_skipped.append(cat)
            else:
                items.append({"category": cat, "package": pkg})
    return {"items": items, "category_skipped": category_skipped, "path": str(p)}


def add(category: str, package: str) -> dict[str, Any]:
    return _toggle(category, package, present=True)


def remove(category: str, package: str) -> dict[str, Any]:
    return _toggle(category, package, present=False)


def _toggle(category: str, package: str, *, present: bool) -> dict[str, Any]:
    if not category or not package:
        raise ValueError("category and package required")
    p = _PATH()
    p.parent.mkdir(parents=True, exist_ok=True)
    cur = p.read_text(encoding="utf-8") if p.exists() else ""
    target = f"{category}:{package}"
    lines = cur.splitlines()
    out: list[str] = []
    matched = False
    for L in lines:
        s = L.split("#", 1)[0].strip()
        if s == target:
            matched = True
            if present:
                out.append(L)        # already present — keep
            else:
                continue              # drop
        else:
            out.append(L)
    if present and not matched:
        out.append(target)
    bak = p.with_suffix(p.suffix + f".bak_{int(time.time())}") if p.exists() else None
    if bak:
        bak.write_text(cur, encoding="utf-8")
    text = "\n".join(out)
    if not text.endswith("\n"):
        text += "\n"
    p.write_text(text, encoding="utf-8")
    return {"ok": True, "added": present and not matched,
            "removed": (not present) and matched, "backup": str(bak) if bak else None}
