#!/usr/bin/env python3
"""Bake a constant yaw offset into one bone-rotation channel of a GLB.

T-023: Action Forge's Mixamo -> KayKit Rogue export keeps the source rig's
180 deg hips yaw, while KayKit Rogue's rest forward is +Z.  The result is a
clip whose body/boots face -Z; a game controller that moves along +Z will look
like it is walking backwards.  This tool pre-multiplies a yaw quaternion onto
the target bone's rotation keys, producing a corrected clip *at the hips layer*
(no mesh/root rotation).

Usage:
  python3 glb_yaw_fix.py in.glb out.glb --bone hips --yaw 180 \
      [--anim "Michelle Walk_fit"] [--rename "Michelle Walk_fit_yawfix"]

Only float32 rotation accessors are written (the exporter used float32 here);
the tool refuses normalized int accessors instead of silently corrupting them.
"""
import argparse
import json
import math
import struct
import sys


def read_glb(path):
    data = open(path, "rb").read()
    magic, ver, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise SystemExit("not a GLB: " + path)
    off = 12
    js = None
    bin_chunk = None
    bin_offset = None
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        start = off + 8
        chunk = data[start:start + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        elif ctype == 0x004E4942:
            bin_chunk = bytearray(chunk)
            bin_offset = start
        off = start + clen
    if js is None or bin_chunk is None:
        raise SystemExit("missing JSON or BIN chunk")
    return data, js, bin_chunk, bin_offset


def quat_yaw(deg):
    h = math.radians(deg) * 0.5
    return (0.0, math.sin(h), 0.0, math.cos(h))


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def accessor_floats(js, acc_idx):
    acc = js["accessors"][acc_idx]
    if acc["componentType"] != 5126 or acc.get("type") != "VEC4":
        raise SystemExit("expected float VEC4 accessor, got %s" % acc)
    bv = js["bufferViews"][acc["bufferView"]]
    base = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = bv.get("byteStride", 16)
    out = []
    for i in range(acc["count"]):
        out.append(struct.unpack_from("<4f", BIN, base + i * stride))
    return out, base, stride


def write_glb(path, js, bin_chunk, template):
    js_bytes = json.dumps(js, separators=(",", ":")).encode("utf-8")
    js_bytes += b" " * ((4 - len(js_bytes) % 4) % 4)
    bin_bytes = bytes(bin_chunk)
    bin_bytes += b"\x00" * ((4 - len(bin_bytes) % 4) % 4)
    total = 12 + 8 + len(js_bytes) + 8 + len(bin_bytes)
    header = struct.pack("<III", 0x46546C67, 2, total)
    with open(path, "wb") as f:
        f.write(header)
        f.write(struct.pack("<II", len(js_bytes), 0x4E4F534A))
        f.write(js_bytes)
        f.write(struct.pack("<II", len(bin_bytes), 0x004E4942))
        f.write(bin_bytes)
    return total


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--bone", default="hips")
    ap.add_argument("--yaw", type=float, default=180.0)
    ap.add_argument("--anim", default=None, help="animation name filter")
    ap.add_argument("--rename", default=None, help="new animation name")
    args = ap.parse_args()

    global BIN
    data, js, BIN, _ = read_glb(args.input)
    nodes = js["nodes"]
    bone_nodes = {i for i, n in enumerate(nodes) if n.get("name") == args.bone}
    if not bone_nodes:
        raise SystemExit("bone node not found: " + args.bone)
    qy = quat_yaw(args.yaw)
    changed = 0
    for anim in js.get("animations", []):
        if args.anim and anim.get("name") != args.anim:
            continue
        for ch in anim["channels"]:
            tgt = ch["target"]
            if tgt.get("node") not in bone_nodes or tgt.get("path") != "rotation":
                continue
            sampler = anim["samplers"][ch["sampler"]]
            vals, base, stride = accessor_floats(js, sampler["output"])
            for i, q in enumerate(vals):
                nq = qmul(qy, q)
                # normalize to reject accumulated drift
                n = math.sqrt(sum(c * c for c in nq)) or 1.0
                nq = tuple(c / n for c in nq)
                struct.pack_into("<4f", BIN, base + i * stride, *nq)
            changed += 1
        if args.rename:
            anim["name"] = args.rename
    if changed == 0:
        raise SystemExit("no matching rotation channel changed")
    js.setdefault("asset", {}).setdefault("extras", {})
    js["asset"]["extras"].update({
        "t023_yaw_fix_bone": args.bone,
        "t023_yaw_fix_deg": args.yaw,
        "t023_yaw_fix_source": args.input.split("/")[-1],
    })
    total = write_glb(args.output, js, BIN, data)
    print("GLB_YAW_FIX input=%s output=%s bone=%s yaw=%.1f channels=%d bytes=%d" % (
        args.input, args.output, args.bone, args.yaw, changed, total))


BIN = None
if __name__ == "__main__":
    main()
