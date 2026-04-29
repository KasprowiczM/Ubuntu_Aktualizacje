"""Dashboard FastAPI application — local 127.0.0.1 service."""
from __future__ import annotations

import asyncio
import json
import shlex
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from . import (
    config,
    db,
    settings as settings_mod,
    sudo as sudo_mod,
    hosts as hosts_mod,
    inventory as inv_mod,
)
from .runner import get_runner

app = FastAPI(title="Ubuntu_Aktualizacje Dashboard", version="0.1.0")


class StartRunRequest(BaseModel):
    profile: str | None = None
    only: str | None = None
    phase: str | None = None
    dry_run: bool = False


class SudoAuthRequest(BaseModel):
    password: str


@app.on_event("startup")
def _startup() -> None:
    db.init_db(config.db_path())


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "repo_root": str(config.repo_root()),
        "db_path": str(config.db_path()),
        "runs_dir": str(config.runs_dir()),
    }


@app.get("/categories")
def list_categories() -> dict[str, Any]:
    cats = config.load_categories()
    return {"categories": [c.__dict__ for c in cats.values()]}


@app.get("/profiles")
def list_profiles() -> dict[str, Any]:
    profs = config.load_profiles()
    return {"profiles": [p.__dict__ for p in profs.values()]}


@app.get("/preflight")
def preflight() -> dict[str, Any]:
    repo = config.repo_root()
    items: list[dict[str, Any]] = []
    # Required tools
    import shutil
    for tool in ["bash", "python3", "git", "flock", "apt-get", "snap", "flatpak", "brew", "npm", "pipx"]:
        items.append({"tool": tool, "present": shutil.which(tool) is not None})
    reboot_required = Path("/var/run/reboot-required").exists()
    return {
        "items": items,
        "needs_reboot": reboot_required,
        "repo_clean": (repo / ".git").exists(),
    }


@app.get("/runs")
def runs(limit: int = 100) -> dict[str, Any]:
    with db.connect(config.db_path()) as con:
        return {"runs": db.list_runs(con, limit=limit)}


@app.post("/runs")
async def start_run(req: StartRunRequest) -> dict[str, Any]:
    # Mutating phases need sudo. Pre-flight check protects from non-TTY failure.
    mutating = (req.phase in (None, "apply", "cleanup")) and not req.dry_run
    if mutating:
        st = sudo_mod.status()
        if not st.cached:
            raise HTTPException(
                status_code=401,
                detail={
                    "code": "SUDO-REQUIRED",
                    "msg": "sudo cache not warm; call POST /sudo/auth with password first",
                    "sudo_detail": st.detail,
                },
            )
    runner = get_runner()
    try:
        h = runner.start(
            loop=asyncio.get_running_loop(),
            profile=req.profile,
            only=req.only,
            phase=req.phase,
            dry_run=req.dry_run,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return {"run_id": h.run_id, "started_at": h.started_at}


@app.get("/sudo/status")
def sudo_status() -> dict[str, Any]:
    s = sudo_mod.status()
    return {"cached": s.cached, "detail": s.detail}


@app.post("/sudo/auth")
def sudo_auth(req: SudoAuthRequest) -> dict[str, Any]:
    ok, detail = sudo_mod.store(req.password)
    if not ok:
        raise HTTPException(status_code=401, detail={"code": "SUDO-AUTH-FAIL", "msg": detail})
    return {"cached": True, "detail": detail}


@app.post("/sudo/invalidate")
def sudo_invalidate() -> dict[str, Any]:
    ok = sudo_mod.invalidate()
    return {"invalidated": ok}


# ── Multi-host (SSH read-only) ────────────────────────────────────────────────

@app.get("/hosts")
def list_hosts() -> dict[str, Any]:
    hosts = hosts_mod.load_hosts()
    return {"hosts": [
        {**h.__dict__} for h in hosts.values()
    ]}


@app.get("/hosts/{host_id}/preflight")
def host_preflight(host_id: str) -> dict[str, Any]:
    hosts = hosts_mod.load_hosts()
    h = hosts.get(host_id)
    if h is None:
        raise HTTPException(status_code=404, detail=f"unknown host: {host_id}")
    return hosts_mod.preflight(h)


# ── Inventory (live package scan) ─────────────────────────────────────────────

@app.get("/inventory/summary")
def inventory_summary() -> dict[str, Any]:
    return inv_mod.summary()


@app.get("/inventory")
def inventory_all() -> dict[str, Any]:
    return {"categories": inv_mod.scan_all()}


@app.get("/inventory/{category}")
def inventory_category(category: str) -> dict[str, Any]:
    try:
        items = inv_mod.scan_category(category)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return {"category": category, "items": items}


@app.post("/inventory/refresh")
def inventory_refresh(category: str | None = None) -> dict[str, Any]:
    inv_mod.invalidate(category)
    return {"refreshed": category or "all"}


# IMPORTANT: register literal /runs/active routes BEFORE /runs/{run_id} so
# FastAPI's path-matching prefers the static route.
@app.get("/runs/active")
def get_active_run() -> dict[str, Any]:
    h = get_runner().active
    if not h:
        return {"active": None}
    return {
        "active": {
            "run_id": h.run_id,
            "started_at": h.started_at,
            "profile": h.profile,
            "only": h.only_cat,
            "phase": h.only_phase,
            "dry_run": h.dry_run,
            "finished": h.finished,
            "exit_code": h.exit_code,
        }
    }


@app.post("/runs/active/stop")
def stop_active_run() -> dict[str, Any]:
    runner = get_runner()
    ok = runner.stop()
    return {"stopped": ok, "run_id": runner.active.run_id if runner.active else None}


@app.get("/runs/active/stream")
async def stream_active_run() -> StreamingResponse:
    runner = get_runner()
    h = runner.active
    if not h:
        raise HTTPException(status_code=404, detail="no active run")

    async def gen():
        try:
            while True:
                if h.queue.empty() and h.finished:
                    yield f"event: done\ndata: {json.dumps({'exit_code': h.exit_code})}\n\n"
                    break
                try:
                    msg = await asyncio.wait_for(h.queue.get(), timeout=1.0)
                except asyncio.TimeoutError:
                    yield ": keepalive\n\n"
                    continue
                if msg.get("type") == "done":
                    yield f"event: done\ndata: {json.dumps(msg)}\n\n"
                    break
                yield f"event: log\ndata: {json.dumps(msg)}\n\n"
        except asyncio.CancelledError:
            return

    return StreamingResponse(gen(), media_type="text/event-stream")


@app.get("/runs/{run_id}")
def get_run(run_id: str) -> dict[str, Any]:
    with db.connect(config.db_path()) as con:
        r = db.get_run(con, run_id)
    if r is None:
        # Fallback: synthesise from on-disk run.json (for runs created via CLI)
        run_dir = config.runs_dir() / run_id
        rj = run_dir / "run.json"
        if rj.exists():
            return {"run": json.loads(rj.read_text(encoding="utf-8")), "from_disk": True}
        raise HTTPException(status_code=404, detail="run not found")
    return {"run": r}


@app.get("/runs/{run_id}/phase/{category}/{phase}")
def get_phase_sidecar(run_id: str, category: str, phase: str) -> dict[str, Any]:
    p = config.runs_dir() / run_id / category / f"{phase}.json"
    if not p.exists():
        raise HTTPException(status_code=404, detail="sidecar not found")
    return json.loads(p.read_text(encoding="utf-8"))


@app.get("/runs/{run_id}/phase/{category}/{phase}/log")
def get_phase_log(run_id: str, category: str, phase: str) -> FileResponse:
    p = config.runs_dir() / run_id / category / f"{phase}.log"
    if not p.exists():
        raise HTTPException(status_code=404, detail="log not found")
    return FileResponse(p, media_type="text/plain")


def _git_run(args: list[str], *, check: bool = True) -> tuple[int, str, str]:
    import subprocess
    repo = config.repo_root()
    res = subprocess.run(
        ["git", *args], cwd=repo, capture_output=True, text=True
    )
    if check and res.returncode != 0:
        raise HTTPException(status_code=500, detail=res.stderr.strip() or res.stdout.strip())
    return res.returncode, res.stdout, res.stderr


@app.get("/git/status")
def git_status() -> dict[str, Any]:
    import subprocess
    repo = config.repo_root()
    try:
        branch = subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo, text=True
        ).strip()
        dirty = subprocess.check_output(
            ["git", "status", "--porcelain=v1", "--untracked-files=no"],
            cwd=repo, text=True,
        ).strip()
        ahead_behind = "0\t0"
        try:
            ahead_behind = subprocess.check_output(
                ["git", "rev-list", "--left-right", "--count", "HEAD...@{u}"],
                cwd=repo, text=True,
            ).strip()
        except subprocess.CalledProcessError:
            pass
        ahead, behind = (ahead_behind.split() + ["0", "0"])[:2]
        return {
            "branch": branch,
            "dirty": bool(dirty),
            "ahead": int(ahead),
            "behind": int(behind),
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/git/fetch")
def git_fetch() -> dict[str, Any]:
    rc, out, err = _git_run(["fetch", "--prune"])
    return {"ok": rc == 0, "stdout": out, "stderr": err}


@app.post("/git/pull")
def git_pull() -> dict[str, Any]:
    """Fast-forward only pull. Refuses if working tree dirty."""
    import subprocess
    repo = config.repo_root()
    dirty = subprocess.check_output(
        ["git", "status", "--porcelain=v1", "--untracked-files=no"],
        cwd=repo, text=True,
    ).strip()
    if dirty:
        raise HTTPException(status_code=409, detail="working tree is dirty; commit or stash first")
    rc, out, err = _git_run(["pull", "--ff-only"])
    return {"ok": rc == 0, "stdout": out, "stderr": err}


@app.post("/git/push")
def git_push() -> dict[str, Any]:
    """Push current branch to its upstream. Never force."""
    rc, out, err = _git_run(["push"])
    return {"ok": rc == 0, "stdout": out, "stderr": err}


@app.get("/sync/status")
def sync_status() -> dict[str, Any]:
    """Read latest dev-sync verification log if present."""
    log_dir = config.repo_root() / "dev_sync_logs"
    if not log_dir.exists():
        return {"available": False, "reason": "dev_sync_logs/ missing"}
    logs = sorted(log_dir.glob("*-verify-full.log"), reverse=True)
    if not logs:
        return {"available": False, "reason": "no verify-full logs"}
    latest = logs[0]
    head = latest.read_text(encoding="utf-8", errors="replace").splitlines()[:40]
    overall = "unknown"
    for line in head:
        if line.startswith("OVERALL "):
            overall = line.split(maxsplit=1)[1].strip()
            break
    return {
        "available": True,
        "log_path": str(latest.relative_to(config.repo_root())),
        "overall": overall,
        "head": head,
    }


@app.get("/settings")
def get_settings() -> dict[str, Any]:
    return settings_mod.load()


@app.put("/settings")
def put_settings(payload: dict[str, Any]) -> dict[str, Any]:
    return settings_mod.save(payload)


@app.post("/scheduler/install")
def scheduler_install(payload: dict[str, Any]) -> dict[str, Any]:
    """Install/update systemd timer using the user's preferences."""
    import subprocess
    s = settings_mod.load()
    sched = {**s.get("scheduler", {}), **payload}
    cmd = [
        str(config.repo_root() / "scripts" / "scheduler" / "install.sh"),
        "--calendar", sched.get("calendar", "Sun *-*-* 03:00:00"),
        "--profile",  sched.get("profile",  "safe"),
    ]
    if sched.get("no_drivers"):
        cmd.append("--no-drivers")
    res = subprocess.run(cmd, capture_output=True, text=True)
    s["scheduler"] = {**sched, "enabled": res.returncode == 0}
    settings_mod.save(s)
    return {
        "ok": res.returncode == 0,
        "stdout": res.stdout[-2000:],
        "stderr": res.stderr[-2000:],
        "settings": s,
    }


@app.post("/scheduler/remove")
def scheduler_remove() -> dict[str, Any]:
    import subprocess
    cmd = [str(config.repo_root() / "scripts" / "scheduler" / "install.sh"), "--remove"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    s = settings_mod.load()
    s["scheduler"]["enabled"] = False
    settings_mod.save(s)
    return {"ok": res.returncode == 0, "stdout": res.stdout, "stderr": res.stderr}


@app.post("/sync/export")
def sync_export(dry_run: bool = True) -> dict[str, Any]:
    """Run dev-sync export. Defaults to dry-run for safety."""
    import subprocess
    repo = config.repo_root()
    cmd = [str(repo / "dev-sync-export.sh")]
    if dry_run:
        cmd.extend(["--dry-run", "--verbose"])
    res = subprocess.run(cmd, cwd=repo, capture_output=True, text=True)
    return {
        "ok": res.returncode == 0,
        "dry_run": dry_run,
        "stdout": res.stdout[-4000:],
        "stderr": res.stderr[-4000:],
        "exit_code": res.returncode,
    }


# ── Static frontend ──────────────────────────────────────────────────────────
_FRONT = Path(__file__).resolve().parent.parent / "frontend"
if _FRONT.exists():
    app.mount("/", StaticFiles(directory=str(_FRONT), html=True), name="frontend")
