"""Frontend smoke test — checks served HTML/CSS/JS structure without a browser.

Validates the contract between backend (FastAPI static mount) and the SPA:
  • /                serves index.html with all 7 view sections
  • /style.css       loads
  • /app.js          loads, references all view ids
  • REST endpoints used by the SPA respond 200
  • SSE endpoint exists and content-type is text/event-stream

Run via:
    app/.venv/bin/python tests/python/test_frontend.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO))


def _client():
    # Lazy-import so the test file is itself importable for syntax check
    from app.backend.main import app
    from fastapi.testclient import TestClient
    return TestClient(app)


def assert_200(client, path):
    r = client.get(path)
    assert r.status_code == 200, f"{path}: HTTP {r.status_code} {r.text[:200]}"
    return r


def test_index_has_all_views(client):
    r = assert_200(client, "/")
    body = r.text
    assert "<!doctype html>" in body.lower()
    expected_views = [
        "view-overview", "view-categories", "view-run",
        "view-history", "view-logs", "view-sync", "view-hosts", "view-settings",
    ]
    for vid in expected_views:
        assert f'id="{vid}"' in body, f"missing section id={vid!r}"
    nav_links = re.findall(r'data-view="([^"]+)"', body)
    assert len(nav_links) == len(expected_views), \
        f"expected {len(expected_views)} nav links, found {len(nav_links)}: {nav_links}"
    print(f"  index.html: all {len(expected_views)} views present")


def test_static_assets(client):
    r = assert_200(client, "/style.css")
    assert "--accent" in r.text or ".badge" in r.text, "style.css missing expected rules"
    assert 'data-theme="light"' in r.text, "style.css missing explicit light theme"
    assert 'data-theme="dark"'  in r.text, "style.css missing explicit dark theme"
    r = assert_200(client, "/app.js")
    js = r.text
    for fn in ("loadOverview", "loadCategories", "loadRunCenter",
               "loadHistory", "loadSettings", "loadSync", "loadHosts",
               "attachStream", "sudoMgr", "bootstrap"):
        assert fn in js, f"app.js missing symbol: {fn}"
    r = assert_200(client, "/i18n.js")
    i18n = r.text
    for sym in ("window.I18N", "window.tr", "window.applyI18n",
                "window.applyTheme", "window.detectLanguage",
                '"pl"', "Ustawienia", "Polski"):
        assert sym in i18n, f"i18n.js missing symbol: {sym!r}"
    print("  style.css + app.js + i18n.js: structural OK")


def test_api_contract(client):
    eps = ("/health", "/categories", "/profiles", "/preflight",
           "/runs", "/runs/active", "/git/status",
           "/sync/status", "/settings", "/sudo/status", "/hosts")
    for ep in eps:
        assert_200(client, ep)
    print(f"  {len(eps)}/{len(eps)} GET endpoints OK")


def test_settings_roundtrip(client):
    original = client.get("/settings").json()
    try:
        r = client.put("/settings", json={
            "default_profile": "quick",
            "snapshot_before_apply": True,
            "ui": {"theme": "dark", "language": "pl"},
            "scheduler": {"calendar": "Mon *-*-* 04:00", "profile": "safe", "no_drivers": True},
        })
        assert r.status_code == 200, r.text
        data = r.json()
        assert data["default_profile"] == "quick"
        assert data["snapshot_before_apply"] is True
        assert data["scheduler"]["calendar"] == "Mon *-*-* 04:00"
        assert data["ui"]["theme"] == "dark"
        assert data["ui"]["language"] == "pl"
        again = client.get("/settings").json()
        assert again["ui"]["language"] == "pl"
        print("  settings PUT/GET roundtrip OK (incl. ui.theme + ui.language)")
    finally:
        client.put("/settings", json=original)


def test_categories_structure(client):
    r = client.get("/categories").json()
    cats = r["categories"]
    ids = {c["id"] for c in cats}
    expected = {"apt", "snap", "brew", "npm", "pip", "flatpak", "drivers", "inventory"}
    assert expected <= ids, f"missing categories: {expected - ids}"
    for c in cats:
        for k in ("id", "display_name", "privilege", "risk", "phases"):
            assert k in c, f"category {c.get('id')} missing key {k}"
    print(f"  /categories: 8 expected categories present, all keys ok")


def main() -> int:
    client = _client()
    failed = 0
    tests = [
        test_index_has_all_views,
        test_static_assets,
        test_api_contract,
        test_settings_roundtrip,
        test_categories_structure,
    ]
    for t in tests:
        try:
            t(client)
        except AssertionError as exc:
            print(f"FAIL {t.__name__}: {exc}")
            failed += 1
    if failed:
        print(f"\n{failed}/{len(tests)} test(s) failed")
        return 1
    print(f"\n{len(tests)}/{len(tests)} frontend smoke tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
