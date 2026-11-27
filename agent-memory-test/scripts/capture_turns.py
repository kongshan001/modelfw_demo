#!/usr/bin/env python3
"""Send a scripted multi-turn conversation to the TDAI gateway.

Reads a JSON array of {"user": ..., "assistant": ...} and POSTs each turn to
/capture, then calls /session/end and optionally waits for L1 records.
"""
import argparse
import glob
import json
import os
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.environ.get("TDAI_DATA_DIR", os.path.join(ROOT, "data"))


def post(base, path, payload, timeout=60):
    body = json.dumps(payload).encode()
    req = urllib.request.Request(base + path, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


def count_records():
    n = 0
    for path in glob.glob(os.path.join(DATA, "records", "*.jsonl")):
        with open(path, encoding="utf-8") as fh:
            n += sum(1 for line in fh if line.strip())
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--session-key", required=True)
    ap.add_argument("--turns-file", required=True)
    ap.add_argument("--base", default=os.environ.get("TDAI_GATEWAY_URL", "http://127.0.0.1:18420"))
    ap.add_argument("--gap", type=float, default=2.0)
    ap.add_argument("--wait-records", type=int, default=0)
    ap.add_argument("--timeout", type=float, default=240.0)
    args = ap.parse_args()

    with open(args.turns_file, encoding="utf-8") as fh:
        turns = json.load(fh)

    for i, turn in enumerate(turns, 1):
        resp = post(args.base, "/capture", {
            "user_content": turn["user"],
            "assistant_content": turn["assistant"],
            "session_key": args.session_key,
        })
        print(f"turn {i}/{len(turns)}: {resp}")
        time.sleep(args.gap)

    print("session/end:", post(args.base, "/session/end", {"session_key": args.session_key}))

    if args.wait_records:
        deadline = time.time() + args.timeout
        last = -1
        while time.time() < deadline:
            n = count_records()
            if n != last:
                print(f"L1 records: {n}/{args.wait_records}")
                last = n
            if n >= args.wait_records:
                print("target reached")
                return 0
            time.sleep(3)
        print(f"WARNING: only {count_records()} L1 records after {args.timeout}s. "
              "The upstream scheduler batches turns; send one neutral capture or wait "
              "for the idle timer, then re-check. See README 'known quirks'.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
