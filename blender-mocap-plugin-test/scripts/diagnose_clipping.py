#!/usr/bin/env python3
"""Measure visible interpenetration for the MediaPipe -> KayKit Rogue walk.

Visible arm region = Rogue_Arm{Left,Right} vertices weighted to hand.* plus
lowerarm.* vertices within 0.16 m of the wrist head (the glove/bracer and the
distal sleeve). Upper-arm seam overlap is intentionally excluded: the KayKit
shoulder joint sits inside the wide chibi torso, exactly as in the built-in
Walking_A clip.

Inside/outside uses a 3-ray majority parity test (the body mesh has small open
seams at the neck/armholes, a single ray can misclassify). Depth is the distance
to the nearest surface; the "volume proxy" is sum(vertex area * depth), reported
in cm^3 as a relative collision measure, not a watertight boolean volume.

Foot contact uses the lowest evaluated leg-mesh vertex vs Z=0, not the bone head
(which under-reports the boot penetration). Bone clearance is sampled on the
forearm/hand chain centres against body/head/cape.

Usage:
  blender -b --factory-startup -noaudio --python scripts/diagnose_clipping.py -- \
    --glb exports/Rogue_MediaPipe_walk_raw.glb --out .work/clipdiag/before.json
"""
import bpy
import json
import os
import sys
from mathutils import Vector
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
if not GLB or not OUT:
    raise SystemExit("DIAG_ERROR: --glb and --out required")
FPS = int(get_arg("--fps", "30"))
THRESH = float(get_arg("--threshold-mm", "4.0")) / 1000.0
SAMPLES = [int(x) for x in get_arg("--samples", "1,19,37,56,74,92,111,130").split(",")]
WEAPONS = ["1H_Crossbow", "2H_Crossbow", "Knife", "Knife_Offhand", "Throwable"]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=GLB)
arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
if arm is None or arm.animation_data is None or arm.animation_data.action is None:
    raise SystemExit("DIAG_ERROR: no animated armature")
action = arm.animation_data.action
start = int(round(action.frame_range[0]))
end = int(round(action.frame_range[1]))
scene.frame_start = start
scene.frame_end = end
meshes = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
required = ["Rogue_Body", "Rogue_Head", "Rogue_Cape", "Rogue_ArmLeft",
            "Rogue_ArmRight", "Rogue_LegLeft", "Rogue_LegRight"]
for name in required:
    if name not in meshes:
        raise SystemExit("DIAG_ERROR: missing mesh " + name)


def inside(bvh, p):
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


GROUPS = {n: dominant_groups(meshes[n]) for n in ["Rogue_ArmLeft", "Rogue_ArmRight"]}
AREA = {}
for n in ["Rogue_ArmLeft", "Rogue_ArmRight"]:
    area = [0.0] * len(meshes[n].data.vertices)
    for poly in meshes[n].data.polygons:
        a = poly.area / max(1, poly.loop_total)
        for vi in poly.vertices:
            area[vi] += a
    AREA[n] = area


def evaluated_verts(o, depsgraph):
    ev = o.evaluated_get(depsgraph)
    me = ev.to_mesh()
    mw = ev.matrix_world
    vs = [mw @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    return vs


def arm_points(side, depsgraph):
    name = "Rogue_ArmLeft" if side == "l" else "Rogue_ArmRight"
    o = meshes[name]
    ev = o.evaluated_get(depsgraph)
    me = ev.to_mesh()
    mw = ev.matrix_world
    verts = [mw @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    wrist = arm.pose.bones["wrist." + side].head
    pts = []
    for i, (p, g) in enumerate(zip(verts, GROUPS[name])):
        if g in ("hand.l", "hand.r"):
            pts.append((p, AREA[name][i]))
        elif g in ("lowerarm.l", "lowerarm.r") and (p - wrist).length < 0.16:
            pts.append((p, AREA[name][i]))
    return pts


def penetration(points, bvhs):
    """points: [(pos, area)] -> (count, max_depth, volume_proxy_m3, target, deepest)"""
    count = 0
    max_d = 0.0
    vol = 0.0
    target = None
    deepest = None
    for p, a in points:
        for tname, bvh in bvhs.items():
            if inside(bvh, p):
                hit = bvh.find_nearest(p)
                if hit[0] is None:
                    continue
                d = hit[3]
                if d <= THRESH:
                    break
                count += 1
                vol += a * d
                if d > max_d:
                    max_d = d
                    target = tname
                    deepest = [round(p.x, 3), round(p.y, 3), round(p.z, 3)]
                break
    return count, max_d, vol, target, deepest


def bone_clearance(side, bvhs):
    """Minimum signed distance of forearm/hand bone centres to body/head/cape."""
    best = 1e9
    for bone_name, t in (("wrist." + side, 0.0), ("hand." + side, 0.0),
                         ("hand." + side, 0.5), ("hand." + side, 1.0)):
        pb = arm.pose.bones[bone_name]
        p = pb.head.lerp(pb.tail, t)
        for bvh in bvhs.values():
            hit = bvh.find_nearest(p)
            if hit[0] is None:
                continue
            if inside(bvh, p):
                d = -hit[3]
            else:
                d = hit[3]
            best = min(best, d)
    return best


def foot_min(name, depsgraph):
    return min(v.z for v in evaluated_verts(meshes[name], depsgraph))


def check_frame(f, depsgraph, bvh_targets):
    rec = {"frame": f}
    for side in ("l", "r"):
        pts = arm_points(side, depsgraph)
        n, d, vol, t, deepest = penetration(pts, bvh_targets)
        rec["arm_" + side] = {
            "verts_inside": n,
            "max_depth_mm": round(d * 1000, 2),
            "volume_proxy_cm3": round(vol * 1e6, 2),
            "target": t,
            "deepest": deepest,
            "bone_clearance_mm": round(bone_clearance(side, bvh_targets) * 1000, 2),
        }
    rec["foot_min_mm"] = {
        "l": round(foot_min("Rogue_LegLeft", depsgraph) * 1000, 2),
        "r": round(foot_min("Rogue_LegRight", depsgraph) * 1000, 2),
    }
    bone_targets = {k: bvh_targets[k] for k in ("body", "head", "cape") if k in bvh_targets}
    for side in ("l", "r"):
        rec["arm_" + side]["bone_clearance_mm"] = round(
            bone_clearance(side, bone_targets) * 1000, 2)
    # cape vertices inside body/arms/head/legs
    cape_pts = [(p, 0.0) for p in evaluated_verts(meshes["Rogue_Cape"], depsgraph)]
    cape_targets = {k: bvh_targets[k] for k in ("body", "head") if k in bvh_targets}
    cape_targets["arm_l"] = bvh_targets["arm_l"]
    cape_targets["arm_r"] = bvh_targets["arm_r"]
    n, d, vol, t, deepest = penetration(cape_pts, cape_targets)
    rec["cape"] = {"verts_inside": n, "max_depth_mm": round(d * 1000, 2), "target": t}
    wrec = {}
    for w in WEAPONS:
        if w not in meshes:
            continue
        pts = [(p, 0.0) for p in evaluated_verts(meshes[w], depsgraph)]
        n, d, vol, t, deepest = penetration(pts, bvh_targets)
        if n:
            wrec[w] = {"verts_inside": n, "max_depth_mm": round(d * 1000, 2), "target": t}
    if wrec:
        rec["weapons"] = wrec
    return rec


samples = []
for f in SAMPLES:
    if f < start or f > end:
        continue
    scene.frame_set(f)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bvhs = {
        "body": BVHTree.FromObject(meshes["Rogue_Body"], depsgraph),
        "head": BVHTree.FromObject(meshes["Rogue_Head"], depsgraph),
        "cape": BVHTree.FromObject(meshes["Rogue_Cape"], depsgraph),
        "arm_l": BVHTree.FromObject(meshes["Rogue_ArmLeft"], depsgraph),
        "arm_r": BVHTree.FromObject(meshes["Rogue_ArmRight"], depsgraph),
    }
    samples.append(check_frame(f, depsgraph, bvhs))
    print("DIAG_FRAME %d" % f)

# all-frame summary (arm visible region, foot)
summary = {"l": {"frames_with_visible_clip": 0, "max_depth_mm": 0.0,
                 "max_verts_inside": 0, "volume_proxy_values_cm3": [], "worst_frame": None},
           "r": {"frames_with_visible_clip": 0, "max_depth_mm": 0.0,
                 "max_verts_inside": 0, "volume_proxy_values_cm3": [], "worst_frame": None}}
foot_all = {"l": [], "r": []}
cape_summary = {"frames_with_clip": 0, "max_depth_mm": 0.0, "worst_frame": None}
weapon_summary = {}
for f in range(start, end + 1):
    scene.frame_set(f)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bvhs = {
        "body": BVHTree.FromObject(meshes["Rogue_Body"], depsgraph),
        "head": BVHTree.FromObject(meshes["Rogue_Head"], depsgraph),
        "cape": BVHTree.FromObject(meshes["Rogue_Cape"], depsgraph),
        "arm_l": BVHTree.FromObject(meshes["Rogue_ArmLeft"], depsgraph),
        "arm_r": BVHTree.FromObject(meshes["Rogue_ArmRight"], depsgraph),
    }
    for side in ("l", "r"):
        n, d, vol, t, deepest = penetration(arm_points(side, depsgraph), bvhs)
        a = summary[side]
        a["volume_proxy_values_cm3"].append(vol * 1e6)
        a["max_verts_inside"] = max(a["max_verts_inside"], n)
        if n:
            a["frames_with_visible_clip"] += 1
            if d * 1000 > a["max_depth_mm"]:
                a["max_depth_mm"] = round(d * 1000, 2)
                a["worst_frame"] = f
    for side, name in (("l", "Rogue_LegLeft"), ("r", "Rogue_LegRight")):
        foot_all[side].append(round(foot_min(name, depsgraph) * 1000, 2))
    cape_pts = [(p, 0.0) for p in evaluated_verts(meshes["Rogue_Cape"], depsgraph)]
    n, d, vol, t, deepest = penetration(cape_pts, {k: bvhs[k] for k in ("body", "head", "arm_l", "arm_r")})
    if n:
        cape_summary["frames_with_clip"] += 1
        if d > cape_summary["max_depth_mm"]:
            cape_summary["max_depth_mm"] = round(d * 1000, 2)
            cape_summary["worst_frame"] = f
    for w in WEAPONS:
        if w not in meshes:
            continue
        pts = [(p, 0.0) for p in evaluated_verts(meshes[w], depsgraph)]
        n, d, vol, t, deepest = penetration(pts, bvhs)
        ws = weapon_summary.setdefault(w, {"frames_with_clip": 0, "max_depth_mm": 0.0,
                                           "worst_frame": None})
        if n:
            ws["frames_with_clip"] += 1
            if d * 1000 > ws["max_depth_mm"]:
                ws["max_depth_mm"] = round(d * 1000, 2)
                ws["worst_frame"] = f
    if f % 20 == 0:
        print("DIAG_ALL_FRAME %d" % f)

foot_summary = {}
for side in ("l", "r"):
    zs = foot_all[side]
    mn = min(zs)
    contact = [z <= mn + 5.0 for z in zs]
    longest = run = 0
    for c in contact:
        run = run + 1 if c else 0
        longest = max(longest, run)
    foot_summary[side] = {"min_mm": round(mn, 2),
                          "max_mm": round(max(zs), 2),
                          "contact_frames": sum(contact),
                          "longest_contact_run": longest,
                          "frames_below_0": sum(1 for z in zs if z < -1.0)}
for side in summary:
    s = summary[side]
    s["max_depth_mm"] = round(s["max_depth_mm"], 2)
    vals = s.pop("volume_proxy_values_cm3")
    s["volume_proxy_mean_cm3"] = round(sum(vals) / max(1, len(vals)), 1)
    s["volume_proxy_max_cm3"] = round(max(vals) if vals else 0.0, 1)

report = {
    "glb": GLB,
    "fps": FPS,
    "frames": [start, end],
    "threshold_mm": THRESH * 1000,
    "mesh_count": len(meshes),
    "arm_visible_region": "hand.* + lowerarm.* within 0.16 m of wrist head",
    "summary": summary,
    "cape": cape_summary,
    "weapons": weapon_summary,
    "foot": foot_summary,
    "samples": samples,
}
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as fh:
    json.dump(report, fh, ensure_ascii=False, indent=1)
print("CLIP_REPORT " + json.dumps({k: v for k, v in report.items() if k != "samples"},
                                  ensure_ascii=False))
