class_name PatternRunner
extends RefCounted

const ArtRes = preload("res://scripts/art.gd")
const Pool = preload("res://scripts/bullet_pool.gd")

# 10 种数据驱动弹幕。每种 pattern 只负责“何时、从哪、以什么速度/行为发射”；
# 运动、碰撞、回收由 Pool 统一处理。
# 参数取自教程的节奏语言（方向组 / 速度组 / 行为组），数值为本项目独立调校。

const COUNT := 10
const NAMES := [
	"单发·瞄准",
	"三向扇",
	"五向扇",
	"环形",
	"双翼螺旋",
	"连射·加速层",
	"正弦花瓣",
	"追踪",
	"定时分裂",
	"旋转弹幕墙",
]
const CODES := ["P01", "P02", "P03", "P04", "P05", "P06", "P07", "P08", "P09", "P10"]
const SUMMARIES := [
	"每 0.72s 朝玩家发 1 发 · 300px/s",
	"每 0.95s 扇形 3 发 · ±13° · 260px/s",
	"每 1.25s 扇形 5 发 · ±22° · 240px/s",
	"每 1.35s 环形 24 发 · 每波转 7° · 230px/s",
	"每 0.055s 双臂各 1 发 · 角度每发 +10°",
	"每 2.3s 三连脉冲 × 5 层速度 · 200→460px/s",
	"每 2.4s 48 发正弦花瓣 · 速度随 cos(3θ) 调制",
	"每 1.35s 追踪扇 5 发 · 转向 1.9rad/s × 2.6s",
	"每 2.0s 大弹 2 发 · 1.05s 后各分裂 12 发",
	"每 2.5s 21 列墙 · 3 列缺口随波次旋转",
]

var pattern_id := 0
var time := 0.0
var timer := 0.0
var wave := 0
var angle := 0.0
var burst_left := 0
var burst_clock := 0.0
var total_shots := 0
var seed_value := 0xB17B17
var rng := RandomNumberGenerator.new()

func _init(id := 0, p_seed := 0xB17B17) -> void:
	setup(id, p_seed)

func setup(id: int, p_seed := 0xB17B17) -> void:
	pattern_id = clampi(id, 0, COUNT - 1)
	seed_value = p_seed
	time = 0.0
	timer = 0.0
	wave = 0
	angle = 0.0
	burst_left = 0
	burst_clock = 0.0
	total_shots = 0
	rng.seed = seed_value

func name() -> String:
	return NAMES[pattern_id]

func code() -> String:
	return CODES[pattern_id]

static func name_of(id: int) -> String:
	return NAMES[clampi(id, 0, COUNT - 1)]

static func code_of(id: int) -> String:
	return CODES[clampi(id, 0, COUNT - 1)]

static func summary_of(id: int) -> String:
	return SUMMARIES[clampi(id, 0, COUNT - 1)]

func update(dt: float, pool: Pool, boss_pos: Vector2, player_pos: Vector2) -> void:
	time += dt
	timer -= dt
	var aim := player_pos - boss_pos
	if aim.length_squared() < 1.0:
		aim = Vector2.DOWN
	aim = aim.normalized()
	match pattern_id:
		0:
			if timer <= 0.0:
				var dir := _aim(boss_pos, player_pos)
				_fire(pool, boss_pos + dir * 28.0, dir * 300.0, 7.0, ArtRes.MAGENTA, Pool.Kind.ORB)
				timer += 0.72
				wave += 1
		1:
			if timer <= 0.0:
				var dir := _aim(boss_pos, player_pos)
				for k in 3:
					var a := dir.angle() + deg_to_rad(13.0) * (k - 1)
					_fire(pool, boss_pos + Vector2.from_angle(a) * 28.0, Vector2.from_angle(a) * 260.0, 6.0, ArtRes.CYAN, Pool.Kind.ORB)
				timer += 0.95
				wave += 1
		2:
			if timer <= 0.0:
				var dir := _aim(boss_pos, player_pos)
				for k in 5:
					var a := dir.angle() + deg_to_rad(11.0) * (k - 2)
					var c := ArtRes.CYAN if k % 2 == 0 else ArtRes.LILAC
					_fire(pool, boss_pos + Vector2.from_angle(a) * 30.0, Vector2.from_angle(a) * 240.0, 6.0, c, Pool.Kind.ORB)
				timer += 1.25
				wave += 1
		3:
			if timer <= 0.0:
				var base := wave * deg_to_rad(7.0)
				for k in 24:
					var a := base + TAU * float(k) / 24.0
					var c := ArtRes.bullet_color(k + wave)
					_fire(pool, boss_pos + Vector2.from_angle(a) * 32.0, Vector2.from_angle(a) * 230.0, 5.6, c, Pool.Kind.ORB)
				timer += 1.35
				wave += 1
		4:
			if timer <= 0.0:
				for arm in 2:
					var a := angle + PI * arm
					var c := ArtRes.CYAN if arm == 0 else ArtRes.MAGENTA
					_fire(pool, boss_pos + Vector2.from_angle(a) * 26.0, Vector2.from_angle(a) * 210.0, 5.6, c, Pool.Kind.ORB)
				angle += deg_to_rad(10.0)
				timer += 0.055
				wave += 1
		5:
			if timer <= 0.0:
				burst_left = 3
				burst_clock = 0.0
				timer += 2.3
				wave += 1
			if burst_left > 0:
				burst_clock -= dt
				while burst_clock <= 0.0 and burst_left > 0:
					var dir := _aim(boss_pos, player_pos)
					for j in 5:
						var a := dir.angle() + deg_to_rad(2.2) * float(j - 2)
						var c := ArtRes.bullet_color(j + 2)
						_fire(pool, boss_pos + Vector2.from_angle(a) * (26.0 + j * 8.0), Vector2.from_angle(a) * (200.0 + 65.0 * j), 6.5, c, Pool.Kind.SHARD)
					burst_left -= 1
					burst_clock += 0.10
		6:
			if timer <= 0.0:
				var phase := wave * 0.31
				for k in 48:
					var a := TAU * float(k) / 48.0
					var speed := 170.0 + 160.0 * absf(cos(3.0 * a + phase))
					var c := ArtRes.CYAN if k % 3 != 0 else ArtRes.bullet_color(k)
					pool.spawn(
						boss_pos + Vector2.from_angle(a) * 30.0,
						Vector2.from_angle(a) * speed,
						5.6, c, Pool.Kind.BLOOM, Pool.Behavior.SINE, 9.0,
						36.0, 4.2, 0.0, float(k) * 0.41, 0
					)
					total_shots += 1
				timer += 2.4
				wave += 1
		7:
			if timer <= 0.0:
				var dir := _aim(boss_pos, player_pos)
				for k in 5:
					var a := dir.angle() + deg_to_rad(8.0) * (k - 2)
					pool.spawn(
						boss_pos + Vector2.from_angle(a) * 30.0,
						Vector2.from_angle(a) * 130.0,
						7.0, ArtRes.GOLD, Pool.Kind.ORB, Pool.Behavior.HOMING, 9.0,
						1.9, 200.0, 2.6, 0.0, 0
					)
					total_shots += 1
				timer += 1.35
				wave += 1
		8:
			if timer <= 0.0:
				var dir := _aim(boss_pos, player_pos)
				for k in 2:
					var a := dir.angle() + (-0.36 if k == 0 else 0.36)
					pool.spawn(
						boss_pos + Vector2.from_angle(a) * 34.0,
						Vector2.from_angle(a) * 95.0,
						14.0, ArtRes.MAGENTA, Pool.Kind.CORE, Pool.Behavior.SPLIT, 8.0,
						1.05, 12.0, 225.0, 5.5, 0
					)
					total_shots += 1
				timer += 2.0
				wave += 1
		9:
			if timer <= 0.0:
				var tilt := sin(wave * 0.8) * deg_to_rad(5.0)
				var dir := Vector2.DOWN.rotated(tilt)
				var perp := Vector2.RIGHT.rotated(tilt)
				var gap_center := posmod(4 + wave * 4, 21)
				for k in 21:
					if absi(k - gap_center) <= 1:
						continue
					var offset := (float(k) - 10.0) * 54.0
					var origin := boss_pos + perp * offset + Vector2(0.0, 22.0).rotated(tilt)
					var c := ArtRes.LILAC if k % 2 == 0 else ArtRes.CYAN
					pool.spawn(origin, dir * 158.0, 8.0, c, Pool.Kind.SHARD, Pool.Behavior.STRAIGHT, 8.0, 0.0, 0.0, 0.0, 0.0, 0)
					total_shots += 1
				timer += 2.5
				wave += 1

func _fire(pool: Pool, at: Vector2, velocity: Vector2, r: float, c: Color, k: int) -> void:
	pool.spawn(at, velocity, r, c, k, Pool.Behavior.STRAIGHT, 8.5, 0.0, 0.0, 0.0, 0.0, 0)
	total_shots += 1

func _aim(boss_pos: Vector2, player_pos: Vector2) -> Vector2:
	var d := player_pos - boss_pos
	if d.length_squared() < 1.0:
		return Vector2.DOWN
	return d.normalized()
