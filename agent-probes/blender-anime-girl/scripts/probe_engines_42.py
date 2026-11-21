"""Probe Blender 4.2.9 render engines on this machine (T-20261121-029).

Findings on the probe machine (Intel HD 6000, macOS):
  * Workbench        -> SIGSEGV in the draw manager (DRW_state_set), even on a
                        factory default cube. Reproduce with --factory.
  * EEVEE Next       -> same SIGSEGV.
  * Cycles CPU       -> renders, but the EEVEE-only Shader-to-RGB toon nodes do
                        not work in Cycles (character renders dark).

Usage:
  /Applications/Blender-4.2.app/Contents/MacOS/Blender -b \
      -P scripts/probe_engines_42.py -- workbench [--factory]
  ... -- workbench --factory     # default cube, proves crash is machine-wide
  ... -- eevee_next
  ... -- cycles                  # 320x400, 8 samples, CPU
"""

import os
import sys
import time

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, 'qinghe.blend')
OUT = os.path.join(ROOT, 'renders')
os.makedirs(OUT, exist_ok=True)

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
MODE = ARGS[0] if ARGS else 'workbench'
FACTORY = '--factory' in ARGS

if FACTORY:
    bpy.ops.wm.read_factory_settings(use_empty=False)
else:
    bpy.ops.wm.open_mainfile(filepath=BLEND)

sc = bpy.context.scene
sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = 'PNG'
sc.render.filepath = os.path.join(OUT, 'engine42_' + MODE + '.png')
sc.render.resolution_x, sc.render.resolution_y = 480, 600
if MODE == 'cycles':
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 8
    sc.render.resolution_x, sc.render.resolution_y = 320, 400
elif MODE == 'eevee_next':
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.eevee.taa_render_samples = 8
else:
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_object_outline = True
    sc.display.shading.show_shadows = True
    sc.display.shading.show_cavity = True

print('PROBE42_START', MODE, 'factory=%s' % FACTORY, sc.render.engine,
      sc.render.resolution_x, sc.render.resolution_y)
t0 = time.time()
bpy.ops.render.render(write_still=True)
print('PROBE42_OK', MODE, 'render=%.1fs' % (time.time() - t0),
      sc.render.filepath)
