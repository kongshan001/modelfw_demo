extends RefCounted

# 运行时 simple 全局增量重定向（世界空间）。
#
# Xbot 的 glTF 骨骼 rest 轴与 Michelle 不同；离线 bake 再导入 Godot 时，
# exporter 会翻转骨骼 rest，导致整体倾斜。这里用 animation-retarget-kit
# 的 simple 公式在运行时直接驱动原生 Xbot：
#   D = src_pose_world * inverse(src_rest_world)
#   tgt_global_world = D * tgt_rest_world
# 父骨骼先算，再把目标全局旋转转成骨骼 local pose。

var _src_skel: Skeleton3D
var _tgt_skel: Skeleton3D
var _pairs: Array = []
var _desired: Dictionary = {}

func setup(src: Skeleton3D, tgt: Skeleton3D) -> void:
	_src_skel = src
	_tgt_skel = tgt
	_pairs.clear()
	_desired.clear()
	if _src_skel == null or _tgt_skel == null:
		return
	var src_by_norm := {}
	for i in _src_skel.get_bone_count():
		src_by_norm[_norm(_src_skel.get_bone_name(i))] = i
	var order: Array[int] = []
	for t in _tgt_skel.get_bone_count():
		if src_by_norm.has(_norm(_tgt_skel.get_bone_name(t))):
			order.append(t)
	order.sort_custom(func(a: int, b: int) -> bool: return _depth(a) < _depth(b))
	for t in order:
		var s: int = src_by_norm[_norm(_tgt_skel.get_bone_name(t))]
		_pairs.append({
			"src": s,
			"tgt": t,
			"parent": _tgt_skel.get_bone_parent(t),
			"src_rest": _src_skel.get_bone_global_rest(s).basis,
			"tgt_rest": _tgt_skel.get_bone_global_rest(t).basis,
		})

func apply() -> void:
	if _src_skel == null or _tgt_skel == null:
		return
	_desired.clear()
	var src_world := _src_skel.global_transform.basis
	var tgt_world := _tgt_skel.global_transform.basis
	for item in _pairs:
		var s: int = item["src"]
		var t: int = item["tgt"]
		var src_rest_w: Basis = src_world * item["src_rest"]
		var src_pose_w: Basis = src_world * _src_skel.get_bone_global_pose(s).basis
		var tgt_rest_w: Basis = tgt_world * item["tgt_rest"]
		var desired_w: Basis = src_pose_w * src_rest_w.inverse() * tgt_rest_w
		var desired_local: Basis = tgt_world.inverse() * desired_w
		var parent: int = item["parent"]
		var parent_global: Basis = _desired.get(parent, Basis.IDENTITY)
		_tgt_skel.set_bone_pose_rotation(t, (parent_global.inverse() * desired_local).get_rotation_quaternion())
		_desired[t] = desired_local

func _norm(name: String) -> String:
	return name.replace(":", "_").to_lower()

func _depth(idx: int) -> int:
	var d := 0
	var p := _tgt_skel.get_bone_parent(idx)
	while p >= 0:
		d += 1
		p = _tgt_skel.get_bone_parent(p)
	return d
