# 战场方向造型与缩放（我方背影 / 敌方正面）实施计划

## 参考分析

- 经典《梦幻西游》战斗为 **45° 斜视角**：敌方左上、我方右下；镜头在我方队伍背后 → **我方背影、敌方正面**。
- 实机图（仅内部参考，不入库）：`/tmp/fwj_ref/bing_4.png`；角色约占屏高 1/6～1/5，环境/地面占主体；两排斜向错开；地面为带透视/圆形纹样的平台；HUD 靠边。
- 参考来源：52PK 多视角战斗报道（“左上右下”经典视角）、搜狐 HD 客户端战斗截图、梦幻西游官网游戏截图。仅用于设计分析。

## 设计

1. **方向系统**：`BattleFieldLayout` slot 增加 `view`（`back`/`front`）+ `facing`；我方 `back`、敌方 `front`。`UnitView.apply_formation(depth, facing, view)` 保存 `_art_view`。
2. **VisualCatalog**：unit entry 支持 `sprites: {front, back}`；有贴图时选当前 view，缺失回退程序化；未来 AI 立绘直接 drop-in。
3. **程序化背影**：我方三英雄在现有正面绘制后叠加背影层：
   - 遮住脸/正面衣领：后脑发团 + 后发/发髻/马尾/发带；
   - 袍背纯色面板 + 背缝/背腰带/背结；保留腿部、侧面手臂与武器；
   - 剑客：后脑短发 + 蓝色发带尾；法师：长发披背 + 发簪背视；医师：发髻 + 药囊背带；武器在侧后方。
   - 敌方保持现有正面。
4. **缩放**：全局 `BASE_ART_SCALE ≈ 0.75`，后排再 ×0.9；头顶名字/血条/状态/气泡锚点/命中区随造型同步收拢，避免“小人顶大血条”；HUD 不动。
5. **构图**：保留 2.5D 透视石台；我方背影朝左上、敌方正面朝右下；检查 HUD/日志不遮挡、前后排可点击。
6. **测试**：`test_formation` 增加 `view` 断言；HUD 真实输入/表现/故事/调试冒烟全绿；重截 1920×1080 截图，重录 GIF。

## Task 1

- 修改 `battle/battle_field_layout.gd`（view）、`battle/battle_session.gd`（传 view）、`battle/views/unit_view.gd`（背影层/缩放/信息条/命中区）、`battle/visual_catalog.gd` + `assets/visuals/visual_catalog.json`（front/back 映射）、`tests/cases/test_formation.gd`、`tools/smoke_hud_input.gd` 的尺寸/点击假设。
- 不修改 `core/`、`data/`、golden。
- 验收：gate 全绿；smoke/HUD/故事/调试全绿；全部单位背影/正面正确、明显缩小、信息条贴近、HUD 不遮挡；截图 + GIF。

## Acceptance

- 我方 3 人显示背影，敌方 4 人显示正面；方向由 slot 数据驱动，未来可加 `front/back` AI 贴图。
- 角色明显缩小（约 0.75），头顶信息条/命中区同步；前后排与 HUD 不遮挡。
- 核心 874+ 断言、HUD 全流程输入、表现/故事/调试冒烟全绿；新截图与 GIF 可复现。
