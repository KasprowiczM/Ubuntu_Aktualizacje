"""Post-run health check facade for the dashboard."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

from . import config


def latest_health(run_id: str | None = None) -> dict[str, Any] | None:
    runs = config.runs_dir()
    if run_id is None:
        candidates = sorted(runs.glob("*/"), key=lambda p: p.name, reverse=True)
    else:
        candidates = [runs / run_id]
    for rd in candidates:
        p = rd / "health.json"
        if p.exists():
            try:
                d = json.loads(p.read_text(encoding="utf-8"))
                d["run_id"] = rd.name.rstrip("/")
                return d
            except Exception:
                continue
    return None


def run_now() -> dict[str, Any]:
    """On-demand health check, separate from a run."""
    repo = config.repo_root()
    p = repo / "scripts" / "health-check.sh"
    if not p.exists():
        return {"score": 0, "issues": [{"severity": "err", "msg": "health-check.sh missing"}]}
    res = subprocess.run(["bash", str(p), "--json"], capture_output=True, text=True, timeout=20)
    try:
        return json.loads(res.stdout)
    except Exception:
        return {"score": 0, "issues": [{"severity": "err", "msg": res.stderr.strip() or "parse failed"}]}
