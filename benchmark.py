"""CModel 性能 benchmark —— 复用同一套 harness 对比【纯 Python】与【C 层 cmodel_fast】。

测量 write→fire 热路径:
- 负载 W1(0 回调)/ W2(K=10 回调, 回调为 Python no-op 函数)
- 类型 int/str/tuple(不可变, 走 _changed 的 != 分支)
     + list/dict/set(可变, 走 is 分支), 共 6 种
- 每次写入不同的值(保证 _changed 为 True, W2 真 fire)
- 预生成值列表, 计时只压纯赋值循环(隔离模型开销)
- 扣除空循环 baseline, 得到「纯模型开销 ns/write」
- timeit repeat=5(REPEAT, bench_config.py 档位)取最小值; 另按 REPEAT 个样本
  输出每 cell 的 mean/σ/95%CI(t 分布), 只做统计展示, 头列值口径不变(min)

两实现用完全相同的 BenchModel 结构(仅基类不同), 直接可比。
"""

import gc
import math
import platform
import timeit

from cmodel import PyCModel          # 显式纯 Python(不受无感自动替换影响)
from cmodel_fast import CModel as CppCModel

from bench_config import K, N_W1, N_W2, REPEAT, GEN   # 单一负载源(与 compare.py 共享)

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


def _make_bench(base):
    """基于给定 CModel 基类构造一个声明了 6 个字段的 bench 模型。"""
    class BenchModel(base):
        def __init__(self):
            super().__init__()
            self.f_int = 0
            self.f_str = ""
            self.f_tuple = ()
            self.f_list = []
            self.f_dict = {}
            self.f_set = set()
    return BenchModel


PyBench = _make_bench(PyCModel)
CppBench = _make_bench(CppCModel)


def bench_field(Bench, field, n, with_callbacks):
    """返回 (raw_writes_per_sec(min), model_only_ns_per_write, (mean, σ, 95%CI))。

    均值/σ/CI 由 REPEAT 个 raw w/s 样本算得(统计展示用), 头值口径 = min 不变。
    """
    m = Bench()
    if with_callbacks:
        for k in range(K):
            m.SetModifyCB(f"cb{k}", field, lambda mdl: None)   # Python no-op 回调
    values = [GEN[field](i) for i in range(n)]                 # 预生成, 不计入计时
    g = {"values": values, "m": m, "x": None}

    full_stmt = f"for v in values: m.{field} = v"              # 循环 + 赋值(+fire)
    base_stmt = "for v in values: x = v"                        # 仅循环+绑定(baseline)

    timeit.timeit(base_stmt, number=1, globals=g)              # warmup
    timeit.timeit(full_stmt, number=1, globals=g)

    t_base = min(timeit.repeat(base_stmt, number=1, globals=g, repeat=REPEAT))
    t_full_list = timeit.repeat(full_stmt, number=1, globals=g, repeat=REPEAT)
    t_full = min(t_full_list)
    t_model = max(t_full - t_base, 0.0)                        # 扣 baseline 得纯模型开销
    samples = [n / t for t in t_full_list]

    del values, m
    return n / t_full, t_model / n * 1e9, _cell_stats(samples)


def fmt(x):
    if x >= 1e6:
        return f"{x/1e6:.2f}M"
    if x >= 1e3:
        return f"{x/1e3:.1f}K"
    return f"{x:.0f}"


def main():
    gc.disable()
    print(f"[{platform.python_version()} | {platform.processor() or platform.machine()}]  "
          f"W1: N={N_W1:,} (0 cb)  W2: N={N_W2:,} (K={K} cb)  repeat={REPEAT} (min, gc off)\n")
    print(f"{'field':<9} {'WL':<3} "
          f"{'Python w/s':>11} {'ns/mod':>7} "
          f"{'cmodel_fast w/s':>16} {'ns/mod':>7} {'speedup':>8}")
    print("-" * 72)
    rows = []
    for field in GEN:
        for wl, n, cb in (("W1", N_W1, False), ("W2", N_W2, True)):
            py_ops, py_ns, py_st = bench_field(PyBench, field, n, cb)
            cpp_ops, cpp_ns, cpp_st = bench_field(CppBench, field, n, cb)
            rows.append((field, wl, py_ops, py_st, cpp_ops, cpp_st))
            print(f"{field:<9} {wl:<3} "
                  f"{fmt(py_ops):>11} {py_ns:>7.0f} "
                  f"{fmt(cpp_ops):>16} {cpp_ns:>7.0f} {cpp_ops/py_ops:>7.2f}×")
    if REPEAT > 1:
        print("\n重复统计 (REPEAT={}, m=均值, σ/CI95 为相对 m 的 %; 头列值口径仍为 min):".format(REPEAT))
        for field, wl, py_ops, py_st, cpp_ops, cpp_st in rows:
            cells = []
            for label, base, st in (("py", py_ops, py_st), ("cpp", cpp_ops, cpp_st)):
                mean, sd, ci = st
                rel = lambda x: "-" if x is None else f"{x / mean * 100:.1f}%"
                cells.append(f"{label}: m={fmt(mean)} σ={rel(sd)} ci95=±{rel(ci)} (min={fmt(base)})")
            print(f"{field:<9} {wl:<3} " + " | ".join(cells))
    print()
    gc.enable()


if __name__ == "__main__":
    main()
