# CREDITS / 许可

## 项目

**Foldpath · 折径** — 原创等轴“不可能几何”折纸解谜 vertical slice
2026-11-26 · T-20261126-016 · Godot 4.6 / GL Compatibility

- 代码、关卡 JSON、程序化几何、材质、shader、关卡布局、角色“小折狐”、UI、文案、截图、GIF 与视频均为本项目原创。
- 项目中没有 Monument Valley / ustwo 的关卡、角色（Ida）、建筑、神圣图案、配色、音乐、UI、品牌或其它素材；也没有把参考视频、帧、音频放入仓库。
- 项目中没有第三方运行时依赖/GDExtension；所有几何与 UI 在运行时由 Godot 内置图元构建。

## 引擎

- **Godot Engine 4.6 stable** — MIT License — https://godotengine.org
- 仅使用引擎内置功能。渲染器：GL Compatibility（OpenGL 4.1）。

## 字体

- 未随仓库分发任何字体文件。
- 中文 HUD 使用 Godot `SystemFont`，按顺序尝试：
  PingFang SC、Hiragino Sans GB、Noto Sans CJK SC、Noto Sans SC、Microsoft YaHei、Source Han Sans SC。
- 本机实际由 macOS 系统字体渲染；若系统无 CJK 字体，Godot 会回退到自身默认字体。
- 字体版权归各系统字体权利方所有；本项目不重新分发字体。

## 参考 / 研究

- 参考视频：B 站《这是解谜游戏史上最富有想象力的关卡之一》
  UP：**A宝OVO_** · `BV1o9pQz2EWm` · 短链 `https://b23.tv/dM7vHb6` · 4:47 · 2026-11-26 查看。
- 研究方式：`yt-dlp` 下载到 `/tmp/monument_ref`（本机取 1080p rendition），`ffmpeg` 抽帧
  t=0/20/40/60/90/120/150/180/210/240/270 s，观察相机构图、旋转/拖动交互、屏幕空间连通、点击行走与过关条件。
- 仅抽象机制研究；**没有**复制视频、游戏画面、UI、建筑、角色、关卡布局、音频或任何品牌元素。
- 参考游戏 **Monument Valley** 由 **ustwo games** 开发；本项目与其开发商/发行商无关联，未获其背书，也未复制其素材。
- 本项目名称 **Foldpath / 折径**、关卡名（纸阶 / 旋桥庭 / 环折塔）、角色“小折狐”、色板（奶油纸 / 苔绿 / 陶土 / 黄铜）、几何、HUD 文案与关卡解法均为原创。

## 工具（开发期，非运行时依赖）

- Godot 4.6（运行 / 导入 / 截图 / 视频帧 / 性能探针）
- yt-dlp（仅将参考视频下载到 /tmp 研究）
- ffmpeg / ffprobe（抽帧、MP4/GIF 编码、尺寸/时长核对）
- Python 3（关卡坐标生成与文档批处理）
- macOS `sips`（截图尺寸核对）
- OpenGL API 4.1 Intel（Intel HD Graphics 6000）真实 GPU 验证

## 素材清单

- 1920×1080 PNG × 7（`docs/shots/01…07`）+ 1280×720 实窗调试 PNG × 1（`08_live_1280.png`）
- 10 秒 1280×720 MP4/GIF（`docs/shots/foldpath_demo_10s.*`）
- 上述媒体均由本项目在真实 GPU 上渲染、录制；不含参考视频内容。
