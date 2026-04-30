from __future__ import annotations

import argparse
import sys
from pathlib import Path

from dev_sync_core import (
    ConfigReviewRequired,
    DevSyncError,
    export_candidates,
    load_config,
    print_config_hint,
    repo_root_from_script,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Export private repo overlay files to configured cloud provider.")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be copied without writing files.")
    parser.add_argument("--verbose", action="store_true", help="Print copied file paths and transport details.")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo_root = repo_root_from_script(__file__)

    try:
        config = load_config(repo_root)
    except ConfigReviewRequired as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        print(print_config_hint(repo_root), file=sys.stderr)
        return 2
    except DevSyncError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        print(print_config_hint(repo_root), file=sys.stderr)
        return 1

    try:
        result = export_candidates(repo_root, config, dry_run=args.dry_run, verbose=args.verbose)
    except DevSyncError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    mode = "DRY-RUN" if result.dry_run else "EXPORT"
    _render_summary(mode, repo_root, config, result)
    return 0


def _render_summary(mode: str, repo_root, config, result) -> None:
    """Render a colourful CLI summary table.

    Falls back to plain key=value lines when stdout is not a TTY (so CI
    logs and `| less` stay clean).
    """
    is_tty = sys.stdout.isatty()
    n_total = len(result.exported_files)
    status_label = "ok"  # we only get here on success; errors raise above
    if is_tty:
        # ANSI palette mirrors lib/tables.sh and dashboard CSS.
        OK   = "\033[38;5;34m"
        DIM  = "\033[2m"
        BLD  = "\033[1m"
        RST  = "\033[0m"
        title = f"{BLD}Ascendo dev-sync — {mode.lower()}{RST}"
        print()
        print(f"  {title}")
        print(f"  {DIM}{repo_root} → {result.destination}{RST}")
        print()
        # Mini table
        rows = [
            ("Provider",   config.provider),
            ("Transport",  result.transport),
            ("Files",      str(n_total)),
            ("Log",        str(result.log_path)),
        ]
        wkey = max(len(k) for k, _ in rows)
        wval = max(len(v) for _, v in rows)
        bar  = "─" * (wkey + wval + 5)
        print(f"  ┌{bar}┐")
        for k, v in rows:
            print(f"  │ {DIM}{k.ljust(wkey)}{RST}  {v.ljust(wval)} │")
        print(f"  └{bar}┘")
        print(f"  {OK}✔{RST} {mode} PASS  {DIM}({n_total} files){RST}")
        print()
    else:
        print(f"{mode} PASS")
        print(f"Project root: {repo_root}")
        print(f"Provider: {config.provider}")
        print(f"Destination: {result.destination}")
        print(f"Files selected: {n_total}")
        print(f"Transport: {result.transport}")
        print(f"Log: {result.log_path}")


if __name__ == "__main__":
    raise SystemExit(main())
