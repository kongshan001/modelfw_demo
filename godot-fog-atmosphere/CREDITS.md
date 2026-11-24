# CREDITS · 雾林微光 / Fogwood

## 原创声明

本项目是**原创**的 Godot 大气/雾气技术 demo：

- 产品名：**雾林微光 / Fogwood**（原创）。
- 场景：雾林、地形、树群、石块、石柱拱门、踏石、浅潭、睡莲、芦苇、石灯笼、雾精灵、草叶。
- 代码、程序化网格、程序化噪声/alpha 贴图、天空/水面/草/光束/后处理 shader、HUD 与数值：全部由本项目原创实现。
- **未使用**任何塞尔达/任天堂的角色、场景、模型、贴图、UI、Logo、音乐或视频画面；未使用任何第三方模型/美术包/字体文件。
- 参考视频仅用于**视觉语言研究**（贴地雾团、浮尘、高角度环绕）；参考帧只保存在 /tmp，不随仓库分发。

## 灵感来源（仅视觉研究）

- B 站短视频《时之笛重制版雾气效果惊人》
  - 链接：https://www.bilibili.com/video/BV1j44t6kE2C （短链 https://b23.tv/hnY9Hrl，12.7s）
  - 仅参考其公开画面中的雾/大气观感：低空翻涌白雾、金色浮尘、柔光、缓慢环绕镜头。
  - 不复制其中的角色、场景布局、美术素材、Logo、音乐或任何画面帧。

## 引擎与工具

| 项 | 说明 |
| --- | --- |
| Godot Engine 4.6 stable | MIT License；https://godotengine.org |
| GDScript | 引擎内置 |
| SystemFont（PingFang SC / Hiragino / Noto Sans CJK / 微软雅黑等） | 仅引用操作系统字体，**不随项目分发** |
| FastNoiseLite / Image / SurfaceTool / MultiMesh | Godot 内置；运行时生成地形、雾/粒子/水面所需的噪声与几何 |
| yt-dlp | 仅用于下载参考视频做 /tmp 抽帧分析，**不作为运行时依赖**，视频未入库 |
| ffmpeg | 仅用于把本项目真实 GPU 采集的帧编码为 MP4/GIF，**不作为运行时依赖** |
| macOS 14 / Intel HD Graphics 6000 | 验收机环境 |

## 资产清单

- 3D：`scripts/world_builder.gd` 程序化生成（地形网格、树/石/遗迹/草/踏石/睡莲 MultiMesh、灯笼与精灵基本体）。
- 贴图：`world_builder.gd` 运行时生成的 detail / mist / patch / glow / pool / leaf 噪声纹理，无外部图片。
- Shader：`shaders/*.gdshader`（sky / water / grass / beam / post_fx）。
- UI：`scripts/hud.gd` 纯 Control + OS SystemFont。
- 截图/GIF/MP4：本项目真实 GPU 运行产生（截图 1920×1080 SubViewport；视频 1280×720@30fps）。

## 许可

- 本项目代码与程序化美术为原创作品；对外许可由项目所有者决定。
- 仓库不附带第三方运行库或资产。
- 若再分发，请保留本文件与 README/TECH 中的原创与灵感来源说明。
- 不得将本项目的名称/素材与参考视频的原作者品牌或游戏名混淆。
