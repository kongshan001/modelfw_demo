# Soldier → Michelle · Walk

这是工具包的 golden example：把 `Soldier.glb` 的 `Walk` 烘焙到 `Michelle.glb`。

## 复现

```bash
bash tools/blender_retarget.sh \
  --source assets/source/Soldier.glb \
  --target assets/target/Michelle.glb \
  --clip Walk \
  --out examples/soldier_to_michelle/Michelle_Walk.glb \
  --fps 30

bash tools/blender_validate.sh examples/soldier_to_michelle/Michelle_Walk.glb
```

## 产物

| 文件 | 说明 |
|---|---|
| `Michelle_Walk.glb` | 烘焙后的目标模型 + 1 条动画（推荐） |
| `Michelle_Walk.fbx` | 同上，FBX 版本 |
| `report.json` | `RETARGET_REPORT`：49/65 骨骼映射、clip、帧范围 |
| `validation.json` | `VALIDATION_REPORT`：骨长漂移 2e-06、65 骨骼、动作 |
| `preview.gif` / `preview.png` | Godot 预览（仅示例，不参与 retarget） |

## 结果摘要

- 源 49 骨骼，目标 65 骨骼，**映射 49**；
- 目标多出的 16 个手指/脚趾末端骨骼保持 rest；
- 输出 1 条动画，约 1 秒，30fps 源采样；
- `max_bone_length_deviation ≈ 2e-06`（< 1%）；
- 左/右肘角度与源动画差 < 2°（修复前会拉直到约 16°）；
- 默认保留 hips 位移（身体前倾/起伏）；`--strip-hips` 可置零。

## 注意

- GLB 只有一个动画；Blender glTF 导出可能把动作命名为 `Animation`，播放唯一 clip 即可。
- 目标骨骼比例由 Michelle rest 保持，不会被 Soldier 拉长。
- 这是 rotation-only bake；脚部接触/IK 未处理。
- `blender_validate.py` 只查骨长，不查姿态；手肘/膝盖是否被拉直必须人工或对比角度。
- 自研引擎 runtime 重定向请参考 `docs/ANIMATION_RETARGET_PIPELINE.md` 的 Godot 同式（局部 pose/rest + 父级 rest 基变换）；不要把全局 pose/rest 代入。
