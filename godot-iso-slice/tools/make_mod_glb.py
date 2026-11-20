#!/usr/bin/env python3
"""Generate the GLB mod fixtures for the runtime-import PoC.

The GLB is written by hand (no DCC): a hexagonal stone base + an ember
crystal, vertex-coloured so the demo can render it unshaded on GL
Compatibility. Three fixtures are produced:

    crystal_lamp  valid manifest
    bad_scale     same GLB, manifest bounds too small -> rejected
    bad_hash      same GLB, manifest sha256 wrong    -> rejected

Run:
    python3 tools/make_mod_glb.py

Outputs:
    mods/<id>/manifest.json
    mods/<id>/crystal_lamp.glb
    mods/README.md
    mods/.gdignore
"""

import hashlib
import json
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODS = os.path.join(ROOT, "mods")

FLOAT = 5126
U16 = 5123
ARRAY_BUFFER = 34962
ELEMENT_ARRAY_BUFFER = 34963


class GLB:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accessors = []

    def add(self, data, comp_type, count, type_, minv=None, maxv=None, target=None):
        pad = (4 - len(self.bin) % 4) % 4
        self.bin += b"\0" * pad
        offset = len(self.bin)
        payload = data + b"\0" * ((4 - len(data) % 4) % 4)
        self.bin += payload
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(payload)}
        if target is not None:
            view["target"] = target
        self.views.append(view)
        acc = {
            "bufferView": len(self.views) - 1,
            "componentType": comp_type,
            "count": count,
            "type": type_,
        }
        if minv is not None:
            acc["min"] = minv
        if maxv is not None:
            acc["max"] = maxv
        self.accessors.append(acc)
        return len(self.accessors) - 1


def f32(vals):
    return struct.pack("<%df" % len(vals), *vals)


def u16(vals):
    return struct.pack("<%dH" % len(vals), *vals)


def build_base():
    n = 6
    r0, r1, h = 0.45, 0.38, 0.5
    pos, nor, col = [], [], []
    for i in range(n):
        a = math.tau * i / n
        pos += [math.cos(a) * r0, 0.0, math.sin(a) * r0]
        nor += [math.cos(a), 0.0, math.sin(a)]
        col += [0.20, 0.22, 0.30, 1.0]
    for i in range(n):
        a = math.tau * i / n
        pos += [math.cos(a) * r1, h, math.sin(a) * r1]
        nor += [math.cos(a), 0.0, math.sin(a)]
        col += [0.38, 0.42, 0.55, 1.0]
    # top cap centre
    pos += [0.0, h, 0.0]
    nor += [0.0, 1.0, 0.0]
    col += [0.46, 0.50, 0.63, 1.0]
    idx = []
    for i in range(n):
        j = (i + 1) % n
        b0, b1, t0, t1 = i, j, n + i, n + j
        idx += [b0, b1, t1, b0, t1, t0]
    centre = 2 * n
    for i in range(n):
        j = (i + 1) % n
        idx += [centre, n + i, n + j]
    return pos, nor, col, idx


def build_crystal():
    top = (0.0, 1.3, 0.0)
    eq = [(0.22, 0.90, 0.0), (0.0, 0.90, 0.22),
          (-0.22, 0.90, 0.0), (0.0, 0.90, -0.22)]
    bottom = (0.0, 0.50, 0.0)
    pos = [top] + eq + [bottom]
    col = [(1.00, 0.78, 0.42, 1.0)] + [(0.95, 0.46, 0.20, 1.0)] * 4 + [(0.45, 0.13, 0.06, 1.0)]
    nor = []
    centre = (0.0, 0.9, 0.0)
    for p in pos:
        dx, dy, dz = p[0] - centre[0], p[1] - centre[1], p[2] - centre[2]
        ln = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
        nor += [dx / ln, dy / ln, dz / ln]
    idx = []
    for i in range(4):
        a = 1 + i
        b = 1 + (i + 1) % 4
        idx += [0, a, b]
        idx += [5, b, a]
    flat_pos, flat_col, flat_nor = [], [], []
    for i in range(len(pos)):
        flat_pos += list(pos[i])
        flat_col += list(col[i])
        flat_nor += nor[i * 3:i * 3 + 3]
    return flat_pos, flat_nor, flat_col, idx


def build_glb():
    base_pos, base_nor, base_col, base_idx = build_base()
    cry_pos, cry_nor, cry_col, cry_idx = build_crystal()

    b = GLB()
    meshes = []
    combined_min = [float("inf")] * 3
    combined_max = [float("-inf")] * 3
    for name, pos, nor, col, idx in (
            ("Base", base_pos, base_nor, base_col, base_idx),
            ("Crystal", cry_pos, cry_nor, cry_col, cry_idx)):
        count = len(pos) // 3
        minv = [min(pos[i::3]) for i in range(3)]
        maxv = [max(pos[i::3]) for i in range(3)]
        for i in range(3):
            combined_min[i] = min(combined_min[i], minv[i])
            combined_max[i] = max(combined_max[i], maxv[i])
        p_acc = b.add(f32(pos), FLOAT, count, "VEC3", minv, maxv, ARRAY_BUFFER)
        n_acc = b.add(f32(nor), FLOAT, count, "VEC3", target=ARRAY_BUFFER)
        c_acc = b.add(f32(col), FLOAT, count, "VEC4", target=ARRAY_BUFFER)
        i_acc = b.add(u16(idx), U16, len(idx), "SCALAR", target=ELEMENT_ARRAY_BUFFER)
        meshes.append({
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": p_acc, "NORMAL": n_acc, "COLOR_0": c_acc},
                "indices": i_acc,
                "material": 0 if name == "Base" else 1,
                "mode": 4,
            }],
        })

    gltf = {
        "asset": {"version": "2.0", "generator": "iso-slice mod poc"},
        "scene": 0,
        "scenes": [{"name": "CrystalLamp", "nodes": [0]}],
        "nodes": [
            {"name": "CrystalLamp", "children": [1, 2]},
            {"name": "Base", "mesh": 0},
            {"name": "Crystal", "mesh": 1},
        ],
        "meshes": meshes,
        "materials": [
            {"name": "stone", "doubleSided": True,
             "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1],
                                      "metallicFactor": 0.0, "roughnessFactor": 0.9}},
            {"name": "ember", "doubleSided": True,
             "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1],
                                      "metallicFactor": 0.0, "roughnessFactor": 0.35},
             "emissiveFactor": [0.28, 0.07, 0.01]},
        ],
        "accessors": b.accessors,
        "bufferViews": b.views,
        "buffers": [{"byteLength": len(b.bin)}],
    }

    json_bytes = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    bin_bytes = bytes(b.bin) + b"\0" * ((4 - len(b.bin) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    out = b"glTF" + struct.pack("<II", 2, total)
    out += struct.pack("<I", len(json_bytes)) + b"JSON" + json_bytes
    out += struct.pack("<I", len(bin_bytes)) + b"BIN\0" + bin_bytes
    return out, (combined_min, combined_max)


def write_fixture(folder, glb_bytes, manifest):
    path = os.path.join(MODS, folder)
    os.makedirs(path, exist_ok=True)
    with open(os.path.join(path, "crystal_lamp.glb"), "wb") as f:
        f.write(glb_bytes)
    with open(os.path.join(path, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2, sort_keys=True)
    print("wrote mods/%s manifest sha=%s" % (folder, manifest["sha256"][:16]))


def main():
    os.makedirs(MODS, exist_ok=True)
    glb_bytes, (minv, maxv) = build_glb()
    sha = hashlib.sha256(glb_bytes).hexdigest()
    tris = 26
    footprint = round(max(maxv[0] - minv[0], maxv[2] - minv[2]), 6)

    bounds = {
        "min": [round(v, 6) for v in minv],
        "max": [round(v, 6) for v in maxv],
    }

    valid = {
        "id": "crystal_lamp",
        "name": "余烬晶灯",
        "version": 1,
        "format": "glb",
        "file": "crystal_lamp.glb",
        "sha256": sha,
        "bounds": bounds,
        "footprint": footprint,
        "pivot": "base-center",
        "max_tris": 200,
        "author": "mod-poc",
        "license": "CC0",
    }
    write_fixture("crystal_lamp", glb_bytes, valid)

    bad_scale = dict(valid)
    bad_scale.update({
        "id": "bad_scale",
        "name": "坏尺寸 mod",
        "bounds": {"min": [-0.2, 0.0, -0.2], "max": [0.2, 0.6, 0.2]},
        "footprint": 0.4,
    })
    write_fixture("bad_scale", glb_bytes, bad_scale)

    bad_hash = dict(valid)
    bad_hash.update({"id": "bad_hash", "name": "坏哈希 mod", "sha256": "0" * 64})
    write_fixture("bad_hash", glb_bytes, bad_hash)

    with open(os.path.join(MODS, ".gdignore"), "w", encoding="utf-8") as f:
        f.write("")
    with open(os.path.join(MODS, "README.md"), "w", encoding="utf-8") as f:
        f.write(
            "# Mod fixtures\n\n"
            "Generated by `tools/make_mod_glb.py`. Do not edit by hand.\n\n"
            "- `crystal_lamp/` — valid mod (hash/bounds/pivot/tris all pass)\n"
            "- `bad_scale/` — same GLB, manifest bounds too small (rejected)\n"
            "- `bad_hash/` — manifest sha256 wrong (rejected)\n\n"
            "Runtime installs these into `user://mods/` and imports the GLB with\n"
            "`GLTFDocument.append_from_file` after validation.\n"
        )
    print("GLB bytes", len(glb_bytes), "sha", sha[:16], "bounds", bounds,
          "footprint", footprint, "tris", tris)


if __name__ == "__main__":
    main()
