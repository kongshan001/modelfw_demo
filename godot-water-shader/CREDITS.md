# CREDITS

## 本项目原创内容

- 代码：`scripts/*.gd`、`shaders/water_surface.gdshader`、`tools/*`、`scenes/main.tscn`、`project.godot`
- 像素场景与水面数据：由 `scripts/pixel_art.gd` 以固定种子 `20261126` 程序化绘制
  - 海湾、沙滩、水下鹅卵石/海草、河流、木桥、内陆湖、小屋、松树、红枫、石灯笼、栅栏、花丛、低洼积水
  - 无外部图片、贴图或字体文件
- HUD 中文：Godot `SystemFont`（PingFang SC / Hiragino Sans GB / Noto Sans CJK SC 等系统回退），不随项目分发字体
- 本项目由 T-20261126-001 的 Game Engineer worker 于 2026-11-26 完成

## 技术参考

- **《2D游戏海河湖共用1个水面Shader？零额外网格源码拆解》**
  - UP：小武同学贼下饭
  - B 站：https://www.bilibili.com/video/BV1SxykzhELX
  - 短链：https://b23.tv/KYEA6ng
  - 用途：理解“16px 离线抠图 / 2-Pass 8 邻域 depth / 零分配 BFS 分类 / Voronoi 焦散 / 双波前白沫 / 桥面裁切 / 雨积水复用”的算法思路与视觉语言。
  - **未复制**其 Unity/C# 源码、贴图、像素场景或视频画面。参考视频仅下载到 `/tmp/water_ref/` 抽帧分析，未进入仓库。

## 引擎与工具

- Godot Engine 4.6 stable（GL Compatibility）
- 截图 / 视频：Godot 离屏 SubViewport + FFmpeg
- 文字：系统 CJK 字体，经 Godot `SystemFont` 调用

## 第三方依赖

- 无第三方运行时库。
- 项目内不含来自 Sketchfab / Poly Haven / KayKit 等外部资产库的模型或贴图。

## 使用与 License

本目录的代码与程序化美术为本次任务原创产出，按仓库既有约定使用；若需对外再分发，请同时保留本 CREDITS 与参考视频链接。
