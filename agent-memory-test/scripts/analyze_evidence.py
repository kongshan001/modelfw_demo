#!/usr/bin/env python3
"""Summarise the recall evidence into evidence/metrics.json.

Token counts use cl100k_base via the js-tiktoken copy in .work/official.
"""
import glob
import json
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVID = os.path.join(ROOT, "evidence")


def tokens(texts):
    proc = subprocess.run(
        ["node", os.path.join(ROOT, "scripts", "token_count.mjs")],
        input=json.dumps(texts), text=True, capture_output=True, check=True,
    )
    return json.loads(proc.stdout)


def first_memory(text):
    """Return the content of the first '- **[type]** ...' block, if present."""
    m = re.search(r"- \*\*\[[^\]]+\]\*\*[^\n]*\n\s*(.+?)(?:\n\n|\Z)", text or "", re.S)
    return m.group(1).strip() if m else ""


BASE_TOP1 = {
    "identity": ["maya"],
    "atlas_launch": ["atlas", "2026-12-15"],
    "format_pref": ["concise", "typescript"],
    "payment_owner": ["leo"],
    "food_allergy": ["peanut"],
    "api_freeze": ["2026-12-01"],
    "cross_lingual_cn": ["atlas", "2026-12-15"],
    "broad_profile": ["maya"],
}
UPDATE_TOP1 = {
    "launch_after_update": ["2027-01-10"],
    "language_after_update": ["go"],
    "payment_after_update": ["priya"],
}


def top1_hit(item, mapping):
    keys = mapping.get(item.get("id"), [])
    content = first_memory(item.get("l1_search", {}).get("results", ""))
    low = content.lower()
    return bool(keys) and any(k.lower() in low for k in keys), content


def main():
    out = {"token_unit": "cl100k_base", "evidence_files": {}}

    base_core = json.load(open(os.path.join(EVID, "core_recall_base.json")))
    upd_core = json.load(open(os.path.join(EVID, "core_recall_update.json")))
    base_http = json.load(open(os.path.join(EVID, "session_b_recall.json")))
    upd_http = json.load(open(os.path.join(EVID, "session_e_update_recall.json")))

    for name, core, http, raw_tokens in [
        ("base", base_core, base_http, base_http["raw_transcript_tokens_cl100k"]),
        ("update", upd_core, upd_http, upd_http["raw_transcript_tokens_cl100k"]),
    ]:
        rows = []
        for r in core["results"]:
            t = tokens([r["prepend_context"], r["append_system_context"]])
            rows.append({
                "id": r["id"],
                "l1_count": r["l1_count"],
                "prepend_chars": len(r["prepend_context"]),
                "append_chars": len(r["append_system_context"]),
                "prepend_tokens": t[0],
                "append_tokens": t[1],
                "total_tokens": t[0] + t[1],
                "latency_ms": r["latency_ms"],
            })
        # HTTP /search/memories top-1
        http_map = {r["id"]: r for r in http["results"]}
        for row in rows:
            item = http_map.get(row["id"])
            hit, content = top1_hit(item, BASE_TOP1 if name == "base" else UPDATE_TOP1)
            row["l1_search_top1_hit"] = hit
            row["l1_search_top1_content"] = content[:200]
        avg_total = round(sum(x["total_tokens"] for x in rows) / len(rows), 1)
        out["evidence_files"][name] = {
            "raw_transcript_tokens": raw_tokens,
            "avg_recall_context_tokens": avg_total,
            "recall_to_transcript_ratio": round(avg_total / raw_tokens, 2) if raw_tokens else None,
            "avg_prepend_tokens": round(sum(x["prepend_tokens"] for x in rows) / len(rows), 1),
            "avg_append_tokens": round(sum(x["append_tokens"] for x in rows) / len(rows), 1),
            "l1_search_top1_accuracy": round(sum(1 for x in rows if x["l1_search_top1_hit"]) / len(rows), 3),
            "rows": rows,
        }

    # Gateway HTTP recall context = append only (persona + scene nav + tools guide).
    for label, http in [("base", base_http), ("update", upd_http)]:
        ctx = [r["context"] for r in http["results"]]
        t = tokens(ctx)
        out["evidence_files"][label]["gateway_recall_context_tokens"] = t[0]
        out["evidence_files"][label]["gateway_recall_latency_ms_median"] = sorted(
            r["latency_ms"] for r in http["results"]
        )[len(http["results"]) // 2]

    # Pipeline timings from the live log, or the curated timing-probe excerpt.
    timings = {"l1": [], "l2": [], "l3": []}
    for log_path in [os.path.join(ROOT, "logs", "gateway.log"),
                     os.path.join(EVID, "pipeline_timing.log")]:
        if not os.path.exists(log_path):
            continue
        current_task = None
        for line in open(log_path, encoding="utf-8", errors="replace"):
            m = re.search(r"run\(\) start: taskId=([^\s,]+)", line)
            if m:
                current_task = m.group(1)
                continue
            m = re.search(r"run\(\) completed: (\d+)ms", line)
            if m and current_task:
                ms = int(m.group(1))
                if current_task == "l1-extraction":
                    timings["l1"].append(ms)
                elif current_task.startswith("scene-extract"):
                    timings["l2"].append(ms)
                elif current_task == "persona-generation":
                    timings["l3"].append(ms)
                current_task = None
        if all(timings.values()):
            break
    out["pipeline_llm_ms"] = {
        k: {"count": len(v), "min": min(v) if v else None,
            "median": sorted(v)[len(v) // 2] if v else None,
            "max": max(v) if v else None}
        for k, v in timings.items()
    }

    # Store inventory.
    import sqlite3
    data = os.path.join(ROOT, "data")
    out["store_inventory"] = {
        "l0_messages": sum(1 for f in glob.glob(os.path.join(data, "conversations", "*.jsonl"))
                           for _ in open(f, encoding="utf-8")),
        "l1_records": sum(1 for f in glob.glob(os.path.join(data, "records", "*.jsonl"))
                          for _ in open(f, encoding="utf-8")),
        "scene_blocks": len(glob.glob(os.path.join(data, "scene_blocks", "*.md"))),
        "persona_chars": len(open(os.path.join(data, "persona.md"), encoding="utf-8").read())
        if os.path.exists(os.path.join(data, "persona.md")) else 0,
        "vectors_db_bytes": os.path.getsize(os.path.join(data, "vectors.db"))
        if os.path.exists(os.path.join(data, "vectors.db")) else 0,
    }

    with open(os.path.join(EVID, "metrics.json"), "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=2)
    print(json.dumps(out, ensure_ascii=False, indent=2)[:4000])


if __name__ == "__main__":
    main()
