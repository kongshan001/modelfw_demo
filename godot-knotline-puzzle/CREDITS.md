# CREDITS / 许可

## 项目

**Knotline · 线屿** — 原创 3D 一笔画 + 绕柱打结解谜 vertical slice
2026-11-26 · T-20261126-015 · Godot 4.6 / GL Compatibility

- 代码、关卡、程序化几何、材质、shader、UI、音效、文案、截图与视频均为本项目原创（除下方字体）。
- 项目中没有 Trifolium / EmptyMatter / GT阿某 的角色、场景、UI、关卡、品牌、音频、视频或其它素材。

## 引擎

- **Godot Engine 4.6** — MIT License — https://godotengine.org
- 仅使用引擎内置功能；无第三方运行时库/GDExtension。

## 字体

- **Noto Sans SC Regular**（子集）— Copyright 2014–2021 Adobe (http://www.adobe.com/)，Noto 是 Google 的商标。
- 许可：**SIL Open Font License 1.1**（OFL）。完整许可见 `assets/fonts/OFL-NotoSansSC.txt`。
- 子集：`assets/fonts/NotoSansSC-Knotline.otf`，用 `fontTools` 的 `pyftsubset` 从本地 Noto Sans SC 2.004 生成，仅包含本作 UI/调试/关卡文案所需字形（约 95 KB）。
- 原字体来源：本机系统缓存中的 Noto Sans SC（Camoufox 附带 Noto 字体包）；未从网络下载、未修改字形设计。OFL 允许子集化与随附分发；保留字体名说明于此。
- Godot 的 UI 主题在找不到该文件时会回退到系统字体（PingFang SC / Noto Sans CJK SC 等），以保证可运行。

## 参考 / 研究

- 参考视频：B 站《【解谜游戏】可以打结的一笔画〈Trifolium〉Demo试玩》— UP：GT阿某 — `BV1DDKKzPEHE` / `https://b23.tv/PGfHEPL` — 23:58 — 2026-11-26 查看。
- 研究方式：`yt-dlp` 下载到 `/tmp/trifolium_ref/`，`ffmpeg` 抽帧 0/1/2/3/5/8/12/16/20/23 分钟，观察抽象机制（一笔画、绕柱/穿环、Quick undo、相机、引导不足）。
- **没有**把参考视频、帧、音频、截图、文案或原游戏素材放入仓库；`docs/迭代记录.md` 仅含文字观察。
- 参考游戏 **Trifolium** 由 **EmptyMatter** 开发；本项目与其开发商/发行商无关联，也未复制其品牌/角色/关卡/美术/UI。
- 本项目的名字 **Knotline / 线屿**、关卡名（青柱庭 / 双环庭）、柱名（青柱/珊瑚柱/铃柱/苔柱）、HUD 文案与色板均为原创。

## 工具（开发期，非运行时依赖）

- Godot 4.6（运行/导入/截图/性能探针）
- ffmpeg / ffprobe（视频抽帧、MP4/GIF 编码）
- yt-dlp（仅下载参考视频到 /tmp 研究）
- fontTools / pyftsubset（字体子集）
- Python 3（文档/批处理小工具）
- macOS `sips`（截图尺寸核对）

## 音频

- 所有音效由 `src/knot_sfx.gd` 在运行时用正弦波/包络合成（AudioStreamGenerator），无外部音频素材。
- 视频为无声演示；游戏内音效可在 `M` 键静音。

## 截图 / 视频

- 1920×1080 截图：本项目真实 GPU（Intel HD Graphics 6000，OpenGL 4.1 Compatibility）渲染，SubViewport 1920×1080 + 2×MSAA + 1280×720 UI 布局放大。
- 1280×720 live 性能图：真实窗口截图。
- 10 秒视频：1280×720、30 fps、300 帧固定步长捕获，`ffmpeg` 编码；演示路径由 `tools/demo_paths.gd` 生成。
- 以上媒体均为本项目原创内容，无第三方素材。
