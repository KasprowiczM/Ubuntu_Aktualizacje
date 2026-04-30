"""SQLite history store for dashboard runs."""
from __future__ import annotations

import json
import re
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from . import migrations


def init_db(path: Path) -> None:
    """Ensure DB exists and all migrations are applied."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(path) as con:
        con.execute("PRAGMA foreign_keys=ON;")
        migrations.apply_pending(con)
        con.commit()


@contextmanager
def connect(path: Path) -> Iterator[sqlite3.Connection]:
    init_db(path)
    con = sqlite3.connect(path, isolation_level=None)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL;")
    con.execute("PRAGMA foreign_keys=ON;")
    try:
        yield con
    finally:
        con.close()


def insert_run(con: sqlite3.Connection, *, run_id: str, started_at: str,
               profile: str | None, only_cat: str | None,
               only_phase: str | None, dry_run: bool, log_dir: str | None,
               source: str = "dashboard") -> None:
    con.execute(
        """INSERT INTO runs (id, started_at, status, profile, only_cat, only_phase,
                              dry_run, log_dir, source)
           VALUES (?,?,?,?,?,?,?,?,?)""",
        (run_id, started_at, "running", profile, only_cat, only_phase,
         1 if dry_run else 0, log_dir, source),
    )


def finalize_run(con: sqlite3.Connection, *, run_id: str, ended_at: str,
                 status: str, needs_reboot: bool, summary: dict) -> None:
    con.execute(
        """UPDATE runs SET ended_at=?, status=?, needs_reboot=?, summary_json=?
           WHERE id=?""",
        (ended_at, status, 1 if needs_reboot else 0, json.dumps(summary), run_id),
    )


def upsert_phase(con: sqlite3.Connection, *, run_id: str, category: str, phase: str,
                 exit_code: int | None, summary: dict | None, json_path: str | None) -> None:
    con.execute(
        """INSERT INTO phase_results (run_id, category, phase, exit_code, summary, json_path)
           VALUES (?,?,?,?,?,?)
           ON CONFLICT(run_id, category, phase) DO UPDATE
             SET exit_code=excluded.exit_code,
                 summary=excluded.summary,
                 json_path=excluded.json_path""",
        (run_id, category, phase, exit_code,
         json.dumps(summary) if summary is not None else None,
         json_path),
    )


def list_runs(con: sqlite3.Connection, *, limit: int = 100) -> list[dict]:
    rows = con.execute(
        """SELECT id, started_at, ended_at, status, profile, only_cat, only_phase,
                  dry_run, needs_reboot, log_dir, summary_json, source
           FROM runs ORDER BY started_at DESC LIMIT ?""",
        (limit,),
    ).fetchall()
    out = []
    for r in rows:
        d = dict(r)
        if d.get("summary_json"):
            try:
                d["summary"] = json.loads(d.pop("summary_json"))
            except Exception:
                d["summary"] = None
        else:
            d.pop("summary_json", None)
            d["summary"] = None
        d["dry_run"] = bool(d["dry_run"])
        d["needs_reboot"] = bool(d["needs_reboot"])
        out.append(d)
    return out


def get_run(con: sqlite3.Connection, run_id: str) -> dict | None:
    row = con.execute(
        """SELECT * FROM runs WHERE id=?""",
        (run_id,),
    ).fetchone()
    if not row:
        return None
    d = dict(row)
    d["dry_run"] = bool(d["dry_run"])
    d["needs_reboot"] = bool(d["needs_reboot"])
    if d.get("summary_json"):
        try:
            d["summary"] = json.loads(d.pop("summary_json"))
        except Exception:
            d["summary"] = None
    else:
        d.pop("summary_json", None)
        d["summary"] = None
    phases = con.execute(
        """SELECT category, phase, exit_code, summary, json_path
           FROM phase_results WHERE run_id=? ORDER BY category, phase""",
        (run_id,),
    ).fetchall()
    d["phases"] = [
        {
            **dict(p),
            "summary": json.loads(p["summary"]) if p["summary"] else None,
        }
        for p in phases
    ]
    return d


# ── Filesystem reconciliation ────────────────────────────────────────────────
_RUN_ID_RE = re.compile(r"^(\d{8})T(\d{6})Z-[A-Za-z0-9]+$")


def _started_at_from_run_id(run_id: str) -> str | None:
    m = _RUN_ID_RE.match(run_id)
    if not m:
        return None
    d, t = m.group(1), m.group(2)
    return f"{d[0:4]}-{d[4:6]}-{d[6:8]}T{t[0:2]}:{t[2:4]}:{t[4:6]}+00:00"


def _infer_profile_from_phases(phases: list[dict]) -> str | None:
    """CLI runs don't record the profile flag, but the phase set hints at it."""
    if not phases:
        return None
    kinds = {p.get("kind") for p in phases}
    cats = {p.get("category") for p in phases}
    if kinds == {"check"}:
        return "quick"
    if "drivers" not in cats:
        return "safe"
    return "full"


def import_disk_runs(con: sqlite3.Connection, runs_dir: Path) -> int:
    """Reconcile logs/runs/<id>/run.json into the DB.

    Picks up runs created from the CLI (./update-all.sh) or scheduler so
    they show up in dashboard history. Idempotent — only inserts ids that
    are not already in the runs table. Returns the count imported.
    """
    if not runs_dir.exists():
        return 0
    existing = {row[0] for row in con.execute("SELECT id FROM runs")}
    imported = 0
    for entry in sorted(runs_dir.iterdir()):
        if not entry.is_dir():
            continue
        run_id = entry.name
        if run_id in existing:
            continue
        rj = entry / "run.json"
        if not rj.exists():
            continue
        try:
            doc = json.loads(rj.read_text(encoding="utf-8"))
        except Exception:
            continue
        started_at = _started_at_from_run_id(run_id) or doc.get("ended_at") or ""
        ended_at = doc.get("ended_at")
        status = doc.get("status", "ok")
        needs_reboot = bool(doc.get("needs_reboot", False))
        phases = doc.get("phases", []) or []
        profile = _infer_profile_from_phases(phases)
        only_cat = None
        only_phase = None
        # Single-category runs: a manual --only invocation.
        cats = {p.get("category") for p in phases}
        if len(cats) == 1:
            only_cat = next(iter(cats))
        kinds = {p.get("kind") for p in phases}
        if len(kinds) == 1:
            only_phase = next(iter(kinds))
        con.execute(
            """INSERT INTO runs (id, started_at, ended_at, status, profile,
                                  only_cat, only_phase, dry_run, needs_reboot,
                                  log_dir, summary_json, source)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (run_id, started_at, ended_at, status, profile, only_cat, only_phase,
             0, 1 if needs_reboot else 0, str(entry),
             json.dumps(doc), "cli"),
        )
        for phase in phases:
            con.execute(
                """INSERT OR REPLACE INTO phase_results
                       (run_id, category, phase, exit_code, summary, json_path)
                   VALUES (?,?,?,?,?,?)""",
                (run_id, phase.get("category", "?"), phase.get("kind", "?"),
                 phase.get("exit_code"),
                 json.dumps(phase.get("summary")) if phase.get("summary") is not None else None,
                 phase.get("json")),
            )
        imported += 1
    return imported
