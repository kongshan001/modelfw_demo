#!/usr/bin/env python3
"""Repair a truncated tcvdb-text BM25 JSON file (test workaround only).

The official npm package is ~286 MB unpacked. If `npm install` is interrupted,
`data/bm25_en_default.json` can be cut mid-string. This script keeps every
complete token_freq line, drops the incomplete last line, and closes the JSON.
It is NOT a substitute for a complete package install; it only unblocks a small
local test. Use the full package for production.
"""
import json
import os
import sys


def main():
    if len(sys.argv) != 2:
        print("usage: repair_bm25.py <bm25_en_default.json>", file=sys.stderr)
        return 2
    path = sys.argv[1]
    if not os.path.exists(path):
        print(f"missing file: {path}", file=sys.stderr)
        return 1
    raw = open(path, "rb").read()
    try:
        json.loads(raw)
        print(f"valid JSON, no repair needed: {path}")
        return 0
    except Exception as exc:
        print(f"invalid JSON ({exc}); attempting truncation repair")

    idx = raw.rfind(b"\n")
    if idx <= 0:
        print("cannot find a complete line; reinstall the package", file=sys.stderr)
        return 1
    head = raw[:idx].rstrip()
    if head.endswith(b","):
        head = head[:-1]
    fixed = head + b"\n  }\n}\n"
    try:
        data = json.loads(fixed)
    except Exception as exc:
        print(f"repair failed: {exc}", file=sys.stderr)
        return 1
    if "token_freq" not in data or "doc_count" not in data:
        print("unexpected BM25 schema; reinstall the package", file=sys.stderr)
        return 1
    tmp = path + ".repaired"
    with open(tmp, "wb") as fh:
        fh.write(fixed)
    os.replace(tmp, path)
    print(f"repaired {path}: {len(raw)} -> {len(fixed)} bytes, "
          f"{len(data['token_freq'])} token_freq entries (tail entries lost)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
