"""Prometheus text-format ``/metrics`` exporter.

Stays dependency-free: emits metrics by hand (Prometheus exposition spec
0.0.4) rather than pulling ``prometheus_client`` to keep the dashboard
runtime small.  Metrics are computed on demand from the SQLite history and
the latest run sidecars — no in-memory counters that need lifetime
management.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable

from . import config, db


def _esc(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _line(name: str, labels: dict[str, str], value: float) -> str:
    if labels:
        body = ",".join(f'{k}="{_esc(v)}"' for k, v in labels.items())
        return f"{name}{{{body}}} {value}"
    return f"{name} {value}"


def render() -> str:
    """Render the current metric snapshot."""
    out: list[str] = []

    # ── Reboot pending ───────────────────────────────────────────────────
    out.append("# HELP ubuntu_aktualizacje_reboot_required 1 if /var/run/reboot-required exists.")
    out.append("# TYPE ubuntu_aktualizacje_reboot_required gauge")
    out.append(_line(
        "ubuntu_aktualizacje_reboot_required", {},
        1 if Path("/var/run/reboot-required").exists() else 0,
    ))

    # ── Last 50 runs: status + duration ─────────────────────────────────
    runs: list[dict] = []
    try:
        with db.connect(config.db_path()) as con:
            runs = db.list_runs(con, limit=50)
    except Exception:
        runs = []

    out.append("# HELP ubuntu_aktualizacje_run_total Number of runs by status (last 50).")
    out.append("# TYPE ubuntu_aktualizacje_run_total counter")
    counts: dict[str, int] = {}
    for r in runs:
        s = r.get("status") or "unknown"
        counts[s] = counts.get(s, 0) + 1
    for status, n in sorted(counts.items()):
        out.append(_line("ubuntu_aktualizacje_run_total", {"status": status}, n))

    out.append("# HELP ubuntu_aktualizacje_last_run_duration_seconds Duration of the most recent finished run.")
    out.append("# TYPE ubuntu_aktualizacje_last_run_duration_seconds gauge")
    last_dur = 0.0
    last_status = "unknown"
    for r in runs:
        if r.get("ended_at"):
            try:
                import datetime as dt
                start = dt.datetime.fromisoformat(r["started_at"].replace("Z", "+00:00"))
                end   = dt.datetime.fromisoformat(r["ended_at"].replace("Z", "+00:00"))
                last_dur = max(0.0, (end - start).total_seconds())
                last_status = r.get("status") or "unknown"
            except Exception:
                pass
            break
    out.append(_line(
        "ubuntu_aktualizacje_last_run_duration_seconds",
        {"status": last_status}, last_dur,
    ))

    # ── Phase summary from latest run sidecars ──────────────────────────
    out.append("# HELP ubuntu_aktualizacje_phase_summary Counts per phase from the most recent run sidecars.")
    out.append("# TYPE ubuntu_aktualizacje_phase_summary gauge")
    if runs:
        log_dir = runs[0].get("log_dir")
        if log_dir:
            for sidecar in sorted(Path(log_dir).glob("*/*.json")):
                if sidecar.name == "run.json":
                    continue
                try:
                    d = json.loads(sidecar.read_text(encoding="utf-8"))
                except Exception:
                    continue
                cat = str(d.get("category", ""))
                phase = str(d.get("kind", ""))
                summary = d.get("summary") or {}
                for bucket in ("ok", "warn", "err"):
                    out.append(_line(
                        "ubuntu_aktualizacje_phase_summary",
                        {"category": cat, "phase": phase, "bucket": bucket},
                        float(summary.get(bucket, 0) or 0),
                    ))

    # ── Inventory totals (cached) ───────────────────────────────────────
    try:
        from . import inventory as inv
        s = inv.summary()
        totals = s.get("totals", {}) if isinstance(s, dict) else {}
        out.append("# HELP ubuntu_aktualizacje_inventory_totals Package status counts across categories.")
        out.append("# TYPE ubuntu_aktualizacje_inventory_totals gauge")
        for k in ("ok", "outdated", "missing"):
            out.append(_line(
                "ubuntu_aktualizacje_inventory_totals",
                {"status": k}, float(totals.get(k, 0) or 0),
            ))
    except Exception:
        pass

    return "\n".join(out) + "\n"
