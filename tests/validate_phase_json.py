#!/usr/bin/env python3
"""Validate phase-result JSON sidecars against schemas/phase-result.schema.json.

Uses a tiny built-in validator (no external deps) covering the subset the
schema actually exercises: const, enum, required, type, additionalProperties,
pattern, minimum, maximum, minLength.

Usage:
    python3 tests/validate_phase_json.py [path ...]

If no paths given, recursively validates everything under logs/runs/**/*.json
(except run.json which has its own schema).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


def _type_ok(value: Any, expected: Any) -> bool:
    if isinstance(expected, list):
        return any(_type_ok(value, t) for t in expected)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "array":
        return isinstance(value, list)
    if expected == "object":
        return isinstance(value, dict)
    if expected == "null":
        return value is None
    return False


def validate(value: Any, schema: dict, path: str = "$") -> list[str]:
    errors: list[str] = []

    if "const" in schema and value != schema["const"]:
        errors.append(f"{path}: expected const {schema['const']!r}, got {value!r}")

    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: {value!r} not in enum {schema['enum']}")

    if "type" in schema and not _type_ok(value, schema["type"]):
        errors.append(f"{path}: expected type {schema['type']}, got {type(value).__name__}")
        return errors  # downstream checks unsafe

    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            errors.append(f"{path}: string shorter than minLength {schema['minLength']}")
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errors.append(f"{path}: {value!r} does not match pattern {schema['pattern']!r}")

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path}: {value} < minimum {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path}: {value} > maximum {schema['maximum']}")

    if isinstance(value, dict):
        for req in schema.get("required", []):
            if req not in value:
                errors.append(f"{path}: missing required key {req!r}")
        props = schema.get("properties", {})
        for k, v in value.items():
            if k in props:
                errors.extend(validate(v, props[k], f"{path}.{k}"))
            elif schema.get("additionalProperties") is False:
                errors.append(f"{path}: unexpected key {k!r}")

    if isinstance(value, list) and "items" in schema:
        for i, item in enumerate(value):
            errors.extend(validate(item, schema["items"], f"{path}[{i}]"))

    return errors


def main(argv: list[str]) -> int:
    repo = Path(__file__).resolve().parent.parent
    schema_path = repo / "schemas" / "phase-result.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))

    if argv:
        paths = [Path(p) for p in argv]
    else:
        paths = [
            p for p in (repo / "logs" / "runs").rglob("*.json")
            if p.name != "run.json"
        ]

    if not paths:
        print("no JSON sidecars found to validate", file=sys.stderr)
        return 0

    failed = 0
    for path in paths:
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            print(f"FAIL {path}: cannot parse: {exc}")
            failed += 1
            continue
        errs = validate(doc, schema)
        if errs:
            failed += 1
            print(f"FAIL {path}:")
            for e in errs:
                print(f"  - {e}")
        else:
            print(f"PASS {path}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
