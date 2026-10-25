class_name CommandRegistry
extends RefCounted

# 事件类型 → 表现命令。未知/无专属表现的事件回落到短等待命令。

var content: ContentDB

func _init(p_content: ContentDB = null) -> void:
	content = p_content

func create(event: BattleEvent) -> BattleCommand:
	match event.type:
		&"round_start":
			return RoundBannerCommand.new(event)
		&"action_start":
			return ActionStartCommand.new(event, content)
		&"damage":
			return DamageCommand.new(event, content)
		&"heal":
			return HealCommand.new(event)
		&"status_tick", &"status_apply", &"status_refresh", &"status_expire":
			return StatusCommand.new(event, content)
		&"death":
			return DeathCommand.new(event)
		&"battle_end":
			return BattleEndCommand.new(event)
		_:
			return SimpleEventCommand.new(event)
