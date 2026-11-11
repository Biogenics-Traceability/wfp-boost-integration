#!/usr/bin/env python3
"""Validate every document in examples/ against the BOOST schemas at the pinned tag.

Usage:  python3 scripts/validate_examples.py <path-to-BOOST-checkout>
Each example is a JSON object keyed by entity (snake_case schema directory name);
each value is one object or a list of objects. Exit non-zero on any failure.
Mirrors what the validator service does, without the HTTP layer.
"""
import json
import sys
from pathlib import Path

import jsonschema

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = sorted((ROOT / "examples").glob("*.json"))


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    schema_dir = Path(sys.argv[1]) / "drafts" / "current" / "schema"
    failures = 0
    for path in EXAMPLES:
        doc = json.loads(path.read_text())
        for entity, value in doc.items():
            schema_file = schema_dir / entity / "validation_schema.json"
            schema = json.loads(schema_file.read_text())["schema"]
            validator = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
            items = value if isinstance(value, list) else [value]
            for i, item in enumerate(items):
                errors = sorted(validator.iter_errors(item), key=lambda e: list(e.absolute_path))
                if errors:
                    failures += 1
                    print(f"FAIL  {path.name} {entity}[{i}]")
                    for err in errors:
                        where = "/".join(str(p) for p in err.absolute_path) or "<root>"
                        print(f"      {where}: {err.message[:160]}")
                else:
                    print(f"ok    {path.name} {entity}[{i}]")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
