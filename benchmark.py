"""CModel 纯 Python 性能 benchmark —— phase 1 基准。

测量 write→fire 热路径吞吐:
- 负载 W1(0 回调)/ W2(K=10 回调, 回调为 Python no-op 函数)
- 类型 int/str/tuple(不可变, 走 _changed 的 != 分支)
     + list/dict/set(可变, 走 is 分支), 共 6 种
- 每次写入不同的值/对象(保证 _changed 为 True, W2 真 fire)
- 预生成值列表, 计时只压纯赋值循环(隔离模型开销, 排除值生成)
- 扣除空循环 baseline, 得到「纯模型开销 ns/write」(跨语言比模型层成本的关键)
- timeit repeat=5 取最小值(滤 GC/调度噪声)
"""

import gc
import platform
import timeit

from cmodel import CModel

K = 10               # W2 每字段回调数
N_W1 = 1_000_000     # W1 写入次数
N_W2 = 100_000       # W2 写入次数(×K = 1e6 次回调触发)
REPEAT = 5

# 字段 -> 值生成器(每次产出与上次不同的值/对象)
GEN = {
    "f_int":   lambda i: i,
    "f_str":   lambda i: f"v{i}",
    "f_tuple": lambda i: (i,),
    "f_list":  lambda i: [i],
    "f_dict":  lambda i: {i: i},
    "f_set":   lambda i: {i},
}


class BenchModel(CModel):
    """6 个已声明字段, 每种类型一个。"""

    def __init__(self):
        super().__init__()
        self.f_int = 0
        self.f_str = ""
        self.f_tuple = ()
        self.f_list = []
        self.f_dict = {}
        self.f_set = set()


def bench_field(field, n, with_callbacks):
    """返回 (raw_writes_per_sec, model_only_ns_per_write)。"""
    m = BenchModel()
    if with_callbacks:
        for k in range(K):
            m.SetModifyCB(f"cb{k}", field, lambda mdl: None)   # Python no-op 回调
    values = [GEN[field](i) for i in range(n)]                 # 预生成, 不计入计时
    g = {"values": values, "m": m, "x": None}

    full_stmt = f"for v in values: m.{field} = v"              # 循环 + 赋值(+fire)
    base_stmt = "for v in values: x = v"                        # 仅循环+绑定(空 baseline)

    # warmup
    timeit.timeit(base_stmt, number=1, globals=g)
    timeit.timeit(full_stmt, number=1, globals=g)

    t_base = min(timeit.repeat(base_stmt, number=1, globals=g, repeat=REPEAT))
    t_full = min(timeit.repeat(full_stmt, number=1, globals=g, repeat=REPEAT))
    t_model = max(t_full - t_base, 0.0)                        # 扣 baseline 得纯模型开销

    raw_ops = n / t_full                                       # 含循环的真实吞吐
    ns_model = t_model / n * 1e9                               # 纯模型 ns/write

    del values, m
    return raw_ops, ns_model


def main():
    gc.disable()   # 计时期间关 GC, 配合 min 进一步降噪
    print(f"[Python {platform.python_version()}] {platform.processor() or platform.machine()}")
    print(f"W1: N={N_W1:,} (0 cb)   W2: N={N_W2:,} (K={K} cb)   repeat={REPEAT} (min, gc off)\n")
    hdr = f"{'field':<9} {'WL':<4} {'writes/sec':>14} {'ns/write(model)':>18}"
    print(hdr)
    print("-" * len(hdr))
    for field in GEN:
        for wl, n, cb in (("W1", N_W1, False), ("W2", N_W2, True)):
            ops, ns = bench_field(field, n, cb)
            print(f"{field:<9} {wl:<4} {ops:>14,.0f} {ns:>18.1f}")
    print()
    gc.enable()


if __name__ == "__main__":
    main()
