# Credits · 雨落青苔

## 参考资料（只做技术拆解）

- 《unity中怎么做出雨天积水？我教你！》
  - UP：小武同学贼下饭
  - Bilibili：<https://www.bilibili.com/video/BV11DyDzjE7c>
  - 仅用于理解 2D 雨丝/积水/涟漪/倒影/1×1 灯柱规则的技术思路。
  - **没有复制**视频帧、Unity 工程、C#/HLSL 代码、角色/场景/UI/音效或任何
    美术资产；原作中的具体场景/构图也没有逐像素照搬。

## 本项目原创内容

- 所有代码：`scripts/`、`shaders/`、`tools/`，为本任务新写。
- 所有像素美术：由 `scripts/pixel_art.gd` 用固定随机种子在启动时程序化生成
  （黄昏草地、红枫、松树、木灯柱、灯笼、蕨叶、石头、双环贴图、倒影图集）。
- 没有外部贴图、字体文件、音频、模型或第三方运行时库。
- 截图与演示视频由本项目的工具生成。

## 引擎与系统字体

- Godot Engine 4.6（MIT License）——<https://godotengine.org>
- UI 使用系统 CJK 字体回退：PingFang SC / Hiragino Sans GB /
  STHeiti / Noto Sans CJK SC；不随项目分发字体文件。

## 相关第三方

- 渲染：Godot GL Compatibility（OpenGL 4.1 / Intel HD Graphics 6000 实测）。
- 视频编码：ffmpeg（仅构建工具，不在运行时依赖）。
- 参考视频封面/标题归原作者所有，本项目未使用其任何素材。

如有后续引用/分发，请保留此文件与 README 中的“技术参考、素材原创”说明。
