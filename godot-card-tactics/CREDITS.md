# Credits · 来源与许可

## 美术 / 2D 图集

- 仓库：[t73liu/open-duelyst-assets](https://github.com/t73liu/open-duelyst-assets)
- 上游：[open-duelyst/duelyst](https://github.com/open-duelyst/duelyst)（CC0-1.0）
- 使用 commit：`9fd0a16b611be8c9b991806ec5a6f602aa981823`（2024-12-26）
- 许可：**CC0 1.0 Universal**。全文见 [`assets/duelyst_cc0/LICENSE`](assets/duelyst_cc0/LICENSE)。
- 原始作品：Duelyst（Counterplay Games，2016）。2022 年以 CC0 1.0 公开代码与美术。
- 本项目只取用 60 个源文件（约 1.1MB）的图集/帧 JSON/卡框/图标/高亮 tile/FX，完整清单与抽取方式见 [`assets/duelyst_cc0/SOURCE.md`](assets/duelyst_cc0/SOURCE.md)。
- 改动：运行时按 JSON 帧裁切成 `AtlasTexture`、在 UI 中缩放/着色；未改动原始 PNG/JSON 文件内容。

### 商标说明

“Duelyst”名称、Logo 与相关品牌标识**不在 CC0 许可范围内**，其权利仍归 Counterplay Games。本项目：

- 游戏名使用原创中文名《格间牌战》/英文代号 Gridbound；
- 不使用 Duelyst 名称/Logo 作为品牌；
- 不使用 Duelyst II / Steam 版本素材；
- 文档中提及 Duelyst 仅用于说明玩法灵感来源与资产出处。

## 代码 / UI

- 全部 GDScript、场景、UI 布局、配色、中文文案：本项目原创（T-20261121-013 worker）。
- 未复制 `open-duelyst/duelyst` 的 CoffeeScript/JS 代码；规则按公开玩法描述独立实现。
- 未使用第三方运行时库；Godot 标准库 + 项目内 JSON/PNG 资源。

## 工具链（不随项目分发）

- [Godot Engine 4.6](https://godotengine.org/) — MIT License。
- [ffmpeg](https://ffmpeg.org/) — 仅用于把录制 AVI 转成 MP4/GIF；不参与运行时。
- 中文 UI 使用操作系统 CJK 字体（PingFang SC / Hiragino Sans GB / Heiti SC / Noto Sans CJK SC / Microsoft YaHei 等），**字体文件未复制进项目**。
- macOS / Intel HD Graphics 6000 用于本机性能与截图验证。
