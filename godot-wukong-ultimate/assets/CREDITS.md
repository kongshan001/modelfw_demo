# Credits / 原创声明

## 本项目原创内容

以下内容均为本项目（T-20261119-008）原创，未复制任何第三方版权角色、模型、贴图、UI 或文案：

- **角色设计**：「齐天大圣 · 极意」——银白后掠尖发、银蓝斗气体、赤膊肌肉躯干、破损橙裤、蓝腰带/护腕/靴、金色头箍、猴脸、尾巴、背棍；以及蓝色眼纹、耳饰等细节。
- **Blender 资产**：`blender-wukong-ultimate/` 下所有网格、贴图、材质、骨架、蒙皮权重、动画、渲染图。
- **Godot 工程**：`godot-wukong-ultimate/` 下所有 GDScript、场景、Shader、HUD 绘制、VFX、程序化场地、工具脚本。
- **Godot 截图/GIF/MP4**：由本项目真实运行产生。

## 首版对比素材

`assets/legacy/wukong_first.glb` 是同一作者/同一系列的首版 chibi 角色（原工程 `blender-wukong/`），仅用于 `docs/shots/06_before_after.png` 的 before/after 对比。首版资产同样是原创的，不是第三方素材。

## 灵感与边界

- 角色名与金箍棒、猴王等元素来自**公有领域**的中国古典小说《西游记》。
- “银色头发 / 爆气 / 放波”属于通用动漫视觉语汇。本角色**没有**复制《龙珠》悟空或其他任何具体版权角色的脸、发型轮廓、服装、标志、UI、台词；没有使用《龙珠》相关素材。
- 未使用 Slotbound 或其他商业游戏的素材/UI/文案。

## 工具与运行时

- **Godot Engine 4.6**（MIT License）— 游戏引擎。项目不包含 Godot 的二进制，只包含使用 Godot 制作的内容。
- **Blender 3.4.1**（GNU GPL 工具）— 用于程序化生成与渲染资产；导出内容为原创数据。
- **ffmpeg**（LGPL/GPL 工具）— 仅用于把 PNG 序列编码为 MP4/GIF，不构成运行时依赖。
- **Python + Pillow**（工具）— 仅用于生成本次 before/after 排版图。
- **中文字体**：HUD/标签通过 Godot `SystemFont` 引用系统字体（PingFang SC / Hiragino Sans GB / Noto Sans CJK SC / Microsoft YaHei 等）；仓库不重分发任何字体文件。数字/英文 HUD 使用引擎默认字体。
- **无第三方运行时库**：Godot 工程不依赖任何插件或 GDExtension。

## 许可

本仓库中由本项目创作的角色、资产、代码与截图用于该任务交付与展示；未声明使用任何第三方版权素材。若需对外单独授权/商用，请与作者确认。
