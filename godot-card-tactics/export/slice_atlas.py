#!/usr/bin/env python3
"""Engine-neutral sprite-atlas slicer / repacker / validator.

Input is a PNG plus the open-duelyst-assets frame JSON:
  {"texture_filename": "...", "width": W, "height": H,
   "frames": {"idle": [{"frame_name": "...", "x0": 0, "y0": 0,
                        "x1": 100, "y1": 100, "width": 100, "height": 100}, ...], ...}}

Commands:
  frames  Extract frames to individual PNG files.
  strip   Repack selected animations into a new PNG atlas + companion JSON.
  contact Build a labeled contact sheet from one or more atlases (evidence/preview).
  verify  Validate export/asset_manifest.json against the real files.

Only Python 3 + Pillow are required. No Godot, no engine SDK.

Examples (from godot-card-tactics/):
  python3 export/slice_atlas.py frames \
      --png assets/duelyst_cc0/units/f1_general.png \
      --json assets/duelyst_cc0/units/f1_general.json \
      --animation idle --animation attack --out-dir /tmp/gridbound_frames

  python3 export/slice_atlas.py strip \
      --png assets/duelyst_cc0/units/f2_onyxjaguar.png \
      --json assets/duelyst_cc0/units/f2_onyxjaguar.json \
      --animation run --out /tmp/onyxjaguar_run_atlas.png --columns 8

  python3 export/slice_atlas.py contact --out export/sample_contact_sheet.png \
      --entry "f1_general / idle=assets/duelyst_cc0/units/f1_general.png:assets/duelyst_cc0/units/f1_general.json:idle:4" \
      --entry "f1_general / attack=assets/duelyst_cc0/units/f1_general.png:assets/duelyst_cc0/units/f1_general.json:attack:4" \
      --entry "fx_f2_phoenixfire / default=assets/duelyst_cc0/fx/fx_f2_phoenixfire.png:assets/duelyst_cc0/fx/fx_f2_phoenixfire.json:default:4"

  python3 export/slice_atlas.py verify --manifest export/asset_manifest.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - friendly message
    sys.stderr.write("Pillow is required: python3 -m pip install Pillow\n")
    raise

ROOT = Path(__file__).resolve().parent.parent
MANIFEST_SCHEMA = "gridbound.asset-manifest/1"


# ---------------------------------------------------------------- utilities

def resolve(path: str, root: Path) -> Path:
    p = Path(path)
    return p if p.is_absolute() else (root / p)


def load_atlas(png_path: Path, json_path: Path):
    if not png_path.exists():
        raise SystemExit(f"missing PNG: {png_path}")
    if not json_path.exists():
        raise SystemExit(f"missing frame JSON: {json_path}")
    with json_path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    image = Image.open(png_path).convert("RGBA")
    width, height = image.size
    if (int(data.get("width", -1)), int(data.get("height", -1))) != (width, height):
        raise SystemExit(f"JSON/PNG size mismatch: {json_path} says {data.get('width')}x{data.get('height')}, "
                         f"PNG is {width}x{height}")
    frames = data.get("frames", {})
    if not frames:
        raise SystemExit(f"no animations in {json_path}")
    for anim, rows in frames.items():
        for frame in rows:
            x0, y0 = int(frame["x0"]), int(frame["y0"])
            w, h = int(frame["width"]), int(frame["height"])
            if w <= 0 or h <= 0:
                raise SystemExit(f"empty rect {frame['frame_name']}")
            if x0 < 0 or y0 < 0 or x0 + w > width or y0 + h > height:
                raise SystemExit(f"rect out of bounds: {frame['frame_name']}")
            if int(frame["x1"]) - x0 != w or int(frame["y1"]) - y0 != h:
                raise SystemExit(f"x1/y1 do not match width/height: {frame['frame_name']}")
    return image, data


def crop_frame(image: Image.Image, frame: dict, scale: float) -> Image.Image:
    x0, y0 = int(frame["x0"]), int(frame["y0"])
    w, h = int(frame["width"]), int(frame["height"])
    crop = image.crop((x0, y0, x0 + w, y0 + h))
    if scale != 1.0:
        crop = crop.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.Resampling.NEAREST)
    return crop


def choose_animations(frames: dict, requested: list[str], all_animations: bool) -> list[str]:
    if all_animations or not requested:
        return list(frames.keys())
    missing = [name for name in requested if name not in frames]
    if missing:
        raise SystemExit(f"unknown animation(s): {', '.join(missing)}; available: {', '.join(frames)}")
    return requested


def safe_name(name: str) -> str:
    return name.replace("/", "_").replace("\\", "_")


def font(size: int):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "DejaVuSans.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


# ----------------------------------------------------------------- commands

def cmd_frames(args) -> int:
    root = Path(args.root).resolve() if args.root else ROOT
    image, data = load_atlas(resolve(args.png, root), resolve(args.json, root))
    animations = choose_animations(data["frames"], args.animation, args.all)
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    for anim in animations:
        for index, frame in enumerate(data["frames"][anim]):
            crop = crop_frame(image, frame, args.scale)
            name = safe_name(frame["frame_name"])
            if not name.lower().endswith(".png"):
                name += ".png"
            crop.save(out_dir / name)
            written += 1
    print(f"frames={written} animations={len(animations)} out={out_dir}")
    return 0


def cmd_strip(args) -> int:
    root = Path(args.root).resolve() if args.root else ROOT
    image, data = load_atlas(resolve(args.png, root), resolve(args.json, root))
    animations = choose_animations(data["frames"], args.animation, args.all)
    frames = [(anim, frame) for anim in animations for frame in data["frames"][anim]]
    if not frames:
        raise SystemExit("nothing to pack")

    cell_w = max(round(int(f["width"]) * args.scale) for _, f in frames)
    cell_h = max(round(int(f["height"]) * args.scale) for _, f in frames)
    columns = max(1, args.columns)
    rows = math.ceil(len(frames) / columns)
    pad = max(0, args.padding)
    sheet_w = columns * cell_w + (columns + 1) * pad
    sheet_h = rows * cell_h + (rows + 1) * pad
    background = (0, 0, 0, 0)
    if args.background and args.background.lower() not in ("none", "transparent"):
        value = args.background.lstrip("#")
        background = tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    sheet = Image.new("RGBA", (sheet_w, sheet_h), background)

    packed = {}
    for index, (anim, frame) in enumerate(frames):
        crop = crop_frame(image, frame, args.scale)
        col = index % columns
        row = index // columns
        x = pad + col * (cell_w + pad)
        y = pad + row * (cell_h + pad)
        sheet.paste(crop, (x, y), crop)
        packed.setdefault(anim, []).append({
            "frame_name": frame["frame_name"],
            "x0": x,
            "y0": y,
            "x1": x + crop.width,
            "y1": y + crop.height,
            "width": crop.width,
            "height": crop.height,
        })

    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    sidecar = {
        "texture_filename": out.name,
        "width": sheet_w,
        "height": sheet_h,
        "frames": packed,
        "grid": {
            "columns": columns,
            "rows": rows,
            "cell_width": cell_w,
            "cell_height": cell_h,
            "padding": pad,
            "scale": args.scale,
        },
        "source": {
            "png": resolve(args.png, root).relative_to(root).as_posix() if resolve(args.png, root).is_relative_to(root) else str(resolve(args.png, root)),
            "json": resolve(args.json, root).relative_to(root).as_posix() if resolve(args.json, root).is_relative_to(root) else str(resolve(args.json, root)),
            "animations": animations,
        },
    }
    sidecar_path = out.with_suffix(".json")
    with sidecar_path.open("w", encoding="utf-8") as fh:
        json.dump(sidecar, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print(f"atlas={sheet_w}x{sheet_h} frames={len(frames)} animations={len(animations)} out={out}")
    print(f"sidecar={sidecar_path}")
    return 0


def parse_entry(entry: str) -> dict:
    if "=" not in entry:
        raise SystemExit(f"bad --entry (want label=png:json:anim[:max]): {entry}")
    label, rest = entry.split("=", 1)
    parts = rest.rsplit(":", 3)
    if len(parts) < 3:
        raise SystemExit(f"bad --entry (want label=png:json:anim[:max]): {entry}")
    png, json_path, anim = parts[0], parts[1], parts[2]
    max_frames = int(parts[3]) if len(parts) == 4 and parts[3] else None
    return {"label": label, "png": png, "json": json_path, "anim": anim, "max": max_frames}


def checkerboard(draw: ImageDraw.ImageDraw, box, size=8):
    x0, y0, x1, y1 = box
    for y in range(y0, y1, size):
        for x in range(x0, x1, size):
            shade = (27, 36, 48, 255) if ((x - x0) // size + (y - y0) // size) % 2 == 0 else (34, 45, 59, 255)
            draw.rectangle((x, y, min(x + size - 1, x1 - 1), min(y + size - 1, y1 - 1)), fill=shade)


def cmd_contact(args) -> int:
    root = Path(args.root).resolve() if args.root else ROOT
    entries = [parse_entry(e) for e in args.entry]
    if not entries:
        raise SystemExit("at least one --entry is required")

    label_font = font(13)
    small_font = font(11)
    thumb = max(32, args.thumb)
    margin = 7
    label_h = 22
    pad = 12
    rows = []

    for entry in entries:
        image, data = load_atlas(resolve(entry["png"], root), resolve(entry["json"], root))
        anim = entry["anim"] or next(iter(data["frames"]))
        if anim not in data["frames"]:
            raise SystemExit(f"{entry['label']}: unknown animation {anim}")
        frames = data["frames"][anim]
        if entry["max"]:
            frames = frames[: entry["max"]]
        thumbs = []
        for frame in frames:
            crop = crop_frame(image, frame, 1.0)
            ratio = min(thumb / crop.width, thumb / crop.height)
            size = (max(1, round(crop.width * ratio)), max(1, round(crop.height * ratio)))
            thumbs.append(crop.resize(size, Image.Resampling.NEAREST))
        row_w = pad * 2 + len(thumbs) * (thumb + margin) - margin
        rows.append({"entry": entry, "anim": anim, "total": len(data["frames"][anim]),
                     "thumbs": thumbs, "width": max(row_w, 320)})

    width = max(r["width"] for r in rows)
    title_h = 20
    height = title_h + pad * 2 + len(rows) * (label_h + thumb + margin) - margin
    sheet = Image.new("RGBA", (width, height), (16, 22, 31, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 3), "Gridbound CC0 atlas contact sheet - sampled frames, rects from JSON",
              font=small_font, fill=(150, 172, 190, 255))

    y = title_h + pad
    for row in rows:
        entry = row["entry"]
        draw.text((pad, y), f"{entry['label']}  /  {row['anim']}  "
                            f"({row['total']} frames, showing {len(row['thumbs'])})",
                  font=label_font, fill=(224, 236, 246, 255))
        x = pad
        for thumb_image in row["thumbs"]:
            box = (x, y + label_h - 2, x + thumb, y + label_h - 2 + thumb)
            checkerboard(draw, box)
            sheet.paste(thumb_image, (x + (thumb - thumb_image.width) // 2,
                                      y + label_h - 2 + (thumb - thumb_image.height) // 2), thumb_image)
            draw.rectangle((box[0], box[1], box[0] + thumb, box[1] + thumb), outline=(64, 84, 104, 255))
            x += thumb + margin
        y += label_h + thumb + margin

    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"contact_sheet={sheet.width}x{sheet.height} rows={len(rows)} out={out}")
    for row in rows:
        print(f"  {row['entry']['label']}: {row['anim']} {len(row['thumbs'])}/{row['total']}")
    return 0


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def cmd_verify(args) -> int:
    manifest_path = Path(args.manifest).resolve()
    root = Path(args.root).resolve() if args.root else ROOT
    if not manifest_path.exists():
        print(f"MANIFEST_FAIL missing {manifest_path}")
        return 1
    with manifest_path.open("r", encoding="utf-8") as fh:
        manifest = json.load(fh)
    errors: list[str] = []

    def err(message: str):
        errors.append(message)

    if manifest.get("schema") != MANIFEST_SCHEMA:
        err(f"schema: expected {MANIFEST_SCHEMA}, got {manifest.get('schema')}")
    for key in ("coordinate_system", "license", "source", "reference_runtime", "counts", "validation", "assets"):
        if key not in manifest:
            err(f"missing top-level key: {key}")
    if manifest.get("license", {}).get("id") != "CC0-1.0":
        err("license.id must be CC0-1.0")
    if "commit" not in manifest.get("source", {}):
        err("source.commit missing")

    assets = manifest.get("assets", [])
    seen_ids = set()
    total_frames = 0
    total_animations = 0

    allowed_kinds = {"unit_atlas", "spell_icon_atlas", "fx_atlas", "tile_texture", "card_frame"}
    for asset in assets:
        label = asset.get("id", "<no id>")
        for key in ("id", "kind", "path", "size_px", "sha256", "used_by"):
            if key not in asset:
                err(f"{label}: missing {key}")
        if label in seen_ids:
            err(f"{label}: duplicate id")
        seen_ids.add(label)
        if asset.get("kind") not in allowed_kinds:
            err(f"{label}: unknown kind {asset.get('kind')}")
        if not isinstance(asset.get("used_by"), list) or not asset.get("used_by"):
            err(f"{label}: used_by must be a non-empty array")
        if not str(asset.get("path", "")).startswith("assets/"):
            err(f"{label}: path must start with assets/")
        if not str(asset.get("upstream_path", "")).startswith("assets/"):
            err(f"{label}: upstream_path must start with assets/")
        if not (isinstance(asset.get("sha256"), str) and len(asset["sha256"]) == 64):
            err(f"{label}: sha256 must be a 64-char hex string")
        if asset.get("license") != "CC0-1.0":
            err(f"{label}: license must be CC0-1.0")
        source = asset.get("source", {})
        if not source.get("repo") or not source.get("commit") or not source.get("path"):
            err(f"{label}: source.repo/commit/path missing")
        elif source.get("path") != asset.get("upstream_path"):
            err(f"{label}: source.path != upstream_path")
        elif source.get("repo") != manifest.get("source", {}).get("repo") or source.get("commit") != manifest.get("source", {}).get("commit"):
            err(f"{label}: source.repo/commit != top-level source")

        path = resolve(asset.get("path", ""), root)
        if not path.exists():
            err(f"{label}: path does not exist: {path}")
            continue
        actual_size = list(Image.open(path).size)
        if actual_size != list(asset.get("size_px", [])):
            err(f"{label}: size {asset.get('size_px')} != PNG {actual_size}")
        if asset.get("sha256") and sha256(path) != asset["sha256"]:
            err(f"{label}: sha256 mismatch")

        frame_rel = asset.get("frame_data")
        if frame_rel:
            frame_path = resolve(frame_rel, root)
            if frame_path.stem != path.stem or frame_path.suffix != ".json":
                err(f"{label}: frame_data must be the same basename + .json")
            if not frame_path.exists():
                err(f"{label}: frame_data does not exist: {frame_path}")
                continue
            if asset.get("frame_data_sha256") and sha256(frame_path) != asset["frame_data_sha256"]:
                err(f"{label}: frame_data sha256 mismatch")
            with frame_path.open("r", encoding="utf-8") as fh:
                data = json.load(fh)
            if (int(data["width"]), int(data["height"])) != tuple(asset["size_px"]):
                err(f"{label}: frame JSON size != manifest size")
            manifest_anims = asset.get("animations", {})
            json_anims = data.get("frames", {})
            if set(manifest_anims) != set(json_anims):
                err(f"{label}: animation names differ: manifest={sorted(manifest_anims)} json={sorted(json_anims)}")
            if asset.get("frame_count") != sum(len(v.get("frames", [])) for v in manifest_anims.values()):
                err(f"{label}: frame_count does not match animation frames")
            for anim, rows in manifest_anims.items():
                total_animations += 1
                manifest_frames = rows.get("frames", [])
                json_frames = json_anims.get(anim, [])
                total_frames += len(manifest_frames)
                if len(manifest_frames) != len(json_frames):
                    err(f"{label}/{anim}: frame count {len(manifest_frames)} != JSON {len(json_frames)}")
                for index, frame in enumerate(manifest_frames):
                    if index >= len(json_frames):
                        break
                    source = json_frames[index]
                    if frame.get("name") != source.get("frame_name"):
                        err(f"{label}/{anim}[{index}]: name mismatch")
                    expected = [int(source["x0"]), int(source["y0"]), int(source["width"]), int(source["height"])]
                    if list(frame.get("rect", [])) != expected:
                        err(f"{label}/{anim}[{index}]: rect {frame.get('rect')} != JSON {expected}")
                    x, y, w, h = expected
                    if w <= 0 or h <= 0 or x < 0 or y < 0 or x + w > asset["size_px"][0] or y + h > asset["size_px"][1]:
                        err(f"{label}/{anim}[{index}]: rect out of bounds")
                if asset.get("frame_size_px"):
                    expected_size = list(asset["frame_size_px"])
                    for index, frame in enumerate(manifest_frames):
                        if list(frame["rect"][2:4]) != expected_size:
                            err(f"{label}/{anim}[{index}]: frame_size_px mismatch")
                            break
        else:
            if asset.get("frame_count", 0) != 0:
                err(f"{label}: frame_count is non-zero but frame_data is missing")

        reference = asset.get("reference_runtime", {})
        static = reference.get("static_card_art")
        if static:
            anim = static.get("animation")
            if anim not in asset.get("animations", {}):
                err(f"{label}: static_card_art animation {anim} missing")
            elif static.get("index", 0) >= len(asset["animations"][anim]["frames"]):
                err(f"{label}: static_card_art index out of range")
        default_anim = reference.get("default_animation")
        if default_anim and default_anim not in asset.get("animations", {}):
            err(f"{label}: default_animation {default_anim} missing")
        if asset.get("kind") in {"unit_atlas", "spell_icon_atlas", "fx_atlas"} and not asset.get("animations"):
            err(f"{label}: atlas asset has no animations")

    counts = manifest.get("counts", {})
    if counts.get("assets") != len(assets):
        err(f"counts.assets {counts.get('assets')} != {len(assets)}")
    if counts.get("frames") != total_frames:
        err(f"counts.frames {counts.get('frames')} != {total_frames}")
    if counts.get("animations") != total_animations:
        err(f"counts.animations {counts.get('animations')} != {total_animations}")
    if counts.get("atlas_assets") != sum(1 for a in assets if a.get("frame_data")):
        err("counts.atlas_assets mismatch")

    if errors:
        print(f"MANIFEST_FAIL errors={len(errors)}")
        for message in errors:
            print("  - " + message)
        return 1
    print(f"MANIFEST_OK assets={len(assets)} atlas_assets={counts.get('atlas_assets')} "
          f"animations={total_animations} frames={total_frames}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Slice/repack/validate open-duelyst-assets atlases without Godot.")
    parser.add_argument("--root", help="project root for relative paths (default: godot-card-tactics/)")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("frames", help="extract individual frame PNGs")
    p.add_argument("--png", required=True)
    p.add_argument("--json", required=True)
    p.add_argument("--animation", action="append", default=[])
    p.add_argument("--all", action="store_true", help="all animations (default when no --animation)")
    p.add_argument("--scale", type=float, default=1.0)
    p.add_argument("--out-dir", required=True)
    p.set_defaults(func=cmd_frames)

    p = sub.add_parser("strip", help="repack selected animations into a new atlas PNG + JSON")
    p.add_argument("--png", required=True)
    p.add_argument("--json", required=True)
    p.add_argument("--animation", action="append", default=[])
    p.add_argument("--all", action="store_true")
    p.add_argument("--scale", type=float, default=1.0)
    p.add_argument("--columns", type=int, default=8)
    p.add_argument("--padding", type=int, default=2)
    p.add_argument("--background", default="transparent", help="transparent or #rrggbb")
    p.add_argument("--out", required=True)
    p.set_defaults(func=cmd_strip)

    p = sub.add_parser("contact", help="build a labeled contact sheet (evidence image)")
    p.add_argument("--entry", action="append", default=[],
                   help="label=png:json:anim[:max_frames]")
    p.add_argument("--thumb", type=int, default=120)
    p.add_argument("--out", required=True)
    p.set_defaults(func=cmd_contact)

    p = sub.add_parser("verify", help="validate an asset manifest against real files")
    p.add_argument("--manifest", required=True)
    p.set_defaults(func=cmd_verify)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
