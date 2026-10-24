# Godot 回合制战斗 Demo — 表现层与可玩闭环实施计划（Plan 2A / 2B）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** 把已完成的确定性战斗内核接上可玩的 2D 表现层：3v4 战场、指令 UI、出手/受击/法术表现、战斗日志、对白/气泡、胜负结算，先用程序化占位美术跑通全流程。

**Architecture:** `BattleScene` 构建背景/单位/相机/UI 层；`BattleSession` 驱动「指令阶段 → 结算 → 事件播放」循环；`BattleSequencer` 顺序执行 `BattleCommand`；`BattleDirector` 把 `BattleEvent` 翻译成命令。表现层只读事件与只读快照，绝不修改战斗数据。视觉资源通过独立的视觉目录/贴图路径覆盖，不写入 `res://data`（避免改变内容 hash 导致黄金回放失效）。

**Tech Stack:** Godot 4.6 stable、GDScript 2.0、`gl_compatibility`、程序化 2D 绘制 + GPUParticles2D、系统字体（中文）。

**Scope:** Plan 2A 完成可玩的无成品美术版本；Plan 2B 完成调试工具、回放播放、AI/免费美术替换、文档与验收。

## Global Constraints

- 不修改 `core/` 战斗逻辑；表现层只消费 `BattleEvent` 与只读 `BattleState`。
- 不修改 `res://data/**` 内容资源（会改变内容 hash，导致 `tests/golden/` 严格校验失败）；视觉映射放 `res://assets/` 目录。
- 逻辑随机仍只来自 `BattleRng`；表现层装饰随机使用独立 `RandomNumberGenerator`。
- 截图分辨率固定 1920×1080；所有战斗关键信息在 1080p 下可读。
- 核心测试门禁保持绿色：`bash godot-battle/tools/run_tests.sh`。
- 表现层冒烟：`godot --headless --path godot-battle -s tools/smoke_presentation.gd`，退出码 0，输出 `PRESENTATION_SMOKE_OK`。
- 截图：`godot --path godot-battle --resolution 1920x1080 -s tools/screenshot.gd`，输出到 `user://screenshots/`；每个任务附至少一张截图供视觉检查。
- 提交仅包含 `godot-battle/` 与相关计划/文档；不提交 `.superpowers/`、`ark-examples/`、`bench_dll_split/`。

---

## File Structure (Plan 2A)

```
godot-battle/
├── project.godot                      # 设置 main_scene
├── scenes/
│   └── battle_scene.tscn              # 根 Node2D + battle_scene.gd
├── battle/
│   ├── battle_scene.gd                # 构建图层、槽位、启动 Session
│   ├── battle_session.gd              # 引擎/视图/回合循环/auto_play
│   ├── battle_context.gd              # 视图、相机、VFX、HUD、等待/快照
│   ├── battle_sequencer.gd            # 命令队列、倍速、跳过
│   ├── battle_director.gd             # 事件 → 命令
│   ├── command_registry.gd
│   ├── commands/
│   │   ├── battle_command.gd
│   │   ├── simple_event_command.gd    # Task 1 基础播放
│   │   ├── action_start_command.gd    # Task 2
│   │   ├── damage_command.gd          # Task 2
│   │   ├── heal_command.gd            # Task 2
│   │   ├── status_command.gd          # Task 2
│   │   ├── death_command.gd           # Task 2
│   │   ├── round_banner_command.gd    # Task 2
│   │   ├── battle_end_command.gd      # Task 2
│   │   └── dialogue_command.gd        # Task 4
│   ├── views/
│   │   ├── unit_view.gd
│   │   ├── background_view.gd
│   │   └── camera_rig.gd
│   ├── vfx_factory.gd                 # Task 2
│   └── float_text.gd                  # Task 2
├── ui/
│   ├── battle_hud.gd                  # Task 3
│   ├── target_selector.gd             # Task 3
│   ├── battle_log.gd                  # Task 3
│   ├── dialogue_box.gd                # Task 4
│   ├── bubble.gd                      # Task 4
│   ├── victory_panel.gd               # Task 4
│   └── font_util.gd                   # 中文 SystemFont
├── assets/
│   └── visuals/                       # Plan 2B 视觉目录；本计划可空
├── tools/
│   ├── smoke_presentation.gd
│   └── screenshot.gd
└── docs/
    └── (Plan 2B 更新 PROGRESS/TECH_NOTES)
```

---

## Task 1: 战场场景、单位视图、背景、相机、Session 与基础播放

**Files:**
- Modify: `godot-battle/project.godot`（`run/main_scene`）
- Create: `godot-battle/scenes/battle_scene.tscn`
- Create: `godot-battle/battle/battle_scene.gd`
- Create: `godot-battle/battle/battle_context.gd`
- Create: `godot-battle/battle/battle_session.gd`
- Create: `godot-battle/battle/battle_sequencer.gd`
- Create: `godot-battle/battle/battle_director.gd`
- Create: `godot-battle/battle/commands/battle_command.gd`
- Create: `godot-battle/battle/commands/simple_event_command.gd`
- Create: `godot-battle/battle/views/unit_view.gd`
- Create: `godot-battle/battle/views/background_view.gd`
- Create: `godot-battle/battle/views/camera_rig.gd`
- Create: `godot-battle/ui/font_util.gd`
- Create: `godot-battle/tools/smoke_presentation.gd`
- Create: `godot-battle/tools/screenshot.gd`

**Interfaces:**
- `BattleContext`（`scene_tree/scene/unit_views/camera/vfx_layer/hud/audio/sequencer/session`；`wait(sec)`、`is_skipping()`、`apply_snapshot(state)`）
- `BattleSequencer`（`enqueue/enqueue_batch/play_all/idle/skip_all/playback_speed`）
- `BattleCommand`（`play(ctx)`、`skip(ctx)`）
- `BattleSession`（`start(seed)`、`auto_play()`、`battle_finished(outcome)` 信号；`engine`、`context`）
- `UnitView`（`setup(unit, home, is_ally)`、`refresh_from_state(unit)`、`set_hp/set_mp/set_statuses`、`set_selected/set_targetable`、`lunge_to/cast_pose/hurt/die/reset_pose`、`clicked` 信号）

- [ ] **Step 1: 写场景与单位视图**

`scenes/battle_scene.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://battle/battle_scene.gd" id="1_battle"]

[node name="BattleScene" type="Node2D"]
script = ExtResource("1_battle")
```

`project.godot` 增加：

```ini
[application]
run/main_scene="res://scenes/battle_scene.tscn"
```

`ui/font_util.gd`:

```gdscript
class_name FontUtil
extends RefCounted

static var _font: SystemFont

static func cjk_font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Microsoft YaHei", "Arial Unicode MS"])
	return _font
```

`battle/views/unit_view.gd` — 完整实现要点：

```gdscript
class_name UnitView
extends Node2D

signal clicked(view: UnitView)

const BAR_WIDTH := 104.0
const BAR_HEIGHT := 9.0

var unit_id: StringName
var side: int = BattleTypes.Side.ALLY
var home_position := Vector2.ZERO
var unit_state: BattleUnitState
var is_ally := false

var _sprite: Sprite2D
var _name_label: Label
var _hp_bg: ColorRect
var _hp_trail: ColorRect
var _hp_fill: ColorRect
var _mp_bg: ColorRect
var _mp_fill: ColorRect
var _status_row: HBoxContainer
var _selection: Polygon2D
var _target_arrow: Polygon2D
var _click_area: Area2D
var _idle_tween: Tween
var _body_color := Color(0.35, 0.6, 1.0)
var _visual_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_visual_rng.seed = hash(String(unit_id)) + 17
	_build_placeholder()
	_build_bars()
	_build_click_area()

func setup(unit: BattleUnitState, home: Vector2, ally: bool) -> void:
	unit_state = unit
	unit_id = unit.id
	side = unit.side
	is_ally = ally
	home_position = home
	position = home
	_body_color = Color(0.32, 0.62, 1.0) if ally else Color(0.95, 0.36, 0.3)
	_name_label.text = unit.data.display_name
	refresh_from_state(unit)
	visible = true
	_start_idle()

func refresh_from_state(unit: BattleUnitState) -> void:
	unit_state = unit
	set_hp(unit.hp, false)
	set_mp(unit.mp, false)
	set_statuses(unit.statuses)
	visible = unit.is_alive() or unit.hp > 0
	if not unit.is_alive():
		modulate.a = 0.35
		rotation = deg_to_rad(-12.0)
		position = home_position + Vector2(0, 26)

func _build_placeholder() -> void:
	_sprite = Sprite2D.new()
	_sprite.visible = false
	add_child(_sprite)
	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse_points(64, 18)
	shadow.color = Color(0, 0, 0, 0.28)
	shadow.position = Vector2(0, 10)
	add_child(shadow)

func _draw() -> void:
	# 程序化 Q 版剪影：脚底在 y=0，身高约 210px
	draw_circle(Vector2(0, -178), 38.0, _body_color.lightened(0.25))
	draw_rect(Rect2(-36, -150, 72, 92), _body_color, true)
	draw_polygon(PackedVector2Array([Vector2(-24, -58), Vector2(24, -58), Vector2(40, 6), Vector2(-40, 6)]), PackedColorArray([_body_color.darkened(0.15)]))
	if is_ally:
		draw_line(Vector2(34, -122), Vector2(78, -186), Color(0.9, 0.9, 0.95), 7.0)
	else:
		draw_line(Vector2(-34, -122), Vector2(-74, -178), Color(0.55, 0.35, 0.2), 7.0)
	draw_circle(Vector2(-12, -184), 3.5, Color(0.1, 0.1, 0.15))
	draw_circle(Vector2(12, -184), 3.5, Color(0.1, 0.1, 0.15))

func _build_bars() -> void:
	_name_label = Label.new()
	_name_label.position = Vector2(-70, -262)
	_name_label.size = Vector2(140, 24)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_override("font", FontUtil.cjk_font())
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_name_label)

	_hp_bg = _bar(Color(0.1, 0.1, 0.12, 0.9), Vector2(-BAR_WIDTH / 2, -238))
	_hp_trail = _bar(Color(1, 1, 1, 0.6), Vector2(-BAR_WIDTH / 2, -238))
	_hp_fill = _bar(Color(0.3, 0.9, 0.4), Vector2(-BAR_WIDTH / 2, -238))
	_mp_bg = _bar(Color(0.1, 0.1, 0.12, 0.9), Vector2(-BAR_WIDTH / 2, -226))
	_mp_fill = _bar(Color(0.35, 0.65, 1.0), Vector2(-BAR_WIDTH / 2, -226))

	_status_row = HBoxContainer.new()
	_status_row.position = Vector2(-BAR_WIDTH / 2, -214)
	_status_row.size = Vector2(BAR_WIDTH, 18)
	_status_row.add_theme_constant_override("separation", 4)
	add_child(_status_row)

	_selection = Polygon2D.new()
	_selection.polygon = _ellipse_points(58, 16)
	_selection.color = Color(1.0, 0.85, 0.2, 0.55)
	_selection.position = Vector2(0, 8)
	_selection.visible = false
	add_child(_selection)

	_target_arrow = Polygon2D.new()
	_target_arrow.polygon = PackedVector2Array([Vector2(-14, -292), Vector2(14, -292), Vector2(0, -270)])
	_target_arrow.color = Color(1.0, 0.85, 0.15)
	_target_arrow.visible = false
	add_child(_target_arrow)

func _bar(color: Color, pos: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = pos
	rect.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	add_child(rect)
	return rect

func _build_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.input_pickable = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(136, 290)
	collision.shape = shape
	collision.position = Vector2(0, -140)
	_click_area.add_child(collision)
	add_child(_click_area)
	_click_area.input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)

func _ellipse_points(rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func set_hp(value: int, animate: bool = true) -> void:
	if unit_state == null:
		return
	var ratio := clampf(float(value) / float(maxi(1, unit_state.data.max_hp)), 0.0, 1.0)
	var target_width := BAR_WIDTH * ratio
	_hp_fill.size.x = target_width
	if animate:
		var tween := create_tween()
		tween.tween_property(_hp_trail, "size:x", target_width, 0.35).set_delay(0.15)
	else:
		_hp_trail.size.x = target_width

func set_mp(value: int, animate: bool = true) -> void:
	if unit_state == null:
		return
	var ratio := clampf(float(value) / float(maxi(1, unit_state.data.max_mp)), 0.0, 1.0)
	var target_width := BAR_WIDTH * ratio
	if animate:
		create_tween().tween_property(_mp_fill, "size:x", target_width, 0.25)
	else:
		_mp_fill.size.x = target_width

func set_statuses(statuses: Array[StatusInstance]) -> void:
	for child in _status_row.get_children():
		child.queue_free()
	for status in statuses:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = status.data.display_color
		dot.tooltip_text = status.data.display_name
		_status_row.add_child(dot)

func set_selected(value: bool) -> void:
	_selection.visible = value
	if value:
		_position_glow()

func set_targetable(value: bool) -> void:
	_target_arrow.visible = value

func _position_glow() -> void:
	_selection.modulate.a = 0.4 + 0.4 * absf(sin(Time.get_ticks_msec() / 300.0))

func _start_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	position = home_position
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "position:y", home_position.y - 4.0, 0.9).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(self, "position:y", home_position.y, 0.9).set_trans(Tween.TRANS_SINE)

func stop_animations() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	position = home_position
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE

func lunge_to(target_position: Vector2) -> void:
	stop_animations()
	var direction := signf(target_position.x - home_position.x)
	var destination := target_position - Vector2(direction * 120.0, 0)
	var tween := create_tween()
	tween.tween_property(self, "position", destination, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func reset_pose() -> void:
	stop_animations()
	_start_idle()

func cast_pose() -> void:
	stop_animations()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.18)
	tween.parallel().tween_property(self, "modulate", Color(1.4, 1.6, 2.0), 0.18)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.2)
	await tween.finished

func hurt() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0), 0.04)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	var base := position
	var knock := base + Vector2(14.0 if is_ally else -14.0, 0)
	tween.parallel().tween_property(self, "position", knock, 0.08)
	tween.parallel().tween_property(self, "position", base, 0.12)
	await tween.finished

func die() -> void:
	stop_animations()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(self, "rotation", deg_to_rad(-70.0), 0.35)
	tween.parallel().tween_property(self, "position:y", home_position.y + 34.0, 0.35)
	await tween.finished
	visible = false
```

`battle/views/background_view.gd`:

```gdscript
class_name BackgroundView
extends Node2D

const W := 1920.0
const H := 1080.0
var _fog: GPUParticles2D

func _ready() -> void:
	_build_fog()

func _build_fog() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 22.0
	mat.gravity = Vector3.ZERO
	mat.color = Color(0.85, 0.9, 1.0, 0.10)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	_fog = GPUParticles2D.new()
	_fog.process_material = mat
	_fog.texture = _soft_circle_texture()
	_fog.amount = 40
	_fog.lifetime = 16.0
	_fog.preprocess = 8.0
	_fog.position = Vector2(0, 560)
	_fog.emitting = true
	add_child(_fog)

func _soft_circle_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _draw() -> void:
	# 天空渐变（分条绘制）
	for i in 48:
		var t := float(i) / 47.0
		var color := Color(0.72, 0.86, 0.95).lerp(Color(0.98, 0.92, 0.78), t)
		draw_rect(Rect2(0, H * t * 0.55, W, H * 0.55 / 48.0 + 2.0), color, true)
	# 远山
	draw_polygon(PackedVector2Array([Vector2(0, 430), Vector2(220, 230), Vector2(470, 430), Vector2(690, 280), Vector2(980, 450), Vector2(1240, 300), Vector2(1560, 450), Vector2(1920, 340), Vector2(1920, 700), Vector2(0, 700)]), PackedColorArray([Color(0.42, 0.58, 0.55)]))
	draw_polygon(PackedVector2Array([Vector2(0, 520), Vector2(300, 390), Vector2(620, 540), Vector2(900, 400), Vector2(1240, 550), Vector2(1600, 420), Vector2(1920, 520), Vector2(1920, 760), Vector2(0, 760)]), PackedColorArray([Color(0.27, 0.46, 0.36)]))
	# 竹林
	for i in 22:
		var x := 60.0 + i * 86.0
		var h := 260.0 + float((i * 53) % 160)
		draw_line(Vector2(x, 600), Vector2(x + 18, 600 - h), Color(0.24, 0.38, 0.24, 0.75), 6.0)
	# 地面
	draw_polygon(PackedVector2Array([Vector2(0, 690), Vector2(1920, 690), Vector2(1920, 1080), Vector2(0, 1080)]), PackedColorArray([Color(0.36, 0.5, 0.3)]))
	for i in 20:
		draw_line(Vector2(0, 720 + i * 18), Vector2(1920, 700 + i * 20), Color(0.28, 0.4, 0.24, 0.25), 2.0)
	# 光斑
	for i in 9:
		var p := Vector2(220 + i * 190, 160 + (i * 137) % 360)
		draw_circle(p, 26.0 + (i * 7) % 22, Color(1.0, 0.95, 0.75, 0.08))
```

`battle/views/camera_rig.gd`:

```gdscript
class_name CameraRig
extends Camera2D

var _visual_rng := RandomNumberGenerator.new()

func _ready() -> void:
	position = Vector2(960, 540)
	_visual_rng.seed = 4242
	zoom = Vector2.ONE

func shake(amount: float = 5.0, duration: float = 0.14) -> void:
	var tween := create_tween()
	var steps := 4
	for i in steps:
		var offset_target := Vector2(_visual_rng.randf_range(-amount, amount), _visual_rng.randf_range(-amount, amount))
		tween.tween_property(self, "offset", offset_target, duration / float(steps))
	tween.tween_property(self, "offset", Vector2.ZERO, 0.06)

func punch_zoom(amount: float = 1.04, duration: float = 0.15) -> void:
	var tween := create_tween()
	tween.tween_property(self, "zoom", Vector2(amount, amount), duration / 2.0)
	tween.tween_property(self, "zoom", Vector2.ONE, duration / 2.0)
```

`battle/battle_context.gd`:

```gdscript
class_name BattleContext
extends RefCounted

var scene_tree: SceneTree
var scene: Node2D
var session: Node
var sequencer: BattleSequencer
var camera: CameraRig
var vfx_layer: Node2D
var hud: Control
var audio: Node
var ui_layer: CanvasLayer

var unit_views: Dictionary = {}
var visual_rng := RandomNumberGenerator.new()

func _init(p_tree: SceneTree, p_scene: Node2D) -> void:
	scene_tree = p_tree
	scene = p_scene
	visual_rng.seed = 9001

func unit_view(unit_id: StringName) -> UnitView:
	return unit_views.get(unit_id)

func wait(seconds: float) -> void:
	var speed := maxf(0.001, sequencer.playback_speed if sequencer != null else 1.0)
	await scene_tree.create_timer(seconds / speed).timeout

func is_skipping() -> bool:
	return sequencer != null and sequencer.is_skipping()

func apply_snapshot(state: BattleState) -> void:
	for unit in state.units:
		var view: UnitView = unit_views.get(unit.id)
		if view != null:
			view.refresh_from_state(unit)
	if hud != null and hud.has_method("refresh_all"):
		hud.refresh_all(state)
```

`battle/battle_sequencer.gd`:

```gdscript
class_name BattleSequencer
extends Node

signal idle

var ctx: BattleContext
var playback_speed := 1.0
var _queue: Array[BattleCommand] = []
var _playing := false
var _skip := false
var _step_mode := false
var _step_requested := false
var _step_signal: Signal

func _ready() -> void:
	_step_signal = get_tree().create_timer(0.0).timeout

func enqueue(cmd: BattleCommand) -> void:
	_queue.append(cmd)

func enqueue_batch(commands: Array) -> void:
	for cmd in commands:
		_queue.append(cmd)

func play_all() -> void:
	if _playing:
		return
	_playing = true
	while not _queue.is_empty():
		if _step_mode:
			while not _step_requested and not _skip:
				await get_tree().process_frame
			_step_requested = false
		var cmd: BattleCommand = _queue.pop_front()
		if _skip:
			cmd.skip(ctx)
			continue
		await cmd.play(ctx)
	_playing = false
	idle.emit()

func skip_all() -> void:
	_skip = true
	playback_speed = 1000.0
	_queue.clear()
	if ctx != null and ctx.session != null:
		ctx.apply_snapshot(ctx.session.engine.state)
	await get_tree().create_timer(0.06, true, false, true).timeout
	playback_speed = 1.0
	_skip = false
	_playing = false
	idle.emit()

func is_skipping() -> bool:
	return _skip

func set_step_mode(enabled: bool) -> void:
	_step_mode = enabled

func request_step() -> void:
	_step_requested = true
```

`battle/commands/battle_command.gd`:

```gdscript
class_name BattleCommand
extends RefCounted

func play(_ctx: BattleContext) -> void:
	pass

func skip(_ctx: BattleContext) -> void:
	pass
```

`battle/commands/simple_event_command.gd`:

```gdscript
class_name SimpleEventCommand
extends BattleCommand

var event: BattleEvent

func _init(p_event: BattleEvent) -> void:
	event = p_event

func play(ctx: BattleContext) -> void:
	match event.type:
		&"round_start":
			await ctx.wait(0.35)
		&"action_start":
			await _play_action_start(ctx)
		&"damage", &"status_tick":
			await _play_damage(ctx)
		&"heal":
			await _play_heal(ctx)
		&"death":
			var view: UnitView = ctx.unit_view(event.target_ids[0]) if not event.target_ids.is_empty() else null
			if view != null:
				await view.die()
		&"status_apply", &"status_refresh", &"status_expire", &"mp_change", &"item_used", &"defend", &"flee_attempt", &"flee_result", &"action_skipped":
			var view: UnitView = ctx.unit_view(event.source_id)
			if view != null and view.unit_state != null:
				view.set_statuses(view.unit_state.statuses)
				view.set_mp(view.unit_state.mp, true)
			await ctx.wait(0.08)
		&"battle_end":
			ctx.session.show_result(int(event.data.get("outcome", BattleTypes.Outcome.NONE)))
		_:
			await ctx.wait(0.02)

func _play_action_start(ctx: BattleContext) -> void:
	var source: UnitView = ctx.unit_view(event.source_id)
	if source == null:
		return
	var kind := String(event.data.get("kind", "attack"))
	if kind == "attack":
		var target: UnitView = ctx.unit_view(event.target_ids[0]) if not event.target_ids.is_empty() else null
		if target != null:
			await source.lunge_to(target.global_position)
			await ctx.wait(0.08)
		else:
			await ctx.wait(0.15)
	elif kind == "skill":
		await source.cast_pose()
	elif kind == "defend":
		source.set_selected(false)
		await ctx.wait(0.18)
	else:
		await ctx.wait(0.12)

func _play_damage(ctx: BattleContext) -> void:
	var target: UnitView = ctx.unit_view(event.target_ids[0]) if not event.target_ids.is_empty() else null
	if target == null:
		return
	target.set_hp(int(event.data.get("hp_after", target.unit_state.hp)), true)
	await target.hurt()
	ctx.camera.shake(5.0, 0.12)
	if String(event.data.get("source_type", "")) == "status_tick":
		ctx.camera.shake(2.0, 0.08)
	await ctx.wait(0.08)
	var source: UnitView = ctx.unit_view(event.source_id)
	if source != null and String(event.data.get("kind", "")) != "skill":
		source.reset_pose()

func _play_heal(ctx: BattleContext) -> void:
	var target: UnitView = ctx.unit_view(event.target_ids[0]) if not event.target_ids.is_empty() else null
	if target != null:
		target.set_hp(int(event.data.get("hp_after", target.unit_state.hp)), true)
	await ctx.wait(0.18)
```

`battle/battle_director.gd`:

```gdscript
class_name BattleDirector
extends RefCounted

func build(events: Array[BattleEvent]) -> Array[BattleCommand]:
	var commands: Array[BattleCommand] = []
	for event in events:
		commands.append(SimpleEventCommand.new(event))
	return commands
```

`battle/battle_session.gd`:

```gdscript
class_name BattleSession
extends Node

signal battle_finished(outcome: int)

var content: ContentDB
var encounter: EncounterData
var engine: BattleEngine
var context: BattleContext
var director := BattleDirector.new()
var sequencer: BattleSequencer
var auto_mode := false
var seed_value := 20261024
var _script_state: EncounterScript

func start(p_seed: int = 20261024) -> void:
	seed_value = p_seed
	content = ContentDB.load_all()
	encounter = content.get_encounter(&"enc_bamboo_01")
	engine = BattleEngine.new(encounter, content, seed_value)
	_script_state = encounter.script_data
	if _script_state != null:
		_script_state.reset()
	sequencer.ctx = context
	context.session = self
	context.sequencer = sequencer
	_build_units()
	if auto_mode:
		auto_play()
	else:
		await _run_battle()

func _build_units() -> void:
	var enemy_positions := [Vector2(330, 700), Vector2(500, 740), Vector2(670, 780), Vector2(840, 820)]
	var ally_positions := [Vector2(1500, 790), Vector2(1330, 760), Vector2(1160, 730)]
	for index in engine.state.units.size():
		var unit := engine.state.units[index]
		var view := UnitView.new()
		context.scene.add_child(view)
		var is_ally := unit.side == BattleTypes.Side.ALLY
		var pos: Vector2 = ally_positions[unit.slot] if is_ally else enemy_positions[unit.slot]
		view.setup(unit, pos, is_ally)
		context.unit_views[unit.id] = view

func _run_battle() -> void:
	if _script_state != null and context.hud != null:
		for beat in _script_state.beats_for_start():
			await context.hud.play_beat(beat)
	while not engine.is_over():
		var intents: Array[BattleIntent]
		if auto_mode or context.hud == null:
			intents = _auto_intents()
		else:
			intents = await context.hud.collect_intents(engine, content)
		var events := engine.resolve_round(intents)
		for command in director.build(events):
			sequencer.enqueue(command)
		await sequencer.play_all()
		if context.hud != null:
			context.hud.refresh_all(engine.state)
	battle_finished.emit(engine.state.outcome)

func auto_play() -> void:
	auto_mode = true
	await _run_battle()

func _auto_intents() -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	var allies := engine.state.living(BattleTypes.Side.ALLY)
	var enemies := engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return intents
	for ally in allies:
		if ally.id == &"hero_healer" and ally.mp >= 30:
			var target := _lowest_ally(allies)
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [target.id], &"heal_single"))
		elif ally.id == &"hero_mage" and ally.mp >= 25:
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"fire_spell"))
		else:
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [enemies[0].id]))
	return intents

func _lowest_ally(allies: Array[BattleUnitState]) -> BattleUnitState:
	var sorted := allies.duplicate()
	sorted.sort_custom(func(a, b): return float(a.hp) / a.data.max_hp < float(b.hp) / b.data.max_hp)
	return sorted[0] if not sorted.is_empty() else null


func show_result(outcome: int) -> void:
	var label := Label.new()
	label.text = "胜利！" if outcome == BattleTypes.Outcome.VICTORY else ("逃跑成功" if outcome == BattleTypes.Outcome.ESCAPED else "战败…")
	label.add_theme_font_override("font", FontUtil.cjk_font())
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(660, 380)
	label.size = Vector2(600, 100)
	context.ui_layer.add_child(label)
```

`battle/battle_scene.gd`:

```gdscript
extends Node2D

func _ready() -> void:
	var background := BackgroundView.new()
	background.name = "Background"
	add_child(background)

	var camera := CameraRig.new()
	camera.name = "CameraRig"
	add_child(camera)
	camera.make_current()

	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	var vfx_layer := Node2D.new()
	vfx_layer.name = "VFXLayer"
	add_child(vfx_layer)

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	var session := BattleSession.new()
	session.name = "BattleSession"
	add_child(session)

	var sequencer := BattleSequencer.new()
	sequencer.name = "BattleSequencer"
	add_child(sequencer)

	var ctx := BattleContext.new(get_tree(), self)
	ctx.scene = world
	ctx.camera = camera
	ctx.vfx_layer = vfx_layer
	ctx.session = session
	ctx.sequencer = sequencer
	ctx.ui_layer = ui_layer
	session.context = ctx
	session.sequencer = sequencer
	session.auto_mode = true
	session.start(20261024)
```

`tools/smoke_presentation.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	root.add_child(scene)
	var session: BattleSession = scene.get_node("BattleSession")
	session.battle_finished.connect(func(_outcome: int) -> void:
		print("PRESENTATION_SMOKE_OK")
		quit(0)
	)
	await create_timer(20.0).timeout
	printerr("PRESENTATION_SMOKE_TIMEOUT")
	quit(1)
```

`tools/screenshot.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	root.add_child(scene)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	for index in 3:
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "user://screenshots/task1_%d.png" % index
		image.save_png(path)
		print("SCREENSHOT: " + ProjectSettings.globalize_path(path))
	quit(0)
```

- [ ] **Step 2: 运行核心门禁与表现冒烟**

```bash
bash godot-battle/tools/run_tests.sh
godot --headless --path godot-battle -s tools/smoke_presentation.gd
```

Expected: core gate 0 failures；smoke `PRESENTATION_SMOKE_OK`，退出码 0。

- [ ] **Step 3: 截图检查**

```bash
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot.gd
```

Expected: 3 张 PNG 输出到 `user://screenshots/`；用图像查看工具确认：背景三层、7 个单位、血蓝条、名字可读、无 UI 遮挡（本任务暂无 HUD）。

- [ ] **Step 4: 提交**

```bash
git add godot-battle/project.godot godot-battle/scenes godot-battle/battle godot-battle/ui/font_util.gd godot-battle/tools/smoke_presentation.gd godot-battle/tools/screenshot.gd
git commit -m "feat(presentation): 战场场景、单位视图与自动播放"
```

---

## Task 2: 命令框架、VFX、飘字、打击反馈、回合横幅与胜负

**Files:**
- Modify: `battle/battle_director.gd`, `battle/battle_session.gd`, `battle/commands/simple_event_command.gd`
- Create: `battle/command_registry.gd`, `battle/vfx_factory.gd`, `battle/float_text.gd`
- Create: `battle/commands/action_start_command.gd`, `damage_command.gd`, `heal_command.gd`, `status_command.gd`, `death_command.gd`, `round_banner_command.gd`, `battle_end_command.gd`

**Requirements:** 用 `CommandRegistry` 按事件类型分发；`action_start` 前冲/施法/防御；`damage` 飘字（暴击金色大字）、白闪、击退、血条缓动、屏震、短暂顿帧；`heal` 绿色飘字+治疗光效；`status_tick` 紫色飘字；`status_apply/expire` 图标更新；`death` 消散；`round_start` 顶部「第 N 回合」横幅 + 行动顺序预热；`battle_end` 结算面板。VFX 用程序化粒子/Line2D：火、雷、风/水、治疗、封印、斩击。所有表现随机用独立 `RandomNumberGenerator`。

**Verification:** gate + smoke + screenshot（攻击/法术帧），检查飘字/特效/横幅；不修改 core/content。

---

## Task 3: HUD 指令阶段、目标选择、倒计时与战斗日志

**Files:**
- Create: `ui/battle_hud.gd`, `ui/target_selector.gd`, `ui/battle_log.gd`
- Modify: `battle/battle_session.gd`, `battle/battle_scene.gd`

**Requirements:** 右下指令面板（攻击/法术/道具/防御 + 独立逃跑）；法术/道具子菜单；目标选择箭头与合法目标高亮；点击/数字键选择；可返回重选；25 秒倒计时，超时自动为剩余角色生成「普攻随机敌人」意图（不要把超时丢给 core 的 missing→defend）；战斗日志左下（颜色区分伤害/治疗/状态）；左上行动顺序条（`round_start.order` 实时高亮）；回合横幅；播放期间隐藏面板；1x/2x 与「跳过本回合」按钮（跳过调用 `sequencer.skip_all()` 并刷新视图）。

**Verification:** gate + smoke（含 UI 指令阶段至少一回合）+ 截图（面板/目标箭头/日志）；手动跑一局确认可点击完成 3 个角色指令。

---

## Task 4: 对白、气泡、技能喊招、胜负演出、音效与播放控制

**Files:**
- Create: `ui/dialogue_box.gd`, `ui/bubble.gd`, `ui/victory_panel.gd`, `battle/audio_director.gd`
- Create: `battle/commands/dialogue_command.gd`, `bubble_command.gd`
- Modify: `battle/battle_session.gd`, `battle/battle_director.gd`, `ui/battle_hud.gd`

**Requirements:** 读 `encounter.script_data` 的 `intro_lines/first_kill_lines/victory_lines/defeat_lines`；开场对白、首次击杀对白、胜利/失败对白；技能出手时 `SkillData.shout_text` 气泡；电影黑边 + 打字机对白；胜利/失败面板显示经验 1200/金币 350 与「再战一场」；音效缺失时静默（可用程序化短音或免费 CC0，不阻塞）；1x/2x/跳过与日志保持可用。

**Verification:** gate + smoke + 截图（对白/气泡/胜利面板）；手动完整一局。

---

## Plan 2A Acceptance

1. `bash godot-battle/tools/run_tests.sh` 0 failures。
2. `godot --headless --path godot-battle -s tools/smoke_presentation.gd` → `PRESENTATION_SMOKE_OK`。
3. 非 headless 可手动完成 3v4 战斗：指令、技能、道具、防御、逃跑、胜负、对白、日志、倍速/跳过。
4. 1080p 截图可读，特效不遮挡指令面板。
5. 不修改 `core/` 与 `data/`，核心黄金回放仍通过。

## Plan 2B (后续，不在本计划执行)

- 调试控制台/浮层/单步、录像回放播放、快照校验、fuzz 命令。
- 视觉目录 + AI 原创 Q 版立绘/背景/图标/UI 皮肤（或免费 CC0 + 程序化兜底），不写入 `data/`。
- README/DEBUGGING/EXTENDING、PROGRESS/TECH_NOTES 更新、全量验收与最终审查。
