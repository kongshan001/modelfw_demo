# Mixamo → Godot 4.6 游戏 Demo

一个可运行的最小第三人称 Demo：

- 玩家可在 **Michelle / Soldier / Xbot** 之间切换（`Tab`）
- Michelle：Michelle 网格 + 隐藏的 Soldier 骨架，通过 `RetargetModifier3D` 实时重定向
- Soldier / Xbot：各自的原生 Mixamo 动画
- `WASD` 移动，`Shift` 奔跑，`Space` 跳舞（Michelle 的 SambaDance），`Tab` 切换角色
- 状态机：`Idle / Walk / Run`，Michelle 额外支持 `Dance`

## 运行

```bash
godot --path godot-mixamo-demo
```

或在 Godot 4.6 中打开 `godot-mixamo-demo/project.godot` 按 F5。

## 验收

```bash
godot --headless --path godot-mixamo-demo -s tools/smoke_demo.gd
# 期望：DEMO_SMOKE_OK

godot --path godot-mixamo-demo --resolution 1280x720 -s tools/capture_swap_gif.gd
# 输出：/tmp/mixamo_swap_frames/frame_000.png ... frame_059.png
```

GIF：`docs/swap_demo.gif`（角色切换）、`docs/dance_demo.gif`（Michelle SambaDance）、`docs/baked_run_demo.gif`（离线烘焙 Run），均 1280×720 / 4 秒 / 15fps。

## 离线烘焙 Demo

- 场景：`scenes/baked_demo.tscn`，直接播放 `animation-retarget-kit` 烘焙出的 `Michelle_Run.glb`
- 运行：`godot --path godot-mixamo-demo scenes/baked_demo.tscn`
- 流程记录：[`docs/BAKED_RETARGET_DEMO.md`](docs/BAKED_RETARGET_DEMO.md)
- 验证：`godot --headless --path godot-mixamo-demo -s tools/smoke_baked_demo.gd` → `BAKED_DEMO_SMOKE_OK`

## 结构

```text
godot-mixamo-demo/
├── assets/characters/   Soldier.glb / Michelle.glb / Xbot.glb / baked/Michelle_Run.glb
├── scenes/demo.tscn     main scene（运行时重定向/切换/跳舞）
├── scenes/baked_demo.tscn  离线烘焙 Run demo
├── src/demo.gd          环境、相机、HUD
├── src/player.gd        移动 + 三角色 rig + RetargetModifier3D
├── src/baked_demo.gd     baked clip 播放 + 相机环绕
├── tools/smoke_demo.gd  headless 冒烟（含切换）
├── tools/smoke_baked_demo.gd  baked demo 冒烟
├── tools/capture_baked_demo.gd baked demo 录帧
├── tools/capture_swap_gif.gd  切换录帧脚本
└── tools/capture_dance_gif.gd 舞蹈录帧脚本
```


## 动作迁移通用流程

- 引擎无关的完整流程（数据模型 / 全局增量公式 / root motion / 自研引擎架构 / 验收清单）：[`../docs/ANIMATION_RETARGET_PIPELINE.md`](../docs/ANIMATION_RETARGET_PIPELINE.md)

## AI 3D 角色管线

- 选型与接入：[`docs/AI_3D_PIPELINE.md`](docs/AI_3D_PIPELINE.md)
- Blender 验收门槛（骨架/骨骼/尺寸/材质/T-pose）：

```bash
bash tools/blender_inspect.sh assets/characters/Michelle.glb --require-armature
```

当前推荐 Tripo（图生 3D + 自动绑定 + 动作，骨骼命名支持 Mixamo）；拿到 `TRIPO_API_KEY` 后可直接用
`godot-battle/assets/visuals/heroes/swordsman_lingxiao.png` 跑首测，再替换本 demo 的 Michelle。

## 重定向关键点

- `RetargetModifier3D` 挂在**源 Skeleton3D** 下，目标 Skeleton3D 是它的直接子节点。
- `profile` 用目标骨架的 `mixamorig_*` 骨骼名构建；源/目标同名（Mixamo→Mixamo）。
- 只开 rotation retarget，关闭 position/scale，避免体型扭曲。
- 移动目标骨架后，网格要重新绑定 `mesh.skeleton = mesh.get_path_to(target_skel)`。
- Michelle 的 rest 轴与 Soldier 匹配，可直接用；Xbot 的 rest 轴不同，需要先做 Rest Fixer/BoneMap（本 demo 未使用 Xbot）。

## 素材与授权

- `Soldier.glb` / `Michelle.glb` 来自 [Three.js 官方示例](https://github.com/mrdoob/three.js/tree/dev/examples/models/gltf)，仅用于技术验证。
- Mixamo 角色/动画本身受 Adobe 条款约束：免版税商用、不可原样转售；Mixamo 服务对中国大陆国家/地区代码的账号不可用。详见 `assets/characters/README.md`。
