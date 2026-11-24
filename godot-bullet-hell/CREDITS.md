# Credits / 许可与来源

## 原创内容

- 代码、程序化图形、角色与 Boss 设计、UI、弹幕形态与配色：为本任务原创，2026-11-24。
  - 玩家机“萤舟” / Boss“辉庭守望者 · 环” / 项目名“绯星弹幕 · Scarlet Orbit”均为原创名称与设计，不对应任何现有 IP。
- 工程不使用任何外部图片、模型、音频或字体文件；所有视觉由 GDScript 绘图与 GLSL shader 在运行时生成。
- 无背景音乐/音效（本版未实现音频）。

## 教程参考（仅研究引用）

- 标题：**《Godot 弹幕怎么做？从一颗子弹到 10 种弹幕》**
- UP 主：**还没醒er**
- 链接：<https://www.bilibili.com/video/BV1B4yRzEE9x>（短链 <https://b23.tv/iCKBB0L>）
- 用途：研究“方向 / 速度 / 行为”拆解、扇形/环形/螺旋/花瓣/追踪/分裂/时间轴的节奏与数学思路。
- 边界：参考视频仅临时下载到 `/tmp/bullet_ref/` 用于抽帧审阅，**没有**把视频、帧、教程代码、角色、UI、音乐或任何素材复制进本仓库。实现参数全部重新调校，视觉为本项目独立设计。
- 本项目与视频作者无隶属或背书关系。

## 引擎与运行环境

- **Godot Engine 4.6 stable** — MIT License，<https://godotengine.org/license>。
- 渲染：GL Compatibility（OpenGL 4.1），无第三方插件或运行时依赖。
- 操作系统验证：macOS，Intel HD Graphics 6000。

## 字体

- 中文 UI 使用 Godot `SystemFont`，按以下顺序回退：
  `PingFang SC`、`Hiragino Sans GB`、`Microsoft YaHei`、`Noto Sans CJK SC`、`Source Han Sans SC`、`WenQuanYi Micro Hei`、`sans-serif`。
- 字体文件**不随本仓库分发**，运行时读取用户操作系统已有字体。
- 若需在缺少 CJK 字体的环境分发，请自行引入 SIL OFL 字体（例如 Noto Sans SC）并保留其许可证；届时更新本文件。

## 第三方资产

- 无。`assets/` 目录不存在；无 CC0/商业素材混入。
- 无东方 Project 或其他同人/商业 IP 的角色、弹幕贴图、UI 或音乐。

## 工具链

- `yt-dlp` / `ffmpeg` 仅用于研究视频抽帧与成片编码，不作为运行时依赖，其输出不包含参考视频素材。
- 性能与截图工具均在本项目 `tools/`，原创。
