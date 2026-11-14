# Animation Retarget Kit — AI 执行协议

当用户要求“把某个动作迁移到另一个模型 / 做动作重定向 / 烘焙动画到目标骨架”时，按本协议执行。

## 开始前

1. 读 `docs/OPERATIONS.md` 和 `docs/ACCEPTANCE.md`。
2. 确认输入：
   - 源模型路径 + 动作名（clip）；
   - 目标模型路径；
   - 非 Mixamo 骨架需要 `maps/<rig>.json`（源骨→目标骨）。
3. **不要修改** `assets/source/`、`assets/target/`、`assets/samples/`；输出只写 `out/` 或 `examples/`。

## 执行流程

```bash
# 1) 检查源/目标（必须都有 Armature）
bash tools/blender_inspect.sh <source> --require-armature
bash tools/blender_inspect.sh <target> --require-armature

# 2) 选择 clip：使用 inspect 报告里的 actions[].name；不确定就问用户

# 3) 烘焙（GLB 或 FBX）
bash tools/blender_retarget.sh \
  --source <source> --target <target> --clip <clip> \
  --out out/<name>.glb --fps 30 [--map maps/<rig>.json] [--strip-hips] [--simple]

# 4) 验收
bash tools/blender_validate.sh out/<name>.glb
```

## 硬性规则

- **没有 Armature** → 停止，告诉用户需要先绑定/重定向；不要对静态网格硬做。
- **非 Mixamo 骨骼名** → 必须让用户提供显式 map；不要猜名字。
- **映射骨骼 < 10** → 停止，报告缺失映射。
- **validate 失败（骨长漂移 > 1%）** → 不要宣称成功；报告源/目标 rest 轴、映射、输出路径，建议 Rest Fixer 或换目标。
- **validate 通过 ≠ 姿态正确**：validate 只查骨长；必须检查手肘/膝盖弯曲是否与源一致。Run 手肘被拉直（像滑行）通常是全局 pose/rest 误代入 Godot 局部 pose/rest 公式。
- **目标整体倾斜（如 Xbot）** → 先试 `--simple`（全局增量）；导出 GLB 在目标引擎仍倾斜时，用运行时 simple 重定向或 Rest Fixer。
- **旋转 + hips 位移**：不要跨比例复制 position/scale；默认保留 hips 位移（身体前倾/起伏），`--strip-hips` 才严格置零；真正的角色位移交给控制器。
- 报告里必须包含：映射数、缺失骨骼、输出路径、验证结果、已知限制（目标多余骨骼保持 rest、动画名可能为 `Animation`）。

## 失败诊断顺序

1. 源/目标没有骨架？→ 先绑定。
2. 骨骼名不匹配？→ 自定义 map。
3. 整体倾斜/四肢上举/拉伸？→ rest 轴/roll 差异；确认是局部 pose/rest 公式（本工具已内置）仍失败时，先 Rest Fixer。
4. 手肘/膝盖伸直、动作像滑行？→ 检查是否把全局 pose/rest 代入 retarget 公式；validate 查不出这个。
5. 脚滑/身体直立？→ 检查是否误用了 `--strip-hips`；单位/移动速度另行核对。
6. 网格炸开？→ bind/inverse bind、负缩放、目标网格蒙皮。

## 输出给用户

- 产物路径（GLB/FBX）；
- `RETARGET_REPORT` 摘要（mapped_bones、missing_*、frames）；
- `VALIDATION_REPORT`（max_bone_length_deviation、actions）；
- 未覆盖的骨骼/动作、目标额外骨骼、下一步建议。

详细决策树见 `docs/AI_PLAYBOOK.md`。
