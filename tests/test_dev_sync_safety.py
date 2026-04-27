from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEV_SYNC_DIR = REPO_ROOT / "dev-sync"
sys.path.insert(0, str(DEV_SYNC_DIR))

from dev_sync_core import (  # noqa: E402
    DEFAULT_EXCLUDE_PATTERNS,
    DEFAULT_INCLUDE_ALWAYS,
    DevSyncError,
    read_manifest,
    safe_relpath,
)
from dev_sync_prune_excluded import quarantine_from_plan  # noqa: E402


class NullLogger:
    def log(self, message: str, always_stdout: bool = True) -> None:
        pass


class DevSyncPathSafetyTests(unittest.TestCase):
    def test_safe_relpath_rejects_escape_paths(self) -> None:
        bad_paths = [
            "../outside",
            "nested/../../outside",
            "/tmp/outside",
            "C:/outside",
            "nested/\noutside",
            "",
            ".",
        ]
        for bad_path in bad_paths:
            with self.subTest(path=bad_path):
                with self.assertRaises(DevSyncError):
                    safe_relpath(bad_path)

    def test_safe_relpath_keeps_normal_project_paths(self) -> None:
        self.assertEqual(safe_relpath("./.env.local"), ".env.local")
        self.assertEqual(safe_relpath("dir/private.txt"), "dir/private.txt")

    def test_read_manifest_rejects_unsafe_relpaths(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / ".dev_sync_manifest.json").write_text(
                json.dumps({"format": 1, "files": ["../outside"]}),
                encoding="utf-8",
            )
            with self.assertRaises(DevSyncError):
                read_manifest(root)

    def test_quarantine_plan_rebuilds_source_from_safe_relpath(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp) / "provider"
            base.mkdir()
            plan = {
                "provider_root": str(base),
                "entries": [
                    {
                        "path": str(base / "safe.txt"),
                        "relpath": "../outside.txt",
                    }
                ],
            }
            with self.assertRaises(DevSyncError):
                quarantine_from_plan(plan, base, base / "dev_sync_quarantine", NullLogger())


class StaticDevSyncConfigTests(unittest.TestCase):
    def read_script(self, name: str) -> str:
        return (REPO_ROOT / name).read_text(encoding="utf-8")

    def test_rebuildable_and_generated_outputs_are_excluded(self) -> None:
        expected = {
            ".tmp-shots/",
            "node_modules/",
            "dist/",
            "build/",
            "logs/",
            "APPS.md",
            ".codex.local/tmp/",
            "config/*.bak_*",
            "graphify-out/cache/",
            "graphify-out/manifest.json",
            "graphify-out/cost.json",
            ".graphify_*",
        }
        self.assertTrue(expected.issubset(set(DEFAULT_EXCLUDE_PATTERNS)))

    def test_private_overlay_policy_is_explicit(self) -> None:
        expected_private = {
            ".dev_sync_config.json",
            ".env.local",
            "github",
            "github.pub",
            ".claude/settings.local.json",
        }
        self.assertTrue(expected_private.issubset(set(DEFAULT_INCLUDE_ALWAYS)))
        self.assertNotIn("APPS.md", DEFAULT_INCLUDE_ALWAYS)
        self.assertNotIn("logs/", DEFAULT_INCLUDE_ALWAYS)

    def test_root_wrappers_delegate_to_dev_sync_scripts(self) -> None:
        wrappers = [
            "dev-sync-export.sh",
            "dev-sync-import.sh",
            "dev-sync-verify-full.sh",
            "dev-sync-verify-git.sh",
            "dev-sync-prune-excluded.sh",
            "dev-sync-purge-quarantine.sh",
            "dev-sync-proton-status.sh",
        ]
        for wrapper in wrappers:
            with self.subTest(wrapper=wrapper):
                text = self.read_script(wrapper)
                self.assertIn(f"/dev-sync/{wrapper}", text)
                self.assertIn('"$@"', text)


if __name__ == "__main__":
    unittest.main()
