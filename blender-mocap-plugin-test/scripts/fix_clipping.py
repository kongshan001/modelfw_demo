#!/usr/bin/env python3
"""Collision-aware cleanup for the MediaPipe -> KayKit Rogue walk retarget.

Fixes the visible interpenetration reported in T-20261127-012 without touching
the source video, the source rig or the walk timing:

1. Arm corridor + 2-bone IK.
   KayKit Rogue is a wide chibi: its built-in Walking_A holds the wrists around
   |x| = 0.51 while this retarget swings them across the belly at |x| = 0.0-0.3.
   We keep the source forward/back swing (y/z) and clamp |wrist.x| to a corridor
   calibrated from the built-in walk + glove radius (default 0.55). The upper and
   lower arm are solved with a 2-bone IK (forward/outward elbow pole). A mesh
   residual pass checks hand + distal forearm vertices against the body/head/cape
   and pushes further only if a vertex is inside by more than --arm-threshold.
   The original upper/lower arm keys are overwritten per frame with LINEAR keys.

2. Foot contact clamp.
   The retarget pitches the boot 50-75 deg toe-down (source foot/toe rotation on
   a much larger foot), burying the mesh up to -0.17 m. We cap the foot/toe
   downward pitch (default 20 deg) and lift the hips by the residual leg-mesh
   penetration (Z=0), then key hips location. Root XZ / walking direction is not
   changed; support-foot slide is reported but not "fixed" (treadmill input).

3. Export.
   Full GLB (with stowed props), clean GLB/FBX (weapons removed: the walk test is
   body motion; props are parented to handslots by the source kit and are hidden
   in the Godot preview), and a JSON report with before/after numbers.

Usage:
  blender -b --factory-startup -noaudio --python scripts/fix_clipping.py -- \
    --glb exports/Rogue_MediaPipe_walk_raw.glb \
    --out exports/Rogue_MediaPipe_walk_fixed.glb \
    --out-full exports/Rogue_MediaPipe_walk_fixed_full.glb \
    --out-fbx exports/Rogue_MediaPipe_walk_fixed.fbx \
    --report .work/clipdiag/fix_report.json
"""
import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def get_arg(name, default=None):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default


GLB = get_arg("--glb")
OUT = get_arg("--out")
OUT_FULL = get_arg("--out-full")
OUT_FBX = get_arg("--out-fbx")
REPORT = get_arg("--report")
if not GLB or not OUT:
    raise SystemExit("FIX_ERROR: --glb and --out are required")

FPS = int(get_arg("--fps", "30"))
ARM_X = float(get_arg("--arm-x", "0.55"))
ARM_THRESHOLD = float(get_arg("--arm-threshold", "0.012"))
ARM_MAX_PUSH = float(get_arg("--arm-max-push", "0.06"))
ARM_ITERS = int(get_arg("--arm-iters", "4"))
FOOT_CAP = float(get_arg("--foot-cap", "20.0"))
HIP_LIFT_MAX = float(get_arg("--hip-lift-max", "0.10"))
DO_ARMS = "--no-arms" not in argv
DO_FEET = "--no-feet" not in argv
DO_EXPORT = "--no-export" not in argv
WEAPON_NAMES = ["1H_Crossbow", "2H_Crossbow", "Knife", "Knife_Offhand", "Throwable"]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=GLB)
bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"

arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
if arm is None or arm.animation_data is None or arm.animation_data.action is None:
    raise SystemExit("FIX_ERROR: no animated armature")
action = arm.animation_data.action
start = int(round(action.frame_range[0]))
end = int(round(action.frame_range[1]))
scene.frame_start = start
scene.frame_end = end
meshes = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
for required in ["Rogue_Body", "Rogue_Head", "Rogue_Cape", "Rogue_ArmLeft",
                 "Rogue_ArmRight", "Rogue_LegLeft", "Rogue_LegRight"]:
    if required not in meshes:
        raise SystemExit("FIX_ERROR: missing mesh " + required)


# ------------------------------------------------------------------ helpers
def update():
    bpy.context.view_layer.update()


def inside(bvh, p):
    """3-ray majority parity test; robust to small open seams in the body mesh."""
    votes = 0
    for d in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        hits = 0
        o = p.copy()
        for _ in range(12):
            loc, nor, idx, dist = bvh.ray_cast(o + d * 1e-5, d)
            if loc is None:
                break
            hits += 1
            o = loc.copy()
        if hits % 2:
            votes += 1
    return votes >= 2


def dominant_groups(o):
    names = [g.name for g in o.vertex_groups]
    out = []
    for v in o.data.vertices:
        best = None
        best_w = -1.0
        for g in v.groups:
            if g.weight > best_w:
                best_w = g.weight
                best = g.group
        out.append(names[best] if best is not None and best < len(names) else "")
    return out


ARM_GROUPS = {n: dominant_groups(meshes[n]) for n in ["Rogue_ArmLeft", "Rogue_ArmRight"]}
# Per-vertex area weights for the penetration-volume proxy (object space).
ARM_AREA = {}
for n in ["Rogue_ArmLeft", "Rogue_ArmRight"]:
    o = meshes[n]
    area = [0.0] * len(o.data.vertices)
    for poly in o.data.polygons:
        a = poly.area / max(1, poly.loop_total)
        for vi in poly.vertices:
            area[vi] += a
    ARM_AREA[n] = area


def evaluated_verts(o, depsgraph):
    ev = o.evaluated_get(depsgraph)
    me = ev.to_mesh()
    mw = ev.matrix_world
    vs = [mw @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    return vs


def arm_points(side, depsgraph):
    """Hand + distal forearm vertices (the visibly clipping part)."""
    name = "Rogue_ArmLeft" if side == "l" else "Rogue_ArmRight"
    o = meshes[name]
    o_eval = o.evaluated_get(depsgraph)
    me = o_eval.to_mesh()
    mw = o_eval.matrix_world
    verts = [mw @ v.co for v in me.vertices]
    o_eval.to_mesh_clear()
    wrist = arm.pose.bones["wrist." + side].head
    groups = ARM_GROUPS[name]
    area = ARM_AREA[name]
    pts = []
    for i, (p, g) in enumerate(zip(verts, groups)):
        if g in ("hand.l", "hand.r"):
            pts.append((p, area[i]))
        elif g in ("lowerarm.l", "lowerarm.r") and (p - wrist).length < 0.16:
            pts.append((p, area[i]))
    return pts


def arm_penetration(side, bvhs, depsgraph):
    pts = arm_points(side, depsgraph)
    worst_depth = 0.0
    count = 0
    volume = 0.0
    target = None
    for p, a in pts:
        for tname, bvh in bvhs.items():
            if inside(bvh, p):
                hit = bvh.find_nearest(p)
                if hit[0] is None:
                    continue
                d = hit[3]
                count += 1
                volume += a * d
                if d > worst_depth:
                    worst_depth = d
                    target = tname
                break
    return count, worst_depth, volume, target


def pose_arm(side, wrist_target):
    """Analytic 2-bone IK for upperarm/lowerarm, preserving the current pole."""
    pb_u = arm.pose.bones["upperarm." + side]
    pb_l = arm.pose.bones["lowerarm." + side]
    S = pb_u.head.copy()
    E = pb_l.head.copy()
    W = arm.pose.bones["wrist." + side].head.copy()
    L1 = (E - S).length
    L2 = (W - E).length
    vec = wrist_target - S
    d = min(max(vec.length, abs(L1 - L2) + 1e-4), L1 + L2 - 1e-5)
    u = vec.normalized()
    side_sign = 1.0 if S.x >= 0 else -1.0
    pole_hint = Vector((0.35 * side_sign, -0.9, 0.15))
    pole = pole_hint - u * pole_hint.dot(u)
    if pole.length < 1e-5:
        pole = Vector((0, 0, 1)) - u * u.z
    pole.normalize()
    a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, L1 * L1 - a * a))
    E1 = S + u * a + pole * h

    u_cur = (E - S).normalized()
    u_des = (E1 - S).normalized()
    q = u_cur.rotation_difference(u_des)
    pb_u.matrix = (Matrix.Translation(S) @ q.to_matrix().to_4x4()
                   @ Matrix.Translation(-S) @ pb_u.matrix)
    update()

    E2 = pb_l.head.copy()
    W2 = arm.pose.bones["wrist." + side].head.copy()
    l_cur = (W2 - E2).normalized()
    l_des = (wrist_target - E2).normalized()
    q2 = l_cur.rotation_difference(l_des)
    pb_l.matrix = (Matrix.Translation(E2) @ q2.to_matrix().to_4x4()
                   @ Matrix.Translation(-E2) @ pb_l.matrix)
    update()


def leg_min_z(name, depsgraph):
    vs = evaluated_verts(meshes[name], depsgraph)
    return min(v.z for v in vs)


def bone_pitch_down(pb):
    d = pb.tail - pb.head
    hor = math.hypot(d.x, d.y)
    return math.degrees(math.atan2(-d.z, hor))


def rotate_about_head(pb, angle_deg):
    h = pb.head.copy()
    M = pb.matrix.copy()
    pb.matrix = (Matrix.Translation(h) @ Matrix.Rotation(math.radians(angle_deg), 4, "X")
                 @ Matrix.Translation(-h) @ M)
    update()


def set_linear(fcurves):
    for fc in fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"


# ------------------------------------------------------------------ arm pass
arm_before = {}
if DO_ARMS:
    print("FIX_ARM_START frames=%d..%d clamp=%.3f" % (start, end, ARM_X))
    for f in range(start, end + 1):
        scene.frame_set(f)
        update()
        depsgraph = bpy.context.evaluated_depsgraph_get()
        bvhs = {
            "body": BVHTree.FromObject(meshes["Rogue_Body"], depsgraph),
            "head": BVHTree.FromObject(meshes["Rogue_Head"], depsgraph),
            "cape": BVHTree.FromObject(meshes["Rogue_Cape"], depsgraph),
        }
        for side, sign in (("l", 1.0), ("r", -1.0)):
            wrist0 = arm.pose.bones["wrist." + side].head.copy()
            if f == start:
                n0, d0, v0, t0 = arm_penetration(side, bvhs, depsgraph)
                arm_before[side] = {"count": n0, "max_depth_mm": round(d0 * 1000, 2),
                                    "volume_mm3": round(v0 * 1e9, 1), "target": t0,
                                    "wrist": [round(x, 4) for x in wrist0]}
            target = wrist0.copy()
            target.x = sign * max(abs(wrist0.x), ARM_X)
            pose_arm(side, target)
            # Residual mesh push: only if the calibrated corridor is not enough.
            for _ in range(ARM_ITERS):
                n, d, vol, t = arm_penetration(side, bvhs, bpy.context.evaluated_depsgraph_get())
                if n == 0 or d <= ARM_THRESHOLD:
                    break
                hand = arm.pose.bones["hand." + side].head.copy()
                radial = Vector((hand.x, hand.y, 0.0))
                radial = radial.normalized() if radial.length > 1e-4 else Vector((sign, 0, 0))
                push_dir = (Vector((sign, 0, 0)) * 0.75 + radial * 0.25).normalized()
                step = min(ARM_MAX_PUSH, max(0.01, (d + 0.008) * 0.9))
                target += push_dir * step
                pose_arm(side, target)
            pb_u = arm.pose.bones["upperarm." + side]
            pb_l = arm.pose.bones["lowerarm." + side]
            pb_u.keyframe_insert("rotation_quaternion", frame=f, group=pb_u.name)
            pb_l.keyframe_insert("rotation_quaternion", frame=f, group=pb_l.name)
        if f % 20 == 0:
            print("FIX_ARM_FRAME %d" % f)
    set_linear([fc for fc in action.fcurves
                if any(k in fc.data_path for k in ("upperarm.", "lowerarm."))])
    print("FIX_ARM_DONE")

# ------------------------------------------------------------------ foot pass
foot_lifts = []
contact_adjust = []
if DO_FEET:
    print("FIX_FOOT_START cap=%.1fdeg" % FOOT_CAP)
    lifts = []
    for f in range(start, end + 1):
        scene.frame_set(f)
        update()
        depsgraph = bpy.context.evaluated_depsgraph_get()
        residual = 0.0
        for side, name in (("l", "Rogue_LegLeft"), ("r", "Rogue_LegRight")):
            pb = arm.pose.bones["foot." + side]
            pt = arm.pose.bones["toes." + side]
            p = bone_pitch_down(pb)
            if p > FOOT_CAP:
                rotate_about_head(pb, -(p - FOOT_CAP))
            ptp = bone_pitch_down(pt)
            if ptp > FOOT_CAP:
                rotate_about_head(pt, -(ptp - FOOT_CAP))
            mn = leg_min_z(name, bpy.context.evaluated_depsgraph_get())
            residual = max(residual, -mn)
            pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
            pt.keyframe_insert("rotation_quaternion", frame=f, group=pt.name)
        lifts.append(residual)
        if f % 20 == 0:
            print("FIX_FOOT_FRAME %d residual_mm=%.1f" % (f, residual * 1000))
    # Dilate by 1 frame then average, but never below the raw requirement.
    n = len(lifts)
    dil = [max(lifts[max(0, i - 1):min(n, i + 2)]) for i in range(n)]
    smoothed = []
    for i in range(n):
        win = dil[max(0, i - 1):min(n, i + 2)]
        avg = sum(win) / len(win)
        smoothed.append(max(lifts[i], avg))
    # Apply the hip lift on top of the existing hips location keys.
    for idx, f in enumerate(range(start, end + 1)):
        if smoothed[idx] <= 1e-5:
            continue
        scene.frame_set(f)
        update()
        hb = arm.pose.bones["hips"]
        M = hb.matrix.copy()
        lift = min(HIP_LIFT_MAX, smoothed[idx] + 0.001)
        hb.matrix = Matrix.Translation(Vector((0.0, 0.0, lift))) @ M
        update()
        hb.keyframe_insert("location", frame=f, group=hb.name)
    # The dilation/smoothing above deliberately biases upward to avoid dips;
    # pull the hips back down until the lowest boot is ~1 mm above Z=0, so the
    # character does not visibly hover during stance.
    contact_adjust = []
    for f in range(start, end + 1):
        scene.frame_set(f)
        update()
        low = min(leg_min_z("Rogue_LegLeft", bpy.context.evaluated_depsgraph_get()),
                  leg_min_z("Rogue_LegRight", bpy.context.evaluated_depsgraph_get()))
        dz = 0.0
        if low > 0.002:
            dz = -(low - 0.001)
        elif low < -0.001:
            dz = -(low - 0.001)
        if abs(dz) > 1e-6:
            hb = arm.pose.bones["hips"]
            M = hb.matrix.copy()
            hb.matrix = Matrix.Translation(Vector((0.0, 0.0, dz))) @ M
            update()
            hb.keyframe_insert("location", frame=f, group=hb.name)
        contact_adjust.append(round(dz * 1000, 2))
    set_linear([fc for fc in action.fcurves
                if fc.data_path.startswith('pose.bones["hips"].location')])
    foot_lifts = [round(x * 1000, 2) for x in lifts]
    print("FIX_FOOT_DONE max_lift_mm=%.1f mean_lift_mm=%.1f contact_adjust_min/max_mm=%.1f/%.1f" % (
        max(foot_lifts), sum(foot_lifts) / max(1, len(foot_lifts)),
        min(contact_adjust) if contact_adjust else 0,
        max(contact_adjust) if contact_adjust else 0))

# ------------------------------------------------------------------ cape rebind
# The source cape is a rigid mesh bone-parented to "chest" with its own object
# action. Re-exporting a bone-parented, object-animated mesh through glTF moves
# it ~90 deg (matrix_parent_inverse is not round-tripped). Convert it into a
# skinned mesh weighted 1.0 to chest at the first frame, preserving the frame-1
# visual; it then follows the chest through the armature clip and exports safely.
CAPE_ERROR_MM = None
if "--no-cape-rebind" not in argv:
    scene.frame_set(start)
    update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    cape = meshes["Rogue_Cape"]
    cape_world = evaluated_verts(cape, depsgraph)
    chest_world = arm.matrix_world @ arm.pose.bones["chest"].matrix
    chest_rest = arm.matrix_world @ arm.data.bones["chest"].matrix_local
    # Armature modifier deform: P_pose * P_rest^-1 * v_rest. Solve for v_rest.
    inv_deform = (chest_world @ chest_rest.inverted()).inverted()
    bind_verts = [inv_deform @ v for v in cape_world]
    old_action = None
    if cape.animation_data and cape.animation_data.action:
        old_action = cape.animation_data.action
    cape.animation_data_clear()
    cape.parent = arm
    cape.parent_type = "OBJECT"
    cape.parent_bone = ""
    cape.matrix_parent_inverse = Matrix.Identity(4)
    cape.matrix_world = Matrix.Identity(4)
    for i, v in enumerate(cape.data.vertices):
        v.co = bind_verts[i]
    cape.vertex_groups.clear()
    vg = cape.vertex_groups.new(name="chest")
    vg.add(list(range(len(cape.data.vertices))), 1.0, "REPLACE")
    cape.modifiers.clear()
    mod = cape.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    if old_action is not None:
        try:
            bpy.data.actions.remove(old_action)
        except Exception:
            pass
    update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    check = evaluated_verts(cape, depsgraph)
    CAPE_ERROR_MM = round(max((a - b).length for a, b in zip(check, cape_world)) * 1000, 3)
    print("FIX_CAPE_REBIND error_mm=%.3f" % CAPE_ERROR_MM)

# ------------------------------------------------------------------ verify
metrics = {"frames": [start, end], "arm_x": ARM_X, "foot_cap_deg": FOOT_CAP,
           "before_frame_start": arm_before}
after = {"l": {"frames": 0, "max_depth_mm": 0.0, "verts": 0, "volume_mm3": 0.0,
               "worst_frame": None},
         "r": {"frames": 0, "max_depth_mm": 0.0, "verts": 0, "volume_mm3": 0.0,
               "worst_frame": None}}
worst_foot = 1e9
for f in range(start, end + 1):
    scene.frame_set(f)
    update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bvhs = {
        "body": BVHTree.FromObject(meshes["Rogue_Body"], depsgraph),
        "head": BVHTree.FromObject(meshes["Rogue_Head"], depsgraph),
        "cape": BVHTree.FromObject(meshes["Rogue_Cape"], depsgraph),
    }
    for side in ("l", "r"):
        n, d, vol, t = arm_penetration(side, bvhs, depsgraph)
        a = after[side]
        if n:
            a["frames"] += 1
            a["verts"] += n
            a["volume_mm3"] += vol * 1e9
            if d * 1000 > a["max_depth_mm"]:
                a["max_depth_mm"] = round(d * 1000, 2)
                a["worst_frame"] = f
    for name in ("Rogue_LegLeft", "Rogue_LegRight"):
        worst_foot = min(worst_foot, leg_min_z(name, depsgraph))
for side in after:
    after[side]["max_depth_mm"] = round(after[side]["max_depth_mm"], 2)
    after[side]["volume_mm3"] = round(after[side]["volume_mm3"], 1)
metrics["after"] = after
metrics["foot_min_mm"] = round(worst_foot * 1000, 3)
metrics["foot_lift_mm"] = {"max": max(foot_lifts) if foot_lifts else 0,
                           "mean": round(sum(foot_lifts) / max(1, len(foot_lifts)), 2) if foot_lifts else 0}
metrics["contact_adjust_mm"] = {"min": min(contact_adjust) if contact_adjust else 0,
                                "max": max(contact_adjust) if contact_adjust else 0}
metrics["cape_rebind_error_mm"] = CAPE_ERROR_MM

# ------------------------------------------------------------------ export
def select_objects(names):
    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    for n in names:
        o = bpy.data.objects.get(n)
        if o is not None:
            o.select_set(True)
            selected.append(o)
    if arm.name in bpy.data.objects:
        arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    return selected


def export_glb(path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_nla_strips=False,
        export_frame_range=True,
        export_yup=True,
        export_apply=False,
        export_force_sampling=False,
        export_optimize_animation_size=True,
    )
    print("FIX_EXPORT_GLB " + path)


if DO_EXPORT:
    all_names = [n for n in meshes.keys()]
    select_objects(all_names)
    if OUT_FULL:
        export_glb(OUT_FULL)
    # clean variant: body motion only, no stowed props (parented to handslots in
    # the KayKit kit, so they follow the hands and clip in this motion).
    for n in WEAPON_NAMES:
        o = bpy.data.objects.get(n)
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)
    clean_names = [n for n in all_names if n not in WEAPON_NAMES and n in bpy.data.objects]
    select_objects(clean_names)
    export_glb(OUT)
    if OUT_FBX:
        os.makedirs(os.path.dirname(os.path.abspath(OUT_FBX)), exist_ok=True)
        bpy.ops.export_scene.fbx(
            filepath=OUT_FBX,
            use_selection=True,
            add_leaf_bones=False,
            bake_anim=True,
            bake_anim_use_all_actions=False,
            bake_anim_use_nla_strips=False,
            bake_anim_force_startend_keying=True,
        )
        print("FIX_EXPORT_FBX " + OUT_FBX)
elif OUT:
    # no-export mode still writes the in-memory verification object count
    pass

if REPORT:
    os.makedirs(os.path.dirname(os.path.abspath(REPORT)), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=1)
    print("FIX_REPORT " + json.dumps(metrics, ensure_ascii=False))
print("FIX_DONE")
