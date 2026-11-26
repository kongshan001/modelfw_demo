# CREDITS · 群铸 / Swarmforge

## 项目原创声明

- 代码、卡牌/单位名称、数值、UI 布局、卡面图形、六角徽记、背景装饰、配色、文案、阵容码格式、AI 名称均为本项目原创，未复制任何参考游戏/视频的素材、UI、角色、卡牌、关卡、音效或品牌。
- 不含 Hearthstone / Blizzard / 《全军出鸡：鸡械绿洲自走棋》的角色、卡牌、UI、美术、音效、文案、关卡或商标。
- 项目不依赖第三方运行时库；没有外部图片、音频、字体文件被打包进仓库（运行期中文来自操作系统字体）。
- 工程内的静态资源仅 `icon.svg`（本任务手绘的六角图标）。

## 引擎

- **Godot Engine 4.6 stable (official)** — MIT License — https://godotengine.org
- 渲染：GL Compatibility（OpenGL 4.1），Intel HD Graphics 6000 上验收。

## 字体

- 运行时使用 `SystemFont` 读取操作系统字体（PingFang SC / Hiragino Sans GB / Noto Sans CJK SC / Microsoft YaHei 等）。
- 字库不随项目分发；在没有这些系统字体的平台上 Godot 会回退到系统默认字体。

## 参考研究（仅机制，不含素材）

- 参考视频：B 站 **BV1EssS6iEux**《酒馆战旗，但场上单位数量×100倍……》，UP 独立游戏蜥蜴君，27:06，1920×1080，2026 发布。
- 视频中的游戏：《全军出鸡：鸡械绿洲自走棋》demo（Steam app 4128840）。本任务只提取抽象机制：5 卡商店、升本、三合一金卡、高星核心、编队数量膨胀、风险/收益波次、阵容复制与镜像。
- 因 B 站网页/CDN 网络限制（SSL EOF / CDN 超时），`yt-dlp` 完整下载失败；机制参考使用了 B 站官方播放器 storyboard API 的低分辨率雪碧图，仅在 `/tmp` 中临时裁切查看，未放入项目、未用于贴图/描摹。
- 参考作品名称仅用于说明研究来源；本作未使用其品牌、角色或视觉语言。

## 工具 / 验证

- Godot 4.6 headless：逻辑自测、真实 GPU 截图/性能/录像。
- `yt-dlp` 2026.08.19、`curl`、Bilibili 公开 API（view/playurl/videoshot）：参考研究；未下载到完整视频。
- Python 3.13 + Pillow：从 storyboard 雪碧图裁切研究帧（未入库）。
- `ffmpeg`：将 7 张真实 GPU 截图做 10 秒 Ken Burns 剪影并编码 MP4/GIF；另有 720p/15fps 实时帧采集工具，因共享主机高负载未完成。
- macOS Intel HD 6000、`RenderingServer.get_video_adapter_name()` 记录的真实 GPU 环境。
- 飞书 `cc-connect send`：最终发送截图/视频附件。

## 第三方资产

无。项目不包含 KayKit、Mixamo、Poly Haven 或任何 CC0/商业模型；单位/图标/背景全部由代码绘制。
