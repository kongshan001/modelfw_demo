# CREDITS · 暮色回廊 / Dusk Cloister

## 原创内容

本项目为 **原创** 3D 低模像素废墟花园 vertical slice：

- 场景布局、石路、残拱、断柱、水池、树木、草叶、路灯、长椅、石狐雕像：全部由 `scripts/garden_world.gd` 程序化生成。
- 角色「苔灯」（宽檐草帽、墨绿披风、锈橙围巾、铜灯笼手杖）：由 `scripts/keeper.gd` 用低模图元程序化搭建，脚本驱动 idle/行走。
- 所有材质/天空/水/光柱/后期 shader：`shaders/` 下原创 GLSL。
- 中文 HUD、时间滑杆、预设、开关、统计：`scripts/hud.gd` 原创。
- 截图/视频/自检图：本项目在真实 GPU 上渲染/录制；标题叠层与 contact sheet 由本项目脚本/PIL 生成。

**没有使用任何外部模型、贴图、音乐、音效、字体文件、付费素材或 Tripo/Blender 资产。**

## 参考（仅视觉语言与技术方向）

- 视频：B 站 **BV1sEpE6pEWK**《【Godot场景展示】傍晚的废墟花园，路灯和萤火是怎么一点点亮起来的？》
- UP：**timbercyke**；时长 346s；简介提到 Godot 实时像素风花园、小女孩行走、黄昏→深夜、路灯/萤火渐亮、水面/云影/光束、像素偏移补偿、风格化草叶、体积光、丁达尔。
- 使用方式：确认技术方向与视觉目标；**未下载/抽取/复用**其画面、模型、贴图、角色、UI 或品牌；未复制其花园布局或角色造型。
- 本项目角色刻意区分：不是红裙金发小女孩，而是原创提灯守园学徒；场景为圆形水池 + 断拱 + 石狐雕像的原创布局。

## 引擎与工具

| 名称 | 用途 | 许可/说明 |
| --- | --- | --- |
| Godot Engine 4.6 stable | 引擎/渲染/输入/UI | MIT；GL Compatibility |
| Godot Movie Maker | 10.4s AVI 录制 | 引擎内置 |
| ffmpeg 8.0.1 | AVI → H.264 MP4 / GIF / 抽帧 | 系统安装 |
| Python Pillow (PIL) | 标题叠层、contact sheet、25%/4×/剪影整理 | 系统安装 |
| macOS PingFang SC | HUD 中文字体（SystemFont） | 系统字体，不随项目分发；其他系统回退 Noto/DejaVu |
| Intel HD Graphics 6000 | 真实 GPU 截图/FPS | Apple OpenGL 4.1 Compatibility |

## 证据

- `docs/shots/00_contact_sheet_1920.png` … `15_character_4x.png`
- `docs/media/dusk_cloister.mp4`（10.43s，1280×720，H.264）
- `docs/media/dusk_cloister.gif`（10.43s，480×270，12fps）
- `docs/media/title_overlay.png`（标题叠层源图，PIL 生成）

## 许可

项目代码与程序化资产为本次任务原创，随仓库交付。仓库未声明单独的开源许可证；如需对外复用/再分发，请先确认仓库 owner 的授权。参考视频及 B 站相关内容的版权归原作者所有，本项目仅引用链接与技术方向，不包含其素材。
