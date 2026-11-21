# Credits / 素材来源（canonical）

> 本文件是素材来源登记的规范路径。规格/计划里写的 `assets/CREDITS.md`
> 是指向本文件的兼容入口。

- 角色、战场背景、面板与其余可视内容均为**原创程序化绘制**：
  由项目内的 GDScript（`battle/views/unit_view.gd`、
  `battle/views/background_view.gd`、`ui/*.gd`）使用 Godot 的
  `draw_circle` / `draw_colored_polygon` / `draw_polyline` 等原语实时绘制。
- 指令 / 状态图标为第三方素材，见下方「第三方素材」；除这些图标外未使用
  第三方图片、字体文件、纹理或商业美术素材，未复制任何现有游戏/动漫角色
  的造型、配色或标志。
- 字体使用操作系统字体回退（PingFang SC / Hiragino Sans GB / Noto Sans
  CJK SC / Microsoft YaHei / Arial Unicode MS），不随项目分发字体文件。
- 音效为程序化合成（`battle/audio_director.gd`），同样不含第三方采样。

## 第三方素材

### game-icons.net（CC BY 3.0）

指令与状态图标取自 [game-icons.net](https://game-icons.net)，授权
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)。本项目在原始 SVG
基础上移除了黑色底、按 HUD 配色改色，未改变图形本体。

| 文件 | 图标 | 作者 |
|---|---|---|
| `assets/visuals/commands/attack.svg` | crossed-swords | Lorc |
| `assets/visuals/commands/skill.svg` | fireball | Lorc |
| `assets/visuals/commands/item.svg` | potion-ball | Lorc |
| `assets/visuals/commands/defend.svg` | checked-shield | Lorc |
| `assets/visuals/commands/flee.svg` | exit-door | Delapouite |
| `assets/visuals/status/poison.svg` | poison | Sbed |
| `assets/visuals/status/armor_down.svg` | broken-shield | Lorc |
| `assets/visuals/status/war_cry.svg` | shouting | Lorc |
| `assets/visuals/status/defending.svg` | checked-shield | Lorc |
| `assets/visuals/status/sealed.svg` | padlock | Lorc |

## AI 立绘（Seedream 5.0 Flash）

2026-10-27：SSO 恢复后，主角选择立绘由火山方舟 **Seedream 5.0 Flash**
生成，接入点 `ep-20261027232001-j8hg2`，按量计费。

- 已生成并接入：凌霄（`assets/visuals/heroes/swordsman_lingxiao.png`）、
  霜岚（`assets/visuals/heroes/swordsman_shuanglan.png`）。
- 生成流程：绿幕全身立绘 → 本地全局绿色掩码抠像/去溢色 → 裁到内容包围盒
  → 1024×1536 透明画布、脚底距底边 6px。
- 待补齐：青鸾、玄烛、白术、紫苏（生成账号欠费暂停，充值后按同一参考图/
  提示词模板补齐）。
- 图片为 AI 生成；未复制任何现有游戏/动漫角色的造型、配色或标志。
  公开发布前请按目标平台的 AI 素材合规要求复核。

## 战斗内美术

战斗角色、战场背景、面板与特效仍为项目内原始程序化绘制（见上）。
`assets/visuals/visual_catalog.json` 保留战斗角色/背景的 drop-in 接口；
AI 图片不要直接沿用 `scale: 1.0`：先按目标高度（推荐 300px）换算
`scale = 300 / 图片像素高度`，再按 `offset` 对齐脚底。

若未来引入任何外部素材，必须在此登记来源与许可证（优先 CC0），
并确保可商用、可再分发。
