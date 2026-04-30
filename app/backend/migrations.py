"""SQLite migrations for the dashboard history database.

Each migration is a callable taking a ``sqlite3.Connection`` and applying
forward-only schema changes. Migrations are numbered; ``schema_migrations``
table records the highest applied version. ``apply_pending`` is idempotent
and is called by ``db.connect`` on every connection.
"""
from __future__ import annotations

import sqlite3
from typing import Callable

# Migration n should NOT depend on (n+1). Each step is forward-only and small.
Migration = Callable[[sqlite3.Connection], None]


def _m001_baseline(con: sqlite3.Connection) -> None:
    """Baseline schema (matches db.SCHEMA at v0.1)."""
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS runs (
            id           TEXT PRIMARY KEY,
            started_at   TEXT NOT NULL,
            ended_at     TEXT,
            status       TEXT NOT NULL,
            profile      TEXT,
            only_cat     TEXT,
            only_phase   TEXT,
            dry_run      INTEGER NOT NULL DEFAULT 0,
            needs_reboot INTEGER NOT NULL DEFAULT 0,
            log_dir      TEXT,
            summary_json TEXT
        );
        CREATE TABLE IF NOT EXISTS phase_results (
            run_id    TEXT NOT NULL,
            category  TEXT NOT NULL,
            phase     TEXT NOT NULL,
            exit_code INTEGER,
            summary   TEXT,
            json_path TEXT,
            PRIMARY KEY (run_id, category, phase),
            FOREIGN KEY (run_id) REFERENCES runs(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_runs_started ON runs(started_at DESC);
        """
    )


def _m002_snapshot_id(con: sqlite3.Connection) -> None:
    """Track the pre-apply snapshot id (timeshift/etckeeper) per run."""
    cols = {row[1] for row in con.execute("PRAGMA table_info(runs)")}
    if "snapshot_id" not in cols:
        con.execute("ALTER TABLE runs ADD COLUMN snapshot_id TEXT")


def _m003_run_label(con: sqlite3.Connection) -> None:
    """Optional human-friendly label for runs (set from UI)."""
    cols = {row[1] for row in con.execute("PRAGMA table_info(runs)")}
    if "label" not in cols:
        con.execute("ALTER TABLE runs ADD COLUMN label TEXT")


def _m004_run_source(con: sqlite3.Connection) -> None:
    """Distinguish dashboard-launched runs from CLI runs imported from disk."""
    cols = {row[1] for row in con.execute("PRAGMA table_info(runs)")}
    if "source" not in cols:
        con.execute("ALTER TABLE runs ADD COLUMN source TEXT NOT NULL DEFAULT 'dashboard'")


MIGRATIONS: list[tuple[int, str, Migration]] = [
    (1, "baseline",     _m001_baseline),
    (2, "snapshot_id",  _m002_snapshot_id),
    (3, "run_label",    _m003_run_label),
    (4, "run_source",   _m004_run_source),
]


def _ensure_table(con: sqlite3.Connection) -> None:
    con.execute(
        """CREATE TABLE IF NOT EXISTS schema_migrations (
               version INTEGER PRIMARY KEY,
               name    TEXT NOT NULL,
               applied_at TEXT NOT NULL DEFAULT (datetime('now'))
           )"""
    )


def current_version(con: sqlite3.Connection) -> int:
    _ensure_table(con)
    row = con.execute("SELECT MAX(version) FROM schema_migrations").fetchone()
    return int(row[0] or 0) if row else 0


def apply_pending(con: sqlite3.Connection) -> list[int]:
    """Apply migrations whose version > current. Returns list of versions applied."""
    _ensure_table(con)
    applied: list[int] = []
    cur = current_version(con)
    for version, name, fn in MIGRATIONS:
        if version <= cur:
            continue
        fn(con)
        con.execute(
            "INSERT INTO schema_migrations (version, name) VALUES (?, ?)",
            (version, name),
        )
        applied.append(version)
    return applied
