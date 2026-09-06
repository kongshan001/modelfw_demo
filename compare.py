"""三实现性能对比 —— phase 3 + harness 门禁.

同一负载、同一 harness(纯 Python 与 pybind11 共享 `for v in values: m.{field} = v`;
C++ 原生跑独立二进制,结果合并),产出对比表与加速比。

三实现:
  - py        : 纯 Python CModel(cmodel.py)
  - pb        : pybind11 换层(cmodelpb.CModel, 字段装 py::object, 回调为 Python 函数)
  - native    : 纯原生 C++(cpp/build/bench_native, C++ 回调, 无 Python)

harness 用法:
  python3 compare.py                                  # 打印对比表
  python3 compare.py --check                          # 断言 bench_thresholds.json 比值, 失败 exit 1
  python3 compare.py --check --json PATH              # 断言 + 写快照(入 git 作趋势)
  python3 compare.py --check --mutate                 # 变异自检: 注入跌破地板 cell → 门禁必须 FAIL, 恢复 → PASS

统计与边距: 每 cell 按 REPEAT(bench_config.py 档位)次取样, 头列值=min(口径不变),
均值/σ/95%CI(样本 t 分布)与地板/边距随快照 rows 落盘; 门禁第二断言 = 任一有效
cell ≥ 0.5×该规则阈值(CELL_GUARD), 挡住"中位数聚合掩盖单类型回退"。
"""

import argparse
import gc
import json
import math
import os
import platform
import subprocess
import sys
import time
import timeit

from cmodel import PyCModel          # 显式纯 Python(不受无感自动替换影响)
from cmodel_fast import CModel as CFastCModel

from bench_config import K, N_W1, N_W2, REPEAT, GEN   # 单一负载源(与 benchmark.py 共享)

# 门禁第二断言: 每规则 任一有效 cell(单字段比值) 不得跌破 该规则阈值×0.5。
# 例子: 中位数门禁曾放过"快照 5/48 cell 低于阈值"的全绿——cell 地板挡住这类单类型回退。
CELL_GUARD = 0.5
# 95% 双侧 t 值(df=1..29; ≥30 用 1.96 近似)。CI 半宽 = t·σ/√REPEAT。
_T95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365,
        8: 2.306, 9: 2.262, 10: 2.228, 11: 2.201, 12: 2.179, 13: 2.160, 14: 2.145,
        15: 2.131, 16: 2.120, 17: 2.110, 18: 2.101, 19: 2.093, 20: 2.086, 21: 2.080,
        22: 2.074, 23: 2.069, 24: 2.064, 25: 2.060, 26: 2.056, 27: 2.052, 28: 2.048,
        29: 2.045}


def _cell_stats(samples):
    """REPEAT 次样本(raw w/s)的 (mean, σ, 95%CI 半宽); n<2 时 σ/CI 为 None。"""
    n = len(samples)
    mean = sum(samples) / n
    if n < 2:
        return mean, None, None
    sd = math.sqrt(sum((x - mean) ** 2 for x in samples) / (n - 1))
    ci = _T95.get(n, 1.96) * sd / math.sqrt(n)
    return mean, sd, ci


class PyBench(PyCModel):
    def __init__(self):
        super().__init__()
        self.f_int = 0
        self.f_str = ""
        self.f_tuple = ()
        self.f_list = []
        self.f_dict = {}
        self.f_set = set()


class CppBench(CFastCModel):
    def __init__(self):
        super().__init__()
        self.f_int = 0
        self.f_str = ""
        self.f_tuple = ()
        self.f_list = []
        self.f_dict = {}
        self.f_set = set()


def bench(factory, field, n, with_cb):
    """返回 (raw writes/sec, 纯模型 ns/write, (mean, σ, 95%CI 半宽))。

    ns/mod 用空循环 baseline 扣除(benchmark.py 同口径); 比值与阈值一律用
    raw writes/sec(n/t_full, 取 min)——BENCHMARK.md 全部参考倍数是 raw 比值, 换口径整体失效。
    均值/σ/CI 由 REPEAT 个 raw w/s 样本算得, 只做统计展示与快照落盘, 不进门禁。
    """
    m = factory()
    setattr(m, field, GEN[field](-1))                 # 初始值(与计时区间 0..n-1 不同)
    if with_cb:
        for k in range(K):
            m.SetModifyCB(f"cb{k}", field, lambda mdl: None)
    values = [GEN[field](i) for i in range(n)]
    g = {"values": values, "m": m, "x": None}
    full_stmt = f"for v in values: m.{field} = v"
    base_stmt = "for v in values: x = v"
    timeit.timeit(base_stmt, number=1, globals=g)     # warmup
    timeit.timeit(full_stmt, number=1, globals=g)
    t_base = min(timeit.repeat(base_stmt, number=1, globals=g, repeat=REPEAT))
    t_full_list = timeit.repeat(full_stmt, number=1, globals=g, repeat=REPEAT)
    t_full = min(t_full_list)
    t_model = max(t_full - t_base, 0.0)
    samples = [n / t for t in t_full_list]
    del values, m
    return n / t_full, t_model / n * 1e9, _cell_stats(samples)


def bench_batch(factory, field, n, with_cb):
    """返回 (raw writes/sec, (mean, σ, 95%CI))。用 set_many: N 次写入只 1 次 Python->C++ 跨界。"""
    m = factory()
    setattr(m, field, GEN[field](-1))
    if with_cb:
        for k in range(K):
            m.SetModifyCB(f"cb{k}", field, lambda mdl: None)
    values = [GEN[field](i) for i in range(n)]
    g = {"values": values, "m": m, "field": field}
    stmt = "m.set_many(field, values)"
    timeit.timeit(stmt, number=1, globals=g)          # warmup
    ts = timeit.repeat(stmt, number=1, globals=g, repeat=REPEAT)
    del values, m
    samples = [n / t for t in ts]
    return n / min(ts), _cell_stats(samples)


def bench_batch_txn(factory, field, n, with_cb):
    """返回 (raw writes/sec, (mean, σ, 95%CI))。set_many 包在 transaction 里: 批末每字段只 fire 一次。"""
    m = factory()
    setattr(m, field, GEN[field](-1))
    if with_cb:
        for k in range(K):
            m.SetModifyCB(f"cb{k}", field, lambda mdl: None)
    values = [GEN[field](i) for i in range(n)]
    g = {"values": values, "m": m, "field": field}
    stmt = "with m.transaction():\n    m.set_many(field, values)"
    timeit.timeit(stmt, number=1, globals=g)          # warmup
    ts = timeit.repeat(stmt, number=1, globals=g, repeat=REPEAT)
    del values, m
    samples = [n / t for t in ts]
    return n / min(ts), _cell_stats(samples)


def run_native():
    """跑 cpp/build/bench_native, 解析 'field WL writes/sec ns/op' 行。

    二进制缺失(未 make build)时提示并 exit 2——不裸抛 CalledProcessError。
    """
    exe = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cpp", "build", "bench_native")
    try:
        out = subprocess.check_output([exe]).decode()
    except FileNotFoundError:
        print("bench_native 未构建: 请先 `make build`", file=sys.stderr)
        sys.exit(2)
    res = {}
    for line in out.splitlines():
        p = line.split()
        if len(p) == 4 and p[0].startswith("f_") and p[1] in ("W1", "W2"):
            res[(p[0], p[1])] = float(p[2])
    return res


def fmt(x):
    if x >= 1e6:
        return f"{x/1e6:.2f}M"
    if x >= 1e3:
        return f"{x/1e3:.1f}K"
    return f"{x:.0f}"


def _median(xs):
    xs = sorted(xs)
    n = len(xs)
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2


def _check(rows):
    """同机同轮比值门禁, 失败 exit 1。双断言:

    ① median(6 字段 col/py) ≥ bench_thresholds.json 该规则阈值;
    ② 任一有效 cell ≥ CELL_GUARD×该规则阈值 —— 单类型回退保护
       (快照 5/48 cell 低于阈值仍全绿 = 中位数掩盖的教训)。
    native 列为 NaN 时显式跳过对应规则。
    """
    with open("bench_thresholds.json", encoding="utf-8") as f:
        thr = json.load(f)
    rules = [("per_op", "cpp_per_op"), ("batch", "cpp_batch"),
             ("batch_txn", "cpp_batch_txn"), ("native", "native")]
    ok = total = 0
    for key, col in rules:
        for wl in ("W1", "W2"):
            cells = [(r["field"], r[col] / r["py"])
                     for r in rows if r["wl"] == wl and not math.isnan(r[col])]
            if not cells:
                if key == "native":
                    print(f"[skip] native 规则跳过(未构建): {wl}")
                    continue
                total += 1
                print(f"[FAIL] {key} {wl}: 无有效比值")
                continue
            total += 1
            ratio = _median(v for _, v in cells)
            guard = CELL_GUARD * thr[key][wl]
            worst_f, worst_v = min(cells, key=lambda kv: kv[1])
            fails = []
            if ratio < thr[key][wl]:
                fails.append(f"median {ratio:.2f}× < {thr[key][wl]}×")
            if worst_v < guard:
                fails.append(f"cell {worst_f} {worst_v:.2f}× < 地板 {guard:.2f}×(0.5×{thr[key][wl]}×)")
            if fails:
                print(f"[FAIL] {key} {wl}: {'; '.join(fails)}")
            else:
                ok += 1
                print(f"[ ok ] {key} {wl}: median {ratio:.2f}× ≥ {thr[key][wl]}× | "
                      f"min cell {worst_v:.2f}× ({worst_f}) ≥ 地板 {guard:.2f}×")
    print(f"规则通过 {ok}/{total}")
    if ok != total:
        sys.exit(1)


def _annotate_floors(rows):
    """给 rows 每 cell 标注地板与边距(读 bench_thresholds.json 的 floors 字段)。

    floor_<col> = 该 cell 地板; margin_<col> = 当前比值(col/py) - 地板。
    地板只做趋势暴露/复核用, 不参与断言(断言地板 = CELL_GUARD×规则阈值)。
    """
    with open("bench_thresholds.json", encoding="utf-8") as f:
        thr = json.load(f)
    fl = thr.get("floors", {})
    for r in rows:
        for col in ("cpp_per_op", "cpp_batch", "cpp_batch_txn", "native"):
            floor = fl.get(col, {}).get(r["field"], {}).get(r["wl"])
            r[f"floor_{col}"] = floor
            if math.isnan(r[col]) or floor is None:
                r[f"margin_{col}"] = None
            else:
                r[f"margin_{col}"] = r[col] / r["py"] - floor


def _inject_mutation(rows, thr):
    """变异自检用: 返回 (rows 副本, 注入描述)。

    把首个有效 (规则, WL, 字段) cell 的比值压到 0.25×该规则阈值 —— 远低于
    CELL_GUARD 地板(0.5×阈值)与绝大多数历史地板, 保证断言②必抓; 单 cell
    不影响断言①中位数, 恰演示"median 掩盖不住 cell 地板"。
    """
    rules = [("per_op", "cpp_per_op"), ("batch", "cpp_batch"),
             ("batch_txn", "cpp_batch_txn"), ("native", "native")]
    for key, col in rules:
        for wl in ("W1", "W2"):
            idx = next((i for i, r in enumerate(rows)
                        if r["wl"] == wl and not math.isnan(r[col])), None)
            if idx is None:
                continue
            guard = CELL_GUARD * thr[key][wl]
            target = 0.25 * thr[key][wl]              # = 0.5×guard, 确定性跌破地板
            mut = list(rows)
            mut[idx] = dict(rows[idx])
            mut[idx][col] = mut[idx]["py"] * target
            return mut, (f"{key} {wl} {rows[idx]['field']}", col, target, guard)
    raise RuntimeError("无任何有效 cell 可注入(全 NaN?)")


def _write_json(rows, path):
    """写快照(含 commit/平台指纹), 覆盖写, git 历史即趋势(CI 不写, 避免混线)。"""
    if os.path.isdir(".git"):
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    else:
        commit = "unknown"
    payload = {
        "commit": commit,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "platform": platform.platform(),
        "python_version": platform.python_version(),
        "rows": [{k: (None if isinstance(v, float) and math.isnan(v) else v)
                  for k, v in r.items()} for r in rows],
    }
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"快照已写: {path}")


def _fmt_pct(x, base):
    return "-" if x is None or base in (None, 0) else f"{x / base * 100:.1f}%"


def main():
    ap = argparse.ArgumentParser(description="py / cpp(per-op) / cpp(batch) / cpp(batch+txn) / native 对比")
    ap.add_argument("--check", action="store_true", help="断言 bench_thresholds.json 比值, 失败 exit 1")
    ap.add_argument("--json", nargs="?", const="bench_results/latest.json", metavar="PATH",
                    help="写快照 json(默认 bench_results/latest.json)")
    ap.add_argument("--mutate", action="store_true",
                    help="变异自检: 注入一个跌破地板的 cell → 门禁必须 FAIL, 恢复(原 rows)→ 必须 PASS; "
                         "任一环节不符 exit 2")
    args = ap.parse_args()

    gc.disable()
    native = run_native()
    print(f"[{platform.python_version()} | {platform.processor() or platform.machine()}]  "
          f"W1: N={N_W1:,} (0 cb)  W2: N={N_W2:,} (K={K} cb)  repeat={REPEAT} (min, gc off)\n")
    print(f"{'field':<9} {'WL':<3} {'Python':>8} {'ns/mod':>7} {'cpp(op)':>13} {'cpp(batch)':>13} "
          f"{'cpp(batch+txn)':>16} {'C++native':>12}")
    print("-" * 88)
    rows = []
    for field in GEN:
        for wl, n, cb in (("W1", N_W1, False), ("W2", N_W2, True)):
            py, py_ns, py_st = bench(lambda: PyBench(), field, n, cb)
            cop, _, cop_st = bench(lambda: CppBench(), field, n, cb)   # cpp ns/mod 与 py 同口径, 不展示
            cbat, cbat_st = bench_batch(lambda: CppBench(), field, n, cb)
            ctxn, ctxn_st = bench_batch_txn(lambda: CppBench(), field, n, cb)
            nat = native.get((field, wl), float("nan"))
            row = {"field": field, "wl": wl, "py": py, "cpp_per_op": cop,
                   "cpp_batch": cbat, "cpp_batch_txn": ctxn, "native": nat}
            for col, st in (("py", py_st), ("cpp_per_op", cop_st), ("cpp_batch", cbat_st),
                            ("cpp_batch_txn", ctxn_st)):
                row[f"{col}_mean"], row[f"{col}_sigma"], row[f"{col}_ci"] = st
            for k in ("native_mean", "native_sigma", "native_ci"):   # 独立二进制单次运行, 无重复样本
                row[k] = None
            rows.append(row)
            print(f"{field:<9} {wl:<3} {fmt(py):>8} {f'{py_ns:.0f}ns':>7} "
                  f"{fmt(cop):>6}({cop/py:>3.1f}×) {fmt(cbat):>6}({cbat/py:>3.1f}×) "
                  f"{fmt(ctxn):>9}({ctxn/py:>3.1f}×) {fmt(nat):>6}({nat/py:>3.1f}×)")
    if REPEAT > 1:
        print("\n重复统计 (REPEAT={}, m=均值, σ/CI95 为相对 m 的 %; 头列值口径仍为 min):".format(REPEAT))
        for row in rows:
            parts = []
            for col, label in (("py", "py"), ("cpp_per_op", "per_op"), ("cpp_batch", "batch"),
                               ("cpp_batch_txn", "txn"), ("native", "native")):
                mean = row[f"{col}_mean"]
                if mean is None:
                    parts.append(f"{label}: 单次")
                    continue
                base = row[f"{col}"]
                parts.append(f"{label}: m={fmt(mean)} σ={_fmt_pct(row[f'{col}_sigma'], mean)} "
                             f"ci95=±{_fmt_pct(row[f'{col}_ci'], mean)} (min={fmt(base)})")
            print(f"{row['field']:<9} {row['wl']:<3} " + " | ".join(parts))
    print()
    gc.enable()
    _annotate_floors(rows)
    if args.json:
        _write_json(rows, args.json)
    if args.check:
        _check(rows)
    if args.mutate:
        _mutate_self_check(rows)


def _mutate_self_check(rows):
    """变异自检: 注入跌破地板的 cell → 断言②必须 FAIL; 原 rows(恢复)→ 必须 PASS。

    通过 = 门禁确实能抓住单 cell 回退(exit 0); 门禁漏检(注入后仍 PASS) = 自检失败 exit 2。
    """
    with open("bench_thresholds.json", encoding="utf-8") as f:
        thr = json.load(f)
    mut, (desc, col, target, guard) = _inject_mutation(rows, thr)
    print(f"[mutate] 注入: {desc} 的 {col} 比值 → {target:.2f}×"
          f"(< 地板 {guard:.2f}× = {CELL_GUARD:.1f}×该规则阈值), 门禁必须 FAIL")
    caught = False
    try:
        _check(mut)
    except SystemExit as e:
        caught = (e.code == 1)
    if not caught:
        print("[mutate] 变异自检失败: 注入跌破地板的 cell 后门禁未拒绝 —— 断言失灵")
        sys.exit(2)
    print("[mutate] ✓ 注入后门禁 FAIL(如预期拒绝单 cell 回退)")
    _check(rows)                      # 恢复(未注入的原 rows)→ 必须 PASS
    print("[mutate] ✓ 恢复后门禁 PASS —— 变异自检通过(注入→FAIL, 恢复→PASS)")


if __name__ == "__main__":
    main()
