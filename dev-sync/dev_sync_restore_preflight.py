from __future__ import annotations

import argparse
import sys
from pathlib import Path

from dev_sync_core import (
    ConfigReviewRequired,
    DevSyncError,
    config_path,
    create_provider,
    dirty_tracked_entries,
    load_config,
    print_config_hint,
    read_manifest,
    repo_root_from_script,
    scan_overlay_files,
    should_include_candidate,
    tracked_files,
)


REQUIRED_RESTORE_FILES = [
    "README.md",
    "dev-sync/README.md",
    "dev-sync/QUICK_START.md",
    "dev-sync/RESTORE_MANIFEST.md",
    "dev-sync/dev-sync-import.sh",
    "dev-sync/dev-sync-verify-full.sh",
    "config/dev-sync-excludes.txt",
]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Check whether a fresh clone is ready for private-overlay restore."
    )
    parser.add_argument("--verbose", action="store_true", help="Print provider overlay file paths when inspectable.")
    return parser


def print_section(label: str, items: list[str]) -> None:
    print(f"{label}:")
    if items:
        for item in items:
            print(f"  {item}")
    else:
        print("  <none>")


def missing_required_files(repo_root: Path) -> list[str]:
    return [relpath for relpath in REQUIRED_RESTORE_FILES if not (repo_root / relpath).is_file()]


def main() -> int:
    args = build_parser().parse_args()
    repo_root = repo_root_from_script(__file__)
    failures: list[str] = []
    warnings: list[str] = []

    missing_files = missing_required_files(repo_root)
    if missing_files:
        failures.append("fresh-clone restore files are missing")

    dirty_entries = dirty_tracked_entries(repo_root)
    if dirty_entries:
        failures.append("tracked working tree is not clean")

    cfg_path = config_path(repo_root)
    if not cfg_path.is_file():
        print("SETUP REQUIRED")
        print(f"Project root: {repo_root}")
        print(f"Missing config: {cfg_path}")
        print(print_config_hint(repo_root))
        print("Next step: bash dev-sync/provider_setup.sh")
        return 2

    try:
        config = load_config(repo_root)
        provider = create_provider(config)
        validation_errors = provider.validate()
        if validation_errors:
            failures.append(f"provider validation failed: {'; '.join(validation_errors)}")
        if not provider.is_available():
            failures.append(f"provider {config.provider} is not available")

        provider_root: Path | None = None
        provider_files: set[str] | None = None
        manifest_state = "unavailable"
        skipped_tracked: list[str] = []

        if provider.is_local_filesystem():
            provider_root = provider.get_project_folder()
            if provider_root.is_dir():
                manifest_files = read_manifest(provider_root)
                manifest_state = "present" if manifest_files is not None else "missing; scanned provider folder"
                provider_files = manifest_files if manifest_files is not None else scan_overlay_files(provider_root, config)
                provider_files = {rel for rel in provider_files if should_include_candidate(rel, config)}
                skipped_tracked = sorted(provider_files & tracked_files(repo_root))
                if skipped_tracked:
                    warnings.append("provider contains Git-tracked paths that import will skip")
            else:
                failures.append(f"provider project folder does not exist: {provider_root}")
        else:
            warnings.append("rclone provider cannot be fully inspected until dry-run import")

    except ConfigReviewRequired as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        print(print_config_hint(repo_root), file=sys.stderr)
        return 2
    except DevSyncError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    passed = not failures
    print("PASS fresh-clone restore preflight" if passed else "FAIL fresh-clone restore preflight")
    print(f"Project root: {repo_root}")
    print(f"Provider: {config.provider}")
    if provider_root is not None:
        print(f"Provider root: {provider_root}")
    print(f"Manifest: {manifest_state}")
    if provider_files is not None:
        print(f"Provider overlay files: {len(provider_files)}")

    print_section("Failures", failures)
    print_section("Warnings", warnings)
    print_section("Missing required restore files", missing_files)
    print_section("Dirty tracked files", dirty_entries)
    if skipped_tracked:
        print_section("Provider tracked files skipped by import", skipped_tracked)
    if args.verbose and provider_files is not None:
        print_section("Provider overlay file list", sorted(provider_files))

    if passed:
        print("Next steps:")
        print("  bash dev-sync-import.sh --dry-run --verbose")
        print("  bash dev-sync-import.sh")
        print("  bash dev-sync-verify-full.sh")

    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
