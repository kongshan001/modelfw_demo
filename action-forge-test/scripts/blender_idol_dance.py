#!/usr/bin/env python3
"""Author the original "Idol-Chick Dance" on the Action Forge KayKit Rogue rig.

T-023 original choreography (no third-party dance, no copyrighted music):
  bar 1  chick wing flaps + knee bounce
  bar 2  hip sway + shoulder shimmy
  bar 3  heart hands + nod
  bar 4  full 360 spin + landing heart
8.0 s at 30 fps, seamless loop (frame 240 == frame 0 pose; hips yaw ends at 360
which is the same orientation as 0).

The AF GLB is imported so the dance uses the exact 41-bone / 12-mesh character
and 0.8032x KayKit scale that the Godot lab walks with. All rotations are local
bone Euler angles in degrees (KayKit local axes verified in T-023):
  torso X=pitch, Y=yaw, Z=side lean
  arms  X=raise/lower, Y=twist, Z=forward/back
  legs  X=swing, Y=twist, Z=abduction; lowerleg X=knee bend
  hips  location (x=side, y=up, z=forward)

Usage:
  Blender -b --python blender_idol_dance.py
Outputs:
  action-forge-test/exports/Rogue_IdolChickenDance_original.glb
  action-forge-test/source/Rogue_IdolChickenDance_original.blend
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
AF_GLB = os.path.join(ROOT, "godot", "assets", "Rogue_WalkLoop_AF_inplace.glb")
GLB_OUT = os.path.join(ROOT, "exports", "Rogue_IdolChickenDance_original.glb")
BLEND_OUT = os.path.join(ROOT, "source", "Rogue_IdolChickenDance_original.blend")
ACTION_NAME = "IdolChickenDance_original"
FPS = 30
DURATION = 8.0
FRAMES = int(DURATION * FPS)  # 240; frames 0..240

TAU = math.pi * 2.0

# Local Euler degrees (X, Y, Z) and hips local location offsets.
BASE = {
    "hips": (0.0, 0.0, 0.0),
    "spine": (0.0, 0.0, 0.0),
    "chest": (0.0, 0.0, 0.0),
    "head": (0.0, 0.0, 0.0),
    "upperarm.l": (-55.0, 0.0, -8.0),
    "upperarm.r": (-55.0, 0.0, 8.0),
    "lowerarm.l": (18.0, 0.0, -22.0),
    "lowerarm.r": (18.0, 0.0, 22.0),
    "hand.l": (0.0, 0.0, 0.0),
    "hand.r": (0.0, 0.0, 0.0),
    "upperleg.l": (0.0, 0.0, -3.0),
    "upperleg.r": (0.0, 0.0, 3.0),
    "lowerleg.l": (6.0, 0.0, 0.0),
    "lowerleg.r": (6.0, 0.0, 0.0),
    "foot.l": (-6.0, 0.0, 0.0),
    "foot.r": (-6.0, 0.0, 0.0),
}
BONES = list(BASE.keys())


def pose(over=None, loc=(0.0, 0.0, 0.0)):
    p = {b: tuple(BASE[b]) for b in BONES}
    if over:
        for b, v in over.items():
            p[b] = tuple(v)
    return {"rot": p, "loc": tuple(loc)}


# Hand-authored key poses.  Every pose is a full pose (base + overrides).
KEYS = [
    # bar 1 - chick wing flaps + bounce
    (0.0, pose()),
    (0.5, pose({
        "upperarm.l": (-18, 0, -12), "upperarm.r": (-18, 0, 12),
        "lowerarm.l": (95, 0, -15), "lowerarm.r": (95, 0, 15),
        "head": (-4, 0, 0),
        "lowerleg.l": (14, 0, 0), "lowerleg.r": (14, 0, 0),
        "foot.l": (-14, 0, 0), "foot.r": (-14, 0, 0),
    }, (0, -0.015, 0))),
    (1.0, pose({
        "upperarm.l": (-68, 0, -5), "upperarm.r": (-68, 0, 5),
        "lowerarm.l": (26, 0, -20), "lowerarm.r": (26, 0, 20),
        "head": (4, 0, 0),
        "lowerleg.l": (3, 0, 0), "lowerleg.r": (3, 0, 0),
        "foot.l": (-3, 0, 0), "foot.r": (-3, 0, 0),
    }, (0, 0.006, 0))),
    (1.5, pose({
        "upperarm.l": (-18, 0, -12), "upperarm.r": (-18, 0, 12),
        "lowerarm.l": (95, 0, -15), "lowerarm.r": (95, 0, 15),
        "head": (-4, 0, 5),
        "lowerleg.l": (14, 0, 0), "lowerleg.r": (14, 0, 0),
        "foot.l": (-14, 0, 0), "foot.r": (-14, 0, 0),
    }, (0, -0.015, 0))),
    # bar 2 - hip sway + shimmy
    (2.0, pose({
        "upperarm.l": (-30, 0, -10), "upperarm.r": (-30, 0, 10),
        "lowerarm.l": (48, 0, -15), "lowerarm.r": (48, 0, 15),
    })),
    (2.5, pose({
        "hips": (0, 22, 8), "chest": (0, -12, -5), "head": (0, -8, 9),
        "upperarm.l": (-22, 0, -16), "upperarm.r": (-18, 0, 22),
        "lowerarm.l": (55, 0, -10), "lowerarm.r": (35, 0, 18),
        "upperleg.l": (-16, 0, -4), "upperleg.r": (4, 0, 4),
        "lowerleg.l": (28, 0, 0), "lowerleg.r": (6, 0, 0),
        "foot.l": (-12, 0, 0), "foot.r": (-6, 0, 0),
    }, (0.02, -0.005, 0))),
    (3.0, pose({
        "upperarm.l": (-30, 0, -10), "upperarm.r": (-30, 0, 10),
        "lowerarm.l": (48, 0, -15), "lowerarm.r": (48, 0, 15),
    })),
    (3.5, pose({
        "hips": (0, -22, -8), "chest": (0, 12, 5), "head": (0, 8, -9),
        "upperarm.l": (-18, 0, -22), "upperarm.r": (-22, 0, 16),
        "lowerarm.l": (35, 0, -18), "lowerarm.r": (55, 0, 10),
        "upperleg.l": (4, 0, -4), "upperleg.r": (-16, 0, 4),
        "lowerleg.l": (6, 0, 0), "lowerleg.r": (28, 0, 0),
        "foot.l": (-6, 0, 0), "foot.r": (-12, 0, 0),
    }, (-0.02, -0.005, 0))),
    # bar 3 - heart hands + nod
    (4.0, pose({
        "upperarm.l": (-38, 0, -28), "upperarm.r": (-38, 0, 28),
        "lowerarm.l": (32, 0, -55), "lowerarm.r": (32, 0, 55),
        "hand.l": (0, 0, -10), "hand.r": (0, 0, 10),
        "head": (4, 0, 3), "chest": (2, 0, 0),
        "lowerleg.l": (9, 0, 0), "lowerleg.r": (9, 0, 0),
        "foot.l": (-9, 0, 0), "foot.r": (-9, 0, 0),
    }, (0, -0.005, 0))),
    (4.5, pose({
        "upperarm.l": (-34, 0, -45), "upperarm.r": (-34, 0, 45),
        "lowerarm.l": (38, 0, -85), "lowerarm.r": (38, 0, 85),
        "hand.l": (0, 0, -15), "hand.r": (0, 0, 15),
        "head": (6, 0, 5), "chest": (3, 0, 2),
        "lowerleg.l": (12, 0, 0), "lowerleg.r": (12, 0, 0),
        "foot.l": (-12, 0, 0), "foot.r": (-12, 0, 0),
    }, (0, -0.012, 0))),
    (5.0, pose({
        "upperarm.l": (-36, 0, -32), "upperarm.r": (-36, 0, 32),
        "lowerarm.l": (36, 0, -58), "lowerarm.r": (36, 0, 58),
        "hand.l": (0, 0, -12), "hand.r": (0, 0, 12),
        "head": (-2, 0, 2),
        "lowerleg.l": (7, 0, 0), "lowerleg.r": (7, 0, 0),
        "foot.l": (-7, 0, 0), "foot.r": (-7, 0, 0),
    }, (0, 0.002, 0))),
    (5.5, pose({
        "hips": (0, 8, -3), "chest": (3, -5, 0), "head": (6, 0, -6),
        "upperarm.l": (-34, 0, -45), "upperarm.r": (-34, 0, 45),
        "lowerarm.l": (38, 0, -85), "lowerarm.r": (38, 0, 85),
        "hand.l": (0, 0, -15), "hand.r": (0, 0, 15),
        "lowerleg.l": (12, 0, 0), "lowerleg.r": (12, 0, 0),
        "foot.l": (-12, 0, 0), "foot.r": (-12, 0, 0),
    }, (0, -0.012, 0))),
    # bar 4 - 360 spin + finish
    (6.0, pose({
        "upperarm.l": (-12, 0, -5), "upperarm.r": (-12, 0, 5),
        "lowerarm.l": (22, 0, -8), "lowerarm.r": (22, 0, 8),
        "head": (0, 15, 0), "chest": (0, 8, 0),
    }, (0, -0.005, 0))),
    (6.3, pose({
        "hips": (0, 90, 4),
        "upperarm.l": (-12, 0, -5), "upperarm.r": (-12, 0, 5),
        "lowerarm.l": (22, 0, -8), "lowerarm.r": (22, 0, 8),
    }, (0, -0.005, 0))),
    (6.6, pose({
        "hips": (0, 180, 4),
        "upperarm.l": (-12, 0, -5), "upperarm.r": (-12, 0, 5),
        "lowerarm.l": (22, 0, -8), "lowerarm.r": (22, 0, 8),
    }, (0, -0.005, 0))),
    (6.9, pose({
        "hips": (0, 270, 4),
        "upperarm.l": (-12, 0, -5), "upperarm.r": (-12, 0, 5),
        "lowerarm.l": (22, 0, -8), "lowerarm.r": (22, 0, 8),
    }, (0, -0.005, 0))),
    (7.2, pose({
        "hips": (0, 360, 0),
        "upperarm.l": (-12, 0, -5), "upperarm.r": (-12, 0, 5),
        "lowerarm.l": (22, 0, -8), "lowerarm.r": (22, 0, 8),
    })),
    (7.5, pose({
        "hips": (0, 360, 0),
        "upperarm.l": (-34, 0, -45), "upperarm.r": (-34, 0, 45),
        "lowerarm.l": (38, 0, -85), "lowerarm.r": (38, 0, 85),
        "hand.l": (0, 0, -15), "hand.r": (0, 0, 15),
        "head": (6, 0, -5), "chest": (3, 0, 0),
        "upperleg.l": (0, 0, -4), "upperleg.r": (0, 0, 4),
        "lowerleg.l": (16, 0, 0), "lowerleg.r": (16, 0, 0),
        "foot.l": (-16, 0, 0), "foot.r": (-16, 0, 0),
    }, (0, -0.02, 0))),
    (8.0, {**pose(), "rot": {**pose()["rot"], "hips": (0, 360, 0)}}),
]


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def lerp_pose(a, b, w):
    rot = {}
    for bone in BONES:
        av = a["rot"][bone]
        bv = b["rot"][bone]
        rot[bone] = tuple(av[i] + (bv[i] - av[i]) * w for i in range(3))
    loc = tuple(a["loc"][i] + (b["loc"][i] - a["loc"][i]) * w for i in range(3))
    return {"rot": rot, "loc": loc}


def pose_at(t):
    if t >= DURATION:
        return lerp_pose(KEYS[-1][1], KEYS[-1][1], 1.0)
    for i in range(len(KEYS) - 1):
        t0, p0 = KEYS[i]
        t1, p1 = KEYS[i + 1]
        if t0 <= t <= t1:
            w = smooth((t - t0) / max(1e-6, t1 - t0))
            p = lerp_pose(p0, p1, w)
            break
    else:
        p = KEYS[-1][1]
    # Procedural beat bounce: 120 BPM (2 dips/s), zero at t=0 and t=8.
    beat = 0.5 - 0.5 * math.cos(TAU * 2.0 * t)
    spin = 6.0 <= t < 7.2
    amt = 0.35 if spin else 1.0
    loc = list(p["loc"])
    loc[1] -= 0.030 * beat * amt
    p["loc"] = tuple(loc)
    for side in ("l", "r"):
        ll = p["rot"]["lowerleg." + side]
        ft = p["rot"]["foot." + side]
        p["rot"]["lowerleg." + side] = (ll[0] + 12.0 * beat * amt, ll[1], ll[2])
        p["rot"]["foot." + side] = (ft[0] - 12.0 * beat * amt, ft[1], ft[2])
    # tiny secondary sway, loop-friendly (integer cycles over 8 s)
    shimmy = 0.0 if (6.0 <= t < 7.2) else 1.0
    p["rot"]["chest"] = (p["rot"]["chest"][0], p["rot"]["chest"][1] + 4.0 * math.sin(TAU * 2.0 * t) * shimmy, p["rot"]["chest"][2] + 2.0 * math.sin(TAU * 2.0 * t))
    p["rot"]["head"] = (p["rot"]["head"][0], p["rot"]["head"][1], p["rot"]["head"][2] + 2.2 * math.sin(TAU * 2.0 * t + 0.8))
    return p


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=AF_GLB)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.render.fps_base = 1.0
    scene.frame_start = 0
    scene.frame_end = FRAMES
    if arm.animation_data:
        arm.animation_data_clear()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a, do_unlink=True)
    arm.animation_data_create()
    action = bpy.data.actions.new(ACTION_NAME)
    action.use_fake_user = True
    arm.animation_data.action = action
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    for frame in range(0, FRAMES + 1):
        t = frame / float(FPS)
        p = pose_at(t)
        for bone in BONES:
            pb = arm.pose.bones.get(bone)
            if pb is None:
                continue
            x, y, z = p["rot"][bone]
            pb.rotation_euler = Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ")
            pb.keyframe_insert("rotation_euler", frame=frame)
            if bone == "hips":
                pb.location = Vector(p["loc"])
                pb.keyframe_insert("location", frame=frame)
    for fc in action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    # Verify the loop seam at the action level.
    p0 = pose_at(0.0)
    p1 = pose_at(DURATION)
    maxd = 0.0
    for bone in BONES:
        for i in range(3):
            maxd = max(maxd, abs(p0["rot"][bone][i] - p1["rot"][bone][i]))
    print("DANCE_ACTION %s frames=%d..%d fcurves=%d bones=%d raw_seam_deg_max=%.4f (hips yaw 0 vs 360 = same quat)" % (
        ACTION_NAME, 0, FRAMES, len(action.fcurves), len(BONES), maxd))
    # Export only this action (no other actions remain).
    os.makedirs(os.path.dirname(GLB_OUT), exist_ok=True)
    os.makedirs(os.path.dirname(BLEND_OUT), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_skins=True,
        export_animations=True,
        export_frame_range=True,
        export_frame_step=1,
        export_force_sampling=True,
        export_nla_strips=False,
        export_nla_strips_merged_animation_name=ACTION_NAME,
        export_anim_single_armature=True,
        export_optimize_animation_size=False,
        export_image_format="AUTO",
        export_materials="EXPORT",
        export_yup=True,
    )
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    print("DANCE_GLB %s bytes=%d" % (GLB_OUT, os.path.getsize(GLB_OUT)))
    print("DANCE_BLEND %s bytes=%d" % (BLEND_OUT, os.path.getsize(BLEND_OUT)))


if __name__ == "__main__":
    main()
