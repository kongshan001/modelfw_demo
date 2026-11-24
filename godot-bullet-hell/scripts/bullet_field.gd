class_name BulletField
extends Node2D

const Pool = preload("res://scripts/bullet_pool.gd")

# 单个 MultiMesh draw call 绘制全部敌弹；逻辑数据在 Pool。
# 圆形/菱形/长条只改实例缩放与旋转，不增加材质或 draw call。

const CAPACITY := 4096
const BULLET_SHADER := preload("res://shaders/bullet_glow.gdshader")

var pool: Pool
var board_rect := Rect2(0.0, 0.0, 1280.0, 720.0)
var _mm: MultiMesh
var _mmi: MultiMeshInstance2D

func _ready() -> void:
	z_index = 5
	pool = Pool.new(CAPACITY, 0xB17B17)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.instance_count = CAPACITY
	_mm.visible_instance_count = 0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mm.mesh = quad
	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = _mm
	var mat := ShaderMaterial.new()
	mat.shader = BULLET_SHADER
	_mmi.material = mat
	add_child(_mmi)

func clear() -> void:
	pool.clear()
	sync()

func sync() -> void:
	var n := pool.count
	_mm.visible_instance_count = n
	for i in n:
		var p := pool.pos[i]
		var v := pool.render_velocity(i)
		var ang := v.angle()
		var r := pool.radius[i]
		var sx := r * 4.0
		var sy := sx
		match pool.kind[i]:
			Pool.Kind.SHARD:
				sx = r * 3.7
				sy = r * 1.5
			Pool.Kind.BLOOM:
				sx = r * 4.5
				sy = sx
			Pool.Kind.CORE:
				sx = r * 3.3
				sy = sx
		var c := pool.color[i]
		var fade := clampf((pool.life[i] - pool.age[i]) / 0.22, 0.0, 1.0)
		c.a *= fade
		_mm.set_instance_transform_2d(i, Transform2D(ang, Vector2(sx, sy), 0.0, p))
		_mm.set_instance_color(i, c)
