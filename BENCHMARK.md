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

## 复现

```bash
python3 benchmark.py                 # phase 1: 纯 Python 基准
cd cpp && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j
./cpp/build/bench_native             # phase 2a: C++ 原生上限
python3 compare.py                   # phase 3: 三实现对比(会自动调用上面的二进制)
```
