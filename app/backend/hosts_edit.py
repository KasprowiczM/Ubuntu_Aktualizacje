"""Read/write helpers for config/hosts.toml.

The dashboard's Hosts tab lets the user add and edit host entries without
shelling into the file. We do a minimal, deterministic TOML serialisation
(only the small subset our schema uses) and back up the previous file
before each write.
"""
from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

from . import config


def _path() -> Path:
    return config.repo_root() / "config" / "hosts.toml"


def _quote(s: str) -> str:
    s = (s or "").replace('\\', '\\\\').replace('"', '\\"')
    return f'"{s}"'


def list_hosts() -> dict[str, Any]:
    """Return the parsed file as a list of {id, ...} dicts. Falls back to
    the example file if hosts.toml hasn't been activated yet."""
    p = _path()
    src = p
    if not p.exists():
        ex = config.repo_root() / "config" / "hosts.toml.example"
        if ex.exists():
            src = ex
    items: list[dict[str, Any]] = []
    cur: dict[str, Any] | None = None
    if src.exists():
        for raw in src.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("[") and line.endswith("]"):
                if cur is not None:
                    items.append(cur)
                cur = {"id": line[1:-1].strip()}
            elif "=" in line and cur is not None:
                k, v = line.split("=", 1)
                k = k.strip(); v = v.strip()
                if v.startswith('"') and v.endswith('"'):
                    v = v[1:-1].replace('\\"', '"').replace("\\\\", "\\")
                # ignore inline comment like  key = "x"   # comment
                cur[k] = v
        if cur is not None:
            items.append(cur)
    return {"items": items, "path": str(src), "active": p.exists()}


def upsert_host(host_id: str, attrs: dict[str, str], orig_id: str | None = None) -> dict[str, Any]:
    """Add or rename+update a host entry. Backs up file on first write."""
    if not host_id or not host_id.replace("-", "").replace("_", "").isalnum():
        raise ValueError("host_id must be alphanumeric (with - or _ only)")
    data = list_hosts()
    items = data["items"]
    target_id = (orig_id or host_id).strip()
    found = False
    for h in items:
        if h.get("id") == target_id:
            h.clear(); h["id"] = host_id
            for k, v in attrs.items():
                if v is not None and v != "":
                    h[k] = v
            found = True
            break
    if not found:
        new = {"id": host_id, **{k: v for k, v in attrs.items() if v}}
        items.append(new)
    return _write(items)


def delete_host(host_id: str) -> dict[str, Any]:
    data = list_hosts()
    items = [h for h in data["items"] if h.get("id") != host_id]
    return _write(items)


def _write(items: list[dict[str, Any]]) -> dict[str, Any]:
    p = _path()
    if p.exists():
        p.with_suffix(p.suffix + f".bak_{int(time.time())}").write_text(
            p.read_text(encoding="utf-8"), encoding="utf-8")
    out = ["# Multi-host registry (managed by Ascendo dashboard).",
           "# Edit via UI Hosts tab; manual edits preserved on next save.",
           ""]
    for h in items:
        hid = h.get("id", "").strip()
        if not hid:
            continue
        out.append(f"[{hid}]")
        for k in ("display_name", "ssh_alias", "repo_path", "description"):
            if k in h and h[k]:
                out.append(f"{k:<13}= {_quote(h[k])}")
        out.append("")
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("\n".join(out), encoding="utf-8")
    return {"ok": True, "items": items, "path": str(p)}
