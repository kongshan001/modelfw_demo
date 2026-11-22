# Credits / 素材与许可

## 原创声明

- 本工程全部 GDScript、场景、UI 布局、程序化瓦片、道具、地形过渡、树/岩石/建筑图形、hillshade、水色、海岸泡沫、背景、调试叠加、地图 chrome、截图与视频，均由本项目代码/工具在本地生成。
- 没有外部贴图、模型、音频、字体文件或第三方运行时库；`scripts/tile_art.gd` 负责所有像素图形，`scripts/ui_theme.gd` 使用系统 CJK 字体（`SystemFont`）。
- 没有复制任何商业游戏的截图、瓦片、UI、地图布局、音乐或品牌；没有把参考案例的画面放进仓库。
- 本工程与下列参考资料的作者/发行商无隶属关系。

## 算法与公开资料参考

只参考公开的算法描述与调研结论，代码按描述独立实现：

- 仓库调研：[`docs/godot-procgen-survey.md`](../docs/godot-procgen-survey.md)、[交互版](../docs/godot-procgen-survey-交互版.html)、[`docs/procedural-generation-teardown.md`](../docs/procedural-generation-teardown.md)；
- 二叉空间分割（BSP）地牢、最近邻/Kruskal 连接、BFS 连通验证、A* 验证：公开的 Rogue 关卡生成实践；本工程代码原创；
- FastNoiseLite / Simplex / Perlin / FBM：Godot 4.6 内置噪声；
- Bridson Poisson Disk 采样：公开算法，按论文/公开描述的思路独立实现；
- FNV-1a 32-bit 签名、PCG32（通过 `RandomNumberGenerator`）：公开算法/引擎 API；
- Godot 4.6 文档：`TileMapLayer`、`TileSetAtlasSource`、`FastNoiseLite`、`AStarGrid2D`、`Camera2D`、`SubViewport`、`Image`/`ImageTexture`、`CanvasItem` 绘制；
- 参考案例（Dome Keeper / Lumencraft / Cassette Beasts / Brotato / Caves of Qud / Bad North / Townscaper 等）只用于理解“程序化地图 + 美术/反馈”的产品思路；**没有**复制素材、算法代码或关卡。

## 没有使用的资产

- 没有使用 Kenney/CC0 外部瓦片或模型（全部为原创程序化图形）。
- 没有使用 mxgmn WFC 的 `samples/*.png`，没有引入 WFC 插件代码。
- 没有使用任何商业游戏截图、UI、图标、音频或商标。
- 没有引入 `godot_voxel`、Terrain3D 或其他 GDExtension/第三方运行时依赖。

## 工具

- Godot Engine 4.6（MIT License）——引擎本身不随工程分发。
- ffmpeg 8.0.1——仅离线把 300 帧 PNG 编码为 MP4/GIF，不是运行时依赖。
- 系统中文字体（macOS PingFang SC / Hiragino Sans GB 等）由 `SystemFont` 引用，不随工程分发；Linux 需安装 Noto CJK 等字体。
- 截图/视频使用 Godot 的 `SubViewport` + `Image.save_png`，无外部录屏软件。

## 媒体生成

- `docs/shots/01..07_*.png`：`tools/screenshot_proc_map.gd` 在 1920×1080 SubViewport 中实拍，GPU：Intel HD Graphics 6000 / GL Compatibility。
- `docs/proc_map_demo.mp4` / `.gif`：`tools/render_proc_map_video.gd` 固定 30fps 抓取 300 帧（10.000s），`ffmpeg` 编码；GIF 为 960×540/15fps。
- 截图/视频中的 `FPS · 录制` 是 capture mode 标记；真实帧率由 `tools/probe_proc_map.gd` 测量，见 README/TECH。

## 使用与再分发

本工程用于学习、算法演示与作品集展示。若要复用代码，请保留本 CREDITS、README 中的原创声明，并自行确认 Godot/ffmpeg 的许可证要求。程序化生成的瓦片/地图可以自由用于学习项目；不要把本工程描述成任何商业游戏的官方复刻或附属作品。
