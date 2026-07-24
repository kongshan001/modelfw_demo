# CModel

Python 层的**数据驱动属性变更回调框架**。给属性赋值就能触发外部注册的回调,用于「数据变了 → 自动响应」的场景。

```python
from cmodel import CModel

class UserModel(CModel):
    def __init__(self):
        super().__init__()          # 必须先调用
        self.sName = ""             # 在 __init__ 里显式声明字段 + 默认值
        self.nAge = 0

def on_name(m):                     # 回调签名统一为 cb(oModel)
    print("name changed ->", m.sName)

oModel = UserModel()
oModel.SetModifyCB(oTag, "sName", on_name)   # 注册回调:(分组tag, 字段名, 回调)
oModel.sName = "test"                        # 赋值即触发 on_name(oModel)
```

## 无感切换到 C++ 实现

`cmodel.CModel` 这个名字**默认自动指向 C++ 实现**(`cmodel_fast` / `cmodelpb`),用户原有代码 `from cmodel import CModel` **一行都不用改**就用上 C++。C++ 后端没构建时**静默回退**纯 Python。

```python
import cmodel
print(cmodel._BACKEND)   # "cpp"(用了 C++)或 "py"(回退纯 Python)
```

控制开关(环境变量 `CMODEL_IMPL`):

| 取值 | 行为 |
|---|---|
| `auto`(默认) | 有 C++ 用 C++,否则回退纯 Python |
| `cpp` | 强制 C++;后端缺失则报错(提示去构建 `cpp/`) |
| `py` | 强制纯 Python |

- 纯 Python 版本始终可显式取用:`from cmodel import PyCModel`。
- 两种实现 API/行为完全一致(同一套 17 用例 ×2 = 34 测试证明,见 `test_cmodel.py`)。
- 性能:作为 Python drop-in 约 **1.2×**;批量 `set_many` 约 **2.4×**(无回调);纯原生 C++ 9–25×。详见 `BENCHMARK.md`。

## 设计决策

框架的每一处行为都来自以下 8 条决策,改动前请先对照这张表。

| # | 主题 | 决策 |
|---|---|---|
| 1 | 字段模型 | **动态**;`_` 开头的属性视为内部状态,绕过回调逻辑 |
| 2 | `oTag` | 分组/注销 key;注册表结构 `{字段: {tag: 回调}}`;同 `(tag, field)` 重复注册**覆盖**并警告 |
| 3 | 回调签名 | `cb(oModel)` —— 只传 model 实例,回调自己读字段、改字段 |
| 4 | 触发条件 | `_changed(old, new)`:可变/不可哈希类型用 `is`,不可变类型用 `!=`(`__eq__` 抛异常则退回 `is`);**首次赋值算变更**;回调在**赋值之后**触发 |
| 5 | 连锁 | 回调里改别的字段会继续触发那些字段的回调;**按字段粒度防环**(自身回调链里重复触发 → 警告并中断) |
| 6 | 构造 | **必须子类化**;字段在子类 `__init__` 用 `self.x = 默认值` 声明,先 `super().__init__()`;子类无需任何开闸代码(构造期注册表为空,fire 自然无害) |
| 7 | 未声明字段 | 仍可赋值、仍会触发,但**追加警告**;`_declared` 由 `__init_subclass__` 在子类 `__init__` 跑完后自动快照 |
| 8 | 回调异常 | **吞掉 + 记日志(带完整堆栈)**,不影响同字段其余回调与连锁 |

## API

| 方法 | 说明 |
|---|---|
| `SetModifyCB(tag, field, cb)` | 注册回调。同 `(tag, field)` 重复注册覆盖并警告。`tag` 任意可哈希值,同一 tag 可盯多字段,同一字段可挂多 tag |
| `ClearModifyCB(tag=None, field=None)` | 清理:只给 `field` 清该字段全部;只给 `tag` 清所有字段下该 tag;两个都给精确清 `(field, tag)`;都不给清空全部 |
| `NotifyChange(field)` | 强制触发某字段回调(不依赖值变化)。主要给可变类型**原地修改**后手动补刀 |

## 重要语义

- **可变类型的原地修改监听不到**。`oModel.lst.append(x)`、`oModel.d["k"] = v` 不经过 `__setattr__`,框架看不见。改完调 `oModel.NotifyChange("lst")` 补一刀,或重新赋一个新对象。
- **防环只断回调链,不断赋值**。回调里 `m.sName = m.sName + "!"` 会先把值改掉,只是它引发的 `sName` 回调被防环拦下、不再递归。
- **子类契约**:`__init__` 必须先 `super().__init__()`,再用 `self.x = 默认值` 声明字段。声明之外的字段可用,但会警告。
- **内部状态用 `_` 前缀**:`_callbacks`、`_firing`、`_declared` 等都不触发回调、不做声明校验。自定义内部属性也请用 `_` 开头。

## 运行

```bash
# 交互式 demo(9 个场景,带打印输出)
python3 cmodel.py

# 回归测试(17 个用例)
python3 -m pytest test_cmodel.py -v
```

## 文件结构

```
modelfw_demo/
├── cmodel.py        # 框架(纯 Python)+ 内置 demo
├── cmodel_fast.py   # C++ 平替入口(配 cpp/cmodel_pybind.cpp), import 即换
├── test_cmodel.py   # 17 用例 × {py, cpp} = 34,证明平替
├── benchmark.py     # 纯 Python 基准
├── compare.py       # 三实现对比(Python / cmodel_fast / C++ 原生)
├── BENCHMARK.md     # 性能对比 + 平替说明
├── cpp/             # C++: CModel<T> 原生 + pybind11 模块(cmake 构建)
└── README.md        # 本文档
```
