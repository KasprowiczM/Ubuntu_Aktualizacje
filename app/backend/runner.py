"""Subprocess runner that spawns update-all.sh and streams output to subscribers."""
from __future__ import annotations

import asyncio
import datetime as dt
import json
import os
import shlex
import subprocess
import threading
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

from . import config, db, settings as settings_mod, sudo as sudo_mod


@dataclass
class RunHandle:
    run_id: str
    proc: subprocess.Popen
    log_path: Path
    queue: asyncio.Queue
    loop: asyncio.AbstractEventLoop
    started_at: str
    profile: str | None
    only_cat: str | None
    only_phase: str | None
    dry_run: bool
    log_dir: Path | None = None
    finished: bool = False
    exit_code: int | None = None


class Runner:
    """Tracks active and recent dashboard-launched runs.

    Concurrency: only one `update-all.sh` run at a time (the on-disk flock
    enforces it across the whole project anyway). Single-shot category/phase
    requests honour the same lock.
    """

    def __init__(self) -> None:
        self._active: RunHandle | None = None
        self._lock = threading.Lock()

    @property
    def active(self) -> RunHandle | None:
        return self._active

    def start(self, *, loop: asyncio.AbstractEventLoop,
              profile: str | None = None, only: str | None = None,
              phase: str | None = None, dry_run: bool = False,
              extra_args: Iterable[str] = ()) -> RunHandle:
        with self._lock:
            if self._active and not self._active.finished:
                raise RuntimeError("a run is already in progress")
            run_id = self._generate_run_id()
            log_dir = config.runs_dir() / run_id
            log_dir.mkdir(parents=True, exist_ok=True)
            log_path = log_dir / "dashboard.log"

            cmd: list[str] = [
                "bash", str(config.repo_root() / "update-all.sh"),
                "--no-notify",
                "--run-id", run_id,
            ]
            if profile:
                cmd.extend(["--profile", profile])
            if only:
                cmd.extend(["--only", only])
            if phase:
                cmd.extend(["--phase", phase])
            if dry_run:
                cmd.append("--dry-run")
            # Honour persistent setting: snapshot before apply
            try:
                s = settings_mod.load()
                if s.get("snapshot_before_apply") and not dry_run:
                    cmd.append("--snapshot")
            except Exception:
                pass
            cmd.extend(extra_args)

            env = os.environ.copy()
            env.setdefault("INVENTORY_SILENT", "1")

            # Wire SUDO_ASKPASS for mutating runs so update-all.sh / sub-sudos
            # can read the password without a TTY. The helper is unlinked
            # when the reader thread finishes (see _reader).
            askpass_for_run: str | None = None
            if not dry_run and (phase in (None, "apply", "cleanup")):
                if sudo_mod.have_password():
                    try:
                        helper = sudo_mod.make_askpass()
                        env["SUDO_ASKPASS"] = str(helper)
                        askpass_for_run = str(helper)
                    except Exception as exc:
                        print(f"warning: could not create askpass helper: {exc}")

            log_fh = log_path.open("wb")
            proc = subprocess.Popen(
                cmd,
                cwd=str(config.repo_root()),
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                bufsize=0,
            )
            queue: asyncio.Queue = asyncio.Queue(maxsize=10000)
            started_at = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")

            handle = RunHandle(
                run_id=run_id,
                proc=proc,
                log_path=log_path,
                queue=queue,
                loop=loop,
                started_at=started_at,
                profile=profile,
                only_cat=only,
                only_phase=phase,
                dry_run=dry_run,
                log_dir=log_dir,
            )
            self._active = handle

            # DB row
            with db.connect(config.db_path()) as con:
                db.insert_run(
                    con,
                    run_id=run_id,
                    started_at=started_at,
                    profile=profile,
                    only_cat=only,
                    only_phase=phase,
                    dry_run=dry_run,
                    log_dir=str(log_dir),
                )

            t = threading.Thread(
                target=self._reader,
                args=(handle, log_fh),
                daemon=True,
            )
            t.start()
            return handle

    def _generate_run_id(self) -> str:
        # ULID-ish: timestamp + short random
        ts = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        return f"{ts}-{uuid.uuid4().hex[:6]}"

    def _reader(self, handle: RunHandle, log_fh) -> None:
        try:
            assert handle.proc.stdout is not None
            for line in iter(handle.proc.stdout.readline, b""):
                log_fh.write(line)
                log_fh.flush()
                try:
                    handle.loop.call_soon_threadsafe(
                        handle.queue.put_nowait,
                        {"type": "log", "line": line.decode("utf-8", "replace").rstrip("\n")},
                    )
                except Exception:
                    pass
            handle.proc.wait()
            handle.exit_code = handle.proc.returncode
        finally:
            log_fh.close()
            handle.finished = True
            self._finalize_db(handle)
            # Always wipe the askpass helper after the run, regardless of
            # outcome. We do NOT clear the in-memory password — it stays for
            # the next run within the sudo timestamp lifetime, until the
            # user clicks Logout (POST /sudo/invalidate).
            try:
                sudo_mod.cleanup_askpass()
            except Exception:
                pass
            try:
                handle.loop.call_soon_threadsafe(
                    handle.queue.put_nowait,
                    {"type": "done", "exit_code": handle.exit_code},
                )
            except Exception:
                pass

    def _finalize_db(self, handle: RunHandle) -> None:
        ended_at = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
        run_summary_path = (handle.log_dir or config.runs_dir() / handle.run_id) / "run.json"
        run_summary: dict = {}
        needs_reboot = False
        status = "ok"
        if run_summary_path.exists():
            try:
                run_summary = json.loads(run_summary_path.read_text(encoding="utf-8"))
                status = run_summary.get("status", "ok")
                needs_reboot = bool(run_summary.get("needs_reboot", False))
            except Exception:
                pass
        if handle.exit_code not in (0, None):
            if status == "ok":
                status = "failed"

        with db.connect(config.db_path()) as con:
            db.finalize_run(
                con,
                run_id=handle.run_id,
                ended_at=ended_at,
                status=status,
                needs_reboot=needs_reboot,
                summary=run_summary,
            )
            for phase in run_summary.get("phases", []) or []:
                db.upsert_phase(
                    con,
                    run_id=handle.run_id,
                    category=phase.get("category", "?"),
                    phase=phase.get("kind", "?"),
                    exit_code=phase.get("exit_code"),
                    summary=phase.get("summary"),
                    json_path=phase.get("json"),
                )

    def stop(self, *, signal: int = 15) -> bool:
        h = self._active
        if not h or h.finished:
            return False
        try:
            h.proc.send_signal(signal)
            return True
        except ProcessLookupError:
            return False


_runner = Runner()


def get_runner() -> Runner:
    return _runner
