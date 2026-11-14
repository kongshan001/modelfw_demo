# 素材与授权

## 素材

| 路径 | 用途 | 骨骼 | 原生动作 |
|---|---|---:|---|
| `assets/source/Soldier.glb` | 源动作 | 49 | Idle / Walk / Run / TPose |
| `assets/target/Michelle.glb` | 目标 | 65 | SambaDance / TPose |
| `assets/samples/Xbot.glb` | 额外测试目标 | 67 | idle / walk / run / agree / headShake / sad_pose / sneak_pose |
| `assets/maps/mixamo.json` | 映射模板 | — | Mixamo 自动映射；自定义骨架填 bones |

骨骼均为 Mixamo 命名（`mixamorig_*`）。Soldier/Michelle/Xbot 来自 Three.js 官方示例：

- https://github.com/mrdoob/three.js/tree/dev/examples/models/gltf

## 授权提醒

- Three.js 示例代码为 MIT；示例模型文件的再分发请以 Three.js 仓库说明为准。
- Mixamo 角色/动画受 Adobe 使用条款约束：拥有 Adobe ID 的用户免费、可免版税商用，但不可未经显著修改原样转售；Mixamo 服务对中国大陆国家/地区代码的账号不可用。
- 本工具包仅用于本地技术验证/团队内部管线；若项目公开或商用，请确认素材授权，或替换为自有/已授权模型。

## 目标骨架要求

- 有 Armature/Skeleton；
- 人形双足、T-pose/中性 rest；
- 骨骼名可映射（Mixamo 或提供 map）；
- 蒙皮权重完整；
- 目标骨骼数可以多于源（多出的保持 rest）。

## 已知限制

- Xbot 的 rest 轴与 Soldier 不同。离线 bake 可用 `--simple` 得到 Blender 内正确的姿态，但 glTF 往返后 Godot 可能翻转骨骼 rest，导致整体倾斜；公开 demo 用运行时 simple 重定向（`godot-mixamo-demo/src/dance_retarget.gd`）。
- 目标多余骨骼（手指末端/脚趾末端）不会被驱动。
- 只搬旋转；肢体比例差异靠目标 rest 保持，不做 IK/脚部接触修正。
- 默认保留 hips 位移（身体前倾/起伏）；`--strip-hips` 可严格置零。
