#!/usr/bin/env python3
"""Generate the original VFX texture set for Magic Projectile Lab.

Everything is procedural (numpy + Pillow), no external art.
Deterministic: seed 20261121. Re-run: python3 tools/gen_assets.py
Outputs PNGs to assets/textures/ plus MANIFEST.json with sha256.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SEED = 20261121
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures"
rng = np.random.default_rng(SEED)


# ── helpers ────────────────────────────────────────────────────────────────────

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def value_noise(w: int, h: int, period: int, rng_: np.random.Generator) -> np.ndarray:
    """Periodic bilinear value noise, tileable in both axes."""
    lattice = rng_.random((period, period)).astype(np.float32)
    ys = np.linspace(0, period, h, endpoint=False, dtype=np.float32)
    xs = np.linspace(0, period, w, endpoint=False, dtype=np.float32)
    x0 = np.floor(xs).astype(np.int32) % period
    y0 = np.floor(ys).astype(np.int32) % period
    x1 = (x0 + 1) % period
    y1 = (y0 + 1) % period
    fx = xs - np.floor(xs)
    fy = ys - np.floor(ys)
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    v00 = lattice[np.ix_(y0, x0)]
    v10 = lattice[np.ix_(y0, x1)]
    v01 = lattice[np.ix_(y1, x0)]
    v11 = lattice[np.ix_(y1, x1)]
    top = v00 * (1 - fx) + v10 * fx
    bot = v01 * (1 - fx) + v11 * fx
    return top * (1 - fy[:, None]) + bot * fy[:, None]


def fbm(w: int, h: int, base: int = 4, octaves: int = 4, seed: int = SEED) -> np.ndarray:
    r = np.random.default_rng(seed)
    out = np.zeros((h, w), dtype=np.float32)
    amp, total = 1.0, 0.0
    p = base
    for _ in range(octaves):
        out += value_noise(w, h, p, r) * amp
        total += amp
        amp *= 0.5
        p *= 2
    return out / total


def alpha_to(R: np.ndarray, G: np.ndarray, B: np.ndarray, A: np.ndarray) -> Image.Image:
    arr = np.stack([R, G, B, A], axis=-1)
    arr = np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def white(alpha: np.ndarray) -> Image.Image:
    a = np.clip(alpha, 0, 1)
    img = alpha_to(a, a, a, a)
    return img


def save(name: str, img: Image.Image) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / name, optimize=True)
    print(f"  {name:24s} {img.size[0]}x{img.size[1]}  {len((OUT / name).read_bytes())//1024:4d} KiB")


# ── textures ──────────────────────────────────────────────────────────────────

def tex_flame_strip(name="flame_strip.png", w=512, h=128, seed=SEED, misty=False):
    """Wavy flame ribbon mask: alpha band with tongues, holes and soft edges."""
    r = np.random.default_rng(seed)
    x = np.linspace(0, 1, w, endpoint=False, dtype=np.float32)
    y = np.linspace(0, 1, h, dtype=np.float32)
    X, Y = np.meshgrid(x, y)
    tau = 2 * np.pi
    if not misty:
        center = 0.5 + 0.135 * np.sin(tau * 2 * X + 0.6) + 0.055 * np.sin(tau * 5 * X + 1.9) \
            + 0.025 * np.sin(tau * 9 * X + 0.3)
        thick = 0.30 + 0.055 * np.sin(tau * 3 * X + 1.1) + 0.025 * np.sin(tau * 7 * X + 2.4)
    else:
        center = 0.5 + 0.07 * np.sin(tau * 2 * X + 1.2) + 0.025 * np.sin(tau * 4 * X + 0.2)
        thick = 0.30 + 0.035 * np.sin(tau * 3 * X + 0.4)
    d = np.abs(Y - center) / np.maximum(thick, 1e-3)
    band = smoothstep(1.35, 0.25, d)

    n1 = fbm(w, h, base=4, octaves=4, seed=seed + 1)
    # x-periodic turbulence: blend the fbm with a rolled copy so it tiles
    n1 = np.maximum(n1, np.roll(n1, w // 3, axis=1) * 0.85)
    n2 = fbm(w, h, base=8, octaves=3, seed=seed + 2)
    tongues = smoothstep(0.47, 0.72, n2 * 0.65 + n1 * 0.55)
    alpha = band * (0.55 + 0.45 * n1) * (0.65 + 0.55 * tongues)
    # punch organic holes near the edges, keep a hot continuous core
    core = smoothstep(0.95, 0.15, d)
    holes = smoothstep(0.52, 0.66, fbm(w, h, base=6, octaves=3, seed=seed + 3))
    alpha *= 1.0 - holes * (1.0 - core) * 0.9
    # taper both ends so the mask reads as a ribbon segment
    ends = smoothstep(0.0, 0.05, X) * smoothstep(1.0, 0.95, X)
    alpha *= ends
    alpha = np.clip(alpha, 0, 1)
    img = white(alpha).filter(ImageFilter.GaussianBlur(1.2 if not misty else 3.0))
    # color channels carry extra flow information for the shader
    g = np.clip(n1 * 0.6 + n2 * 0.4, 0, 1)
    b = np.clip((1.0 - d) * 0.8 + g * 0.2, 0, 1)
    arr = np.array(img, dtype=np.float32) / 255.0
    arr[..., 1] = g
    arr[..., 2] = b
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    save(name, img)


def tex_radial(name, size=256, power=2.4, core=0.06, seed=None):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    r = np.sqrt((xx - (size - 1) / 2) ** 2 + (yy - (size - 1) / 2) ** 2) / (size / 2)
    a = np.clip(1.0 - r, 0, 1) ** power
    a = np.maximum(a, np.exp(-(r / core) ** 2) * 0.95)
    save(name, white(a))


def tex_spark(size=64):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx = cy = (size - 1) / 2
    r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size / 2)
    a = np.clip(1 - r, 0, 1) ** 2.2
    a = np.maximum(a, np.exp(-(r / 0.22) ** 2))
    # tiny 4-point glint
    dx = np.abs(xx - cx) / (size / 2)
    dy = np.abs(yy - cy) / (size / 2)
    glint = np.exp(-(dx / 0.05) ** 2) * np.clip(1 - dy, 0, 1) * 0.5
    glint += np.exp(-(dy / 0.05) ** 2) * np.clip(1 - dx, 0, 1) * 0.5
    a = np.clip(a + glint * 0.6, 0, 1)
    save("spark.png", white(a))


def tex_streak(w=64, h=256):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (xx - (w - 1) / 2) / (w / 2)
    ny = (yy - (h - 1) / 2) / (h / 2)
    a = np.exp(-(nx / 0.32) ** 2) * np.clip(1 - np.abs(ny), 0, 1) ** 1.4
    a = np.maximum(a, np.exp(-((nx / 0.12) ** 2 + (ny / 0.55) ** 2)))
    save("spark_streak.png", white(a))


def tex_smoke(size=128):
    n = fbm(size, size, base=4, octaves=4, seed=SEED + 11)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    r = np.sqrt((xx - (size - 1) / 2) ** 2 + (yy - (size - 1) / 2) ** 2) / (size / 2)
    mask = smoothstep(1.0, 0.2, r)
    a = smoothstep(0.25, 0.8, n) * mask
    a = a * 0.9
    img = white(a).filter(ImageFilter.GaussianBlur(3.0))
    save("smoke.png", img)


def tex_ring(size=256, band=0.035, soft=0.03):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    r = np.sqrt((xx - (size - 1) / 2) ** 2 + (yy - (size - 1) / 2) ** 2) / (size / 2)
    a = np.exp(-((r - 0.8) / band) ** 2) * smoothstep(1.0, 0.92, r)
    a += np.exp(-((r - 0.8) / (band * 3.0)) ** 2) * 0.22
    save("ring.png", white(np.clip(a, 0, 1)))


def tex_shard(w=64, h=128):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (xx - (w - 1) / 2) / (w / 2)
    ny = (yy - (h - 1) / 2) / (h / 2)
    # elongated diamond with a bright vertical core
    a = np.clip(1.0 - (np.abs(nx) / 0.62 + np.abs(ny) / 0.95), 0, 1) ** 0.8
    a = np.maximum(a, np.exp(-(nx / 0.14) ** 2) * np.clip(1 - np.abs(ny), 0, 1) ** 0.5)
    a *= smoothstep(-1.0, -0.55, ny) * smoothstep(1.0, 0.55, ny)
    save("shard.png", white(np.clip(a, 0, 1)))


def tex_flare(size=128):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx = cy = (size - 1) / 2
    nx = (xx - cx) / (size / 2)
    ny = (yy - cy) / (size / 2)
    r = np.sqrt(nx * nx + ny * ny)
    glow = np.exp(-(r / 0.32) ** 2)
    hspike = np.exp(-(ny / 0.035) ** 2) * np.clip(1 - np.abs(nx), 0, 1) ** 0.8
    vspike = np.exp(-(nx / 0.05) ** 2) * np.clip(1 - np.abs(ny) * 1.35, 0, 1) ** 1.2
    a = np.clip(glow + hspike * 0.9 + vspike * 0.65, 0, 1)
    save("flare.png", white(a))


def tex_rune(size=512):
    ss = 2
    W = size * ss
    img = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(img)
    c = W / 2
    R = W * 0.46
    r = np.random.default_rng(SEED + 21)

    def circle(rad, width, fill=255):
        d.ellipse([c - rad, c - rad, c + rad, c + rad], outline=fill, width=width)

    circle(R, 3)
    circle(R * 0.9, 1)
    circle(R * 0.62, 2)
    circle(R * 0.58, 1)
    circle(R * 0.24, 2)
    # outer tick marks
    for i in range(48):
        ang = i / 48 * math.tau
        ln = R * (0.075 if i % 4 == 0 else 0.04)
        x0, y0 = c + math.cos(ang) * R * 0.915, c + math.sin(ang) * R * 0.915
        x1, y1 = c + math.cos(ang) * (R * 0.915 - ln), c + math.sin(ang) * (R * 0.915 - ln)
        d.line([x0, y0, x1, y1], fill=255, width=3 if i % 4 == 0 else 1)
    # inner rotating star
    pts = []
    for i in range(6):
        ang = i / 6 * math.tau - math.pi / 2
        pts.append((c + math.cos(ang) * R * 0.52, c + math.sin(ang) * R * 0.52))
    d.polygon(pts, outline=200, width=2)
    # glyph strokes between the two rings
    for i in range(8):
        ang = i / 8 * math.tau
        gx, gy = c + math.cos(ang) * R * 0.75, c + math.sin(ang) * R * 0.75
        for _ in range(4):
            a = r.uniform(0, math.tau)
            l1 = r.uniform(0.02, 0.06) * R
            x0 = gx + math.cos(a) * l1
            y0 = gy + math.sin(a) * l1
            b = a + r.uniform(-1.3, 1.3)
            l2 = r.uniform(0.03, 0.08) * R
            d.line([x0, y0, x0 + math.cos(b) * l2, y0 + math.sin(b) * l2], fill=230, width=2)
    # central sigil
    for i in range(3):
        ang = i / 3 * math.tau - math.pi / 2
        d.line([c, c, c + math.cos(ang) * R * 0.22, c + math.sin(ang) * R * 0.22], fill=255, width=3)
    img = img.resize((size, size), Image.LANCZOS)
    a = np.array(img, dtype=np.float32) / 255.0
    a = np.clip(a + np.array(img.filter(ImageFilter.GaussianBlur(3)), dtype=np.float32) / 255.0 * 0.55, 0, 1)
    save("rune.png", white(a))


def tex_contact(size=128):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    nx = (xx - (size - 1) / 2) / (size / 2)
    ny = (yy - (size - 1) / 2) / (size / 2)
    a = np.clip(1.0 - np.sqrt((nx / 1.0) ** 2 + (ny / 0.55) ** 2), 0, 1) ** 2.0
    save("contact_shadow.png", white(a * 0.85))


def tex_dust(size=32):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    r = np.sqrt((xx - 15.5) ** 2 + (yy - 15.5) ** 2) / 16
    save("dust.png", white(np.clip(1 - r, 0, 1) ** 2.4))


def tex_noise(size=256):
    r = np.random.default_rng(SEED + 31)
    rg = fbm(size, size, base=4, octaves=4, seed=SEED + 32)
    gg = fbm(size, size, base=8, octaves=3, seed=SEED + 33)
    bb = fbm(size, size, base=16, octaves=3, seed=SEED + 34)
    arr = np.stack([rg, gg, bb, np.ones_like(rg)], axis=-1)
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    save("noise.png", img)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    print("generating original VFX textures")
    tex_flame_strip("flame_strip.png", seed=SEED)
    tex_flame_strip("frost_strip.png", seed=SEED + 40, misty=True)
    tex_radial("glow.png", 256, power=2.6, core=0.05)
    tex_radial("glow_wide.png", 256, power=1.7, core=0.03)
    tex_spark()
    tex_streak()
    tex_smoke()
    tex_ring()
    tex_shard()
    tex_flare()
    tex_rune()
    tex_contact()
    tex_dust()
    tex_noise()

    manifest = {"generator": "tools/gen_assets.py", "seed": SEED, "files": {}}
    for p in sorted(OUT.glob("*.png")):
        manifest["files"][p.name] = {
            "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
            "bytes": p.stat().st_size,
        }
    (OUT / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {len(manifest['files'])} textures + MANIFEST.json")


if __name__ == "__main__":
    main()
