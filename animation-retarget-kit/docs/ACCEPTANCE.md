# 验收门槛

## 自动检查

```bash
bash tools/blender_inspect.sh <model> --require-armature
bash tools/blender_retarget.sh --source ... --target ... --clip ... --out ...
bash tools/blender_validate.sh <out>
```

| 检查 | 通过标准 | 失败处理 |
|---|---|---|
| 源/目标 Armature | 都 ≥1 | 先绑定/修资产 |
| 骨骼数 | 人形 ≥20；Mixamo 源 49/67/65 | 检查导入 |
| 尺寸 | 1.5–2.0m | 检查单位/缩放 |
| T-pose hint | 建议 true | A-pose 先 Rest Fixer |
| 映射骨骼 | ≥10，且核心骨覆盖 | 补 `maps/*.json` |
| 输出动作 | 至少 1 条，帧范围非空 | 检查 clip |
| 骨长漂移 | `max_bone_length_deviation < 0.01` | 不要交付；查 rest/映射/拉伸 |
| 材质/网格 | 有 mesh、有材质 | 检查导出选择 |

> `blender_validate.py` 只做骨长/结构检查，**不做姿态保真检查**。必须人工或数值对比源/目标的手肘、膝盖弯曲角度；本示例 Walk 两肘与源差 < 2°。手肘被拉直（Run 像滑行）通常是把全局 pose/rest 代入 Godot 局部 pose/rest 公式。

> 目标整体倾斜时先试 `--simple`（全局增量）。Xbot 的 SambaDance 用 `--simple` 在 Blender 中躯干与源一致（6°/7°），但导出 GLB 在 Godot 中会因 glTF rest 轴翻转而倾斜；此时用运行时 simple 重定向（参考 `godot-mixamo-demo/src/dance_retarget.gd`）。

## 人工/视觉检查

- [ ] 连续播放 ≥2 个循环（Idle/Walk/Run），无倾斜、无麻花、无拉伸
- [ ] 手肘/膝盖弯曲与源动画一致（不是直臂/直腿）
- [ ] 脚底不明显滑；root 轨迹连续
- [ ] 目标 rest 比例保持（不被源骨架拉长/压扁）
- [ ] 目标额外骨骼保持 rest，不出现乱动
- [ ] 在目标引擎里导入后，蒙皮/材质/动画正常

## 当前示例（Soldier → Michelle Walk）

- 源 49 骨骼，目标 65 骨骼，映射 49；
- 目标多出 16 个手指/脚趾末端骨骼，保持 rest；
- `VALIDATION_REPORT.max_bone_length_deviation ≈ 2e-06`（远低于 1%）；
- 左/右肘角度与源动画差 < 2°（局部 pose/rest 公式；修复前会拉直到约 16°）；
- 输出：`examples/soldier_to_michelle/Michelle_Walk.glb`，预览 `preview.png`。

## 失败即停止

- 无 Armature；
- 映射 < 10；
- 骨长漂移 > 1%；
- 输出无动画/无 mesh；
- 手肘/膝盖被明显拉直或动作像滑行（先查全局 pose/rest 误用）；
- 连续播放明显倾斜/拉伸但用户要求直接交付。

失败时向用户报告：源/目标路径、clip、映射数、缺失骨骼、`VALIDATION_REPORT`、怀疑的 rest/bind 问题。
