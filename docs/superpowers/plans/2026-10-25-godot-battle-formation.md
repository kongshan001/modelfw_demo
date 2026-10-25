# Godot 战斗站位系统（2.5D 俯视阵型）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development.

**Goal:** 把当前横排战场升级为梦幻西游式的 2.5D 俯视/等距阵型：前后两排、透视地面、Y 排序、按排深度缩放、面向翻转，并把点击/信息/探针/HUD 适配。

**Scope:** 表现层与站位系统；不修改 `core/`、`res://data/**`、golden。

## Design

- **投影**：不是纯垂直俯视，而是 2.5D：地面透视平台 + 角色直立、按脚底 Y 排序、后排 0.9 倍/前排 1.05 倍；保留 Q 版立绘。
- **阵型**：`BattleFieldLayout` 管理每侧 slot 的 `row/pos/depth/art_flip`；默认 3v4 两排，未来可换阵型。
  - 我方（右下）：剑客前排 (1150,800) 1.05 面向左；法师后排 (1290,680) 0.92；医师后排 (930,680) 0.90。
  - 敌方（左上）：妖兵甲前排 (750,800) 1.05 面向右；妖兵乙后排 (610,680) 0.90；妖将前排 (470,800) 1.05（美术镜像，斧头朝左）；狐妖后排 (260,680) 0.90（美术镜像，尾巴朝左）。
  - 同排/跨排的 x 命中区互不相交（约 130px 宽，间隔 ≥10px）；避免 HUD/日志遮挡。
- **视觉**：透视石台/地面网格、边缘描金、中心暗纹；Y 排序 `world.y_sort_enabled`；深度缩放只作用于美术层（`draw_set_transform`），名字/血条/命中区保持可读；面向只翻转美术层。
- **动作**：前冲/受击/特效落点仍使用地面位置；信息条/气泡锚点不镜像。
- **测试**：阵型单测（slot 数、唯一位置、行/深度、屏幕内、命中区 x 不相交）；表现冒烟/HUD 输入/故事/调试保持绿色；新增截图 + GIF。

## Task 1: 阵型系统、俯视地面、UnitView 深度/面向

**Files:** create `battle/battle_field_layout.gd`, `tests/cases/test_formation.gd`; modify `battle/battle_session.gd`, `battle/battle_scene.gd`, `battle/views/unit_view.gd`, `battle/views/background_view.gd`, `tools/smoke_hud_input.gd` (仅阵型适配), `tools/screenshot_art.gd` if needed.

**Steps:**
1. Add `BattleFieldLayout` with the slot table above; methods `slot(side,index)`, `ally_slots()`, `enemy_slots()`, `all_slots()`.
2. `battle_scene.gd`: `world.y_sort_enabled = true`.
3. `battle_session.gd` `_build_units`: use the layout; call `view.setup(unit, slot.pos, is_ally)` then `view.apply_formation(slot.depth, slot.art_flip)`.
4. `unit_view.gd`: add `_formation_depth`, `_facing`; `apply_formation(depth, facing)`; `_draw` uses `_art_scale * _formation_depth` and x sign `_facing`; `visual_scale()` includes depth; `appendage_points()` mirrors x by `_facing`; keep hit rect/info/bubble unscaled. Ensure `_facing` does not mirror labels/bars.
5. `background_view.gd`: add `_draw_battle_platform()` (perspective trapezoid/stone + grid + border + center motif) between ground and ground light; keep fog/light; not block units.
6. Update `smoke_hud_input.gd` formation-specific assumptions:
   - hit rect x ranges disjoint; keep no-overlap/panel/log checks; appendage points may be outside owner but must not fall in a neighbor's rect (relax the "inside owner" rule for the formation, or adjust art so points stay within free gaps).
   - target clicks use the unit center; target keys still work; full battle remains.
7. Add `tests/cases/test_formation.gd`; run the core gate.
8. Verify: gate 0 failures; presentation smoke; HUD input full battle; screenshots (full/HUD/skill/victory) at 1920×1080; inspect formation (two rows, depth, facing, no HUD/log occlusion).
9. Commit `feat(presentation): 2.5D 俯视阵型与透视战场`.

## Task 2: 截图/GIF、文档、验收

- Re-record a 20s battle GIF (Movie Maker or frames) showing the new formation; save under `/tmp` or `assets`? Keep GIF out of the repo unless requested; report path.
- Update README (formation description, controls), PROGRESS/TECH_NOTES (formation system, y-sort/depth/facing, pitfalls); run the full acceptance list.
- Review the formation change (subagent) and fix Critical/Important; report.

## Acceptance

- 3v4 visible in two rows on a perspective ground; units y-sorted and depth-scaled; facing art flipped only.
- HUD/log/panel clear; target clicks/number keys work; full-input battle passes.
- Core gate/smokes/story/debug green; new formation test green; screenshots + GIF.
- No core/data/golden changes.
