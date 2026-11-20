extends SceneTree

# T-20261121-001 美术自检 render rig：walk 侧向 / 正面逐帧 + 8 关键帧接触表。
# 只读取 PaperDollRenderer 与 DollPose，不修改游戏逻辑。
#
# 用法：
#   godot --path godot-paper-doll --resolution 1280x720 -s tools/walk_rig.gd -- \
#       --out=res://docs/shots/walk/side_frames --dir=6 --seconds=2 --scale=2.05
#
# 产出：
#   <out>/frame_000.png ...（640×360 @30fps）
#   <out>/contact_000.png ...（1280×720 大图，供接触表裁切）
# 正/侧向都用同一 rig；GIF 由 tools/record_walk.sh 合成。

const STAGE_W := 640
const STAGE_H := 360
const FPS := 30.0
const CYCLE := 0.82


func _initialize() -> void:
	var out := "res://docs/shots/walk/side_frames"
	var dir := 6
	var seconds := 2.0
	var display_scale := 2.05
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--dir="):
			dir = int(arg.trim_prefix("--dir="))
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--scale="):
			display_scale = float(arg.trim_prefix("--scale="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	var lineup: Array = DollData.load_lineup()
	if lineup.size() != 16:
		lineup = DollData.fallback_lineup()
	var outfit: Dictionary = lineup[0]["outfit"]

	await _render_run(out, outfit, dir, seconds, display_scale, false)
	await _render_run(out, outfit, dir, 8.0 / FPS, 4.0, true)
	print("WALK_RIG_OK out=%s dir=%d frames=%d" % [out, dir, int(round(seconds * FPS))])
	quit(0)


func _render_run(out: String, outfit: Dictionary, dir: int, seconds: float,
		display_scale: float, contact: bool) -> void:
	var w := 1280 if contact else STAGE_W
	var h := 720 if contact else STAGE_H
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var stage := StageBackdrop.new()
	stage.size = Vector2(w, h)
	vp.add_child(stage)

	var doll := PaperDollRenderer.new()
	doll.animate = false
	doll.show_shadow = true
	doll.show_effects = false
	doll.set_doll(outfit, dir, "walk")
	doll.set_display_scale(display_scale)
	doll.position = Vector2(w * 0.5, h - (60.0 if contact else 30.0))
	vp.add_child(doll)

	var count := int(round(seconds * FPS))
	for i in count:
		if contact:
			# 8 keys：0, 0.125, … 0.875 × 0.82s。
			doll.set_clock(CYCLE * float(i) / 8.0)
		else:
			doll.set_clock(float(i) / FPS)
		await _settle()
		var image := vp.get_texture().get_image()
		var path := out + ("/contact_%03d.png" % i if contact else "/frame_%03d.png" % i)
		image.save_png(path)
	if contact:
		print("WALK_CONTACT_OK ", out)
	else:
		print("WALK_FRAMES_OK ", out)

	vp.queue_free()
	await process_frame


func _settle() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
