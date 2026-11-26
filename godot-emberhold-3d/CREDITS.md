# 余烬堡 3D · Emberhold 3D — Credits / 许可

- 任务：T-20261126-029（T-20261126-022 的 follow-up）
- 日期：2026-11-26
- 作者：Game Engineer worker（程序化几何、GDScript、渲染、QA）

## 原创内容

- `scripts/`、`scenes/`、`shaders/`、`materials/`、`tools/` 下全部代码与程序化 3D 几何为本任务原创。
- 4 种塔、5 种敌人、两张地图、出生门、终点灯塔、道具、UI 图标、HUD 布局、VFX、抖动过渡均为原创。
- 没有使用任何第三方模型、贴图、音频、字体文件或运行时库。
- 中文字体通过 Godot `SystemFont` 调用操作系统字体（PingFang SC / Microsoft YaHei / Noto Sans CJK 等），**不随项目分发字体文件**。
- 参考 HTML 版 `web-html-tower-defense/` 由 T-20261126-022 原创；本项目复用其玩法规则/数值/AI 逻辑，并保留原项目不改。

## 引擎

- **Godot Engine 4.6**（MIT License），GL Compatibility 渲染器。
- 使用 Godot 内置的 `SubViewport`、`DirectionalLight3D`、`WorldEnvironment`、`CPUParticles3D`、`Label3D`、`Sprite3D` 等能力；无插件。

## 概念参考

- 《Cinderwatch》（MIT，https://github.com/kevintngo/cinderwatch）仅在 T-20261126-022 中作为“单文件、零外部资源、AI 托管”的体验对照；本 3D 移植未下载、未复制其代码、模型、贴图、名称或文本。
- 本项目的名称、世界观（余烬灯塔/灰烬小径/冻苔回廊）、数值和界面文案均沿用本线程的原创设定。

## 验证工具

- Godot headless / real-GPU 运行、MovieWriter、ffmpeg（MP4/GIF 编码）。
- Python 仅用于辅助统计/文件检查，不在运行时依赖中。

## 资产替换

`materials/*.tres`、`scenes/*_view.tscn`、`scripts/*_view.gd` 是给后续美术 pass（T-030）准备的替换入口；替换时请保持场景根节点类型、公开方法（`setup` / `set_level` / `sync` 等）和 3D 几何约束，避免引入 2D billboard 冒充模型。
