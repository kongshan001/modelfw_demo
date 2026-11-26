# CREDITS · 群铸 / Swarmforge

## 项目原创声明

- 代码、卡牌/单位名称、数值、UI 布局、卡面图形、六角徽记、背景装饰、配色、文案、阵容码格式、AI 名称均为本项目原创，未复制任何参考游戏/视频的素材、UI、角色、卡牌、关卡、音效或品牌。
- 不含 Hearthstone / Blizzard / 《全军出鸡：鸡械绿洲自走棋》的角色、卡牌、UI、美术、音效、文案、关卡或商标。
- 项目不依赖第三方运行时库；除 OFL 字体外，没有外部图片、音频或模型文件被打包进仓库。
- 单位/卡牌/环境/VFX/图标/key art 全部由本仓库的 `tools/art_gen/`（Pillow + numpy）程序化生成；生成参数、种子、尺寸与偏差见 `assets/art/PROVENANCE.md`。
- 没有使用任何参考游戏的截图、角色、卡面、UI 或 logo 作为输入/描摹；没有使用 AI 图像生成 API。

## 引擎

- **Godot Engine 4.6 stable (official)** — MIT License — https://godotengine.org
- 渲染：GL Compatibility（OpenGL 4.1），Intel HD Graphics 6000 上验收。

## 美术资产（T-20261126-026）

- `assets/art/units/unit_atlas_10x12_768x640.png` — 10 卡 × 12 帧，64px；程序化（`gen_units.py` + `artlib.py`）。
- `assets/art/cards/card_atlas_1024x768.png` + `assets/art/cards/src/*.png` — 10 张原创 512px 插画/256px atlas（`gen_cards.py`）。
- `assets/art/env/arena_1800x570.png`、`flag_ally_96x192.png`、`flag_enemy_96x192.png`、`fog_0/1.png` — 程序化（`gen_env.py`）。
- `assets/art/vfx/vfx_atlas_96x192.png` — 6 类 × 3 帧（`gen_vfx.py`）。
- `assets/art/ui/icons_20.png` — 17 个 20px 线性图标（`gen_ui.py`）。
- `assets/art/keyart/victory_1920x1080.png` — 终局 key art（`gen_keyart.py`）。
- 以上均为本项目原创，许可证随项目；不含第三方 IP。

## 字体

- **Noto Sans SC**（Google Fonts）— SIL Open Font License 1.1，© The Noto Project Authors。项目内为 wght 400/700 静态实例 + 740 字形子集：`assets/fonts/NotoSansSC-Regular-subset.otf`、`NotoSansSC-Bold-subset.otf`（各约 244KB）。许可证：`assets/fonts/OFL-NotoSansSC.txt`。
- **Oxanium**（Google Fonts）— SIL Open Font License 1.1，© The Oxanium Project Authors。项目内为 wght 600 静态实例：`assets/fonts/Oxanium-SemiBold.ttf`（28KB），用于数字/HUD。许可证：`assets/fonts/OFL-Oxanium.txt`。
- 子集外/缺失的 CJK 字形通过 Godot `FontFile.allow_system_fallback` 回退到系统字体（PingFang SC / Noto Sans CJK SC 等）；新增中文文案需重新子集化（`tools/art_gen/README.md`）。

## 参考研究（仅机制，不含素材）

- 参考视频：B 站 **BV1EssS6iEux**《酒馆战旗，但场上单位数量×100倍……》，UP 独立游戏蜥蜴君，27:06，1920×1080，2026 发布。
- 视频中的游戏：《全军出鸡：鸡械绿洲自走棋》demo（Steam app 4128840）。本任务只提取抽象机制：5 卡商店、升本、三合一金卡、高星核心、编队数量膨胀、风险/收益波次、阵容复制与镜像。
- 因 B 站网页/CDN 网络限制（SSL EOF / CDN 超时），`yt-dlp` 完整下载失败；机制参考使用了 B 站官方播放器 storyboard API 的低分辨率雪碧图，仅在 `/tmp` 中临时裁切查看，未放入项目、未用于贴图/描摹。
- 参考作品名称仅用于说明研究来源；本作未使用其品牌、角色或视觉语言。

## 工具 / 验证

- Godot 4.6 headless/GUI：逻辑自测、真实 GPU 截图/性能/录像/节点统计。
- Python 3.13 + Pillow 12.2、numpy：程序化美术生成；`fontTools` 4.69：字体实例化/子集化。
- `ffmpeg` 8.0：将 `tools/video_swarm.gd` 采集的 150 帧真实 gameplay（1920×1080/15fps）编码为 10s MP4 与 960×540/10fps GIF。
- macOS Intel HD 6000、`RenderingServer.get_video_adapter_name()` 记录的真实 GPU 环境。
- `yt-dlp` 2026.08.19、`curl`、Bilibili 公开 API（view/playurl/videoshot）：参考研究；未下载到完整视频，参考帧仅在 `/tmp`。
- 飞书 `cc-connect send`：最终发送截图/视频附件。

## 第三方资产

仅字体：Noto Sans SC、Oxanium（均为 OFL 1.1，许可证随包）。项目不包含 KayKit、Mixamo、Poly Haven 或任何 CC0/商业模型/图片；所有游戏图片由本仓库程序化生成。
