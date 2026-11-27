#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
GODOT="${GODOT:-godot}"
for f in raw simplified; do
  "$BLENDER" -b --factory-startup -noaudio --python "$ROOT/scripts/inspect_blender.py" -- \
    --glb "$ROOT/exports/Rogue_MediaPipe_walk_$f.glb" | grep BLENDER_INSPECT
  bash "$REPO/animation-retarget-kit/tools/blender_validate.sh" \
    "$ROOT/exports/Rogue_MediaPipe_walk_$f.glb" | grep VALIDATION_REPORT
done
"$BLENDER" -b --factory-startup -noaudio --python-expr "
import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=30
bpy.ops.import_scene.fbx(filepath='$ROOT/exports/Rogue_MediaPipe_walk.fbx')
arms=[o for o in bpy.data.objects if o.type=='ARMATURE']
meshes=[o for o in bpy.data.objects if o.type=='MESH']
print('FBX_INSPECT arms=%d meshes=%d verts=%d' % (len(arms), len(meshes), sum(len(o.data.vertices) for o in meshes)))
" | grep FBX_INSPECT
"$GODOT" --headless --path "$ROOT/godot" -s tools/inspect_fbx.gd
"$GODOT" --headless --path "$ROOT/godot" -s tools/smoke.gd
