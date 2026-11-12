# Character assets

这几个 GLB 来自 Three.js 官方示例，作为 Mixamo 骨骼/动画的技术验证素材：

- `Soldier.glb`：https://github.com/mrdoob/three.js/blob/dev/examples/models/gltf/Soldier.glb
- `Michelle.glb`：https://github.com/mrdoob/three.js/blob/dev/examples/models/gltf/Michelle.glb
- `Xbot.glb`：https://github.com/mrdoob/three.js/blob/dev/examples/models/gltf/Xbot.glb

骨骼均为 Mixamo 命名（`mixamorig_*`），原生动作包含：

- Soldier：Idle / Walk / Run / TPose
- Michelle：SambaDance / TPose
- Xbot：idle / walk / run / agree / headShake / sad_pose / sneak_pose（67 骨骼）

## 授权提醒

- Three.js 示例代码为 MIT；示例模型文件的再分发请以 Three.js 仓库说明为准。
- Mixamo 角色/动画受 Adobe 使用条款约束：对拥有 Adobe ID 的用户免费、可免版税商用，但不可未经显著修改原样转售；Mixamo 服务对中国大陆国家/地区代码的账号不可用。
- 本项目仅用于本地技术验证，不将模型作为独立资产再分发。

> Xbot 在 swap demo 中使用原生动画；它的 rest 轴与 Soldier 不同，不要直接拿 Soldier 的 Animation 轨道硬套 Xbot。
