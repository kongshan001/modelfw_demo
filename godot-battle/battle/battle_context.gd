class_name BattleContext
extends RefCounted

var scene_tree: SceneTree
var scene: Node2D
var session: Node
var sequencer: BattleSequencer
var camera: CameraRig
var vfx_layer: Node2D
var hud: Control
var audio: AudioDirector
var dialogue: DialogueBox
var bubble: Bubble
var victory_panel: VictoryPanel
var ui_layer: CanvasLayer

var unit_views: Dictionary = {}
var visual_rng := RandomNumberGenerator.new()
var _vfx: VFXFactory

func _init(p_tree: SceneTree, p_scene: Node2D) -> void:
	scene_tree = p_tree
	scene = p_scene
	visual_rng.seed = 9001

func unit_view(unit_id: StringName) -> UnitView:
	return unit_views.get(unit_id)

func vfx_factory() -> VFXFactory:
	if _vfx == null:
		_vfx = VFXFactory.new(scene_tree, vfx_layer, ui_layer, visual_rng.seed)
	return _vfx

func wait(seconds: float) -> void:
	var speed := maxf(0.001, sequencer.playback_speed if sequencer != null else 1.0)
	await scene_tree.create_timer(seconds / speed).timeout

func play_sfx(sfx_name: StringName) -> void:
	if audio != null:
		audio.play_sfx(sfx_name)

func is_skipping() -> bool:
	return sequencer != null and sequencer.is_skipping()

func apply_snapshot(state: BattleState) -> void:
	for unit in state.units:
		var view: UnitView = unit_views.get(unit.id)
		if view != null:
			view.refresh_from_state(unit)
	if hud != null and hud.has_method("refresh_all"):
		hud.refresh_all(state)
