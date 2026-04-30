"""Compute a per-package diff between two runs.

Each phase sidecar carries an ``items`` list with ``{id, action, from, to,
result}``.  We walk both runs' sidecars and bucket the deltas by category
into added / removed / upgraded / downgraded / unchanged.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def _index_run(run_dir: Path) -> dict[str, dict[str, Any]]:
    """Map ``"<category>:<id>"`` → item dict for a run."""
    out: dict[str, dict[str, Any]] = {}
    for sidecar in run_dir.glob("*/*.json"):
        if sidecar.name == "run.json":
            continue
        try:
            d = json.loads(sidecar.read_text(encoding="utf-8"))
        except Exception:
            continue
        cat = d.get("category", "?")
        for item in d.get("items") or []:
            iid = item.get("id")
            if not iid:
                continue
            out[f"{cat}:{iid}"] = item
    return out


def diff_runs(run_a_dir: Path, run_b_dir: Path) -> dict[str, Any]:
    a = _index_run(run_a_dir)
    b = _index_run(run_b_dir)
    keys = set(a) | set(b)
    added: list[dict] = []
    removed: list[dict] = []
    upgraded: list[dict] = []
    downgraded: list[dict] = []
    unchanged = 0
    for k in sorted(keys):
        ia = a.get(k)
        ib = b.get(k)
        if ia and not ib:
            removed.append({"id": k, "from": ia.get("to") or ia.get("from")})
        elif ib and not ia:
            added.append({"id": k, "to": ib.get("to") or ib.get("from")})
        else:
            assert ia is not None and ib is not None  # for type checker
            va = (ia.get("to") or ia.get("from") or "").strip()
            vb = (ib.get("to") or ib.get("from") or "").strip()
            if va == vb:
                unchanged += 1
                continue
            entry = {"id": k, "from": va, "to": vb}
            # cheap heuristic: lexicographic compare on version strings
            if vb > va:
                upgraded.append(entry)
            else:
                downgraded.append(entry)
    return {
        "a": run_a_dir.name,
        "b": run_b_dir.name,
        "totals": {
            "added":      len(added),
            "removed":    len(removed),
            "upgraded":   len(upgraded),
            "downgraded": len(downgraded),
            "unchanged":  unchanged,
        },
        "added":      added,
        "removed":    removed,
        "upgraded":   upgraded,
        "downgraded": downgraded,
    }
