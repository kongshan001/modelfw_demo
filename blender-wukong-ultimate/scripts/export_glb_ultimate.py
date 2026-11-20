"""Bake the IK poses into per-frame FK and export wukong_ultimate.glb.

Blender 3.4.1.  The .blend keeps the editable IK rig; this script opens it,
bakes each action with visual keying, removes constraints/control bones and
writes a game-ready GLB with six named clips.
"""

import bpy
import json
import os
import struct

ROOT = "/Users/ks_128/Documents/modelfw_demo/blender-wukong-ultimate"
BLEND = ROOT + "/wukong_ultimate.blend"
OUT = ROOT + "/wukong_ultimate.glb"
CLIPS = ["Idle", "Run", "Charge", "Cast", "Hit", "Victory"]


def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = 'XYZ'
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)


def glb_json(path):
    with open(path, 'rb') as f:
        magic, version, length = struct.unpack('<4sII', f.read(12))
        assert magic == b'glTF', magic
        chunk_len, chunk_type = struct.unpack('<II', f.read(8))
        data = f.read(chunk_len)
    return json.loads(data.decode('utf-8'))


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    scene = bpy.context.scene
    arm = bpy.data.objects['WukongUltimateRig']
    body = bpy.data.objects['WukongUltimate_Body']
    bpy.context.view_layer.objects.active = arm

    # ── 1. bake each source action in place (visual keying, keeps IK live)
    for name in CLIPS:
        act = bpy.data.actions[name]
        reset_pose(arm)
        arm.animation_data.action = act
        first, last = [int(round(x)) for x in act.frame_range]
        scene.frame_start = first
        scene.frame_end = last
        bpy.ops.object.mode_set(mode='POSE')
        bpy.ops.pose.select_all(action='SELECT')
        bpy.ops.nla.bake(
            frame_start=first, frame_end=last, step=1,
            only_selected=True, visual_keying=True, clear_constraints=False,
            clear_parents=False, use_current_action=True,
            bake_types={'POSE'})
        bpy.ops.object.mode_set(mode='OBJECT')
        print('BAKE', name, 'frames', first, last,
              'curves', len(act.fcurves))

    # ── 2. freeze FK: remove constraints and the non-deform controls
    for pb in arm.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    bpy.ops.object.mode_set(mode='EDIT')
    for eb in list(arm.data.edit_bones):
        if eb.name.startswith('ctrl_'):
            arm.data.edit_bones.remove(eb)
    bpy.ops.object.mode_set(mode='OBJECT')
    for act in bpy.data.actions:
        for fc in list(act.fcurves):
            if 'ctrl_' in fc.data_path:
                act.fcurves.remove(fc)
            else:
                for kp in fc.keyframe_points:
                    kp.interpolation = 'LINEAR'
                    kp.co.x -= 1.0
                    kp.handle_left.x -= 1.0
                    kp.handle_right.x -= 1.0
                fc.update()
    reset_pose(arm)

    # ── 3. verify the baked pose by rendering one charge frame
    scene.eevee.taa_render_samples = 10
    scene.render.resolution_x = 560
    scene.render.resolution_y = 560
    scene.render.resolution_percentage = 100
    arm.animation_data.action = bpy.data.actions['Charge']
    scene.frame_set(17)
    scene.render.filepath = '/tmp/wukong_baked_charge.png'
    bpy.ops.render.render(write_still=True)
    arm.animation_data.action = bpy.data.actions['Victory']
    scene.frame_set(26)
    scene.render.filepath = '/tmp/wukong_baked_victory.png'
    bpy.ops.render.render(write_still=True)

    # ── 4. one NLA track per clip for the glTF exporter
    arm.animation_data.action = None
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
    for name in CLIPS:
        act = bpy.data.actions[name]
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, act)
        strip.name = name
        strip.action_frame_start = act.frame_range[0]
        strip.action_frame_end = act.frame_range[1]
    arm.animation_data.use_nla = True

    # ── 5. export rig + skinned mesh only
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format='GLB', use_selection=True,
        export_animations=True, export_nla_strips=True,
        export_frame_range=False, export_force_sampling=True,
        export_skins=True, export_yup=True, export_apply=False,
        export_cameras=False, export_lights=False, export_colors=True,
        export_def_bones=False, export_anim_single_armature=True,
        export_reset_pose_bones=True)

    # ── 6. validate
    doc = glb_json(OUT)
    anims = [a.get('name', '?') for a in doc.get('animations', [])]
    skins = doc.get('skins', [])
    joints = len(skins[0]['joints']) if skins else 0
    prims = [p for m in doc.get('meshes', []) for p in m['primitives']]
    tris = 0
    for p in prims:
        acc = doc['accessors'][p['indices']] if 'indices' in p else None
        if acc:
            tris += acc['count'] // 3
        else:
            tris += doc['accessors'][p['attributes']['POSITION']]['count'] // 3
    attrs = sorted(set(k for p in prims for k in p['attributes']))
    times = []
    for a in doc.get('animations', []):
        tmax = 0.0
        for s in a['samplers']:
            acc = doc['accessors'][s['input']]
            if 'max' in acc:
                tmax = max(tmax, float(acc['max'][0]))
        times.append(round(tmax, 3))
    print('GLB_ULT_OK file=%s bytes=%d tris=%d joints=%d animations=%d names=%s '
          'durations=%s attrs=%s materials=%d images=%d' % (
              OUT, os.path.getsize(OUT), tris, joints, len(anims),
              ','.join(anims), times, ','.join(attrs),
              len(doc.get('materials', [])), len(doc.get('images', []))))
    expected = set(CLIPS)
    got = set(anims)
    if not expected.issubset(got):
        print('GLB_ULT_WARN missing clips', expected - got)
    if not (15000 <= tris <= 60000):
        print('GLB_ULT_WARN tri budget', tris)
    if joints < 25:
        print('GLB_ULT_WARN joint count', joints)


if __name__ == '__main__':
    main()
