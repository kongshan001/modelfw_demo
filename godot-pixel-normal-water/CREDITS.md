# Credits · 静水回廊

## 参考资料（仅技术拆解）

- 《硬核源码拆解｜拒绝塑料贴纸感！单人手搓 Unity 2D 像素法线受光 + 零额外相机水面夜景反射》
  - UP：小武同学贼下饭
  - Bilibili：<https://www.bilibili.com/video/BV1ePyizHED1>（短链 <https://b23.tv/XKbRSNA>）
  - 只用于理解以下技术概念：2D 法线正交拆解、方向光/环境光/细节凹凸、沿脚底锚点
    镜像、单 Mesh 倒影合批、暖色像素保留、`round()` 整格水波。
  - **没有复制**视频帧、Unity 工程、C#/HLSL 源码、场景、角色、UI、音效或任何
    美术资产；本项目场景构图、建筑、树、石头、街灯、水面参数均为独立原创。

## 本项目原创内容

- 全部代码：`scripts/`、`shaders/`、`scenes/`、`tools/`，为本任务新写。
- 全部像素美术 / 法线图 / 粗糙度图 / 自发光遮罩：由
  `scripts/pixel_art.gd` 与 `scripts/pixel_surface.gd` 用固定种子在启动时程序化
  生成；没有外部贴图、字体文件、模型、音频或第三方运行时库。
- 界面文案、演示字幕、说明文档：本项目原创。
- 截图、GIF、MP4 均由本项目自己的工具生成。

## 引擎与构建工具

- Godot Engine 4.6（MIT License）——<https://godotengine.org>
- 视频编码/拼接：ffmpeg（仅构建工具，不在运行时依赖）
- UI 使用系统 CJK 字体回退：PingFang SC / Hiragino Sans GB / STHeiti /
  Noto Sans CJK SC；不随项目分发字体文件。
- Godot Movie Maker 用于录制 10s 演示帧序列（工具链，不参与游戏运行）。

## 第三方运行库

- 无。项目不依赖任何第三方 GDExtension、插件、脚本包或外部服务。

如有引用/分发，请保留本文件与 README 中关于“技术参考、素材原创”的说明。
