# Credits / 来源与许可

## 原创内容

- 代码：`godot-sprite-normal-light/` 下的全部 GDScript、shader、场景、工具脚本，
  为本任务（T-20261125-013）为项目原创实现。
- 美术：五张受光精灵（石狐守卫、木桶、苔灵、砖墙、石板地）、光晕、原生光纹理、
  接触阴影和全部法线/高度图，均由 `tools/gen_assets.py`（Python + Pillow，
  deterministic seeds）程序化绘制/生成；没有从教程、原作或素材站复制任何
  角色、贴图、图标、UI 或声音。
- 字体：使用系统字体（PingFang SC / Noto Sans CJK 等）回退，不打包第三方字体。

## 教程/参考

- B 站翻译教程：**《Godot 法线贴图：实现精灵光照效果》**
  链接：<https://www.bilibili.com/video/BV1TJsc61Ewe>（短链 <https://b23.tv/3eSeHcH>）
  UP：**寓学堂**；原作者：**Coding Quests**。
- 仅用于技术路线确认（Aseprite 高度图 → normal map；Godot Sprite2D +
  CanvasTexture(Diffuse/NormalMap) + PointLight2D；With/Without 对比）。
- 参考视频仅下载到 `/tmp` 抽帧分析，未纳入仓库；没有复制其工程、代码、角色
  素材、截图或字幕。本项目的场景、文案、调参与画面均为独立创作。

## 开发工具

- **Godot Engine 4.6**（MIT）— 运行时与截图/性能工具。
- **Python 3.13 + Pillow 12**（Pillow 采用 HPND 许可）— 仅开发期资产生成。
- **ffmpeg / ffprobe** — 仅开发期视频/GIF 编码与抽帧。
- **yt-dlp** — 仅开发期下载参考视频到 `/tmp`，不参与运行时。
- macOS 系统字体 — HUD/视频字幕的中文字形回退。

## 许可说明

本目录的原创代码与美术按仓库整体策略提供；第三方工具按其各自许可证使用。
项目运行时无第三方依赖，不包含任何参考视频/原作素材。

如将来替换为 DirectX 法线图，请把对应 `.import` 的
`process/normal_map_invert_y` 设为 `true`，并重新导入；详见 `docs/TECH.md`。
