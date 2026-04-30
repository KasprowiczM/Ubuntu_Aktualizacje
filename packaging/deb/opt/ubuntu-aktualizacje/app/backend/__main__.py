"""Entrypoint: `python3 -m app.backend` runs the dashboard on 127.0.0.1:8765."""
from __future__ import annotations

import os

import uvicorn


def main() -> None:
    host = os.environ.get("UA_DASHBOARD_HOST", "127.0.0.1")
    port = int(os.environ.get("UA_DASHBOARD_PORT", "8765"))
    uvicorn.run("app.backend.main:app", host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()
