"""Original realistic sports roadster concept renderer (Blender 3.x, headless).

Builds a brand-free, original low-slung two-seat roadster from scratch and
renders multi-view reference images for Tripo image-to-3D. No third-party
models, photos, logos or trademarks are used.

Coordinates: +Y = forward, +X = left, +Z = up. Wheels are intentionally
omitted: the game keeps its procedural wheels, so the reference has carved
wheel wells only.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/blender/realistic_car_refs.py -- \
      --out /tmp/realistic_car --samples 32 --size 512
"""

import argparse
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument("--out", default="/tmp/realistic_car")
parser.add_argument("--samples", type=int, default=64)
parser.add_argument("--size", type=int, default=1024)
parser.add_argument("--preview", action="store_true")
args = parser.parse_args(ARGS)

OUT = os.path.abspath(args.out)
os.makedirs(OUT, exist_ok=True)

# --------------------------------------------------------------------------
# Scene reset
# --------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = args.samples
scene.cycles.use_denoising = True
scene.render.resolution_x = args.size
scene.render.resolution_y = args.size
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Filmic"
scene.view_settings.look = "Medium High Contrast"

# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------
def principled(name, base, metallic=0.0, roughness=0.5, coat=0.0,
               emission=None, emission_strength=0.0, transmission=0.0,
               alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*base, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    elif "Clearcoat" in bsdf.inputs:
        bsdf.inputs["Clearcoat"].default_value = coat
    if emission is not None:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if transmission > 0.0:
        if "Transmission Weight" in bsdf.inputs:
            bsdf.inputs["Transmission Weight"].default_value = transmission
        elif "Transmission" in bsdf.inputs:
            bsdf.inputs["Transmission"].default_value = transmission
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = "BLEND"
    return mat


# Neutral warm-white paint so per-team tinting in Godot multiplies cleanly.
MAT_PAINT = principled("Paint_PearlWhite", (0.78, 0.76, 0.71), 0.55, 0.26, coat=1.0)
MAT_BLACK = principled("Trim_SatinBlack", (0.015, 0.017, 0.020), 0.10, 0.38, coat=0.25)
MAT_CARBON = principled("Trim_Carbon", (0.028, 0.031, 0.036), 0.25, 0.32, coat=0.5)
MAT_GLASS = principled("Glass_Smoke", (0.012, 0.020, 0.028), 0.25, 0.045, coat=1.0)
MAT_CHROME = principled("Trim_Chrome", (0.72, 0.73, 0.75), 1.0, 0.14)
MAT_INTERIOR = principled("Interior_Leather", (0.035, 0.033, 0.031), 0.0, 0.62)
MAT_WELL = principled("WheelWell_Gray", (0.055, 0.058, 0.063), 0.0, 0.72)
MAT_HEADLIGHT = principled("Light_Head", (0.92, 0.95, 1.0), 0.0, 0.15,
                           emission=(1.0, 0.97, 0.90), emission_strength=9.0)
MAT_TAILLIGHT = principled("Light_Tail", (0.65, 0.02, 0.03), 0.0, 0.22,
                           emission=(1.0, 0.035, 0.02), emission_strength=7.0)
MAT_STEEL = principled("Brake_Steel", (0.35, 0.34, 0.33), 0.85, 0.32)
MAT_WELL_DEEP = principled("WheelWell_Deep", (0.045, 0.048, 0.052), 0.0, 0.82)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
def link(obj):
    bpy.context.collection.objects.link(obj)
    return obj


def set_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def shade_smooth(obj, angle=35.0):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if hasattr(obj.data, "use_auto_smooth"):
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(angle)


def apply_mods(obj):
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def bevel(obj, width=0.015, segments=3):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    return mod


def add_box(name, size, loc, mat, rot=(0, 0, 0), bevel_width=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel_width > 0:
        bevel(obj, bevel_width, 3)
        apply_mods(obj)
    set_material(obj, mat)
    shade_smooth(obj, 50)
    return obj


def add_cyl(name, radius, depth, loc, mat, axis="Z", segments=32, rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius,
                                        depth=depth, location=loc)
    obj = bpy.context.object
    obj.name = name
    if rot is not None:
        obj.rotation_euler = rot
    elif axis == "X":
        obj.rotation_euler = (0, math.pi * 0.5, 0)
    elif axis == "Y":
        obj.rotation_euler = (math.pi * 0.5, 0, 0)
    set_material(obj, mat)
    shade_smooth(obj, 40)
    return obj


def add_torus(name, major, minor, loc, mat, rot=(math.pi * 0.5, 0, 0),
              major_seg=32, minor_seg=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=major_seg,
                                     minor_segments=minor_seg,
                                     location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    set_material(obj, mat)
    shade_smooth(obj, 40)
    return obj


def add_arch_trim(side, y, radius=0.383, tube=0.017, mat=None, cx=None):
    """Half-torus wheel-arch lip in the YZ plane (top half only)."""
    verts = []
    rings = []
    steps = 28
    radial_steps = 8
    if mat is None:
        mat = MAT_BLACK
    if cx is None:
        cx = side * 0.910
    zc = 0.345
    for i in range(steps + 1):
        a = math.pi * i / steps
        cy = y + radius * math.cos(a)
        cz = zc + radius * math.sin(a)
        rad = Vector((0.0, math.cos(a), math.sin(a)))
        ring = []
        for j in range(radial_steps):
            b = math.tau * j / radial_steps
            p = Vector((cx, cy, cz)) + rad * (tube * math.cos(b)) + Vector((tube * math.sin(b), 0, 0))
            ring.append(len(verts))
            verts.append(tuple(p))
        rings.append(ring)
    faces = []
    for i in range(steps):
        for j in range(radial_steps):
            j2 = (j + 1) % radial_steps
            faces.append((rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]))
    mesh = bpy.data.meshes.new("ArchTrimMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = link(bpy.data.objects.new("ArchTrim", mesh))
    set_material(obj, mat)
    shade_smooth(obj, 40)
    return obj


# --------------------------------------------------------------------------
# Body: lofted cross-sections + subsurf, then boolean wheel arches / cockpit
# --------------------------------------------------------------------------
# (y, half_width, bottom_z, top_z)
STATIONS = [
    (1.66, 0.40, 0.28, 0.52),
    (1.62, 0.62, 0.22, 0.50),
    (1.50, 0.76, 0.16, 0.54),
    (1.34, 0.85, 0.13, 0.58),
    (1.18, 0.90, 0.12, 0.69),
    (1.02, 0.93, 0.12, 0.745),   # front fender peak
    (0.86, 0.91, 0.12, 0.68),
    (0.66, 0.89, 0.12, 0.615),
    (0.42, 0.88, 0.12, 0.625),
    (0.20, 0.87, 0.12, 0.665),
    (0.02, 0.86, 0.12, 0.705),
    (-0.22, 0.87, 0.12, 0.735),
    (-0.52, 0.89, 0.12, 0.755),
    (-0.82, 0.92, 0.13, 0.785),
    (-1.02, 0.93, 0.14, 0.80),   # rear fender peak
    (-1.22, 0.90, 0.16, 0.785),
    (-1.42, 0.83, 0.19, 0.755),
    (-1.58, 0.72, 0.23, 0.715),
    (-1.66, 0.50, 0.28, 0.67),
]
RING_POINTS = 24


def ring_points(y, half_w, bottom, top):
    pts = []
    zc = (bottom + top) * 0.5
    hh = (top - bottom) * 0.5
    for i in range(RING_POINTS):
        t = math.tau * i / RING_POINTS
        cx, sz = math.cos(t), math.sin(t)
        x = half_w * math.copysign(abs(cx) ** 0.62, cx)
        q = 0.55 if sz < 0 else 0.72
        z = zc + hh * math.copysign(abs(sz) ** q, sz)
        # Slight tumblehome above the shoulder and tuck under the sill.
        if sz > 0.0:
            x *= 1.0 - 0.10 * sz
        else:
            x *= 1.0 - 0.035 * (-sz)
        pts.append((x, y, z))
    return pts


def build_body():
    bm = bmesh.new()
    rings = []
    for y, w, b, t in STATIONS:
        ring = [bm.verts.new(p) for p in ring_points(y, w, b, t)]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(RING_POINTS):
            j = (i + 1) % RING_POINTS
            bm.faces.new((a[i], a[j], b[j], b[i]))
    # Crease the shoulder loop so the subsurf keeps a readable character line.
    bm.edges.ensure_lookup_table()
    crease = bm.edges.layers.crease.verify()
    for a, b in zip(rings, rings[1:]):
        for idx in (2, RING_POINTS - 2):
            e = bm.edges.get((a[idx], b[idx]))
            if e is not None:
                e[crease] = 0.55
    # Cap both ends with a fan around the ring centroid.
    for ring, y in ((rings[0], STATIONS[0][0]), (rings[-1], STATIONS[-1][0])):
        center = bm.verts.new((0.0, y, (ring[0].co.z + ring[RING_POINTS // 2].co.z) * 0.5))
        for i in range(RING_POINTS):
            j = (i + 1) % RING_POINTS
            bm.faces.new((center, ring[i], ring[j]))
    bm.normal_update()
    mesh = bpy.data.meshes.new("BodyMesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new("Body", mesh))
    set_material(obj, MAT_PAINT)
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    apply_mods(obj)
    shade_smooth(obj, 32)
    return obj


def boolean_difference(target, cutter):
    mod = target.modifiers.new("Cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    apply_mods(target)
    bpy.data.objects.remove(cutter, do_unlink=True)


def build_arch_cutter(y):
    # Rounded wheel-arch cutter, open to the outside so it never cuts the
    # opposite side of the body.
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.365, depth=0.9,
                                        location=(0.78, y, 0.345),
                                        rotation=(0, math.pi * 0.5, 0))
    obj = bpy.context.object
    bevel_mod = obj.modifiers.new("Bevel", "BEVEL")
    bevel_mod.width = 0.02
    bevel_mod.segments = 3
    apply_mods(obj)
    return obj


def build_cockpit_cutter():
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.0, -0.47, 0.67))
    obj = bpy.context.object
    obj.scale = (0.52, 0.43, 0.30)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel(obj, 0.07, 4)
    apply_mods(obj)
    return obj


def build_body_and_arches():
    body = build_body()
    for y in (1.02, -1.02):
        boolean_difference(body, build_arch_cutter(y))
    boolean_difference(body, build_cockpit_cutter())
    shade_smooth(body, 32)
    # Wheel-well liners: an open half-tube above each wheel plus an inboard
    # disc, so the boolean hole never shows the lit inside of the body.
    for y in (1.02, -1.02):
        for side in (-1.0, 1.0):
            add_wheel_liner(side, y)
            add_cyl("WheelInner", 0.355, 0.012, (side * 0.575, y, 0.345),
                    MAT_WELL_DEEP, axis="X", segments=40)
            add_arch_trim(side, y, radius=0.383, tube=0.016, cx=side * 0.905)
            add_arch_trim(side, y, radius=0.408, tube=0.027, mat=MAT_PAINT,
                          cx=side * 0.928)
    return body


def add_wheel_liner(side, y):
    verts = []
    rings = []
    steps = 20
    x0, x1 = side * 0.605, side * 0.925
    for x in (x0, x1):
        ring = []
        for i in range(steps + 1):
            a = math.pi * i / steps
            ring.append(len(verts))
            verts.append((x, y + 0.362 * math.cos(a), 0.345 + 0.362 * math.sin(a)))
        rings.append(ring)
    faces = []
    for i in range(steps):
        faces.append((rings[0][i], rings[0][i + 1], rings[1][i + 1], rings[1][i]))
    mesh = bpy.data.meshes.new("WheelLinerMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = link(bpy.data.objects.new("WheelLiner", mesh))
    set_material(obj, MAT_WELL)
    shade_smooth(obj, 40)
    return obj


body = build_body_and_arches()

# --------------------------------------------------------------------------
# Cockpit interior
# --------------------------------------------------------------------------
add_box("CockpitTub", (0.80, 0.86, 0.30), (0, -0.47, 0.44), MAT_INTERIOR,
        bevel_width=0.03)
add_box("SeatCushion", (0.56, 0.44, 0.10), (0, -0.52, 0.47), MAT_INTERIOR,
        bevel_width=0.04)
add_box("SeatBack", (0.58, 0.13, 0.40), (0, -0.78, 0.66), MAT_INTERIOR,
        bevel_width=0.05)
add_box("Headrest", (0.30, 0.10, 0.13), (0, -0.80, 0.90), MAT_INTERIOR,
        bevel_width=0.04)
add_box("Dashboard", (0.74, 0.17, 0.11), (0, -0.115, 0.60), MAT_BLACK,
        bevel_width=0.03)
add_box("Binnacle", (0.30, 0.09, 0.07), (0, -0.075, 0.655), MAT_BLACK,
        bevel_width=0.02)
add_cyl("SteeringColumn", 0.022, 0.20, (0, 0.015, 0.665), MAT_BLACK,
        axis="Y", segments=16)

# Low raked windscreen with black frame.
def windshield_grid(rows=5, cols=9):
    verts = []
    for r in range(rows):
        v = r / (rows - 1.0)
        y = 0.15 - v * 0.43
        z = 0.695 + v * 0.255
        half = (0.38 - v * 0.075)
        for c in range(cols):
            u = c / (cols - 1.0) * 2.0 - 1.0
            x = u * half
            yy = y + (1.0 - u * u) * 0.022 - (1.0 - v) * 0.012
            verts.append((x, yy, z))
    faces = []
    for r in range(rows - 1):
        for c in range(cols - 1):
            a = r * cols + c
            faces.append((a, a + 1, a + 1 + cols, a + cols))
    return verts, faces, rows, cols


def build_windshield():
    verts, faces, rows, cols = windshield_grid()
    mesh = bpy.data.meshes.new("WindshieldMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = link(bpy.data.objects.new("Windshield", mesh))
    set_material(obj, MAT_GLASS)
    solidify = obj.modifiers.new("Solidify", "SOLIDIFY")
    solidify.thickness = 0.012
    apply_mods(obj)
    shade_smooth(obj, 35)
    # Swept black frame around the glass border (no floating A-pillar boxes).
    border = []
    for c in range(cols):
        border.append(c)
    for r in range(1, rows):
        border.append(r * cols + cols - 1)
    for c in range(cols - 2, -1, -1):
        border.append((rows - 1) * cols + c)
    for r in range(rows - 2, 0, -1):
        border.append(r * cols)
    normal = Vector((0.0, -0.62, 0.78)).normalized()
    tube_r = 0.026
    radial_steps = 6
    frame_verts = []
    frame_rings = []
    n = len(border)
    for i, idx in enumerate(border):
        p = Vector(verts[idx])
        prev_p = Vector(verts[border[(i - 1) % n]])
        next_p = Vector(verts[border[(i + 1) % n]])
        tangent = (next_p - prev_p).normalized()
        bitangent = tangent.cross(normal).normalized()
        ring = []
        for j in range(radial_steps):
            a = math.tau * j / radial_steps
            q = p + normal * (tube_r * math.cos(a)) + bitangent * (tube_r * math.sin(a))
            ring.append(len(frame_verts))
            frame_verts.append(tuple(q))
        frame_rings.append(ring)
    frame_faces = []
    for i in range(n):
        j = (i + 1) % n
        for k in range(radial_steps):
            k2 = (k + 1) % radial_steps
            frame_faces.append((frame_rings[i][k], frame_rings[i][k2],
                                frame_rings[j][k2], frame_rings[j][k]))
    frame_mesh = bpy.data.meshes.new("WindshieldFrameMesh")
    frame_mesh.from_pydata(frame_verts, [], frame_faces)
    frame_mesh.update()
    frame_obj = link(bpy.data.objects.new("WindshieldFrame", frame_mesh))
    set_material(frame_obj, MAT_BLACK)
    shade_smooth(frame_obj, 40)
    return obj


build_windshield()

# Roll hoops behind the seats.
for side in (-1.0, 1.0):
    add_torus("RollHoop", 0.18, 0.032, (side * 0.25, -0.86, 0.72),
              MAT_BLACK, rot=(math.pi * 0.5, 0, 0))

# Mirrors.
for side in (-1.0, 1.0):
    add_box("MirrorStalk", (0.16, 0.040, 0.032),
            (side * 0.875, 0.075, 0.765), MAT_BLACK,
            rot=(0, side * math.radians(-12), 0), bevel_width=0.008)
    add_box("MirrorPod", (0.16, 0.11, 0.070),
            (side * 0.965, 0.065, 0.795), MAT_PAINT, bevel_width=0.028)

# Side skirts and front splitter / rear diffuser.
for side in (-1.0, 1.0):
    add_box("SideSkirt", (0.09, 1.55, 0.11),
            (side * 0.855, -0.03, 0.155), MAT_CARBON, bevel_width=0.012)
add_box("FrontSplitter", (1.84, 0.32, 0.045), (0, 1.60, 0.105), MAT_CARBON,
        bevel_width=0.012)
add_box("SplitterLip", (1.88, 0.06, 0.07), (0, 1.745, 0.115), MAT_BLACK,
        bevel_width=0.01)
add_box("RearDiffuser", (1.46, 0.30, 0.08), (0, -1.58, 0.145), MAT_CARBON,
        bevel_width=0.01)
for i in range(5):
    x = -0.56 + i * 0.28
    add_box("DiffuserFin", (0.025, 0.28, 0.16), (x, -1.58, 0.20), MAT_BLACK)

# Front intakes and headlights.
add_box("FrontIntake", (0.88, 0.05, 0.15), (0, 1.685, 0.315), MAT_BLACK,
        bevel_width=0.02)
for side in (-1.0, 1.0):
    add_box("SideIntake", (0.24, 0.05, 0.16), (side * 0.68, 1.665, 0.30),
            MAT_BLACK, bevel_width=0.02)
    add_box("HeadlightHousing", (0.36, 0.065, 0.10),
            (side * 0.49, 1.625, 0.50), MAT_BLACK,
            rot=(0, 0, side * math.radians(-6)), bevel_width=0.015)
    add_box("HeadlightBar", (0.31, 0.045, 0.045),
            (side * 0.49, 1.655, 0.505), MAT_HEADLIGHT,
            rot=(0, 0, side * math.radians(-6)), bevel_width=0.01)
    add_box("DRL", (0.045, 0.04, 0.10),
            (side * 0.66, 1.64, 0.44), MAT_HEADLIGHT,
            rot=(0, 0, side * math.radians(-6)), bevel_width=0.008)
    # Side gill behind the front wheel.
    add_box("SideGill", (0.045, 0.36, 0.12),
            (side * 0.900, 0.36, 0.47), MAT_BLACK,
            rot=(0, side * math.radians(4), 0), bevel_width=0.012)
    # Hood vent + door shutline.
    add_box("HoodVent", (0.24, 0.34, 0.014),
            (side * 0.34, 0.72, 0.652), MAT_BLACK,
            rot=(math.radians(-3), 0, side * math.radians(3)), bevel_width=0.006)
    add_box("DoorSeam", (0.006, 0.010, 0.34),
            (side * 0.902, -0.075, 0.455), MAT_BLACK, bevel_width=0.002)

# Full-width tail light + rear deck lip.
for i in range(3):
    x = -0.26 + i * 0.26
    add_box("DeckVent", (0.14, 0.30, 0.012), (x, -1.12, 0.807), MAT_BLACK,
            rot=(math.radians(-3), 0, 0), bevel_width=0.004)
add_box("TailHousing", (1.38, 0.06, 0.085), (0, -1.675, 0.655), MAT_BLACK,
        bevel_width=0.015)
add_box("TailBar", (1.30, 0.035, 0.040), (0, -1.705, 0.655), MAT_TAILLIGHT,
        bevel_width=0.008)
add_box("Ducktail", (1.44, 0.24, 0.055), (0, -1.43, 0.805), MAT_PAINT,
        rot=(math.radians(-7), 0, 0), bevel_width=0.02)
for side in (-1.0, 1.0):
    add_box("DucktailPost", (0.055, 0.10, 0.06),
            (side * 0.55, -1.42, 0.765), MAT_BLACK, bevel_width=0.01)

# Exhaust tips.
for side in (-1.0, 1.0):
    add_cyl("Exhaust", 0.058, 0.14, (side * 0.22, -1.72, 0.30), MAT_CHROME,
            axis="Y", segments=24)
    add_cyl("ExhaustInner", 0.045, 0.06, (side * 0.22, -1.755, 0.30), MAT_BLACK,
            axis="Y", segments=24)

# Two-tone rocker accent: a thin dark stripe (helps the tinted paint read).
for side in (-1.0, 1.0):
    add_box("RockerStripe", (0.012, 1.30, 0.035),
            (side * 0.895, 0.05, 0.27), MAT_BLACK, bevel_width=0.004)

# --------------------------------------------------------------------------
# Ground, lights, cameras
# --------------------------------------------------------------------------
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
ground = bpy.context.object
ground.name = "ShadowCatcher"
ground.is_shadow_catcher = True
set_material(ground, MAT_WELL)

world = bpy.data.worlds.new("StudioWorld")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.42, 0.45, 0.50, 1.0)
bg.inputs["Strength"].default_value = 0.65

def add_area(name, loc, target, energy, size, color=(1, 1, 1)):
    bpy.ops.object.light_add(type="AREA", location=loc)
    light = bpy.context.object
    light.name = name
    direction = Vector(target) - Vector(loc)
    light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    return light

add_area("Key", (4.5, 5.5, 6.0), (0, 0.2, 0.4), 560, 4.5, (1.0, 0.97, 0.92))
add_area("Fill", (-5.5, 2.0, 3.2), (0, 0.0, 0.4), 220, 5.0, (0.82, 0.89, 1.0))
add_area("Rim", (-2.5, -6.0, 4.5), (0, -0.8, 0.5), 480, 3.5, (0.92, 0.96, 1.0))
add_area("Top", (0, 0, 7.0), (0, -0.2, 0.3), 300, 6.0, (1.0, 1.0, 1.0))

def camera(name, loc, target, lens):
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.object
    cam.name = name
    cam.data.lens = lens
    cam.data.sensor_width = 36
    direction = Vector(target) - Vector(loc)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return cam

TARGET = (0.0, 0.02, 0.44)
cams = {
    "3q": camera("Cam_3q", (4.35, 4.95, 1.52), (0.0, 0.03, 0.44), 62),
    "side": camera("Cam_side", (9.6, 0.02, 0.52), (0, 0.02, 0.48), 70),
    "front": camera("Cam_front", (0.0, 8.8, 0.62), (0, 0.0, 0.44), 75),
    "rear3q": camera("Cam_rear3q", (-4.85, -5.65, 1.75), (0, -0.12, 0.45), 60),
}

# --------------------------------------------------------------------------
# Render
# --------------------------------------------------------------------------
def render(name, cam, size=None):
    if size:
        scene.render.resolution_x = size
        scene.render.resolution_y = size
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)

if args.preview:
    render("preview_3q", cams["3q"], args.size)
    render("preview_side", cams["side"], args.size)
else:
    for key, cam in cams.items():
        render("realistic_car_%s" % key, cam, args.size)

# Save the procedural source scene for provenance (no external assets).
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "realistic_car_concept.blend"))
print("DONE", OUT)
