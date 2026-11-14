# AI Playbook

## 输入契约

用户至少要给：

1. 源模型（GLB/FBX）+ 动作名；
2. 目标模型（GLB/FBX）；
3. 非 Mixamo 骨架：`maps/<rig>.json`。

缺少动作名时：先跑 inspect，列出 `actions[].name`，再让用户选；不要猜。

## 决策树

```text
源/目标有 Armature？
  ├─ 否 → 停止，说明需要先绑定
  └─ 是
      ├─ 骨骼名是 Mixamo → 自动映射
      ├─ 自定义名字 → 需要 map JSON
      └─ 映射 < 10 → 停止，要求补 map
           ↓
      运行 retarget（默认 rotation + hips 位移）
           ↓
      validate 通过（骨长漂移 <1%）？
        ├─ 是 → 检查手肘/膝盖弯曲与源一致
        │     ├─ 是 → 交付并报告
        │     └─ 否 → 查全局/局部 pose 误用；不要硬交付
        └─ 否 → 查 rest 轴/绑定/映射；不要硬交付
```

## 执行步骤

1. `blender_inspect.sh <source> --require-armature`
2. `blender_inspect.sh <target> --require-armature`
3. 选 clip（从源 actions）
4. `blender_retarget.sh --source ... --target ... --clip ... --out ... [--simple]`
5. `blender_validate.sh <out>`
6. 视觉/连续帧检查：倾斜、脚滑、**手肘/膝盖弯曲**（validate 不查姿态）
7. 报告

## 报告格式

```text
完成：out/<name>.glb
- 源/目标：...
- clip：...
- 映射：49/65（目标额外骨骼保持 rest）
- 验证：max_bone_length_deviation=2e-06，actions=[...]
- 已知限制：无手指末端驱动；hips 位移默认保留
```

## 失败处理

| 失败 | 报告/动作 |
|---|---|
| 无 Armature | 停止，要求绑定 |
| clip 不存在 | 列出 actions，要求选择 |
| 映射 <10 | 要求 map；不要猜 |
| 骨长漂移 >1% | 报告 worst_bone + 怀疑 rest/bind；建议 Rest Fixer |
| 四肢上举/扭转 | 确认使用局部 pose/rest 公式；仍失败 → Rest Fixer |
| 手肘/膝盖伸直、像滑行 | 默认公式查是否把全局 pose/rest 代入；`--simple` 才用全局量；validate 查不出 |
| 整体倾斜 | 先试 `--simple`；导出后在目标引擎仍倾斜用运行时 simple 重定向/Rest Fixer |
| 网格炸开 | bind/inverse bind/负缩放；停止 |
| 身体直立/脚滑 | 检查是否误用 --strip-hips；单位/移动速度 |

## 护栏

- 不改 `assets/source|target|samples`；
- 输出只写 `out/` 或 `examples/`；
- 不声称“成功”除非 validate 通过**且**手肘/膝盖姿态与源一致；
- 不在没有映射时凭名字猜测自定义骨骼；
- 公开/商用前确认素材授权。
