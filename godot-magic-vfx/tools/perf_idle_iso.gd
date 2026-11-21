extends SceneTree
var main
var hud
var vig
var states := ["FULL", "NO_HUD", "NO_VIGNETTE", "NO_HUD_VIG", "NO_LIGHTS", "NO_DUST", "NO_LANTERNS"]
func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await create_timer(5.0, true, false, true).timeout
	main.capture_mode = true
	main.display_still = true
	main.auto_demo = false
	hud = main.get_node("HudLayer")
	vig = main.get_node("VignetteLayer")
	var light_nodes := []
	for c in main.get_children():
		if c is DirectionalLight3D or c is OmniLight3D:
			light_nodes.append(c)
	var dust = null
	for c in main.get_node("VfxRoot").get_children():
		if c is GPUParticles3D:
			dust = c
	for st in states:
		hud.visible = st != "NO_HUD" and st != "NO_HUD_VIG"
		vig.visible = st != "NO_VIGNETTE" and st != "NO_HUD_VIG"
		for l in light_nodes:
			l.visible = st != "NO_LIGHTS"
		if dust: dust.visible = st != "NO_DUST"
		for lant in main.lanterns:
			lant.visible = st != "NO_LANTERNS"
		await create_timer(0.3, true, false, true).timeout
		var start := Time.get_ticks_msec(); var last := start; var frames := 0; var maxdt := 0.0; var slow := 0
		while Time.get_ticks_msec() - start < 3000:
			await process_frame
			frames += 1
			var now := Time.get_ticks_msec(); var dt := now - last; last = now
			maxdt = maxf(maxdt, float(dt))
			if dt > 100: slow += 1
		var total := float(Time.get_ticks_msec() - start) / 1000.0
		print("IDLEISO %s fps=%.2f slow=%d maxdt=%.0f" % [st, frames / total, slow, maxdt])
	# restore
	hud.visible = true; vig.visible = true
	for l in light_nodes: l.visible = true
	if dust: dust.visible = true
	for lant in main.lanterns: lant.visible = true
	print("IDLEISO_DONE")
	quit(0)
