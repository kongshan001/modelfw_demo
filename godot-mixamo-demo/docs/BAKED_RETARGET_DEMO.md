# 离线烘焙 Demo：Soldier Run → Michelle

这个 demo 不复用运行时 `RetargetModifier3D`，而是走 **animation-retarget-kit** 的离线流程：

```text
inspect 源/目标
  → retarget（Blender headless，Soldier Run → Michelle）
  → validate（骨长漂移 < 1%）
  → 目标 GLB 自带 baked clip
  → Godot 直接播放 + 相机环绕
```

## 1. 生成 baked 资产

在仓库根目录：

```bash
cd animation-retarget-kit

bash tools/blender_inspect.sh assets/source/Soldier.glb --require-armature
bash tools/blender_inspect.sh assets/target/Michelle.glb --require-armature

bash tools/blender_retarget.sh \
  --source assets/source/Soldier.glb \
  --target assets/target/Michelle.glb \
  --clip Run \
  --out /tmp/Michelle_Run.glb \
  --fps 30

bash tools/blender_validate.sh /tmp/Michelle_Run.glb

cp /tmp/Michelle_Run.glb ../godot-mixamo-demo/assets/characters/baked/Michelle_Run.glb
```

本次结果：

- 源 49 骨骼 / 目标 65 骨骼，映射 49；
- 目标多出的手指/脚趾末端保持 rest；
- `max_bone_length_deviation ≈ 3e-06`；
- 输出 1 条 baked clip（GLB 内动作名可能为 `Animation`）。

## 2. 运行 demo

```bash
godot --path godot-mixamo-demo scenes/baked_demo.tscn
```

场景内容：

- 直接播放 `assets/characters/baked/Michelle_Run.glb` 的唯一动画；
- 相机缓慢环绕；
- 无输入；HUD 标注 `inspect → retarget → validate → Godot`。

## 3. 录制 GIF

```bash
godot --path godot-mixamo-demo --resolution 1280x720 -s tools/capture_baked_demo.gd
# 输出：/tmp/mixamo_baked_demo_frames/frame_000.png ... frame_059.png
```

GIF：`docs/baked_run_demo.gif`（1280×720 / 4 秒 / 15fps）。

## 4. 与运行时 demo 的区别

| | `demo.tscn` | `baked_demo.tscn` |
|---|---|---|
| 方式 | 运行时 `RetargetModifier3D` | 离线 Blender bake |
| 动画源 | 隐藏 Soldier 骨架实时驱动 Michelle | 目标模型自带 baked clip |
| 输入 | WASD / Shift / Tab / Space | 无，相机环绕 |
| 用途 | 验证运行时重定向 | 验证工具链产物可直接进引擎 |
