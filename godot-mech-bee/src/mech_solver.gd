extends RefCounted

# Pure flight / telemetry solver for the Mellis HB-7.
# No nodes, no rendering: motion and HUD numbers are derived from the same
# functions, so the gauges can never disagree with the model.

const STATES := [
	"HOVER", "BANKING", "WING OFF", "ABDOMEN OPEN",
	"THORAX OPEN", "TEARDOWN", "REASSEMBLY", "DEPARTING",
]

var t := 0.0
var state := "HOVER"
var paused := false


func step(delta: float) -> void:
	if not paused:
		t += delta


func beat_hz() -> float:
	match state:
		"HOVER":
			return 4.2
		"BANKING":
			return 5.0
		"ABDOMEN OPEN":
			return 2.1
		"THORAX OPEN":
			return 2.4
		"WING OFF", "TEARDOWN", "REASSEMBLY":
			return 0.0
		"DEPARTING":
			return 5.6
		_:
			return 3.0


func wing_amplitude_deg() -> float:
	return 32.0


func wing_angle(index: int) -> float:
	var hz := beat_hz()
	if hz <= 0.001:
		return 0.0
	var phase := TAU * hz * t + float(index) * 1.7
	return deg_to_rad(wing_amplitude_deg()) * sin(phase)


func wing_signal(index: int) -> float:
	var hz := beat_hz()
	if hz <= 0.001:
		return sin(t * 1.2) * 0.06
	return sin(TAU * hz * t + float(index) * 1.7)


func wing_angle_at(index: int, phase_offset: float) -> float:
	var hz := beat_hz()
	if hz <= 0.001:
		return 0.0
	var phase := TAU * hz * t + float(index) * 1.7 + phase_offset
	return deg_to_rad(wing_amplitude_deg()) * sin(phase)


func bob() -> float:
	return sin(t * 1.25) * 0.045 + sin(t * 0.37) * 0.018


func pitch_deg() -> float:
	var base := sin(t * 0.45) * 1.2
	if state == "BANKING":
		base += 6.0
	elif state == "DEPARTING":
		base -= 8.0
	return base


func roll_deg() -> float:
	var base := sin(t * 0.7) * 1.4
	if state == "BANKING":
		base += 14.0
	return base


func yaw_drift() -> float:
	return sin(t * 0.21) * 0.045


func battery() -> float:
	return clampf(0.83 - t * 0.00002, 0.0, 1.0)


func power_draw() -> float:
	return 35.2 + 6.4 * (beat_hz() / 5.0) + sin(t * 1.7) * 0.4


func cell_v() -> float:
	return 3.70 - sin(t * 0.3) * 0.004


func motor_temp() -> float:
	return 38.0 + 4.2 * (beat_hz() / 5.0) + sin(t * 0.4) * 0.3


func servo_load(i: int) -> float:
	var base := 0.33 + 0.26 * absf(sin(t * 1.1 + float(i) * 0.9))
	if state == "BANKING":
		base += 0.12 * (1.0 if i % 2 == 0 else 0.5)
	elif state == "TEARDOWN" or state == "REASSEMBLY":
		base *= 0.4
	return clampf(base, 0.0, 1.0)


func lift_load() -> float:
	var base := 0.56 + 0.16 * sin(t * 0.9)
	if state == "DEPARTING":
		base += 0.18
	return clampf(base, 0.0, 1.0)


func alt_agl() -> float:
	var base := 150.0 + sin(t * 0.8) * 2.1
	if state == "DEPARTING":
		base += 34.0
	return base


func vertical_speed() -> float:
	return 0.8 if state == "DEPARTING" else sin(t * 0.8) * 0.02


func runtime_text() -> String:
	var total := int(t)
	return "00:%02d:%02d" % [total / 60, total % 60]


func status_text() -> String:
	return state


func flight_mode_text() -> String:
	return state


func mode_hint() -> String:
	match state:
		"HOVER":
			return "AUTO HOLD · FIELD 3"
		"BANKING":
			return "ROLL 14° · CROSSWIND"
		"WING OFF":
			return "STARBOARD ROOT DISENGAGED"
		"ABDOMEN OPEN":
			return "CAPSULE 95% APART · SERVICE"
		"THORAX OPEN":
			return "SHELL SEGMENT 2 REMOVED"
		"TEARDOWN":
			return "FULL EXPLODED VIEW"
		"REASSEMBLY":
			return "RETURNING TO FLIGHT POSE"
		"DEPARTING":
			return "CLIMB · 34 MM AGL"
		_:
			return ""


func subsystem_rows() -> Array:
	var drive := "RUNNING" if beat_hz() > 0.01 else "STOPPED"
	var drive_color := "green" if beat_hz() > 0.01 else "amber"
	var wings := "PARKED" if beat_hz() <= 0.01 else "SPINNING"
	var wings_color := "amber" if beat_hz() <= 0.01 else "green"
	var capsule := "OPEN" if state == "ABDOMEN OPEN" or state == "TEARDOWN" or state == "REASSEMBLY" else "SEALED"
	var capsule_color := "red" if capsule == "OPEN" else "green"
	var legs := "ONLINE" if state != "TEARDOWN" else "SERVICE"
	var legs_color := "green" if legs == "ONLINE" else "amber"
	return [
		{"name": "OPTIC HEAD", "detail": "2 × 5.8 MM LENS · AMBER IR", "status": "LINKED", "color": "green"},
		{"name": "NECK BEARING", "detail": "36-ROLLER COLLAR", "status": "LOCKED", "color": "green"},
		{"name": "THORAX DRIVE", "detail": "6 ACTUATORS", "status": drive, "color": drive_color},
		{"name": "WING ROOTS", "detail": "4 WINGS · 7.5 N·M CRANK", "status": wings, "color": wings_color},
		{"name": "LEG SERVOS", "detail": "6 JOINTS", "status": legs, "color": legs_color},
		{"name": "ABDOMEN CAPSULE", "detail": "GEAR TRAIN · RETURN SPRING", "status": capsule, "color": capsule_color},
	]


func servo_names() -> Array:
	return ["L1", "L2", "L3", "R1", "R2", "R3"]
