# 美术资源与 AI 美术接入

当前版本的**角色、战场背景、面板与战斗特效**仍由 GDScript 程序化绘制；
指令/状态图标使用 game-icons.net（CC BY 3.0）。程序化绘制始终可用，是任何
缺失资源的兜底。

## 当前素材状态

2026-10-27：SSO 已恢复，Seedream 5.0 Flash 接入点可用。主角选择的凌霄、
霜岚立绘已生成并抠像，放在 `assets/visuals/heroes/`；青鸾、玄烛、白术、
紫苏待账号充值后补齐。战斗内角色与背景仍为程序化绘制。

1. 主角选择立绘：透明 PNG，缺图自动回退程序化；
2. 指令/状态图标：game-icons.net（CC BY 3.0，见 `CREDITS.md`）；
3. `assets/visuals/visual_catalog.json` 继续保留战斗角色/背景的 drop-in 接口。

> 已试过免费商用「竹林の神社」背景，但与程序化角色在地面落点、光照和透视上
> 互相架空，已回退。背景与角色应作为同一风格套件一起替换。

## 目录

```
assets/
  CREDITS.md           # 指针 → art/CREDITS.md（规范文档实际位置）
  art/
    README.md          # 本文件
    CREDITS.md         # 版权与来源说明（canonical）
  visuals/
    visual_catalog.json
    units/             # （可选）放置角色立绘 PNG/WebP
    background/        # （可选）放置 1920x1080 背景图
    status/            # （可选）状态图标
    commands/          # （可选）指令图标
```

## 接入角色立绘

1. 把透明背景 PNG（脚底贴图片底边）放到 `assets/visuals/units/`，
   文件名建议与单位 id 一致，例如 `hero_swordsman.png`。背影单位可加
   `_back` 后缀，例如 `hero_swordsman_back.png`。
2. 以 **设计高度 300px** 为基准换算缩放：`scale = 300 / 图片像素高度`
   （例如 1024px 高的原图填 `scale: 0.293`）。小妖等矮单位可在目标高度
   基础上再乘 0.8–0.9。UnitView 会再乘全局 `BASE_ART_SCALE=0.66`
   与阵型 depth，因此 300px 的设计高度在屏上约 198px。
3. 编辑 `assets/visuals/visual_catalog.json`，按视图分别提供贴图：

```json
"units": {
  "hero_swordsman": {
    "sprites": {
      "front": "res://assets/visuals/units/hero_swordsman.png",
      "back": "res://assets/visuals/units/hero_swordsman_back.png"
    },
    "scale": 1.0,
    "offset": [0, 0]
  }
}
```

- `sprites.front` / `sprites.back`：当前视图的贴图。值可以是路径字符串，
  也可以是 `{"sprite": "...", "scale": 0.29, "offset": [0, 0]}` 字典以单独
  覆盖该视图的缩放/偏移。当前视图由 `BattleFieldLayout` 的 slot 数据驱动：
  镜头在我方背后，我方 `back`、敌方 `front`。
- 旧版 `sprite` / `path` 仍兼容：没有对应视图的 `sprites` 条目时，
  两视图共用旧版贴图。
- `scale`：整体缩放；默认 1.0。未来 AI 图片必须按设计高度（推荐 300px）
  换算，而不是直接沿用 1.0。
- `offset`：以“脚底为原点”的像素偏移，向上为负 y；会随全局缩放一起缩。

UnitView 会把图片底边对齐到角色脚底（`y = 0`），并让名字 / 血蓝条 / 状态 /
命中区按剪影高度与全局缩放同步收拢。某个视图的图片缺失、损坏或导入失败时，
自动回退到该视图对应的程序化正面/背影绘制。

`core/data/unit_data.gd` 里已有 `sprite_path` / `visual_scale` 字段，可作为
备用入口；`visual_catalog.json` 优先级更高，核心数据无需改动。

## 接入战场背景

把 1920×1080 的背景图放到 `assets/visuals/background/`，然后：

```json
"background": {
  "path": "res://assets/visuals/background/bamboo_dawn.png",
  "scale": 1.0,
  "modulate": [1.0, 0.98, 0.94, 1.0]
}
```

背景图会铺在程序化天空/竹林/地面之前并替换它们；光柱、地面光斑、地面薄雾、
暗角、GPU 雾带与飘叶层仍会叠加在背景图之上，保持战场氛围统一。
路径为空或加载失败时继续使用程序化竹林。

## 接入状态 / 指令图标

```json
"status_icons": {
  "poison": {"path": "res://assets/visuals/status/poison.png"}
},
"command_icons": {
  "attack": {"path": "res://assets/visuals/commands/attack.png"}
}
```

- 状态图标会替代单位头顶的圆形文字徽章（推荐 24×24 透明 PNG）。
- 指令图标会作为 Button 的 `icon` 显示，替代一字符金色徽章
  （推荐 28×28 透明 PNG）。

## 注意

- Godot 4 需要先导入位图（编辑器打开一次或运行 `godot --headless --path
  godot-battle --editor --quit`）；未导入的 res:// 图片会尝试用
  `Image.load_from_file` 直接加载，但正式发布请走导入管线。
- 新增美术文件不会改变 `res://data/**` 的内容哈希，因此不会影响黄金回放与核心门禁。
- 请只接入自有或明确授权（CC0 / CC BY / 明确免费商用）的素材，并同步更新
  `CREDITS.md`（canonical 路径：`assets/art/CREDITS.md`）。标注「再配布禁止」
  的素材需在公开发布时从源码包排除，只保留游戏内嵌入形式。
