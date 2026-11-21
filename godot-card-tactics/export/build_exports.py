#!/usr/bin/env python3
"""Build engine-neutral exports from the Godot project's source data.

Outputs (relative to the project root):
  export/asset_manifest.json  - textures, atlas frame data, animations, license/source
  export/cards.json           - normalized card/general/deck data + rules constants

The script is deterministic: it reads data/cards.json and assets/duelyst_cc0/,
preserves source frame order, and sorts assets by path. No Godot dependency.
Run from anywhere:  python3 godot-card-tactics/export/build_exports.py
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "duelyst_cc0"
CARDS_PATH = ROOT / "data" / "cards.json"
EXPORT = ROOT / "export"

LICENSE = {
    "id": "CC0-1.0",
    "name": "Creative Commons Zero 1.0 Universal",
    "url": "https://creativecommons.org/publicdomain/zero/1.0/",
    "file": "assets/duelyst_cc0/LICENSE",
    "trademark_note": "Duelyst names and logos are trademarks of Counterplay Games and are not covered by CC0. This project uses the art assets only, under an original title and original UI.",
}

SOURCE = {
    "repo": "https://github.com/t73liu/open-duelyst-assets",
    "upstream": "https://github.com/open-duelyst/duelyst",
    "commit": "9fd0a16b611be8c9b991806ec5a6f602aa981823",
    "commit_date": "2024-12-26",
    "extraction": "Sparse/partial clone; only the 60 files used by this project were copied. See assets/duelyst_cc0/SOURCE.md.",
}

COORDINATES = {
    "origin": "top-left",
    "x": "right",
    "y": "down",
    "logical_unit": "px at 1280x720 design resolution",
    "atlas_rect": "[x0, y0, width, height]; x1=x0+width and y1=y0+height are exclusive edges",
    "board_index": "x in [0,8] left-to-right, y in [0,4] top-to-bottom",
}

BOARD = {
    "cols": 9,
    "rows": 5,
    "cell_px": 88,
    "origin_px": [236, 104],
    "pixel_size_px": [792, 440],
    "player_general": [4, 4],
    "ai_general": [4, 0],
    "neighbors": "4-connected (left/right/up/down), no diagonals",
}

RUNTIME_DEFAULTS = {
    "design_resolution_px": [1280, 720],
    "board": BOARD,
    "unit_sprite_scale": 1.22,
    "general_scale_multiplier": 1.1,
    "unit_sprite_offset_px": [0, -2],
    "ground_shadow_offset_px": [0, 31],
    "tile_render_size_px": [88, 88],
    "card_size_px": [104, 144],
    "card_art_rect_px": [10, 25, 84, 66],
    "animation_fps": {"idle": 8, "run": 13, "attack": 17, "hit": 15, "death": 14},
    "animation_loop": {"idle": True, "run": True, "attack": False, "hit": False, "death": False},
    "animation_fallbacks": {
        "hit": ["hurt"],
        "idle": ["breathing"],
        "run": ["idle"],
        "attack": ["cast"],
        "death": ["idle"],
    },
    "fx_fps": 24,
    "fx_loop": False,
    "depth": {
        "unit": "10 + grid_y",
        "death_ghost": 55,
        "fx": 60,
        "hover_card": 60,
        "selected_card": 40,
        "overlay": 1000,
    },
    "filters": {"unit_atlas": "nearest", "spell_icon_atlas": "nearest", "fx_atlas": "nearest", "card_frame": "linear", "tile": "linear"},
}

FX_VISUAL_SCALE = {
    "fx_impact": 2.3,
    "fx_slashfrenzy": 0.95,
    "fx_heal": 1.15,
    "fx_buff": 1.8,
    "fx_summonlegendary": 0.82,
    "fx_f2_phoenixfire": 0.95,
}

FX_USAGE = {
    "fx_impact": ["vfx:ranged_attack:f1_backlinearcher", "vfx:spell:f1_truestrike"],
    "fx_slashfrenzy": ["vfx:melee_attack"],
    "fx_heal": ["vfx:spell:f1_sundropelixir"],
    "fx_buff": ["vfx:spell:f2_cobrastrike", "vfx:spell:fallback"],
    "fx_summonlegendary": ["vfx:summon"],
    "fx_f2_phoenixfire": ["vfx:spell:f2_phoenixfire"],
}

TILE_USAGE = {
    "tile_hover": ["tile:move", "tile:hover"],
    "tile_attack": ["tile:attack_target"],
    "tile_spawn": ["tile:summon"],
    "tile_spell": ["tile:spell_target"],
    "tile_target": ["tile:selected"],
}


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_size(path: Path):
    # The PNG IHDR stores width/height at bytes 16..24. Avoid a Pillow dependency
    # in the build step so the manifest can be regenerated in a bare Python env.
    with path.open("rb") as fh:
        header = fh.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"not a PNG: {path}")
    width = int.from_bytes(header[16:20], "big")
    height = int.from_bytes(header[20:24], "big")
    return width, height


def animations_from_json(data: dict) -> dict:
    out = {}
    for name, frames in data.get("frames", {}).items():
        rows = []
        for frame in frames:
            rows.append({
                "name": frame["frame_name"],
                "rect": [int(frame["x0"]), int(frame["y0"]), int(frame["width"]), int(frame["height"])],
            })
        out[name] = {"frames": rows}
    return out


def first_frame(anims: dict, requested: str = "") -> dict:
    if requested and requested in anims:
        name = requested
    else:
        name = next(iter(anims))
    frame = anims[name]["frames"][0]
    return {"animation": name, "index": 0, "frame": frame["name"], "rect": frame["rect"]}


def make_asset(path: Path, kind: str, cards: dict, used_by: list[str]) -> dict:
    rel = path.relative_to(ROOT).as_posix()
    upstream_path = f"assets/{path.parent.name}/{path.name}"
    width, height = png_size(path)
    asset = {
        "id": path.stem,
        "kind": kind,
        "path": rel,
        "upstream_path": upstream_path,
        "size_px": [width, height],
        "sha256": sha256(path),
        "license": LICENSE["id"],
        "source": {
            "repo": SOURCE["repo"],
            "commit": SOURCE["commit"],
            "path": upstream_path,
        },
        "used_by": used_by,
    }

    frame_path = path.with_suffix(".json")
    if frame_path.exists():
        data = load_json(frame_path)
        if (int(data["width"]), int(data["height"])) != (width, height):
            raise ValueError(f"JSON/PNG size mismatch: {frame_path}")
        anims = animations_from_json(data)
        asset["frame_data"] = frame_path.relative_to(ROOT).as_posix()
        asset["frame_data_sha256"] = sha256(frame_path)
        asset["animations"] = anims
        asset["frame_count"] = sum(len(a["frames"]) for a in anims.values())
        sizes = sorted({tuple(f["rect"][2:4]) for a in anims.values() for f in a["frames"]})
        if len(sizes) == 1:
            asset["frame_size_px"] = list(sizes[0])
        else:
            asset["frame_sizes_px"] = [list(s) for s in sizes]
    else:
        asset["frame_count"] = 0

    if kind == "unit_atlas":
        asset["reference_runtime"] = {
            "pivot": "center",
            "scale": RUNTIME_DEFAULTS["unit_sprite_scale"],
            "general_scale_multiplier": RUNTIME_DEFAULTS["general_scale_multiplier"],
            "offset_px": RUNTIME_DEFAULTS["unit_sprite_offset_px"],
            "animation_fps": RUNTIME_DEFAULTS["animation_fps"],
            "animation_loop": RUNTIME_DEFAULTS["animation_loop"],
            "animation_fallbacks": RUNTIME_DEFAULTS["animation_fallbacks"],
            "static_card_art": first_frame(asset["animations"], "idle"),
        }
    elif kind == "spell_icon_atlas":
        asset["reference_runtime"] = {
            "pivot": "center",
            "static_card_art": first_frame(asset["animations"]),
        }
    elif kind == "fx_atlas":
        asset["reference_runtime"] = {
            "pivot": "center",
            "fps": RUNTIME_DEFAULTS["fx_fps"],
            "loop": RUNTIME_DEFAULTS["fx_loop"],
            "default_animation": next(iter(asset["animations"])),
            "visual_scale": FX_VISUAL_SCALE.get(path.stem, 1.0),
        }
    elif kind == "tile_texture":
        asset["reference_runtime"] = {
            "pivot": "top-left",
            "render_size_px": RUNTIME_DEFAULTS["tile_render_size_px"],
            "filter": "linear",
        }
    elif kind == "card_frame":
        asset["reference_runtime"] = {
            "pivot": "top-left",
            "render_size_px": RUNTIME_DEFAULTS["card_size_px"],
            "fit": "stretch (non-uniform)",
            "filter": "linear",
        }
    return asset


def build_assets(cards_data: dict) -> list[dict]:
    cards = cards_data["cards"]
    generals = cards_data["generals"]
    assets: list[dict] = []

    for path in sorted((ASSETS / "units").glob("*.png")):
        used = ["board_unit"]
        for general in generals.values():
            if general.get("sprite") == path.stem:
                used.append(f"general:{general['faction']}")
        for card in cards:
            if card.get("sprite") == path.stem:
                used.append(f"card_art:{card['id']}")
        assets.append(make_asset(path, "unit_atlas", cards_data, sorted(set(used))))

    for path in sorted((ASSETS / "icons").glob("*.png")):
        used = [f"spell_art:{card['id']}" for card in cards if card.get("icon") == path.stem]
        assets.append(make_asset(path, "spell_icon_atlas", cards_data, used or ["unused"]))

    for path in sorted((ASSETS / "fx").glob("*.png")):
        assets.append(make_asset(path, "fx_atlas", cards_data, FX_USAGE.get(path.stem, ["vfx:unused"])))

    for path in sorted((ASSETS / "tiles").glob("*.png")):
        assets.append(make_asset(path, "tile_texture", cards_data, TILE_USAGE.get(path.stem, ["tile:unused"])))

    frame_used = {}
    for card in cards:
        key = f"{card.get('faction','neutral')}_{card.get('type','unit')}"
        frame_used.setdefault(key, []).append(f"card:{card['id']}")
    for path in sorted((ASSETS / "card_backgrounds").glob("*.png")):
        assets.append(make_asset(path, "card_frame", cards_data, frame_used.get(path.stem, ["card_frame:unused"])))

    return assets


def build_manifest(assets: list[dict]) -> dict:
    total_frames = sum(a["frame_count"] for a in assets)
    atlas_assets = sum(1 for a in assets if a["frame_count"] > 0)
    total_animations = sum(len(a.get("animations", {})) for a in assets)
    return {
        "schema": "gridbound.asset-manifest/1",
        "generated": {
            "date": "2026-11-21",
            "by": "export/build_exports.py",
            "source_project": "godot-card-tactics",
        },
        "project": {
            "name": "格间牌战 · Gridbound",
            "description": "9x5 card + tactics vertical slice. Original code/UI; CC0 art subset.",
        },
        "coordinate_system": COORDINATES,
        "license": LICENSE,
        "source": SOURCE,
        "reference_runtime": RUNTIME_DEFAULTS,
        "counts": {
            "assets": len(assets),
            "atlas_assets": atlas_assets,
            "animations": total_animations,
            "frames": total_frames,
        },
        "validation": {
            "command": "python3 export/slice_atlas.py verify --manifest export/asset_manifest.json",
            "checks": [
                "path exists",
                "PNG size matches size_px",
                "sha256 matches",
                "frame_data JSON size matches",
                "animation names and per-frame name/rect match source JSON",
                "rects are in bounds and x1/y1 match width/height",
                "static_card_art/default_animation exist",
                "counts match",
            ],
        },
        "assets": assets,
    }


def build_cards(cards_data: dict) -> dict:
    cards = []
    for card in cards_data["cards"]:
        out = {
            "id": card["id"],
            "name": card["name"],
            "type": card["type"],
            "faction": card["faction"],
            "cost": int(card["cost"]),
            "keywords": list(card.get("keywords", [])),
            "desc": card.get("desc", ""),
        }
        if card["type"] == "unit":
            out["stats"] = {"atk": int(card["atk"]), "hp": int(card["hp"])}
            out["opening_heal"] = int(card.get("opening_heal", 0))
            out["art"] = {
                "asset_id": card["sprite"],
                "static_frame": {"animation": "idle", "index": 0},
                "card_frame_asset_id": f"{card['faction']}_{card['type']}",
            }
        else:
            out["spell"] = {
                "effect": card["effect"],
                "amount": int(card["amount"]),
                "target": card["target"],
            }
            icon_frames = load_json(ASSETS / "icons" / f"{card['icon']}.json")["frames"]
            out["art"] = {
                "asset_id": card["icon"],
                "static_frame": {"animation": next(iter(icon_frames)), "index": 0},
                "card_frame_asset_id": f"{card['faction']}_{card['type']}",
            }
        cards.append(out)

    generals = []
    for faction, general in cards_data["generals"].items():
        generals.append({
            "id": f"general_{faction}",
            "faction": faction,
            "name": general["name"],
            "title": general["title"],
            "stats": {"atk": int(general["atk"]), "hp": int(general["hp"])},
            "art": {
                "asset_id": general["sprite"],
                "static_frame": {"animation": "idle", "index": 0},
            },
        })

    return {
        "schema": "gridbound.cards/1",
        "generated": {"date": "2026-11-21", "by": "export/build_exports.py"},
        "source": {
            "path": "data/cards.json",
            "sha256": sha256(CARDS_PATH),
            "note": "Original data/cards.json is unchanged; this export is a normalized, engine-neutral view.",
        },
        "license_note": "Card names, descriptions and rules are original to this project. Art assets are CC0-1.0; see export/asset_manifest.json and assets/duelyst_cc0/LICENSE.",
        "board": BOARD,
        "rules": {
            "players": 2,
            "starting_hand": 3,
            "draw_per_turn": 1,
            "hand_limit": 6,
            "mana_start": 1,
            "mana_gain_per_turn": 1,
            "mana_cap": 9,
            "replace_per_turn": 1,
            "move_per_turn": 1,
            "attack_per_turn": 1,
            "summon_adjacent_to_friendly_only": True,
            "no_counterattack": True,
            "ranged": {"range": 2, "same_row_or_col": True, "requires_clear_mid_cell": True},
            "keywords": {
                "ranged": "Attack a target 1-2 cells away in the same row/column; the middle cell must be empty at distance 2.",
                "provoke": "If an enemy provoke unit is adjacent to the attacker, it must be attacked first.",
                "rush": "Can attack on the turn it is summoned.",
            },
            "spell_effects": {
                "heal": "Restore amount HP, capped at max HP.",
                "damage": "Deal amount damage; may kill the target and end the game if it is a general.",
                "buff_attack": "Permanently add amount attack.",
            },
            "spell_targets": {
                "friendly_any": "Any friendly unit, including the general.",
                "friendly_minion": "Friendly non-general unit.",
                "enemy_minion": "Enemy non-general unit.",
                "enemy_any": "Any enemy unit, including the general.",
            },
            "win_condition": "A general at 0 HP is removed; the other side wins.",
        },
        "generals": generals,
        "cards": cards,
        "decks": cards_data["decks"],
    }


def main() -> None:
    cards_data = load_json(CARDS_PATH)
    assets = build_assets(cards_data)
    manifest = build_manifest(assets)
    cards_export = build_cards(cards_data)

    EXPORT.mkdir(parents=True, exist_ok=True)
    with (EXPORT / "asset_manifest.json").open("w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    with (EXPORT / "cards.json").open("w", encoding="utf-8") as fh:
        json.dump(cards_export, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    print(f"assets={manifest['counts']['assets']} atlas_assets={manifest['counts']['atlas_assets']} "
          f"animations={manifest['counts']['animations']} frames={manifest['counts']['frames']}")
    print("wrote export/asset_manifest.json")
    print(f"wrote export/cards.json cards={len(cards_export['cards'])} generals={len(cards_export['generals'])}")


if __name__ == "__main__":
    main()
