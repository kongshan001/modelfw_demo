# Credits / 许可与来源

## 本项目

- 代码、网格、材质、程序化贴图、UI 均为本项目原创，由 Godot 4.6 + GDScript/GLSL 生成。
- 无第三方模型、贴图、音频、字体文件或付费资产。
- 中文字体使用系统字体（PingFang SC / Hiragino Sans GB / Noto Sans CJK SC / Microsoft YaHei），不随项目分发字体文件。
- 渲染引擎：Godot Engine 4.6（MIT License，https://godotengine.org）。

## 参考

- **TechFusion（B 站）《风格化海洋第二版》**，BV1AE4u6KEAR，2026，31s，1920×1080。仅作为视觉语言、构图、色阶、泡沫、交互类型的参考。**未复制**视频画面、UP 主或原作者的代码、模型、贴图、音频、UI 或任何素材；项目内截图均为本 demo 在真实 GPU 上的渲染结果。
- 视频中的 “Dynamic Wet Sand / Shoreline Authoring / Stylized Clouds / Animated Fish Schools / Day/Night Lighting / Rain & Water Ripples / Stylized Wild Ocean” 等展示点提供了功能方向；本项目的具体实现、参数、资产与代码均为独立原创。
- 2026-11-26 岸线整改（T-20261126-021）重新抽取了参考视频 0/5/10/15/20/25/30 s 的岸线帧做视觉分析；抽帧与参考文件仅存于 `/tmp/ocean_v2_ref/`，**不进入仓库**，项目内 before/after 截图均为本 demo 自己在真实 GPU 上的渲染结果。

## 许可

- 本项目代码与程序化资产：供本项目展示与内部评审使用；如需对外分发/商用，请先确认团队许可策略。
- 参考视频版权归原作者所有；本仓库不包含参考视频文件或抽帧图片。

## 工具

- Godot 4.6（GL Compatibility）
- yt-dlp / ffmpeg（仅本地参考视频抽帧与媒体编码）
- Python + Pillow（参考帧颜色采样、联系表；不进入运行时）
