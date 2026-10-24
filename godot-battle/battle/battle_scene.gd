extends Node2D

func _exit_tree() -> void:
	Engine.time_scale = 1.0

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
