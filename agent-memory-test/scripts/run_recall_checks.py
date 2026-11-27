#!/usr/bin/env python3
"""Run cross-session recall checks against the TDAI gateway and save evidence.

No credentials are read or written here; the gateway host/port are local.
"""
import argparse
import glob
import json
import os
import subprocess
import time
import urllib.request
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.environ.get("TDAI_GATEWAY_URL", "http://127.0.0.1:18420")
DATA = os.environ.get("TDAI_DATA_DIR", os.path.join(ROOT, "data"))


def post(path, payload, timeout=60):
    body = json.dumps(payload).encode()
    req = urllib.request.Request(BASE + path, data=body, headers={"Content-Type": "application/json"})
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
    elapsed_ms = round((time.perf_counter() - start) * 1000, 1)
    return json.loads(raw), elapsed_ms


def token_counts(texts):
    if not texts:
        return []
    proc = subprocess.run(
        ["node", os.path.join(ROOT, "scripts", "token_count.mjs")],
        input=json.dumps(texts), text=True, capture_output=True, check=True,
    )
    return json.loads(proc.stdout)


def raw_transcript():
    parts = []
    for path in glob.glob(os.path.join(DATA, "conversations", "*.jsonl")):
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if rec.get("role") in ("user", "assistant") and rec.get("content"):
                    parts.append(rec["content"])
    return "\n".join(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--query-set", default="base", choices=["base", "update", "restart"])
    ap.add_argument("--label", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--with-search", action="store_true")
    args = ap.parse_args()

    with open(os.path.join(ROOT, "samples", "recall_queries.json"), encoding="utf-8") as fh:
        queries = json.load(fh)[args.query_set]

    results = []
    for q in queries:
        recall, recall_ms = post("/recall", {"query": q["query"], "session_key": f"session-{args.label}"})
        context = recall.get("context", "") or ""
        lower = context.lower()
        expected = [{"text": e, "present": e.lower() in lower} for e in q.get("expect", [])]
        also = [{"text": e, "present": e.lower() in lower} for e in q.get("also_check", [])]
        item = {
            "id": q["id"],
            "query": q["query"],
            "latency_ms": recall_ms,
            "memory_count": recall.get("memory_count", 0),
            "strategy": recall.get("strategy"),
            "context_chars": len(context),
            "expected": expected,
            "also_check": also,
            "context": context,
        }
        if args.with_search:
            search, search_ms = post("/search/memories", {"query": q["query"], "limit": 8})
            item["l1_search"] = {
                "latency_ms": search_ms,
                "total": search.get("total", 0),
                "strategy": search.get("strategy"),
                "results": search.get("results", ""),
            }
        results.append(item)
        hit = sum(1 for e in expected if e["present"])
        print(f"{q['id']}: recall={recall_ms}ms chars={len(context)} memories={item['memory_count']} "
              f"expected={hit}/{len(expected)}" + (f" search={item['l1_search']['total']}" if args.with_search else ""))

    transcript = raw_transcript()
    counts = token_counts([transcript] + [r["context"] for r in results])
    transcript_tokens = counts[0]
    for item, n in zip(results, counts[1:]):
        item["context_tokens"] = n
        item["context_vs_full_transcript"] = round(n / transcript_tokens, 3) if transcript_tokens else None

    total_expected = sum(len(r["expected"]) for r in results)
    total_hits = sum(1 for r in results for e in r["expected"] if e["present"])
    payload = {
        "label": args.label,
        "query_set": args.query_set,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "gateway": BASE,
        "data_dir": DATA,
        "raw_transcript_tokens_cl100k": transcript_tokens,
        "raw_transcript_chars": len(transcript),
        "recall_expected_hit_rate": round(total_hits / total_expected, 3) if total_expected else None,
        "results": results,
    }
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
    print(f"saved {args.out}; raw transcript={transcript_tokens} tokens; "
          f"expected hit rate={payload['recall_expected_hit_rate']}")


if __name__ == "__main__":
    main()
