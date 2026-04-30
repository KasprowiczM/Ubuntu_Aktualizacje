"""Local-only run telemetry — duration averages, ETAs, simple charts."""
from __future__ import annotations

from typing import Any

from . import config, db


def averages_by_profile(limit: int = 50) -> dict[str, Any]:
    """Average run duration per profile, computed from the last N runs.
    Used by the History tab to show ETA next to a freshly started run."""
    out: dict[str, dict[str, Any]] = {}
    with db.connect(config.db_path()) as con:
        cur = con.execute(
            "SELECT profile, started_at, ended_at, status FROM runs "
            "WHERE ended_at IS NOT NULL ORDER BY id DESC LIMIT ?", (limit,))
        for prof, sa, ea, st in cur:
            if not prof or not sa or not ea:
                continue
            try:
                # Stored as ISO-8601; parse loosely.
                from datetime import datetime as _dt
                d_a = _dt.fromisoformat(sa.replace("Z", "+00:00"))
                d_b = _dt.fromisoformat(ea.replace("Z", "+00:00"))
                seconds = max(0, int((d_b - d_a).total_seconds()))
            except Exception:
                continue
            slot = out.setdefault(prof, {"durations": [], "ok": 0, "fail": 0})
            slot["durations"].append(seconds)
            if st == "ok":
                slot["ok"] += 1
            else:
                slot["fail"] += 1
    summary: dict[str, Any] = {}
    for prof, slot in out.items():
        ds = slot["durations"]
        if not ds:
            continue
        ds_sorted = sorted(ds)
        summary[prof] = {
            "samples": len(ds),
            "avg_seconds": int(sum(ds) / len(ds)),
            "median_seconds": ds_sorted[len(ds_sorted) // 2],
            "p90_seconds": ds_sorted[int(len(ds_sorted) * 0.9)] if len(ds_sorted) > 1 else ds_sorted[0],
            "ok_pct": int(slot["ok"] * 100 / max(1, slot["ok"] + slot["fail"])),
        }
    return summary
