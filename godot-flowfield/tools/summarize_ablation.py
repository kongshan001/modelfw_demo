#!/usr/bin/env python3
"""Summarize docs/perf/ablation_*.csv + runs_raw.json into Markdown tables.

Stdlib only. Usage: python3 tools/summarize_ablation.py
"""
from __future__ import annotations

import csv
import json
import os
import statistics
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PERF = os.path.join(ROOT, "docs", "perf")
CONFIG_ORDER = ["baseline", "aa_off", "hz10", "half", "aa_off_hz10", "aa_off_half", "hz10_half", "all"]
SHORT = {
    "baseline": "B (AA on/15Hz/full)",
    "aa_off": "-AA",
    "hz10": "10Hz",
    "half": "1/2 trail",
    "aa_off_hz10": "-AA+10Hz",
    "aa_off_half": "-AA+1/2",
    "hz10_half": "10Hz+1/2",
    "all": "ALL (default)",
}


def read_csv(path):
    if not os.path.exists(path):
        return []
    with open(path, newline="") as fh:
        return list(csv.DictReader(fh))


def med(vals):
    return statistics.median(vals) if vals else float("nan")


def pct(sorted_vals, p):
    if not sorted_vals:
        return float("nan")
    idx = max(0, min(len(sorted_vals) - 1, int(-(-p * len(sorted_vals) // 1)) - 1))
    return sorted_vals[idx]


def fmt(v, nd=1):
    return "—" if v != v else f"{v:.{nd}f}"


def rows_for(rows, kind, agents):
    return [r for r in rows if r["kind"] == kind and int(r["agents"]) == agents]


def summary(rows, kind="ablation", agents=1000):
    out = {}
    for cid in CONFIG_ORDER:
        rs = [r for r in rows_for(rows, kind, agents) if r["config_id"] == cid]
        if not rs:
            continue
        out[cid] = {
            "n": len(rs),
            "fps": [float(r["avg_fps"]) for r in rs],
            "p95": [float(r["p95_ms"]) for r in rs],
            "p99": [float(r["p99_ms"]) for r in rs],
            "worst": [float(r["worst_ms"]) for r in rs],
            "hitch33": [int(r["hitch_33ms"]) for r in rs],
            "hitch50": [int(r["hitch_50ms"]) for r in rs],
            "logic": [float(r["logic_step_mean_ms"]) for r in rs],
            "budget": [float(r["logic_budget_pct"]) for r in rs],
            "build": [float(r["build_ms"]) for r in rs],
            "draw": [int(r["draw_calls_median"]) for r in rs],
            "prims": [int(r["primitives_median"]) for r in rs],
            "objects": [int(r["objects_median"]) for r in rs],
            "load": [float(r["load1_start"]) for r in rs],
        }
    return out


def table(sm, title):
    print(f"\n### {title}\n")
    print("| config | runs | avg FPS med [min–max] | P95 ms med [min–max] | hitch >33.3 /300 | hitch >50 /300 | logic step ms | budget % | build ms |")
    print("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
    for cid in CONFIG_ORDER:
        if cid not in sm:
            continue
        s = sm[cid]
        print("| %s | %d | %s [%s–%s] | %s [%s–%s] | %s [%d–%d] | %s [%d–%d] | %s | %s | %s |" % (
            SHORT[cid], s["n"], fmt(med(s["fps"])), fmt(min(s["fps"])), fmt(max(s["fps"])),
            fmt(med(s["p95"])), fmt(min(s["p95"])), fmt(max(s["p95"])),
            fmt(med(s["hitch33"]), 0), min(s["hitch33"]), max(s["hitch33"]),
            fmt(med(s["hitch50"]), 0), min(s["hitch50"]), max(s["hitch50"]),
            fmt(med(s["logic"]), 2), fmt(med(s["budget"]), 0), fmt(med(s["build"]), 2)))


def main_effects(sm, title):
    print(f"\n### {title}\n")
    print("| factor | level | avg FPS med | Δ FPS vs baseline | P95 ms med | Δ P95 ms | hitch >33.3 med |")
    print("| --- | --- | ---: | ---: | ---: | ---: | ---: |")
    base_fps = med(sm.get("baseline", {}).get("fps", []))
    base_p95 = med(sm.get("baseline", {}).get("p95", []))
    factors = {
        "AA": [("on (cost)", ["baseline", "hz10", "half", "hz10_half"]),
               ("off (opt)", ["aa_off", "aa_off_hz10", "aa_off_half", "all"])],
        "10Hz large-group refresh": [("off (15Hz)", ["baseline", "aa_off", "half", "aa_off_half"]),
                                     ("on (10Hz)", ["hz10", "aa_off_hz10", "hz10_half", "all"])],
        "trail half sampling": [("off (all trails)", ["baseline", "aa_off", "hz10", "aa_off_hz10"]),
                                ("on (half)", ["half", "aa_off_half", "hz10_half", "all"])],
    }
    for factor, levels in factors.items():
        for label, cids in levels:
            fps = [v for cid in cids for v in sm.get(cid, {}).get("fps", [])]
            p95 = [v for cid in cids for v in sm.get(cid, {}).get("p95", [])]
            h33 = [v for cid in cids for v in sm.get(cid, {}).get("hitch33", [])]
            if not fps:
                continue
            print("| %s | %s | %s | %+.1f | %s | %+.1f | %s |" % (
                factor, label, fmt(med(fps)), med(fps) - base_fps,
                fmt(med(p95)), med(p95) - base_p95, fmt(med(h33), 0)))
    print("\n> 主效应 = 该因子两个水平各自汇总 4 种组合 × 5 轮（20 次运行）后的中位数；Δ 仅作方向参考，"
          "精确的单因子增益见下方 paired 表。")


def paired_gains(sm):
    print("\n### 单因子 / 组合增益（中位 FPS、P95）\n")
    print("| comparison | avg FPS med | Δ FPS | Δ % | P95 ms med | Δ P95 |")
    print("| --- | ---: | ---: | ---: | ---: | ---: |")
    base = sm.get("baseline", {})
    bf = med(base.get("fps", []))
    bp = med(base.get("p95", []))
    pairs = [("baseline", "all", "全开 vs 初版"),
             ("baseline", "aa_off", "仅关 AA"),
             ("baseline", "hz10", "仅 10Hz"),
             ("baseline", "half", "仅半采样"),
             ("aa_off", "aa_off_hz10", "关 AA 后再开 10Hz"),
             ("aa_off", "aa_off_half", "关 AA 后再开半采样"),
             ("hz10", "hz10_half", "10Hz 后再开半采样"),
             ("all", "baseline", "默认相对初版")]
    for a, b, label in pairs:
        if a not in sm or b not in sm:
            continue
        af = med(sm[a]["fps"])
        bf2 = med(sm[b]["fps"])
        ap = med(sm[a]["p95"])
        bp2 = med(sm[b]["p95"])
        delta = bf2 - af
        pct = delta / af * 100 if af else float("nan")
        print("| %s | %s → %s | %+.1f | %+.0f%% | %s → %s | %+.1f |" % (
            label, fmt(af), fmt(bf2), delta, pct, fmt(ap), fmt(bp2), bp2 - ap))


def normalized_gains(rows, title):
    """同轮对照：每轮内 config 与 baseline 的比值，抵消跨轮机器负载漂移。"""
    rr = rows_for(rows, "ablation", 1000)
    by_round = defaultdict(dict)
    for r in rr:
        by_round[int(r["round"])][r["config_id"]] = r
    print(f"\n### {title}（同轮相对 baseline 的倍数；中位 [最小–最大]）\n")
    print("| config | FPS / baseline | P95 / baseline（越低越好） | 轮数 |")
    print("| --- | ---: | ---: | ---: |")
    for cid in CONFIG_ORDER:
        ratios_fps = []
        ratios_p95 = []
        for rnd, cfg in by_round.items():
            if cid not in cfg or "baseline" not in cfg:
                continue
            b = cfg["baseline"]
            c = cfg[cid]
            bf = float(b["avg_fps"])
            bp = float(b["p95_ms"])
            if bf > 0:
                ratios_fps.append(float(c["avg_fps"]) / bf)
            if bp > 0:
                ratios_p95.append(float(c["p95_ms"]) / bp)
        if not ratios_fps:
            continue
        print("| %s | %s [%s–%s] | %s [%s–%s] | %d |" % (
            SHORT[cid], fmt(med(ratios_fps), 2), fmt(min(ratios_fps), 2), fmt(max(ratios_fps), 2),
            fmt(med(ratios_p95), 2), fmt(min(ratios_p95), 2), fmt(max(ratios_p95), 2),
            len(ratios_fps)))


def json_runs(js):
    out = defaultdict(list)
    for tag, block in js.get("resolutions", {}).items():
        for run in block.get("runs", []):
            if run.get("kind") == "ablation" and run.get("agents") == 1000:
                out[(tag, run["config_id"])].append(run)
    return out


def pooled_frames(jr):
    print("\n### 合并帧时间分布（5 轮 × 300 帧 = 1500 帧/配置）\n")
    print("| res | config | P50 | P95 | P99 | worst | hitch >33.3 | hitch >50 |")
    print("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
    for tag in ["1280x720", "1920x1080"]:
        for cid in CONFIG_ORDER:
            runs = jr.get((tag, cid), [])
            if not runs:
                continue
            frames = []
            for r in runs:
                frames.extend(r.get("frame_ms", []))
            frames.sort()
            h33 = sum(1 for v in frames if v > 33.3)
            h50 = sum(1 for v in frames if v > 50.0)
            print("| %s | %s | %s | %s | %s | %s | %d/%d (%.0f%%) | %d/%d (%.0f%%) |" % (
                tag, SHORT[cid], fmt(pct(frames, .50)), fmt(pct(frames, .95)),
                fmt(pct(frames, .99)), fmt(frames[-1] if frames else float("nan")),
                h33, len(frames), 100 * h33 / len(frames) if frames else 0,
                h50, len(frames), 100 * h50 / len(frames) if frames else 0))


def engine_table(rows_720, rows_1080):
    print("\n### 引擎渲染计数（1000 智能体，各配置 5 轮中位）\n")
    print("| res | config | draw calls | objects | primitives | video MB | texture MB | buffer MB |")
    print("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
    for tag, rows in [("1280x720", rows_720), ("1920x1080", rows_1080)]:
        rr = rows_for(rows, "ablation", 1000)
        for cid in CONFIG_ORDER:
            sub = [r for r in rr if r["config_id"] == cid]
            if not sub:
                continue
            print("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
                tag, SHORT[cid],
                fmt(med([int(r["draw_calls_median"]) for r in sub]), 0),
                fmt(med([int(r["objects_median"]) for r in sub]), 0),
                fmt(med([int(r["primitives_median"]) for r in sub]), 0),
                fmt(med([float(r["video_mem_mb"]) for r in sub])),
                fmt(med([float(r["texture_mem_mb"]) for r in sub])),
                fmt(med([float(r["buffer_mem_mb"]) for r in sub]))))


def layer_table(rows):
    rs = [r for r in rows if r["kind"] == "layer"]
    if not rs:
        return
    print("\n### 图层归因（1280×720，1000 智能体，3 轮，全优化配置）\n")
    print("| variant | runs | avg FPS med [min–max] | P95 ms med | primitives med | objects med | draw calls med |")
    print("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")
    full = [r for r in rs if r["config_id"] == "layer_full"]
    full_fps = med([float(r["avg_fps"]) for r in full]) if full else float("nan")
    for lid in ["layer_full", "layer_no_trails", "layer_no_agents", "layer_no_arrows"]:
        sub = [r for r in rs if r["config_id"] == lid]
        if not sub:
            continue
        fps = [float(r["avg_fps"]) for r in sub]
        print("| %s | %d | %s [%s–%s] | %s | %s | %s | %s |" % (
            lid, len(sub), fmt(med(fps)), fmt(min(fps)), fmt(max(fps)),
            fmt(med([float(r["p95_ms"]) for r in sub])),
            fmt(med([int(r["primitives_median"]) for r in sub]), 0),
            fmt(med([int(r["objects_median"]) for r in sub]), 0),
            fmt(med([int(r["draw_calls_median"]) for r in sub]), 0)))
    if full:
        print("\n> 相对 all-layers 的 FPS 差（正值 = 去掉该层后更快）：")
        for lid in ["layer_no_trails", "layer_no_agents", "layer_no_arrows"]:
            sub = [r for r in rs if r["config_id"] == lid]
            if sub:
                delta = med([float(r["avg_fps"]) for r in sub]) - full_fps
                print(f"> - {lid}: {delta:+.1f} FPS")


def round_drift(rows):
    print("\n### 轮次漂移（每轮所有配置的中位 FPS，作为机器负载代理）\n")
    print("| res | round | configs | median FPS | median load1 |")
    print("| --- | ---: | ---: | ---: | ---: |")
    for tag, path in [("1280x720", os.path.join(PERF, "ablation_1280x720.csv")),
                      ("1920x1080", os.path.join(PERF, "ablation_1920x1080.csv"))]:
        rr = rows_for(read_csv(path), "ablation", 1000)
        for rnd in sorted({int(r["round"]) for r in rr}):
            sub = [r for r in rr if int(r["round"]) == rnd]
            print("| %s | %d | %d | %s | %s |" % (
                tag, rnd, len(sub), fmt(med([float(r["avg_fps"]) for r in sub])),
                fmt(med([float(r["load1_start"]) for r in sub]), 2)))


def control_500(rows):
    sm = summary(rows, "ablation_500", 500)
    if not sm:
        return
    print("\n### 500 智能体对照（1280×720，10Hz 阈值 >700 不生效）\n")
    print("| config | runs | avg FPS med [min–max] | P95 ms med | hitch >33.3 med |")
    print("| --- | ---: | ---: | ---: | ---: |")
    for cid in ["baseline", "aa_off", "half", "aa_off_half"]:
        if cid not in sm:
            continue
        s = sm[cid]
        print("| %s | %d | %s [%s–%s] | %s | %s |" % (
            SHORT[cid], s["n"], fmt(med(s["fps"])), fmt(min(s["fps"])), fmt(max(s["fps"])),
            fmt(med(s["p95"])), fmt(med(s["hitch33"]), 0)))


def main():
    rows_720 = read_csv(os.path.join(PERF, "ablation_1280x720.csv"))
    rows_1080 = read_csv(os.path.join(PERF, "ablation_1920x1080.csv"))
    js_path = os.path.join(PERF, "runs_raw.json")
    js = json.load(open(js_path)) if os.path.exists(js_path) else {}
    meta = js.get("meta", {})
    print("## Flow Field ablation summary\n")
    print("```")
    for k in ["generated", "godot", "os", "cpu", "gpu", "gl_api", "renderer", "window_size", "screen_size", "seed", "map"]:
        if k in meta:
            print(f"{k}: {meta[k]}")
    print("```")
    all_loads = [float(r["load1_start"]) for r in rows_720 + rows_1080]
    if all_loads:
        print(f"\nload1 range across runs: {min(all_loads):.2f} – {max(all_loads):.2f} "
              f"(median {statistics.median(all_loads):.2f})\n")
    sm720 = summary(rows_720, "ablation", 1000)
    sm1080 = summary(rows_1080, "ablation", 1000)
    table(sm720, "1280×720 · 1000 智能体（每轮 60 预热 + 300 采样，5 轮）")
    table(sm1080, "1920×1080 · 1000 智能体（离屏 SubViewport，5 轮）")
    paired_gains(sm720)
    paired_gains(sm1080)
    normalized_gains(rows_720, "同轮归一 · 1280×720")
    normalized_gains(rows_1080, "同轮归一 · 1920×1080")
    main_effects(sm720, "主效应 · 1280×720")
    main_effects(sm1080, "主效应 · 1920×1080")
    pooled_frames(json_runs(js))
    engine_table(rows_720, rows_1080)
    layer_table(rows_720)
    control_500(rows_720)
    round_drift(rows_720)


if __name__ == "__main__":
    main()
