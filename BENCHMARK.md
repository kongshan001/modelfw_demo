# CModel 性能对比:Python vs C++

目标:回答"**把 py 层 CModel 换成 C++ 层,到底能快多少?值不值?**"

## 三个实现

| 标签 | 实现 | 字段类型 | 回调驻地 | 说明 |
|---|---|---|---|---|
| **Python** | `cmodel.py` | 动态 | Python 函数 | 基准 |
| **pybind11** | `cmodelpb.CModel`(cpp/cmodel_pybind.cpp) | `py::object` | Python 函数 | 真实"换层":从 Python 调、行为与 Python 版逐条一致 |
| **C++native** | `CModel<T>`(cpp/cmodel_native.hpp + bench_native) | C++ 模板 | C++ lambda | 纯原生上限,全程不碰 Python |

C++ 设计取舍(详见 grilling 决策):原生版用**习惯用法等价**——复刻热路径语义(变更检测、按字段防环、回调派发),丢弃 Python 仅为动态类型而做的簿记(无 type-hash 分支、无 `_declared` 集)。pybind11 版因字段装 `py::object`,**必须**完整复刻 Python 的可变/不可变 `_changed` 逻辑,否则行为不一致。

## 方法

- 负载:**W1**(0 回调,N=1,000,000 次写入)/ **W2**(K=10 回调,N=100,000,×10=1,000,000 次回调触发)
- 类型:int/str/tuple(不可变)+ list/dict/set(可变),覆盖 `_changed` 两条分支
- 每次写入**不同的值**(保证 `_changed` 为 True、W2 真 fire)
- 预生成值列表,计时只压 `for v in values: m.{field} = v`(隔离模型开销)
- timeit / steady_clock,**repeat=5 取最小值**,关 GC
- Python 与 pybind11 **共用同一份 harness**(仅 import 的类不同)

## 结果(raw writes/sec,括号为相对 Python 的倍数)

```
field     WL      Python         pybind11        C++native
----------------------------------------------------------
f_int     W1       1.60M     2.09M ( 1.3×)    39.64M (24.8×)
f_int     W2      561.5K    699.0K ( 1.2×)     5.80M (10.3×)
f_str     W1       1.57M     2.04M ( 1.3×)    29.24M (18.6×)
f_str     W2      557.3K    697.2K ( 1.3×)     5.17M ( 9.3×)
f_tuple   W1       1.55M     2.10M ( 1.4×)    37.72M (24.4×)
f_tuple   W2      551.9K    701.8K ( 1.3×)     5.46M ( 9.9×)
f_list    W1       1.67M     2.10M ( 1.3×)    29.07M (17.4×)
f_list    W2      566.0K    716.5K ( 1.3×)     5.34M ( 9.4×)
f_dict    W1       1.66M     2.24M ( 1.3×)    23.07M (13.9×)
f_dict    W2      570.8K    717.3K ( 1.3×)     4.85M ( 8.5×)
f_set     W1       1.63M     1.91M ( 1.2×)    22.60M (13.9×)
f_set     W2      556.7K    681.4K ( 1.2×)     4.93M ( 8.9×)
```

## 分析

### 1. pybind11 换层几乎不值:仅 1.2–1.4×

这是最关键的结论。C++ 明明快得多,但从 Python 调用时几乎没赚到——**因为每次写入都要 Python→C++ 跨界一次,W2 里每次回调还要 C++→Python 跨界一次**。FFI 过路费把 C++ 的速度优势吃掉了。

### 2. 纯原生 C++ 是真正的天花板:8.5–25×

完全在 C++ 里跑、不碰 Python 时,加速可观(W1 int 接近 25×)。但这个版本**没法从 Python 直接用**——它测的是"如果整个热路径都在 C++ 里、连回调也是 C++,能多快"。

### 3. native 与 pybind11 之间的巨大鸿沟 = FFI 代价

W1 int:native 24.8× vs pybind11 1.3×。也就是 **C++ 理论上 24.8× 的潜力,换层后只剩 1.3×——约 19 倍的潜力被 FFI 过路费吃掉**。这正是 (A)/(B)/(C) 三组数对比的价值所在(光看 pybind11 会误判"换层没用",光看 native 会误判"换层能快 25 倍")。

### 4. 回调密度(pybind11 这边)没出现"反超",但也没拉开

grilling 时预测"回调密集可能让 pybind11 比纯 Python 还慢"。实测 W2 仍有 1.2–1.3× 微弱领先——因为 C++ 单次 setattr 快得足以抵消 10 次回调跨界。但收益和 W1 几乎一样薄,说明**回调跨界开销和 setattr 节省大致抵消**。

### 5. C++ 在 W2 优势缩小:native 从 ~25× 掉到 ~10×

W1(纯写入)native ~25×,W2(带回调)掉到 ~10×。回调派发无论 Python/C++ 都按次付费,C++ 的 `std::function` 调用不如纯计算那么廉价,留给 C++ 的空间小。

## 结论 / 建议

> 对**细粒度属性回调模型**这类"每次操作都小、回调频繁"的场景:**pybind11 换层不划算**(FFI 是主要矛盾,仅 1.2–1.4×)。要么继续用 Python,要么彻底走 C++ 且**连回调也留在 C++ 侧**(native 路线,9–25×),避免每个操作都跨界。

换层真正值得的前提:能把**一批操作打包成一次 C++ 调用**(批量跨界),或把回调逻辑整体下沉到 C++。逐次跨界的小操作,FFI 会吞掉全部收益。

## 平替(drop-in):cmodel_fast.CModel

`cmodel_fast.CModel` 是纯 Python `cmodel.CModel` 的**完整平替**——C++ 核心(`cmodelpb`)+ 极薄 Python 壳(只为复刻 `__init_subclass__` 声明快照)。用户改一行 import 即换:

```python
# 原: from cmodel import CModel
from cmodel_fast import CModel        # 其余代码不动
```

**API 与行为逐条一致**(含未声明字段警告、覆盖警告、按字段防环、`ClearModifyCB` 四向、`NotifyChange`、回调异常带堆栈日志)。由同一套 17 个回归用例对两实现各跑一遍证明:**34 passed**(见 `test_cmodel.py`)。

**性能**:作为 Python drop-in,与上表 pybind11 列同档(**1.0–1.3×**,薄壳近乎零开销;瓶颈仍是 per-op FFI)。同一份 C++ 核心若从 C++ 侧调用则是 9–25×。所以这个平替的价值是 **API 一致性 / 可替换性**(以及:若 app 主体用 C++ 驱动该 model,可拿满速度),而非 Python 侧提速。


## 经验参考:per-op FFI 与批量跨界

> 本性能对比沉淀下来的核心经验, 供以后评估"Python 调 C++"类方案参考。

### 什么是 per-op FFI

- **FFI**(Foreign Function Interface)= Python 与 C++ 之间的调用桥(本项目用 pybind11)。
- **per-op FFI** = "每一次操作都要过一次这座桥、交一次过路费"。过路费是固定的(调用帧、类型转换、GIL、引用计数), 与这步活儿大小无关, 通常几百 ns。

### CModel 里一次写入发生几次跨界

`m.f_int = v`(m 是 C++ 实现)的旅程:
- ① Python → C++: 执行 `__setattr__`(每写 1 次)。
- ② 若有 K 个 Python 回调: 每个 fire 都 C++ → Python(K 次)。

所以:
- W1(0 回调): **每写 1 次跨界**。
- W2(K=10 回调): **每写 11 次跨界**(1 setattr + 10 回调)。

### 数字拆解(为什么 pybind11 只有 ~1.2×)

| | 单次写入纯模型开销 | 其中 C++ 真正干活 | 即 per-op FFI 过路费 |
|---|---|---|---|
| C 层(pybind11) | ~527 ns | ~25 ns | ~500 ns |

C++ 25ns 能干完的活, 过桥费 500ns 把它淹了 → 比纯 Python(~619ns)只省 ~92ns ≈ **1.2×**。

### 解法:批量跨界(`set_many`)

把 N 次写入打包成 1 次 C++ 调用, N 次过路费压成 1 次:

| 负载 | per-op(pybind11) | batch(`set_many`) | 说明 |
|---|---|---|---|
| W1(0 回调) | 1.1× | **2.4×** | setattr 跨界从 N 次压成 1 次, 收益翻倍 |
| W2(K=10 回调) | 1.2× | **1.5–1.6×** | setattr 跨界省了, 但回调跨界(N×K)仍在, 收益受限 |

### 两个天花板(batch 也没能突破的)

1. **回调跨界**: batch 只压了 setattr 的跨界; 回调是 Python 函数, 每次 fire 仍要 C++→Python。W2 因此卡在 ~1.5×。要再突破, 回调本身也得下沉到 C++。
2. **Python 对象本身**: 即便 batch, 值仍是 Python 对象, C++ 侧遍历 list、对 `py::object` 做 `==`/`is`、引用计数都要回 Python。所以 batch W1(2.4×)远低于纯 native(25×)——纯 native 用 C++ 值类型, 全程不碰 Python 对象。

### 一句话经验

> 评估"Python 调 C++"提速时, 先问:**跨界频率有多高?**
> - 细粒度、逐次跨界(per-op)→ FFI 过路费主导, 提速被压在 ~1×–2×。
> - 能批量跨界(batch)→ 把 N 次费压成 1 次, 提速上一个台阶, 但仍受限于"值/回调是否也在 C++ 侧"。
> - 全 C++ 且值/回调都在 C++ → 才能拿到 native 级(本项目 9–25×)提速。

**迁移启发**:pybind11 加速适合"粗粒度、单次调用做大量 C++ 内部工作"的场景; 对 CModel 这种"每个属性变更都要立刻通知"的细粒度响应式模型, 真正的提速要么批量、要么整体下沉 C++。

## 复现

```bash
python3 benchmark.py                 # phase 1: 纯 Python 基准
cd cpp && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j
./cpp/build/bench_native             # phase 2a: C++ 原生上限
python3 compare.py                   # 四列对比: Python / cpp(per-op) / cpp(batch,set_many) / native
```
