# Portable Core — 跨引擎核心层

> 一句话：把「算法与数据协议」从引擎代码里抽出来，用三语言 golden 向量锁死；
> 引擎侧只保留适配层（Vector2 / 矩阵 / 文件 API）。

## 1. 为什么

技术方案总览（`docs/技术方案总览.md` 第 9 章）把可移植性拆成四层：
A 数据/协议、B 算法、C shader/粒子、D 编辑器。`portable-core` 是 B 层的第一个落地：

- 同一份算法有 **Python / GDScript / JavaScript** 三份实现；
- 用同一组 golden 向量验证逐值一致（等距移动、8 扇区、`hash32`）；
- Godot、Three.js、烘焙脚本都只写「薄适配层」。

## 2. 目录

```
portable-core/
├── spec/
│   ├── functions.md          # 语言无关契约（输入/输出/边界）
│   └── golden.json           # 15 个 iso + 9 个 hash 向量（生成物）
├── impl/
│   ├── python/portable_core.py
│   ├── gdscript/portable_core.gd
│   └── js/portable_core.mjs
├── tools/gen_golden.py       # 用 Python 参考实现生成 golden.json
├── tests/
│   ├── test_python.py
│   └── test_js.mjs
├── sync.py                   # 同步 core + golden 到引擎工程（--check 检漂移）
└── verify.sh                 # 三语言 + Godot 全量校验
```

## 3. 契约

| 函数 | 输入 | 输出 | 说明 |
| --- | --- | --- | --- |
| `screen_motion(x, y)` | 屏幕输入向量 | `[x, y*0.5]` | 等距 2:1；先除 2 再归一化 |
| `dir_index(x, y)` | 屏幕方向 | `0..7` | 0=右、2=下、4=左、6=上；零向量→0 |
| `hash32(x, y, seed)` | int | uint32 | xorshift 风格整数哈希；溢出掩 `0xFFFFFFFF` |

边界（零向量、负角度、负数坐标、32 位溢出）见 `spec/functions.md`。

## 4. Golden 协议

- 唯一来源：`spec/golden.json`，由 `tools/gen_golden.py` 用 Python 实现生成；
- 三份实现必须逐值一致：motion 容差 `1e-9`，dir / hash 精确相等；
- 改算法时：改契约 → 改三份实现 → 重新生成 golden → 跑 `verify.sh`；
- golden 由 `sync.py` 复制进 Godot 工程，作为无头测试数据。

## 5. 同步到引擎

`sync.py` 当前同步两个目标：

| 源 | 目标 |
| --- | --- |
| `impl/gdscript/portable_core.gd` | `godot-iso-slice/src/core/portable_core.gd` |
| `impl/python/portable_core.py` | `godot-iso-slice/tools/core/portable_core.py` |
| `spec/golden.json` | `godot-iso-slice/tests/portable_golden.json` |

引擎工程保持自包含（`res://` 路径、无符号链接）；`--check` 用来发现手工改动导致的漂移，
已接入 `godot-iso-slice/tools/verify.sh`。

## 6. 当前接入

| 使用方 | 适配层 | 说明 |
| --- | --- | --- |
| `godot-iso-slice` 移动 | `src/iso_math.gd` | Vector2 → 标量契约；返回 Vector2（引擎 float32） |
| `godot-iso-slice` 烘焙 | `src/sigil_rules.gd` `hash32` + `tools/bake_pipeline.py` | 两端都直接用 core 的 `hash32`，不再各写一份 |
| 未来 Three.js | `impl/js/portable_core.mjs` | 已通过 golden 测试，尚未接入 craft-* 应用 |

## 7. 验证

```bash
bash portable-core/verify.sh
# PORTABLE_SYNC_OK
# PORTABLE_PY_OK iso=15 hash=9
# PORTABLE_JS_OK iso=15 hash=9
# PORTABLE_GD_OK iso=15 hash=9
# PORTABLE_ALL_OK
```

## 8. 新增函数 / 新增引擎

1. 在 `spec/functions.md` 写清输入输出与边界；
2. 三份实现各加一份，Python 作为参考；
3. `gen_golden.py` 加用例并重新生成；
4. 三端测试加断言；
5. `sync.py` 增加目标工程路径；
6. 引擎侧只写适配层，不复制算法。

## 9. 边界（故意不放进 core）

- Shader / 粒子（C 层）：语法与管线随引擎重写，只有数学和参数可带走；
- 文件 / GLTF / 纹理导入（D 层）：各引擎 API 不同；
- 引擎类型（Vector2 / 矩阵 / 节点）：只出现在适配层，核心层用标量/数组；
- GDScript 核心返回 `Array`（float64），避免 Vector2（float32）破坏逐值一致；
  适配层再转 Vector2，游戏手感不受影响。
