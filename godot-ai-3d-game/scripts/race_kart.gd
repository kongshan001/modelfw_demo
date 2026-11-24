class_name RaceKart
extends Node3D

# 街机式卡丁车控制器。玩家与 AI 共用同一个视觉体和赛道查询；
# 玩家受输入/赛道边界约束，AI 沿中心线带车道摆动，并带轻微橡皮筋。

signal bumped

const MAX_SPEED := 24.0
const BOOST_SPEED := 31.0
const REVERSE_SPEED := 6.5
const ACCELERATION := 14.5
const BRAKE_FORCE := 27.0
const COAST := 6.0
const LANE_LIMIT := 5.55
const WALL_LIMIT := 6.55

var is_player := false
var display_name := "车手"
var track: RaceTrack
var visual: KartVisual

var speed := 0.0
var yaw := 0.0
var race_distance := 0.0
var last_progress := 0.0
var boost_timer := 0.0
var boost_count := 0
var best_speed := 0.0
var finished := false
var active := false
var auto_drive := false
var finish_place := 0
var current_place := 1
var bump_timer := 0.0

var ai_lane := 0.0
var ai_progress := 0.0
var ai_base_speed := 19.0
var ai_phase := 0.0
var ai_speed_smooth := 0.0
var start_progress := 0.0
var _steer_visual := 0.0


func setup(p_track: RaceTrack, player: bool, body: Color, accent: Color, lane: float, speed_base := 19.0) -> void:
	track = p_track
	is_player = player
	ai_lane = lane
	ai_base_speed = speed_base
	ai_phase = randf() * TAU
	visual = KartVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup(body, accent, player)
	name = "PlayerKart" if player else "RivalKart"


func reset_at(progress: float, lane: float) -> void:
	var xf := track.grid_transform(progress, lane)
	global_position = xf.origin
	yaw = xf.basis.get_euler().y
	rotation.y = yaw
	speed = 0.0
	boost_timer = 0.0
	boost_count = 0
	best_speed = 0.0
	finished = false
	finish_place = 0
	current_place = 1
	active = false
	race_distance = 0.0
	start_progress = wrapf(progress, 0.0, track.length)
	last_progress = start_progress
	ai_progress = start_progress
	ai_speed_smooth = 0.0
	if visual != null:
		visual.update_motion(0.016, 0.0, 0.0, false)


func release() -> void:
	active = true


func stop() -> void:
	active = false
	speed = 0.0
	if visual != null:
		visual.update_motion(0.016, 0.0, 0.0, false)


func step_player(delta: float) -> void:
	if not active or finished:
		if visual != null:
			visual.update_motion(delta, 0.0, 0.0, false)
		return
	if bump_timer > 0.0:
		bump_timer = maxf(0.0, bump_timer - delta)
	var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
	var steer := Input.get_axis("steer_left", "steer_right")
	if auto_drive:
		var near := track.nearest(global_position)
		var look := track.point_at(float(near["progress"]) + 14.0)
		var to_look := look - global_position
		var desired_yaw := atan2(-to_look.x, -to_look.z)
		var angle_diff := wrapf(desired_yaw - yaw, -PI, PI)
		steer = -clampf(angle_diff * 2.4, -1.0, 1.0)
		throttle = 1.0 if absf(angle_diff) < 0.75 else 0.25
	if boost_timer > 0.0:
		boost_timer = maxf(0.0, boost_timer - delta)
		speed = move_toward(speed, BOOST_SPEED, 25.0 * delta)
	else:
		if throttle > 0.01:
			speed = move_toward(speed, MAX_SPEED, ACCELERATION * delta * throttle)
		elif throttle < -0.01:
			if speed > 0.0:
				speed = move_toward(speed, 0.0, BRAKE_FORCE * delta)
			else:
				speed = move_toward(speed, -REVERSE_SPEED, 8.0 * delta)
		else:
			speed = move_toward(speed, 0.0, COAST * delta)

	var speed_norm := clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
	var turn_rate := lerpf(2.35, 1.12, speed_norm)
	if absf(speed) > 0.35:
		yaw -= steer * turn_rate * delta * signf(speed) * clampf(absf(speed) / 7.0, 0.22, 1.0)
	rotation.y = yaw

	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var next_pos := global_position + forward * speed * delta
	var near := track.nearest(next_pos)
	var lateral := float(near["lateral"])
	if absf(lateral) > WALL_LIMIT:
		var right: Vector3 = near["right"]
		var tangent: Vector3 = near["tangent"]
		var center: Vector3 = near["center"]
		var along := (next_pos - center).dot(tangent)
		next_pos = center + right * signf(lateral) * WALL_LIMIT + tangent * along
		next_pos.y = 0.0
		speed *= 0.70
		if bump_timer <= 0.0:
			bump_timer = 0.35
			bumped.emit()
	global_position = next_pos
	global_position.y = 0.0
	near = track.nearest(global_position)
	_advance(float(near["progress"]))
	best_speed = maxf(best_speed, absf(speed))
	_steer_visual = steer
	if visual != null:
		visual.update_motion(delta, speed, steer, boost_timer > 0.0)


func step_ai(delta: float, player_distance: float) -> void:
	if not active or finished:
		if visual != null:
			visual.update_motion(delta, 0.0, 0.0, false)
		return
	var curve := track.curvature_at(ai_progress)
	var rubber := clampf(1.0 + (player_distance - race_distance) * 0.0030, 0.95, 1.20)
	var target_speed := ai_base_speed * lerpf(1.0, 0.82, curve) * rubber
	ai_speed_smooth = move_toward(ai_speed_smooth, target_speed, 8.5 * delta)
	speed = ai_speed_smooth
	race_distance += speed * delta
	var track_pos := fposmod(start_progress + race_distance, track.length)
	var wobble := sin(race_distance * 0.034 + ai_phase) * 0.80
	var lane := clampf(ai_lane + wobble, -LANE_LIMIT, LANE_LIMIT)
	global_position = track.point_at(track_pos) + track.right_at(track_pos) * lane
	var desired := track.point_at(track_pos + 4.0) - track.point_at(track_pos)
	var target_yaw := atan2(-desired.x, -desired.z)
	var turn := wrapf(target_yaw - yaw, -PI, PI)
	yaw = wrapf(yaw + turn * (1.0 - exp(-delta * 7.0)), -PI, PI)
	rotation.y = yaw
	_steer_visual = clampf(turn * 1.6, -1.0, 1.0)
	ai_progress = track_pos
	last_progress = track_pos
	best_speed = maxf(best_speed, absf(speed))
	if visual != null:
		visual.update_motion(delta, speed, _steer_visual, false)


func _advance(progress: float) -> void:
	var delta := wrapf(progress - last_progress, -track.length * 0.5, track.length * 0.5)
	race_distance = maxf(0.0, race_distance + delta)
	last_progress = progress


func apply_boost(seconds: float) -> bool:
	if not active or finished:
		return false
	if boost_timer <= 0.0:
		boost_count += 1
	boost_timer = maxf(boost_timer, seconds)
	speed = maxf(speed, MAX_SPEED + 1.5)
	return true


func progress_ratio() -> float:
	return clampf(race_distance / maxf(0.001, track.length), 0.0, 1.0)


func speed_kmh() -> float:
	return absf(speed) * 3.6


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func mark_finished(place: int) -> void:
	finished = true
	active = false
	finish_place = place
	speed = 0.0
	if visual != null:
		visual.update_motion(0.016, 0.0, 0.0, false)
