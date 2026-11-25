# CREDITS · 苔光浮庭 / Mosslight Isle

## 原创内容

- 项目代码、GDScript 逻辑、程序化网格、shader、程序化贴图/噪声、UI 布局、交互设计、程序化音效：本项目原创实现，2026-11-25。
- 场景物件：浮空苔岛、月树、茶亭、砂径、池塘、苔灯、风铃、苔猫、锦鲤、花海、萤火/雨/雾等，均为程序化生成或在本仓库内用代码建模，**不复制参考视频的场景/物件/角色/UI**。
- 运行环境字体为系统字体（PingFang SC / Hiragino / STHeiti / Noto Sans CJK 等回退链），未打包或分发字体文件。
- 截图/视频由本项目的 Godot 场景真实渲染，ffmpeg 仅用于编码，不引入外部画面素材。

## 参考

- 任务参考视频：《有人用 ai 搞的一个游戏 feralui 的场景，感觉非常不错，转发分享下》，Bilibili BV1aCyozLErR / 短链 https://b23.tv/towtE2d，UP 主 `eddieliugd`，来源 X `@SolutionB2u`，2026-11-25 访问。
- 参考仅用于研究 3D 3/4 浮岛、冷/暖光、微动画节奏与界面结构的**视觉语言**；mp4/抽帧只存在于 `/tmp`，未入库；项目中没有使用其任何模型、贴图、音乐、角色、Logo、UI 或品牌。
- 未使用任何第三方运行时库。Godot Engine 4.6 stable（MIT）作为引擎；ffmpeg 用于本地媒体编码。

## 资产许可

本仓库内的程序化场景资产为本次任务原创。若需复用，请同时保留本 CREDITS 与参考视频“仅视觉语言参考、非素材来源”的说明，避免将本作误标为 feralui 或原作者作品。

## 工具链

- Godot 4.6 stable / GL Compatibility / OpenGL 4.1。
- `yt-dlp`、`ffmpeg`/`ffprobe` 仅在本机对参考与输出媒体做转码/编码。
- macOS 系统字体（未随项目分发）。
