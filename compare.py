"""三实现性能对比 —— phase 3.

同一负载、同一 harness(纯 Python 与 pybind11 共享 `for v in values: m.{field} = v`;
C++ 原生跑独立二进制,结果合并),产出对比表与加速比。

三实现:
  - py        : 纯 Python CModel(cmodel.py)
  - pb        : pybind11 换层(cmodelpb.CModel, 字段装 py::object, 回调为 Python 函数)
  - native    : 纯原生 C++(cpp/build/bench_native, C++ 回调, 无 Python)
"""

import gc
import os
import platform
import subprocess
import sys
import timeit

from cmodel import CModel
from cmodel_fast import CModel as CFastCModel

K = 10
N_W1 = 1_000_000
N_W2 = 100_000
REPEAT = 5

GEN = {
    "f_int":   lambda i: i,
    "f_str":   lambda i: f"v{i}",
    "f_tuple": lambda i: (i,),
    "f_list":  lambda i: [i],
    "f_dict":  lambda i: {i: i},
    "f_set":   lambda i: {i},
}


class PyBench(CModel):
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
    """返回 raw writes/sec。预生成值, timeit stmt 内联赋值, repeat=5 取最小值。"""
    m = factory()
    setattr(m, field, GEN[field](-1))                 # 初始值(与计时区间 0..n-1 不同)
    if with_cb:
        for k in range(K):
            m.SetModifyCB(f"cb{k}", field, lambda mdl: None)
    values = [GEN[field](i) for i in range(n)]
    g = {"values": values, "m": m}
    stmt = f"for v in values: m.{field} = v"
    timeit.timeit(stmt, number=1, globals=g)          # warmup
    t = min(timeit.repeat(stmt, number=1, globals=g, repeat=REPEAT))
    del values, m
    return n / t


def bench_batch(factory, field, n, with_cb):
    """返回 raw writes/sec。用 set_many: N 次写入只 1 次 Python->C++ 跨界。"""
    m = factory()
    setattr(m, field, GEN[field](-1))
    if with_cb:
        for k in range(K):
            m.SetModifyCB(f"cb{k}", field, lambda mdl: None)
    values = [GEN[field](i) for i in range(n)]
    g = {"values": values, "m": m, "field": field}
    stmt = "m.set_many(field, values)"
    timeit.timeit(stmt, number=1, globals=g)          # warmup
    t = min(timeit.repeat(stmt, number=1, globals=g, repeat=REPEAT))
    del values, m
    return n / t


def run_native():
    """跑 cpp/build/bench_native, 解析 'field WL writes/sec ns/op' 行。"""
    exe = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cpp", "build", "bench_native")
    out = subprocess.check_output([exe]).decode()
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


def main():
    gc.disable()
    native = run_native()
    print(f"[{platform.python_version()} | {platform.processor() or platform.machine()}]  "
          f"W1: N={N_W1:,} (0 cb)  W2: N={N_W2:,} (K={K} cb)  repeat={REPEAT} (min, gc off)\n")
    print(f"{'field':<9} {'WL':<3} {'Python':>9} {'cpp(op)':>15} {'cpp(batch)':>17} {'C++native':>15}")
    print("-" * 72)
    for field in GEN:
        for wl, n, cb in (("W1", N_W1, False), ("W2", N_W2, True)):
            py = bench(lambda: PyBench(), field, n, cb)
            cop = bench(lambda: CppBench(), field, n, cb)
            cbat = bench_batch(lambda: CppBench(), field, n, cb)
            nat = native.get((field, wl), float("nan"))
            print(f"{field:<9} {wl:<3} {fmt(py):>9} "
                  f"{fmt(cop):>8} ({cop/py:>4.1f}×) {fmt(cbat):>9} ({cbat/py:>4.1f}×) "
                  f"{fmt(nat):>8} ({nat/py:>4.1f}×)")
    print()
    gc.enable()


if __name__ == "__main__":
    main()
