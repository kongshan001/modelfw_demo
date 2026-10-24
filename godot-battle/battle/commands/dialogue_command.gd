class_name DialogueCommand
extends BattleCommand

# 剧情对白命令：经 DialogueBox 播放；无对白框时退化为日志 + 短等待。

var lines: Array = []

func _init(p_lines: Array) -> void:
	lines = p_lines.duplicate()

func play(ctx: BattleContext) -> void:
	if lines.is_empty():
		return
	if ctx.hud != null and ctx.hud.has_method("log_system"):
		for line in lines:
			ctx.hud.log_system(String(line), Color(0.86, 0.88, 0.95))
	if ctx.dialogue != null:
		if ctx.sequencer != null:
			ctx.dialogue.clock_scale = maxf(1.0, ctx.sequencer.playback_speed)
		await ctx.dialogue.play_lines(lines)
		if ctx.dialogue != null:
			ctx.dialogue.clock_scale = 1.0
	else:
		for line in lines:
			await ctx.wait(0.8)

func skip(ctx: BattleContext) -> void:
	if ctx.dialogue != null:
		ctx.dialogue.hide_now()
