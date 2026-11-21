# 主角选择界面 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Godot 4.6 项目里实现舞台式主角选择界面：6 名预设主角、职业/性别/种族/描述/属性/技能、切换与确认动效、AI 立绘 + 程序化兜底，确认后进入现有战斗。

**Architecture:** 角色档案是独立 Resource（放在 `res://roster/`，避开 `res://data/` 内容哈希）；界面由 `CharacterSelect` 控制器 + 背景/立绘/详情/卡片四个视图组成，全部 Control 绘制；图片缺失时 `HeroPortraitView` 回退程序化 Q 版立绘；选择写入 `user://character_select.cfg`。

**Tech Stack:** Godot 4.6 (GDScript), Control nodes, Tween, ConfigFile, custom `_draw`, Pillow (only for AI portrait keying), Seedream 5.0 Flash.

## Global Constraints

- Godot **4.6**, 1920×1080, `canvas_items` + `keep`。
- 角色档案不得放入 `res://data/`；`ContentDB.content_hash()` 必须保持不变。
- 新增内容不引入第三方运行时依赖；字体走 `FontUtil.cjk_font()`。
- 视觉语言沿用 `UiStyle` 的金边/檀木/内描边，但背景更通透、留白更多。
- AI 立绘：透明 PNG，1024×1536，脚底距底边 6px；缺图必须回退，不能空白。
- 无 `SCRIPT ERROR`；测试命令以 `run_tests.sh` 为准。

---

### Task 1: 角色档案数据与加载器

**Files:**
- Create: `roster/hero_profile.gd`
- Create: `roster/hero_roster.gd`
- Create: `roster/heroes/*.tres` (6)
- Test: `tests/cases/test_hero_roster.gd`

**Interfaces:**
- `HeroProfile` fields: `id: StringName`, `display_name`, `title`, `hero_class`, `gender`, `race`, `accent: Color`, `quote`, `description`, `hp_bar/atk_bar/mag_bar/spd_bar: int`, `skills: Array[String]`, `portrait_path: String`, `sort_order: int`.
- `HeroRoster.load_all() -> Array[HeroProfile]`
- `HeroRoster.find(profiles: Array[HeroProfile], id: StringName) -> HeroProfile`
- `HeroRoster.validate(profiles) -> Array[String]`

- [ ] 写 `hero_profile.gd` 与 6 份 `.tres`（凌霄/霜岚/青鸾/玄烛/白术/紫苏，属性见 spec）。
- [ ] 写 `hero_roster.gd`：扫描目录、按 sort_order 排序、校验数量/职业×性别/种族/id。
- [ ] 写测试：6 人、3 职业、每职业 2 性别、3 种族、id 唯一、描述≥20 字、语录非空、四维 0–100、缺图路径可为空。
- [ ] 运行：`bash tools/run_tests.sh`；期望 `PASS test_hero_roster.gd`、`RESULT: ... 0 failures`。

### Task 2: 选择持久化

**Files:**
- Modify: `roster/hero_roster.gd`
- Test: `tests/cases/test_hero_roster.gd`

**Interfaces:**
- `HeroRoster.SAVE_PATH := "user://character_select.cfg"`
- `HeroRoster.save_id(id: StringName) -> Error`
- `HeroRoster.load_saved_id() -> StringName`
- `HeroRoster.clear_saved_id() -> void`

- [ ] 写失败测试：保存 `swordsman_lingxiao` → 读取相同；保存不存在 id → 读取返回空；测试结束恢复原值。
- [ ] 实现 ConfigFile 读写；`load_saved_id` 只返回仍存在于 roster 的 id。
- [ ] 运行测试通过。

### Task 3: 视觉样式与背景

**Files:**
- Create: `ui/character_select/select_style.gd`
- Create: `ui/character_select/select_backdrop.gd`

**Interfaces:**
- `SelectStyle.palette` 常量、`SelectStyle.title_label(text, size) -> Label`、`SelectStyle.tag(text, accent) -> PanelContainer`、`SelectStyle.stat_bar(...)`。
- `SelectBackdrop.set_accent(color: Color)`、`SelectBackdrop.set_parallax(offset: Vector2)`、`SelectBackdrop.start_intro() -> Tween`。

- [ ] `SelectBackdrop` 自定义 `_draw`：天空渐变、远山 3 层、日轮、云带、竹影、暗角、粒子；`_process` 更新粒子/云，鼠标视差。
- [ ] `set_accent` 用 Tween 平滑背景光晕与主色。
- [ ] 截图验证：1920×1080 背景无空洞、60fps、无每帧节点创建。

### Task 4: 立绘视图与程序化兜底

**Files:**
- Create: `ui/character_select/hero_portrait_view.gd`
- Test: 由 smoke 覆盖

**Interfaces:**
- `HeroPortraitView.show_profile(profile: HeroProfile, animated: bool) -> void`
- `HeroPortraitView.current_id() -> StringName`
- `HeroPortraitView.set_accent(color: Color) -> void`

- [ ] 优先 `load(profile.portrait_path)`；成功则 `TextureRect` 底边对齐到脚底锚点，保持宽高比。
- [ ] 失败/空路径回退 `_draw`：按职业画武器/法杖/药杖，按性别画发型/身形，按种族加耳/羽/尾，配色用 accent。
- [ ] 切换动效：淡出→替换→淡入 + 上浮 30px→0（0.35s）。
- [ ] 缺图测试：临时清空路径，断言节点仍可见且 `current_id` 正确。

### Task 5: 角色卡与右侧详情

**Files:**
- Create: `ui/character_select/hero_card.gd`
- Create: `ui/character_select/hero_detail_panel.gd`

**Interfaces:**
- `HeroCard.setup(profile, thumbnail_path)`、`HeroCard.set_selected(bool)`；信号 `pressed(profile)`、`hovered(profile)`。
- `HeroDetailPanel.show_profile(profile, animated)`；信号 `confirm_pressed()`；`set_confirm_enabled(bool)`。

- [ ] 角色卡：140×120，缩略立绘/职业符印、姓名、职业色底纹；选中金框 + 笔触。
- [ ] 详情面板：姓名 40px、称号 20px、三枚标签、描述 3 行、语录斜体、四条属性条（0.4s 动画）、3 个技能条、确认按钮。
- [ ] 文本溢出/换行检查。

### Task 6: 控制器、场景与主场景切换

**Files:**
- Create: `ui/character_select/character_select.gd`
- Create: `scenes/character_select.tscn`
- Modify: `project.godot` (`run/main_scene`)

**Interfaces:**
- `CharacterSelect.auto_enter_battle := true`
- `CharacterSelect.select_hero(id: StringName, animated := true) -> bool`
- `CharacterSelect.selected_id() -> StringName`
- `CharacterSelect.confirm() -> void`
- signals `hero_changed(profile)`, `confirmed(profile)`

- [ ] `_ready`：加载 roster、恢复存档、构建 6 卡、默认凌霄、播放 intro。
- [ ] 输入：←/→/A/D、1–6、Enter、鼠标点击卡片。
- [ ] 切换：调用 portrait/detail/backdrop 的 show/set_accent，更新卡片选中。
- [ ] 确认：保存 id → 朱印动画 0.6s → 发 `confirmed`；`auto_enter_battle` 时 `change_scene_to_file("res://scenes/battle_scene.tscn")`。
- [ ] 失败：roster 为空时显示错误面板，不崩溃。

### Task 7: 冒烟与截图

**Files:**
- Create: `tools/smoke_character_select.gd`
- Create: `tools/screenshot_character_select.gd`

**Interfaces:**
- 冒烟输出 `CHARACTER_SELECT_SMOKE_OK`；截图输出 `SCREENSHOT: <path>`。

- [ ] 冒烟：headless 实例化、6 卡、select 6 人、confirm 落盘、`auto_enter_battle=false` 不切场景。
- [ ] 截图：SubViewport 1920×1080，默认凌霄、切换青鸾、确认态各 1 张。
- [ ] 运行：`bash tools/smoke_gate.sh smoke_character_select.gd --headless`；期望 `exit=0`。
- [ ] 截图发飞书目检。

### Task 8: AI 立绘补齐与接入

**Files:**
- Create: `assets/visuals/heroes/*.png` (6)
- Update: `assets/art/CREDITS.md`

**Interfaces:**
- 路径固定 `res://assets/visuals/heroes/<id>.png`；档案 `portrait_path` 指向它。

- [ ] 凌霄、霜岚已出图并抠像；剩余 4 张在账号充值后生成（同一参考图/提示词模板）。
- [ ] 每张：绿幕 → 全局绿色掩码 + 去溢色 → 裁包围盒 → 1024×1536、脚底 6px → 存 PNG。
- [ ] 目检：无绿边、无残缺、与已出图风格一致；不达标重生成。
- [ ] 更新 CREDITS（Seedream 生成，账号/日期）。

### Task 9: 文档与回归

**Files:**
- Modify: `README.md`
- Modify: `docs/PROGRESS.md`（新增本次记录）

- [ ] README：主场景改为角色选择、操作说明、冒烟/截图命令。
- [ ] 跑完整回归：`bash tools/run_tests.sh`、`smoke_character_select`、`smoke_presentation`、黄金回放。
- [ ] 确认 `ContentDB.content_hash()` 与改动前一致（新增 roster 不在 data/）。
- [ ] 截图 1920×1080 发飞书，收集用户反馈。

## Self-Review

- Spec 覆盖：布局/角色/动效/数据/存盘/立绘/兜底/测试/文档均有任务。
- 类型一致：`HeroProfile` 字段在 Task 1 定义，后续只读；`HeroRoster` 方法签名统一。
- 风险：AI 账号欠费 → Task 8 允许分批；界面先用 2 张真图 + 4 张程序化兜底。
