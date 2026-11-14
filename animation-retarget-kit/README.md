# Animation Retarget Kit

给 **AI + 工程** 用的动作迁移工具包：把源骨架的动画烘焙到目标骨架，输出 GLB/FBX，可直接放进自研引擎。

- **引擎无关**：核心是 Blender headless 工具，不依赖 Godot/Unity/UE；
- **一键迁移**：`retarget.sh` 自动 inspect → retarget → validate；macOS 可双击 `一键迁移.command`；
- **AI 可读**：`AGENTS.md` / `CLAUDE.md` + JSON 报告（`RETARGET_REPORT` / `VALIDATION_REPORT`）；
- **可验收**：骨架/骨骼/尺寸/T-pose 检查 + 目标骨长漂移检测（抓拉伸）；
- **开箱示例**：Soldier → Michelle Walk，`examples/soldier_to_michelle/`。

## 依赖

| 依赖 | 版本 | 说明 |
|---|---|---|
| Blender | 3.4+（实测 3.4.1） | 推荐 macOS `/Applications/Blender.app`；`setup.sh` 自动写入 `config.env` |
| Python 3 | 任意 3.x | 仅用于一键脚本的 JSON 摘要；核心烘焙用 Blender 自带 Python |
| Godot | 可选 | 仅用于 `examples` 的预览，不参与 retarget |

## 环境（一次性）

```bash
cd animation-retarget-kit
./setup.sh
# 可选：./setup.sh --full  # 额外跑完整 golden example
```

`setup.sh` 会：

1. 找 Blender（`BLENDER` 环境变量 / macOS 默认路径 / Windows Git Bash 常见路径 / PATH）；
2. 检查 Blender ≥ 3.4；
3. 写 `config.env`（后续 `retarget.sh` 自动读取）；
4. 用内置 Soldier/Michelle 做一次 inspect 自检。

Windows 额外需要 Git for Windows（Git Bash）和 Python 3；见 [`windows/README.md`](windows/README.md)，双击 `windows/setup.bat` → `windows/retarget.bat`。

## 一键迁移

macOS 双击 `一键迁移.command`，按对话框选择目标模型（FBX/GLB）、动作和输出格式即可。

命令行等价：

```bash
./retarget.sh --target /path/your_model.fbx --clip samba
# 输出：out/your_model_samba.glb

./retarget.sh --target /path/your_model.fbx --clip run --fbx
# 输出 FBX，适合 UE/Unity 或其他引擎
```

内置动作：`idle` / `walk` / `run` / `samba(dance)`，详见 [`docs/CLIPS.md`](docs/CLIPS.md)。自定义源动作：

```bash
./retarget.sh --target /path/your_model.fbx \
  --source /path/your_source.glb --clip <准确动作名>
```

常用参数：`--simple`（目标 rest 轴差异大时）、`--map maps/<rig>.json`（非 Mixamo 骨架）、`--out <path>`、`--fps 30`。

> FBX 目标的纹理如果无法加载（Blender 里图片尺寸为 0），工具会先移除这些坏图片节点再导出 GLB（Blender 3.4 exporter 的已知崩溃）；有效纹理会保留。若纹理很重要，请把 FBX 的贴图文件放在同目录，或直接输出 FBX。

## 手动流程（高级）

```bash
# 1) 检查源/目标
bash tools/blender_inspect.sh assets/source/Soldier.glb --require-armature
bash tools/blender_inspect.sh assets/target/Michelle.glb --require-armature

# 2) 烘焙：Soldier Walk -> Michelle
bash tools/blender_retarget.sh \
  --source assets/source/Soldier.glb \
  --target assets/target/Michelle.glb \
  --clip Walk \
  --out examples/soldier_to_michelle/Michelle_Walk.glb \
  --fps 30

# 3) 验收：骨长漂移 < 1%
bash tools/blender_validate.sh examples/soldier_to_michelle/Michelle_Walk.glb

# 一键跑完整示例
bash tools/run_example.sh
```

输出：

- `examples/soldier_to_michelle/Michelle_Walk.glb`（推荐）
- `.../Michelle_Walk.fbx`（可选；`--out` 改成 `.fbx`）
- `.../report.json` / `validation.json` / `preview.png`

## 目录

```text
animation-retarget-kit/
├── README.md
├── AGENTS.md / CLAUDE.md      AI 入口
├── kit.json                   清单
├── setup.sh                   环境检查 + 写 config.env + 自检
├── retarget.sh                一键 inspect → retarget → validate
├── 一键迁移.command             macOS 双击入口
├── windows/
│   ├── README.md                Windows（Git Bash）说明
│   ├── setup.bat                双击配置环境
│   └── retarget.bat             双击/拖入 FBX 迁移
├── docs/
│   ├── ANIMATION_RETARGET_PIPELINE.md   引擎无关原理/公式
│   ├── OPERATIONS.md                    操作手册
│   ├── ACCEPTANCE.md                    验收门槛
│   ├── AI_PLAYBOOK.md                   AI 执行协议
│   ├── CLIPS.md                         内置动作/自定义动作
│   └── ASSETS.md                        素材与授权
├── assets/
│   ├── source/Soldier.glb              源：Idle/Walk/Run
│   ├── target/Michelle.glb             目标：65 骨骼，T-pose，SambaDance
│   ├── samples/Xbot.glb                额外测试目标（67 骨骼）
│   └── maps/mixamo.json                骨骼映射模板（Mixamo 自动映射）
├── tools/
│   ├── blender_inspect.py/.sh
│   ├── blender_retarget.py/.sh
│   ├── blender_validate.py/.sh
│   └── run_example.sh
├── examples/soldier_to_michelle/
└── LICENSES/
```

## 适用 / 不适用

适用：

- Mixamo → Mixamo（骨骼名自动映射）；
- 自定义人形骨架（提供 `maps/<rig>.json` 显式映射）；
- 离线 bake 到 GLB/FBX，供自研引擎播放；
- AI 自动执行 inspect → retarget → validate → 报告。

不适用：

- 源/目标没有骨架（先绑定）；
- 非人形/多足/翅膀等复杂骨架（需要自定义 profile 和更多人工验收）；
- 需要 runtime IK/动态混合（本工具是离线 bake；可参考 `docs/ANIMATION_RETARGET_PIPELINE.md` 的 runtime 架构）。

## 授权

`Soldier/Michelle/Xbot` 来自 Three.js 官方示例，Mixamo 条款约束；详见 `LICENSES/` 与 `docs/ASSETS.md`。公开仓库发布前请确认素材再分发权利。
