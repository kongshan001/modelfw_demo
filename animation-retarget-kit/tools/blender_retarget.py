#!/usr/bin/env python3
"""Engine-agnostic animation retargeter using Blender (headless).

Imports a source rig+clip and a target rig, transfers the source pose in model
space onto the target rest pose, bakes a target action, and exports GLB.

Core math (column-vector convention):
  D = src_pose_global * inverse(src_rest_global)
  target_pose_global = D * target_rest_global
  target_pose_local = inverse(target_parent_global) * target_pose_global

Rotations are retargeted; target bone lengths are preserved. Hips translation
(body lean/bounce) is preserved by default; --strip-hips zeroes it for strict
in-place clips.

Usage:
  blender -b -P tools/blender_retarget.py -- \
    --source assets/source/Soldier.glb \
    --target assets/target/Michelle.glb \
    --clip Walk \
    --out examples/soldier_to_michelle/Michelle_Walk.glb \
    [--map assets/maps/mixamo.json] [--fps 30] [--strip-hips] [--simple]

The script prints a RETARGET_REPORT JSON line for tools/AI to parse.
"""

import bpy
import json
import os
import sys
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []

def get_arg(name, default=None):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default

source_path = get_arg("--source")
target_path = get_arg("--target")
clip_name = get_arg("--clip")
out_path = get_arg("--out")
map_path = get_arg("--map")
fps = int(get_arg("--fps", "30"))
strip_hips = "--strip-hips" in argv
simple_formula = "--simple" in argv
root_motion_scale = float(get_arg("--root-motion-scale", "1.0"))

if not (source_path and target_path and clip_name and out_path):
    print("RETARGET_ERROR: --source --target --clip --out are required")
    raise SystemExit(2)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = max(1, fps)


def import_asset(path):
    before = set(bpy.data.objects)
    ext = os.path.splitext(path)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        try:
            bpy.ops.preferences.addon_enable(module="io_scene_fbx")
        except Exception:
            pass
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        raise RuntimeError(f"unsupported asset extension: {ext}")
    return [o for o in bpy.data.objects if o not in before]


def find_armature(objects):
    arms = [o for o in objects if o.type == "ARMATURE"]
    return arms[0] if arms else None


try:
    src_objs = import_asset(source_path)
    # Actions created by the source import; the target import may add actions
    # with similar names (e.g. Xbot's "run_Armature"), so restrict clip lookup
    # to source actions.
    src_action_names = {a.name for a in bpy.data.actions}
    tgt_objs = import_asset(target_path)
    src_arm = find_armature(src_objs)
    tgt_arm = find_armature(tgt_objs)
    if src_arm is None or tgt_arm is None:
        raise RuntimeError("source and target must both contain an Armature")
except Exception as e:
    print("RETARGET_ERROR: " + str(e))
    raise SystemExit(1)

# ---------------------------------------------------------------- actions
src_actions = [a for a in bpy.data.actions if a.name in src_action_names]
src_action = next((a for a in src_actions if a.name == clip_name), None)
if src_action is None:
    matches = [a for a in src_actions if clip_name.lower() in a.name.lower() and "mixamorig" not in a.name.lower()]
    if not matches:
        matches = [a for a in src_actions if clip_name.lower() in a.name.lower()]
    if matches:
        src_action = matches[0]
if src_action is None:
    names = sorted(a.name for a in src_actions)
    print(f"RETARGET_ERROR: clip {clip_name!r} not found. actions={names}")
    raise SystemExit(1)

src_arm.animation_data_create()
src_arm.animation_data.action = src_action
src_clip_name = src_action.name

# Detach any native target actions/NLA before baking into a fresh action.
if tgt_arm.animation_data:
    tgt_arm.animation_data_clear()
tgt_arm.animation_data_create()
tgt_action = bpy.data.actions.new(f"Retarget_{clip_name}")
tgt_action.use_fake_user = True
tgt_arm.animation_data.action = tgt_action

for pb in tgt_arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
    pb.matrix_basis = Matrix.Identity(4)

# ---------------------------------------------------------------- mapping
def norm(name):
    return name.replace("mixamorig:", "mixamorig_").replace("mixamorig_", "").lower()


src_bones = {b.name: b for b in src_arm.data.bones}
tgt_bones = {b.name: b for b in tgt_arm.data.bones}
src_by_norm = {}
for name in src_bones:
    src_by_norm.setdefault(norm(name), []).append(name)

mapping = {}  # target name -> source name
missing_in_target = []
missing_in_source = []

if map_path:
    data = json.loads(open(map_path, encoding="utf-8").read())
    for s, t in data.get("bones", {}).items():
        if s in src_bones and t in tgt_bones:
            mapping[t] = s
        else:
            missing_in_source.append(s if s not in src_bones else None)
            missing_in_target.append(t if t not in tgt_bones else None)
else:
    for t in tgt_bones:
        candidates = src_by_norm.get(norm(t), [])
        if len(candidates) == 1:
            mapping[t] = candidates[0]
        elif len(candidates) > 1:
            missing_in_source.append(f"ambiguous:{t}")

for t in tgt_bones:
    if t not in mapping:
        missing_in_source.append(t)
for s in src_bones:
    if s not in mapping.values():
        missing_in_target.append(s)

if len(mapping) < 10:
    print(f"RETARGET_ERROR: only {len(mapping)} bones mapped; provide --map with explicit names")
    raise SystemExit(1)

# ---------------------------------------------------------------- bake
src_rest = {name: src_arm.data.bones[name].matrix_local.copy() for name in src_bones}
tgt_rest = {name: tgt_arm.data.bones[name].matrix_local.copy() for name in tgt_bones}

def depth(bone):
    d = 0
    p = bone.parent
    while p is not None:
        d += 1
        p = p.parent
    return d

order = sorted(mapping.keys(), key=lambda n: depth(tgt_bones[n]))
root_target = None
for candidate in ("mixamorig_Hips", "Hips", "Root", "mixamorig_Root"):
    if candidate in mapping:
        root_target = candidate
        break
if root_target is None:
    root_target = order[0] if order else None

start = int(src_action.frame_range[0])
end = int(src_action.frame_range[1])
scene.frame_start = start
scene.frame_end = end

# Rotation-only retarget, preserving target bone heads/rest lengths.
# Work in armature ("model") space, matching Godot RetargetModifier3D:
#   tgt_local = inv(P_t) * P_s * src_local_pose * inv(src_local_rest)
#               * inv(P_s) * P_t * tgt_local_rest
# P_s/P_t are the parent global rest rotations; the bone pose/rest are LOCAL.
# Using global pose/rest with this formula twists limbs (e.g. straight elbows).
all_order = sorted(tgt_bones.keys(), key=lambda n: depth(tgt_bones[n]))
tgt_rest_local_rot = {}
for name in all_order:
    parent = tgt_bones[name].parent
    if parent is not None:
        tgt_rest_local_rot[name] = tgt_rest[parent.name].to_quaternion().to_matrix().inverted() @ tgt_rest[name].to_quaternion().to_matrix()
    else:
        tgt_rest_local_rot[name] = tgt_rest[name].to_quaternion().to_matrix()

root_src = mapping.get(root_target) if root_target is not None else None

for f in range(start, end + 1):
    scene.frame_set(f)
    bpy.context.view_layer.update()
    pose_world_rot = {}
    for tgt_name in all_order:
        parent = tgt_bones[tgt_name].parent
        parent_world = pose_world_rot.get(parent.name, Matrix.Identity(3)) if parent is not None else Matrix.Identity(3)
        base = parent_world @ tgt_rest_local_rot[tgt_name]
        if tgt_name not in mapping:
            pose_world_rot[tgt_name] = base
            continue

        src_name = mapping[tgt_name]
        src_pb = src_arm.pose.bones.get(src_name)
        if src_pb is None:
            pose_world_rot[tgt_name] = base
            continue
        src_bone = src_bones[src_name]
        src_parent = src_bone.parent
        src_pose_global = src_pb.matrix.to_quaternion().to_matrix()
        src_rest_global = src_rest[src_name].to_quaternion().to_matrix()
        tgt_rest_global = tgt_rest[tgt_name].to_quaternion().to_matrix()
        tgt_pb = tgt_arm.pose.bones[tgt_name]
        tgt_pb.rotation_mode = "QUATERNION"

        if simple_formula:
            # Step 6 global-delta: D_src * R_t_rest. Use when the target rest
            # axes differ strongly (e.g. Michelle SambaDance -> Xbot).
            desired_world = src_pose_global @ src_rest_global.inverted() @ tgt_rest_global
            local_rot = base.inverted() @ desired_world
            tgt_pb.rotation_quaternion = local_rot.to_quaternion()
            pose_world_rot[tgt_name] = desired_world
        else:
            # Godot RetargetModifier3D formula (model space, LOCAL pose/rest).
            src_parent_rest = src_rest[src_parent.name].to_quaternion().to_matrix() if src_parent else Matrix.Identity(3)
            src_parent_pose = src_arm.pose.bones[src_parent.name].matrix.to_quaternion().to_matrix() if src_parent else Matrix.Identity(3)
            src_rest_local = src_parent_rest.inverted() @ src_rest_global
            src_pose_local = src_parent_pose.inverted() @ src_pose_global

            tgt_parent = tgt_bones[tgt_name].parent
            tgt_parent_rest = tgt_rest[tgt_parent.name].to_quaternion().to_matrix() if tgt_parent else Matrix.Identity(3)
            tgt_rest_local = tgt_parent_rest.inverted() @ tgt_rest_global

            tgt_local_pose = (
                tgt_parent_rest.inverted()
                @ src_parent_rest
                @ src_pose_local
                @ src_rest_local.inverted()
                @ src_parent_rest.inverted()
                @ tgt_parent_rest
                @ tgt_rest_local
            )
            basis = tgt_rest_local.inverted() @ tgt_local_pose
            tgt_pb.rotation_quaternion = basis.to_quaternion()
            pose_world_rot[tgt_name] = parent_world @ tgt_local_pose

        tgt_pb.location = Vector((0.0, 0.0, 0.0))
        tgt_pb.scale = Vector((1.0, 1.0, 1.0))
        # Hips translation is part of the pose (body lean/bounce). Preserve it
        # by default; --strip-hips zeroes it for strict in-place clips.
        if tgt_name == root_target and root_src is not None and not strip_hips:
            src_root_pb = src_arm.pose.bones.get(root_src)
            if src_root_pb is not None:
                delta_world = (src_arm.matrix_world @ src_root_pb.matrix).translation - (src_arm.matrix_world @ src_rest[root_src]).translation
                # Full inverse includes the armature object scale (0.01 for these
                # glTF imports); using only the 3x3 rotation made motion 100x small.
                delta_arm = tgt_arm.matrix_world.inverted() @ (delta_world * root_motion_scale)
                rest_rot = tgt_rest[tgt_name].to_quaternion().to_matrix()
                tgt_pb.location = rest_rot.inverted() @ delta_arm
        tgt_pb.keyframe_insert(data_path="rotation_quaternion", frame=f, group=tgt_name)
        tgt_pb.keyframe_insert(data_path="location", frame=f, group=tgt_name)

for fc in tgt_action.fcurves:
    for kp in fc.keyframe_points:
        kp.interpolation = "LINEAR"

# ---------------------------------------------------------------- export
for o in src_objs:
    if o.name in bpy.data.objects:
        bpy.data.objects.remove(o, do_unlink=True)

for a in list(bpy.data.actions):
    if a != tgt_action:
        try:
            bpy.data.actions.remove(a)
        except Exception:
            pass

tgt_arm.animation_data.action = tgt_action
bpy.ops.object.select_all(action="DESELECT")
for o in tgt_objs:
    if o.name in bpy.data.objects:
        o.select_set(True)
bpy.context.view_layer.objects.active = tgt_arm


def _sanitize_materials(strip_specular=False):
    """Remove unloadable images (FBX targets often have zero-size textures).

    Blender 3.4's glTF exporter crashes on a zero-size specular image
    (`zero-size array to reduction operation maximum`). Removing broken
    image nodes keeps the bake/export usable; valid textures are preserved.
    """
    changed = False
    for mat in bpy.data.materials:
        if mat is None or not mat.use_nodes or mat.node_tree is None:
            continue
        tree = mat.node_tree
        for node in list(tree.nodes):
            if node.type != "TEX_IMAGE":
                continue
            img = node.image
            if img is not None and (img.size[0] == 0 or img.size[1] == 0):
                try:
                    img.reload()
                except Exception:
                    pass
            if img is None or img.size[0] == 0 or img.size[1] == 0:
                for out in node.outputs:
                    for link in list(out.links):
                        tree.links.remove(link)
                tree.nodes.remove(node)
                changed = True
        if strip_specular:
            for node in list(tree.nodes):
                if node.type != "BSDF_PRINCIPLED":
                    continue
                for inp in node.inputs:
                    if "Specular" in inp.name or "Sheen" in inp.name:
                        for link in list(inp.links):
                            tree.links.remove(link)
                            changed = True
    return changed


def _export_gltf():
    try:
        bpy.ops.export_scene.gltf(
            filepath=out_path,
            export_format="GLB",
            use_selection=True,
            export_animations=True,
            export_nla_strips=False,
            export_frame_range=True,
            export_yup=True,
            export_apply=False,
        )
    except TypeError:
        # Older Blender builds may not accept every keyword; retry minimal.
        bpy.ops.export_scene.gltf(
            filepath=out_path,
            export_format="GLB",
            use_selection=True,
            export_animations=True,
            export_frame_range=True,
        )


os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
if out_path.lower().endswith(".fbx"):
    bpy.ops.export_scene.fbx(
        filepath=out_path,
        use_selection=True,
        add_leaf_bones=False,
        bake_anim=True,
        bake_anim_use_all_actions=False,
        bake_anim_use_nla_strips=False,
        bake_anim_force_startend_keying=True,
    )
else:
    if _sanitize_materials(strip_specular=False):
        print("RETARGET_WARN: removed unloadable/zero-size image nodes before glTF export")
    try:
        _export_gltf()
    except Exception as first_error:
        print("RETARGET_WARN: glTF export failed (" + str(first_error) + "); retrying with simplified materials")
        _sanitize_materials(strip_specular=True)
        try:
            _export_gltf()
        except Exception as second_error:
            print("RETARGET_ERROR: glTF export failed: " + str(second_error))
            print("RETARGET_HINT: use --out <name>.fbx for this target")
            raise SystemExit(1)

report = {
    "source": source_path,
    "target": target_path,
    "clip": src_clip_name,
    "output": out_path,
    "fps": fps,
    "frames": [start, end],
    "source_bones": len(src_bones),
    "target_bones": len(tgt_bones),
    "mapped_bones": len(mapping),
    "formula": "simple" if simple_formula else "godot-local",
    "hips_translation": not strip_hips,
    "root_bone": root_target,
    "missing_in_target": [x for x in missing_in_target if x][:30],
    "missing_in_source": [x for x in missing_in_source if x][:30],
}
print("RETARGET_REPORT " + json.dumps(report, ensure_ascii=False))
