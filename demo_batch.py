"""端到端 demo:批量导入 + 批末统一刷新 —— set_many + transaction 的典型用法。

场景: 向 model 批量导入 N 条更新(每条改 sName 和 nAge), 一个"刷新"回调在字段
变更时重算派生摘要 sSummary。对比三种写法的【回调触发次数】与【耗时】。

预期:
- per-op:        每次写入都 fire → 回调触发 2N 次, 最慢。
- set_many:      setattr 跨界批量化, 但回调仍每次 fire → 2N 次, 较快。
- set_many+txn:  批末每字段只 fire 1 次 → 2 次, 最快, 且终值与上面一致。
"""

import time

from cmodel import CModel, _BACKEND  # 无感: 默认自动用 C++ 实现

N = 200_000


class UserModel(CModel):
    def __init__(self):
        super().__init__()
        self.sName = ""
        self.nAge = 0
        self.sSummary = ""          # 派生字段, 由刷新回调重算


def make_model():
    """造一个挂了刷新回调的 model。state['fires'] 记录刷新触发次数。"""
    m = UserModel()
    state = {"fires": 0}

    def refresh(mm):
        state["fires"] += 1
        mm.sSummary = f"{mm.sName}/{mm.nAge}"   # 代表"刷新"工作

    m.SetModifyCB("r", "sName", refresh)
    m.SetModifyCB("r", "nAge", refresh)
    return m, state


values = [(f"user{i}", i) for i in range(N)]     # 预生成待导入数据
_names = [n for n, _ in values]
_ages = [a for _, a in values]


def per_op():
    m, st = make_model()
    for name, age in values:
        m.sName = name
        m.nAge = age
    return m, st


def batch():
    m, st = make_model()
    m.set_many("sName", _names)     # 批量跨界: 每字段 1 次 C++ 调用
    m.set_many("nAge", _ages)
    return m, st


def batch_txn():
    m, st = make_model()
    with m.transaction():           # 批内不 fire, 批末每字段 fire 1 次
        m.set_many("sName", _names)
        m.set_many("nAge", _ages)
    return m, st


def best_of(fn, repeat=5):
    return min(_once(fn) for _ in range(repeat))


def _once(fn):
    t0 = time.perf_counter()
    fn()
    return time.perf_counter() - t0


def main():
    print(f"backend = {_BACKEND} | N = {N:,} 条更新(每条改 2 个字段)\n")
    base = None
    for label, fn in [("per-op", per_op),
                      ("set_many", batch),
                      ("set_many + transaction", batch_txn)]:
        m, st = fn()
        t = best_of(fn)
        base = base or t
        print(f"{label:<24} 耗时 {t*1000:8.1f} ms ({base/t:4.1f}×) | "
              f"回调触发 {st['fires']:>9,} 次 | 终值 sSummary = {m.sSummary!r}")
    print("\n结论: transaction 把回调从 2N 次压到 2 次, 终值一致, 最快。")


if __name__ == "__main__":
    main()
