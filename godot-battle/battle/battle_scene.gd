extends Node2D

# 工具（冒烟/截图）在 add_child 前设为 true，即可跳过手动指令阶段。
var start_auto_mode := false

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _ready() -> void:
	# UnitView 用 Area2D 接收点击，需开启视口物理拾取。
	get_viewport().physics_object_picking = true
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

	var hud := BattleHUD.new()
	hud.name = "BattleHUD"
	ui_layer.add_child(hud)
	hud.setup(ctx)
	ctx.hud = hud

	session.context = ctx
	session.sequencer = sequencer
	session.context.hud = hud
	session.auto_mode = start_auto_mode
	session.start(20261024)
