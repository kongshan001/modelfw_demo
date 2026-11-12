# Mixamo → Godot 重定向验证

> 日期：2026-11-10 · 引擎：Godot 4.6 stable（GL Compatibility） · 参考视频：[用 AI 复刻《仙剑奇侠传4》](https://b23.tv/IulfzRm)

## 结论

Godot 原生可行。`RetargetModifier3D` 可以把一套 Mixamo 骨架的动画重定向到另一套 Mixamo 骨架，且保留目标骨架的 rest pose（T-pose），不需要 Unity Humanoid。

直接拷贝 `Animation` 轨道（无论位置+旋转，还是只拷旋转）都会扭曲/塌陷；原因是各角色骨骼的 rest pose 不同，动画轨道存的是局部旋转，不能跨 rest 复用。

## 实测

| 角色 | 骨骼数 | 结果 |
|---|---|---|
| Soldier（源） | 49 | 原生 Idle 1.97s / Walk 1.03s / Run 0.70s 正常 |
| Xbot（目标） | 67 | 静帧看似正常；连续 Idle/Walk 会整体倾斜——rest 轴与源差异大，需 Rest Fixer/BoneMap 统一 |
| Michelle（目标） | 65 | rest=T-pose；连续播放 Soldier Walk 正常，多余骨骼保持 rest |

测试数据来自 Three.js 官方 Mixamo 样例（`Soldier.glb` / `Xbot.glb` / `Michelle.glb`），不是从 Mixamo 现下的。测试脚本：`/tmp/mixamo_verify/verify_rmod.gd`（临时目录，未入库）。

## 最小用法

```gdscript
# 1. 源骨架：正常播动画
source_ap.play("Walk")

# 2. 构建 profile：骨骼名 = 目标骨架的 mixamorig_* 名
var profile := SkeletonProfile.new()
profile.bone_size = target_skel.get_bone_count()
for i in target_skel.get_bone_count():
    profile.set_bone_name(i, target_skel.get_bone_name(i))
    var parent := target_skel.get_bone_parent(i)
    profile.set_bone_parent(i, &"" if parent < 0 else target_skel.get_bone_name(parent))
profile.root_bone = target_skel.get_bone_name(0)
profile.scale_base_bone = "mixamorig_Hips"

# 3. RetargetModifier3D 挂在源 Skeleton3D 下
var modifier := RetargetModifier3D.new()
source_skel.add_child(modifier)
modifier.profile = profile
modifier.set_position_enabled(false)
modifier.set_scale_enabled(false)
modifier.set_rotation_enabled(true)

# 4. 目标 Skeleton3D 必须是 modifier 的直接子节点
target_skel.reparent(modifier, true)

# 5. 网格留在原模型根下，重绑到移动后的 Skeleton3D
for mesh in target_meshes:
    mesh.skeleton = mesh.get_path_to(target_skel)
```

## 关键点

- `profile` 的骨骼名必须同时存在于源和目标骨架。Mixamo→Mixamo 同名（`mixamorig_*`）可直接用；非同名骨架需要 BoneMap/改名/自定义 profile。
- 目标 `Skeleton3D` 必须是 `RetargetModifier3D` 的直接子节点；挂错层级会静默不生效。
- 只开 rotation retarget，避免 position/scale 造成体型扭曲。需要 root motion 时再单独开 position；`use_global_pose=true` 要求骨骼长度完全一致。
- **Xbot 的导出 rest 轴与 Soldier 不同**：同一套 rotation-only 配置下，静帧看似正常，连续 Idle/Walk 会整体倾斜；Michelle 的 rest 轴与 Soldier 匹配，直接正常。生产上先用导入期 Rest Fixer/BoneMap 统一 rest 轴，再开 `RetargetModifier3D`，或为不同 rest 轴单独调 profile。
- 网格重绑是工程上最容易踩的坑：移动 skeleton 后要更新 `MeshInstance3D.skeleton` 路径。
- 生产环境也可走导入期 BoneMap + `SkeletonProfileHumanoid`；运行时 `RetargetModifier3D` 更适合动态混合/换装。

## 录制

- `/tmp/mixamo_gif/godot_retarget.gif`：1280×518，2 秒循环，30 帧 / 15fps；源 Soldier Walk（左）→ Michelle 重定向（右）。
- Xbot 的连续帧验证失败（rest 轴倾斜），未放入 GIF。

## 游戏 Demo

- 已落盘 `godot-mixamo-demo/`：可运行第三人称 demo，源 NPC（Soldier 原生 Idle）+ 玩家（Michelle 重定向），WASD 移动 / Shift 奔跑。
- 运行：`godot --path godot-mixamo-demo`。
- GIF：`godot-mixamo-demo/docs/demo.gif`（1280×720 / 4s / 15fps）与 `demo_960.gif`。
- 冒烟：`godot --headless --path godot-mixamo-demo -s tools/smoke_demo.gd` → `DEMO_SMOKE_OK`。

## 限制

- Mixamo 自动绑定仍需 Adobe ID；Adobe 官方 FAQ 明确**中国大陆国家/地区代码的账号不可用**。本验证只覆盖“已有 Mixamo 骨架 + 动画”的重定向，不覆盖上传 Tripo 模型自动绑定。
- 目标视频的 Unity 链路靠 Humanoid retarget；Godot 链路用本文件的 `RetargetModifier3D` 或导入期 BoneMap，效果等价。
