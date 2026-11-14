# 操作手册

## 0. 环境

```bash
# Blender 3.4+；macOS 默认路径：
BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
export BLENDER
```

工具全部为 Blender headless，不需要 pip 包。

## 1. 检查源/目标

```bash
bash tools/blender_inspect.sh <model.glb|fbx> --require-armature
```

看 `BLENDER_REPORT`：

- `armatures=1`，`bones` 数量，`mixamo_bones` 覆盖率；
- `size` 约 1.5–2.0m，`tpose_hint=true`；
- `actions` 列表（源模型的动作名在这里）；
- `materials` 是否完整。

没有 Armature → 先绑定，不要继续。

## 2. 选择动作与骨骼映射

**动作名**用 inspect 报告里的 `actions[].name`；不要凭记忆写 `Walk`（实际可能叫 `Walk_Character`）。

**Mixamo → Mixamo**：不需要 map，工具按规范化名字自动映射（`mixamorig:` / `mixamorig_` / 大小写）。

**非 Mixamo 或自定义骨架**：提供 `maps/<rig>.json`：

```json
{
  "bones": {
    "mixamorig:Hips": "Bip001 Pelvis",
    "mixamorig:Spine": "Bip001 Spine",
    "mixamorig:LeftArm": "Bip001 L UpperArm"
  }
}
```

规则：

- key = 源骨骼名，value = 目标骨骼名；
- 只列需要映射的骨骼；缺失的目标骨骼保持 rest；
- 左右侧、父子层级要人工核对，工具不会猜。

## 3. 烘焙

```bash
bash tools/blender_retarget.sh \
  --source <source.glb> \
  --target <target.glb> \
  --clip <action-name> \
  --out out/<name>.glb \
  --fps 30 \
  [--map maps/<rig>.json] \
  [--strip-hips] [--root-motion-scale 0.01] \
  [--simple]
```

- 默认 **只传旋转**：目标骨长保持，适合不同比例；
- 默认 Godot 同式的**局部 pose/rest** 公式；目标 rest 轴差异大（例如 Xbot）且结果整体倾斜时，加 `--simple` 改用 Step 6 的**全局增量**公式；
- 默认保留 **hips 位移**（身体前倾/重心/起伏，Run 必要）；`--strip-hips` 才严格 in-place；
- 输出 `.glb` 或 `.fbx`（按扩展名）；
- 只保留这一条烘焙动作；目标多余骨骼保持 rest。

读取 `RETARGET_REPORT`：

```json
{
  "mapped_bones": 49,
  "missing_in_source": ["..."],
  "missing_in_target": [],
  "frames": [0, 31],
  "output": "..."
}
```

`missing_in_source` 通常是目标多出的手指/脚趾末端骨骼（保持 rest 即可）；`mapped_bones` 过少要补映射。

## 4. 验收

```bash
bash tools/blender_validate.sh out/<name>.glb
```

看 `VALIDATION_REPORT`：

- `armatures=1`，`actions` 非空；
- `max_bone_length_deviation < 0.01`（1%）；
- `worst_bone` 无异常；
- 连续播放目标动画，确认无倾斜/麻花/脚滑；
- **检查手肘/膝盖弯曲**：validate 只查骨长，不查姿态；Run 手肘被拉直通常是全局 pose/rest 误代入公式。

失败不要交付；按 `docs/ACCEPTANCE.md` 排查。

## 5. 放进自研引擎

- 导入 GLB/FBX 到目标骨架；播放唯一动画（GLB 导出的动作名可能是 `Animation`，FBX 可能是 `Character.001|Scene`）；
- 蒙皮使用目标原始 bind；不要把源模型的 inverse bind 带过去；
- 自研 runtime 重定向可参考 `docs/ANIMATION_RETARGET_PIPELINE.md` 的 Godot 同式（局部 pose/rest + 父级 rest 基变换）；不要把全局 pose/rest 代入；
- 真正的角色位移（root motion）从 hips 位移中提取，交给角色控制器；不要把同一份位移既写进 hips 又传给控制器。

## 6. 常见问题

| 现象 | 处理 |
|---|---|
| 找不到 clip | 用 inspect 的 `actions` 列表，传准确名字；工具只在源模型动作里找 |
| 四肢上举/扭转/拉伸 | 确认使用本工具（局部 pose/rest 公式）；仍失败先做 Rest Fixer |
| 手肘/膝盖伸直、动作像滑行 | 默认 Godot 同式必须用局部 pose/rest，不要代入全局量；`--simple` 才用全局增量；validate 查不出这个 |
| 整体倾斜 | 根/hips rest 轴或映射错误；检查 map 与 root；先试 `--simple`，仍倾斜用 Rest Fixer 或运行时 simple 重定向 |
| FBX 目标 GLB 导出报 `zero-size array` | Blender 3.4 glTF exporter 对无法加载的纹理崩溃；工具会自动移除 zero-size 图片节点。确保 FBX 纹理文件可访问，或改用 FBX 输出 |
| 身体直立/脚滑 | 检查是否误用 `--strip-hips`；单位/移动速度另行核对 |
| 网格炸开 | bind/inverse bind、负缩放、蒙皮权重 |
| 只有部分骨骼动 | 映射缺失；看 `mapped_bones` / `missing_*` |
| 目标多出骨骼 | 正常；保持 rest，不参与动作 |

## 7. 一键示例

```bash
bash tools/run_example.sh
```

会依次 inspect、retarget、validate，产物在 `examples/soldier_to_michelle/`。
