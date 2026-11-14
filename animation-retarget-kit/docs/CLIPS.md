# 内置动作（动作依赖文件）

这些源模型随工具包一起分发，`retarget.sh` 的别名直接使用它们；不需要登录 Mixamo。

| 别名 | 源模型 | 动作 | 源骨骼 |
|---|---|---|---:|
| `idle` | `assets/source/Soldier.glb` | `Idle_Character` | 49 |
| `walk` | `assets/source/Soldier.glb` | `Walk_Character` | 49 |
| `run` | `assets/source/Soldier.glb` | `Run_Character` | 49 |
| `samba` / `dance` | `assets/target/Michelle.glb` | `SambaDance_Character` | 65 |

另有测试目标 `assets/samples/Xbot.glb`（67 骨骼）和本地动作清单，可作为 rest 轴差异的测试对象；它不参与一键迁移的默认动作。

## 用自定义动作

```bash
bash tools/blender_inspect.sh /path/your_source.glb --require-armature
# 从 actions[] 里拿到准确动作名
./retarget.sh --target /path/your_model.fbx \
  --source /path/your_source.glb --clip <准确动作名>
```

## 产物说明

`retarget.sh` 输出的是**目标模型 + 一条 baked clip**的 GLB/FBX，不是独立动画库。换模型就重新 bake；如果要在 Unity/UE 里把同一段动画复用到多个模型，用引擎自带的 Humanoid/IK Retargeter 导入这条 clip，或对每个目标分别 bake。

## 授权

`Soldier / Michelle / Xbot` 来自 Three.js 官方示例（Mixamo 骨骼/动作）。Three.js 示例代码为 MIT；模型/动作的再分发与商用请遵守 Mixamo/Adobe 条款；详见 `LICENSES/` 与 `docs/ASSETS.md`。公开或商用前请替换为自有/已授权资产。
