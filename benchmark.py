"""CModel 性能 benchmark —— 复用同一套 harness 对比【纯 Python】与【C 层 cmodel_fast】。

测量 write→fire 热路径:
- 负载 W1(0 回调)/ W2(K=10 回调, 回调为 Python no-op 函数)
- 类型 int/str/tuple(不可变, 走 _changed 的 != 分支)
     + list/dict/set(可变, 走 is 分支), 共 6 种
- 每次写入不同的值(保证 _changed 为 True, W2 真 fire)
- 预生成值列表, 计时只压纯赋值循环(隔离模型开销)
- 扣除空循环 baseline, 得到「纯模型开销 ns/write」
- timeit repeat=5 取最小值

两实现用完全相同的 BenchModel 结构(仅基类不同), 直接可比。
"""

import gc
import platform
import timeit

from cmodel import PyCModel          # 显式纯 Python(不受无感自动替换影响)
from cmodel_fast import CModel as CppCModel

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
    """返回 (raw_writes_per_sec, model_only_ns_per_write)。"""
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
    t_full = min(timeit.repeat(full_stmt, number=1, globals=g, repeat=REPEAT))
    t_model = max(t_full - t_base, 0.0)                        # 扣 baseline 得纯模型开销

    del values, m
    return n / t_full, t_model / n * 1e9


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
    for field in GEN:
        for wl, n, cb in (("W1", N_W1, False), ("W2", N_W2, True)):
            py_ops, py_ns = bench_field(PyBench, field, n, cb)
            cpp_ops, cpp_ns = bench_field(CppBench, field, n, cb)
            print(f"{field:<9} {wl:<3} "
                  f"{fmt(py_ops):>11} {py_ns:>7.0f} "
                  f"{fmt(cpp_ops):>16} {cpp_ns:>7.0f} {cpp_ops/py_ops:>7.2f}×")
    print()
    gc.enable()


if __name__ == "__main__":
    main()
