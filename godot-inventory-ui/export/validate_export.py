#!/usr/bin/env python3
"""Engine-agnostic validator for the exported inventory UI package.

Only the Python standard library is required. Run from anywhere:

    python3 export/validate_export.py

Checks:
  * ui_layout.json: schema, canvas, rect bounds, px/norm consistency,
    parent containment, 5x5 grid, 5 tabs, 3 nav tabs, 8 equipment slots,
    detail buttons, fonts, motion, interactions, self-check block.
  * asset_manifest.json: every path exists, PNG/SVG dimensions match,
    nine-slice field present, licenses, icon counts, item data counts.
  * Markdown links in the docs resolve to real files (no external URLs).

Exit code 0 only if all three groups pass. Prints:
    EXPORT_LAYOUT_OK
    EXPORT_MANIFEST_OK
    EXPORT_LINKS_OK
"""

from __future__ import annotations

import json
import os
import re
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent                      # godot-inventory-ui/
LAYOUT = HERE / "ui_layout.json"
MANIFEST = HERE / "asset_manifest.json"
W, H = 1280.0, 720.0

layout_checks = 0
layout_fails: list[str] = []
manifest_checks = 0
manifest_fails: list[str] = []
link_checks = 0
link_fails: list[str] = []


def ok_layout(cond: bool, msg: str) -> bool:
    global layout_checks
    layout_checks += 1
    if not cond:
        layout_fails.append(msg)
        print("  LAYOUT FAIL:", msg)
    return bool(cond)


def ok_manifest(cond: bool, msg: str) -> bool:
    global manifest_checks
    manifest_checks += 1
    if not cond:
        manifest_fails.append(msg)
        print("  MANIFEST FAIL:", msg)
    return bool(cond)


def ok_link(cond: bool, msg: str) -> bool:
    global link_checks
    link_checks += 1
    if not cond:
        link_fails.append(msg)
        print("  LINK FAIL:", msg)
    return bool(cond)


def is_num(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def rect_ok(r, allow_zero_size=False) -> bool:
    if not isinstance(r, list) or len(r) != 4 or not all(is_num(v) for v in r):
        return False
    if allow_zero_size:
        return r[2] >= 0 and r[3] >= 0
    return r[2] > 0 and r[3] > 0


def png_size(path: Path) -> list[int]:
    with open(path, "rb") as f:
        head = f.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    w, h = struct.unpack(">II", head[16:24])
    return [int(w), int(h)]


def svg_size(path: Path) -> tuple[list[int], str | None]:
    text = path.read_text(encoding="utf-8", errors="replace")[:8192]
    tag = re.search(r"<svg[^>]*", text)
    if not tag:
        raise ValueError("no <svg> tag")
    tag_s = tag.group(0)
    mw = re.search(r'width="([0-9.]+)"', tag_s)
    mh = re.search(r'height="([0-9.]+)"', tag_s)
    if not mw or not mh:
        raise ValueError("no width/height on <svg>")
    vb = re.search(r'viewBox="([^"]+)"', tag_s)
    return [int(float(mw.group(1))), int(float(mh.group(1)))], (vb.group(1) if vb else None)


def check_color(value: str) -> bool:
    if not isinstance(value, str):
        return False
    if re.fullmatch(r"#[0-9a-fA-F]{3,8}", value):
        return True
    if re.fullmatch(r"rgba?\([0-9.,\s]+\)", value):
        return True
    return False


# ---------------------------------------------------------------- layout
def validate_layout() -> dict:
    if not LAYOUT.exists():
        ok_layout(False, f"missing {LAYOUT}")
        return {}
    try:
        doc = json.loads(LAYOUT.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        ok_layout(False, f"invalid JSON: {e}")
        return {}

    ok_layout(isinstance(doc, dict), "top level is an object")
    ok_layout(str(doc.get("schema", "")).startswith("modelfw.inventory.layout/"),
              "schema is modelfw.inventory.layout/*")
    canvas = doc.get("canvas", {})
    ok_layout(canvas.get("width") == 1280 and canvas.get("height") == 720,
              "canvas is 1280x720")
    ok_layout(canvas.get("origin") == "top-left" and canvas.get("y_axis") == "down",
              "canvas origin top-left, y down")
    ok_layout(canvas.get("min_window_px") == [960, 540], "min window is 960x540")
    ok_layout(canvas.get("reference_canvas_px") == [529, 356],
              "reference canvas recorded as 529x356")

    palette = doc.get("palette", {})
    ok_layout(isinstance(palette, dict) and len(palette) >= 40, "palette has >= 40 tokens")
    bad_colors = [k for k, v in palette.items() if not check_color(v)]
    ok_layout(not bad_colors, f"palette values are colors (bad: {bad_colors[:5]})")

    fonts = doc.get("fonts", {})
    sizes = fonts.get("sizes", {})
    ok_layout(isinstance(sizes, dict) and len(sizes) >= 30, "font size table has >= 30 entries")
    ok_layout(all(is_num(v) and 6 <= v <= 72 for v in sizes.values()),
              "font sizes are numeric and within 6..72")
    ok_layout(fonts.get("body", {}).get("bundled") is False and
              fonts.get("title", {}).get("bundled") is False,
              "fonts marked as not bundled")

    nodes = doc.get("nodes", {})
    ok_layout(isinstance(nodes, dict) and len(nodes) >= 100, "nodes map has >= 100 entries")
    bleed = float(canvas.get("bleed_allowance_px", 0))
    required = ["panel", "title", "close_button", "character_stage", "attributes",
                "tabs", "item_grid", "currency", "sort_button", "side_nav",
                "detail_card", "capacity_label", "filter_button", "filter_popup",
                "grid_backing", "grid_scrollbar", "empty_state", "tooltip",
                "fx_layer", "toast", "placeholder_overlay", "confirm_dialog",
                "reopen_root", "align_overlay", "fps_label"]
    missing = [r for r in required if r not in nodes]
    ok_layout(not missing, f"required nodes present (missing: {missing})")

    normalized_max_error = 0.0
    for key, node in nodes.items():
        if not isinstance(node, dict):
            ok_layout(False, f"{key}: node is not an object")
            continue
        parent = node.get("parent")
        ok_layout(parent is None or parent in nodes, f"{key}: parent exists ({parent})")
        rect = node.get("rect_px")
        norm = node.get("rect_norm")
        ok_layout(rect_ok(rect), f"{key}: rect_px is 4 positive numbers")
        ok_layout(rect_ok(norm, allow_zero_size=True), f"{key}: rect_norm is 4 numbers")
        if not (rect_ok(rect) and rect_ok(norm, True)):
            continue
        expected = [rect[0] / W, rect[1] / H, rect[2] / W, rect[3] / H]
        err = max(abs(norm[i] - expected[i]) for i in range(4))
        normalized_max_error = max(normalized_max_error, err)
        ok_layout(err <= 1e-6, f"{key}: rect_norm matches rect_px (err {err:.2e})")

        # canvas bounds + declared overflow
        x, y, w, h = rect
        over = {"left": max(0.0, -x), "top": max(0.0, -y),
                "right": max(0.0, x + w - W), "bottom": max(0.0, y + h - H)}
        outside = {k: v for k, v in over.items() if v > 1e-9}
        if outside:
            decl = node.get("overflow", {})
            ok_layout(isinstance(decl, dict) and bool(decl.get("why")),
                      f"{key}: overflow is declared with a reason")
            for side, px in outside.items():
                declared = decl.get(side + "_px", 0) if isinstance(decl, dict) else 0
                ok_layout(is_num(declared) and abs(declared - px) <= 0.01 and px <= bleed,
                          f"{key}: overflow {side} {px:.2f}px matches declaration and <= bleed")
        else:
            ok_layout(True, f"{key}: inside canvas")

        anchors = node.get("anchors")
        if anchors is not None:
            amn, amx, piv = anchors.get("min"), anchors.get("max"), anchors.get("pivot")
            ok_layout(isinstance(amn, list) and len(amn) == 2 and
                      isinstance(amx, list) and len(amx) == 2 and
                      isinstance(piv, list) and len(piv) == 2,
                      f"{key}: anchors have 2D min/max/pivot")
            if all(isinstance(a, list) and len(a) == 2 for a in (amn, amx, piv)):
                ok_layout(all(0 <= v <= 1 for v in amn + amx + piv),
                          f"{key}: anchor values within 0..1")

        within = node.get("within")
        if within:
            target = nodes.get(within)
            ok_layout(isinstance(target, dict), f"{key}: within target exists ({within})")
            if isinstance(target, dict) and rect_ok(target.get("rect_px")):
                tx, ty, tw, th = target["rect_px"]
                inside = (x >= tx - 0.01 and y >= ty - 0.01 and
                          x + w <= tx + tw + 0.01 and y + h <= ty + th + 0.01)
                ok_layout(inside, f"{key}: inside {within}")

    ok_layout(normalized_max_error <= 1e-6,
              f"global normalized rounding error <= 1e-6 ({normalized_max_error:.2e})")

    # panel / split / regions
    panel = nodes.get("panel", {})
    ok_layout(panel.get("rect_px") == [17, 47, 1193, 659],
              "panel rect is (17,47,1193,659)")
    split = panel.get("sections", {}).get("split_x_px")
    ok_layout(split == 653, "panel split x is 653")
    left = panel.get("sections", {}).get("left_region", {}).get("rect_px")
    right = panel.get("sections", {}).get("right_region", {}).get("rect_px")
    ok_layout(left == [17, 47, 636, 659], "left region is 636 wide")
    ok_layout(right == [653, 47, 557, 659], "right region is 557 wide")
    ok_layout(left[2] + right[2] == panel["rect_px"][2],
              "region widths add up to the panel width")
    ok_layout(left[0] + left[2] == split and right[0] == split,
              "regions meet at the 653 split")

    # title: export rect must be fully inside; the original Godot label box
    # (with 3px top padding) is recorded separately for traceability.
    title = nodes.get("title", {})
    ok_layout("overflow" not in title, "title rect has no out-of-canvas overflow")
    ok_layout(title.get("center_px") == [212, 20], "title center is (212,20)")
    ok_layout(title.get("control_box_px") == [160, -3, 104, 46],
              "title records the original Godot label box")

    # grid
    cells = [n for n in nodes.values() if n.get("kind") == "item_cell"]
    ok_layout(len(cells) == 25, "25 item cells")
    seen = set()
    for cell in cells:
        c = cell.get("cell", {})
        row, col, idx = c.get("row"), c.get("col"), c.get("index")
        ok_layout(isinstance(row, int) and 0 <= row < 5 and
                  isinstance(col, int) and 0 <= col < 5 and idx == row * 5 + col,
                  f"cell index/row/col consistent ({idx})")
        seen.add(idx)
        expected = [653 + col * 110, 121 + row * 91, 102, 85]
        ok_layout(cell.get("rect_px") == expected,
                  f"cell {idx} rect follows origin+pitch")
        ok_layout(cell.get("parent") == "item_grid", f"cell {idx} parent is item_grid")
        ok_layout(cell.get("within") == "item_grid", f"cell {idx} within item_grid")
    ok_layout(seen == set(range(25)), "cell indices cover 0..24")
    grid = nodes.get("item_grid", {})
    geom = grid.get("geometry", {})
    ok_layout(geom.get("cols") == 5 and geom.get("rows") == 5 and geom.get("cell_count") == 25,
              "grid geometry is 5x5x25")
    ok_layout(geom.get("cell_size_px") == [102, 85] and geom.get("pitch_px") == [110, 91],
              "grid cell 102x85 pitch 110x91")
    ok_layout(geom.get("content_size_px") == [542, 449], "grid content is 542x449")
    ok_layout(grid.get("rect_px") == [653, 121, 542, 449],
              "grid rect is (653,121,542,449)")

    # tabs
    tabs = [n for n in nodes.values() if n.get("kind") == "tab"]
    ok_layout(len(tabs) == 5, "5 page tabs")
    ok_layout(nodes.get("tabs", {}).get("geometry", {}).get("gap_px") == 7,
              "tab gap is 7")
    for t in tabs:
        page = t.get("page")
        ok_layout(isinstance(page, int) and 1 <= page <= 5, f"tab page {page} valid")
        ok_layout(t.get("rect_px") == [653 + (page - 1) * 110, 59, 103, 54],
                  f"tab {page} rect follows pitch")
        ok_layout(t.get("within") == "tabs", f"tab {page} within tabs")

    # side nav
    navs = [n for n in nodes.values() if n.get("kind") == "nav_tab"]
    ok_layout(len(navs) == 3, "3 side-nav tabs")
    for i, n in enumerate(sorted(navs, key=lambda z: z["rect_px"][1])):
        ok_layout(n.get("rect_px") == [1198, 87 + i * 145, 78, 129],
                  f"nav tab {i} rect follows pitch")
        ok_layout(n.get("within") == "side_nav", f"nav tab {i} within side_nav")
    ok_layout(nodes.get("side_nav", {}).get("geometry", {}).get("gap_px") == 16,
              "side nav gap is 16")

    # equipment slots
    slots = [n for n in nodes.values() if n.get("kind") == "equipment_slot"]
    ok_layout(len(slots) == 8, "8 equipment slots")
    keys = {n.get("slot_key") for n in slots}
    expected_keys = {"artifact", "boots", "armor", "helmet", "necklace",
                     "ring_left", "ring_right", "weapon"}
    ok_layout(keys == expected_keys, "equipment slot keys match the 8 expected keys")
    for s in slots:
        x, y, w, h = s["rect_px"]
        ok_layout([w, h] == [104, 90], f"{s.get('slot_key')}: 104x90")
        ok_layout(s.get("slot_center_px") == [x + 52, y + 45],
                  f"{s.get('slot_key')}: center derived from rect")
        ok_layout(s.get("local_px") == [x - 60, y - 47],
                  f"{s.get('slot_key')}: local = rect - (60,47)")
        ok_layout(s.get("within") == "panel", f"{s.get('slot_key')}: within panel")

    # attributes / currency / detail
    for bar in ("hp_track", "mp_track"):
        ok_layout(nodes.get(bar, {}).get("rect_px", [None, None, 0, 0])[2:] == [358, 30],
                  f"{bar} is 358x30")
    stats = [n for n in nodes.values() if n.get("kind") == "stat"]
    ok_layout(len(stats) == 4, "4 stat rows")
    ok_layout(nodes.get("hp_track", {}).get("rect_px", [0, 0])[:2] == [225, 513],
              "HP bar at (225,513)")
    ok_layout(nodes.get("mp_track", {}).get("rect_px", [0, 0])[:2] == [225, 551],
              "MP bar at (225,551)")
    ok_layout(nodes.get("coin_gold_pill", {}).get("rect_px") == [706, 606, 246, 32],
              "gold pill 246x32 at (706,606)")
    ok_layout(nodes.get("coin_silver_pill", {}).get("rect_px") == [706, 659, 246, 30],
              "silver pill 246x30 at (706,659)")
    ok_layout(nodes.get("sort_button", {}).get("rect_px") == [994, 613, 182, 61],
              "sort button 182x61 at (994,613)")
    detail = nodes.get("detail_card", {})
    ok_layout(detail.get("rect_px") == [898, 132, 290, 440],
              "detail card (898,132,290,440)")
    dbuttons = [k for k in nodes if k.startswith("detail_btn_")]
    ok_layout(len(dbuttons) == 3, "3 detail action buttons")
    for b in dbuttons:
        ok_layout(nodes[b].get("within") == "detail_card", f"{b} within detail_card")
    ok_layout(nodes.get("detail_card_layout", {}).get("geometry", {})
              .get("action_gap_px") == 8, "detail action gap is 8")

    # motion
    motion = doc.get("motion", [])
    ok_layout(isinstance(motion, list) and len(motion) >= 25, "motion has >= 25 entries")
    for m in motion:
        ok_layout(isinstance(m, dict) and bool(m.get("id")) and bool(m.get("target")),
                  "motion entry has id/target")
        ok_layout(is_num(m.get("duration_ms")) and m["duration_ms"] >= 0,
                  f"motion {m.get('id')}: duration >= 0")
        ok_layout(bool(m.get("easing")), f"motion {m.get('id')}: easing present")
        ok_layout(isinstance(m.get("properties"), dict) and bool(m["properties"]),
                  f"motion {m.get('id')}: properties present")

    # interactions
    inter = doc.get("interactions", {})
    ok_layout(isinstance(inter, dict), "interactions object present")
    for k in ("pointer", "keyboard", "state_precedence", "selection", "states"):
        ok_layout(k in inter, f"interactions.{k} present")
    states = inter.get("states", {})
    for k in ("item_cell", "button", "tab", "side_nav_tab", "equip_slot"):
        ok_layout(k in states, f"states.{k} present")
    cell_states = states.get("item_cell", {})
    for k in ("normal", "hover", "selected", "disabled", "empty"):
        ok_layout(k in cell_states, f"item_cell.{k} state present")
    buttons = states.get("button", {})
    for kind in ("gold", "slate", "danger", "ice", "ghost"):
        ok_layout(kind in buttons, f"button kind {kind} present")
        for st in ("normal", "hover", "pressed"):
            ok_layout(st in buttons.get(kind, {}), f"button {kind}.{st} present")
    ok_layout(inter.get("state_precedence", [])[:4] ==
              ["confirm_dialog", "placeholder_overlay", "filter_popup", "panel_open"],
              "overlay precedence is confirm > placeholder > filter > panel")

    # state machine
    sm = doc.get("state_machine", {})
    for k in ("panel", "page", "category", "detail", "confirm"):
        ok_layout(k in sm, f"state_machine.{k} present")

    # self check consistency
    sc = doc.get("self_check", {})
    ok_layout(sc.get("canvas_px") == [1280, 720], "self_check canvas")
    ok_layout(sc.get("node_count") == len(nodes), "self_check node_count matches")
    ok_layout(sc.get("motion_count") == len(motion), "self_check motion_count matches")
    ok_layout(sc.get("grid", {}).get("cell_count") == len(cells), "self_check grid cells")
    ok_layout(sc.get("equipment_slots", {}).get("count") == len(slots), "self_check slots")
    ok_layout(sc.get("tabs", {}).get("count") == len(tabs), "self_check tabs")
    ok_layout(sc.get("side_nav", {}).get("count") == len(navs), "self_check nav")
    ok_layout(sc.get("detail_card", {}).get("action_buttons") == len(dbuttons),
              "self_check detail buttons")
    ok_layout(sc.get("fonts", {}).get("min_px") == min(sizes.values()) and
              sc.get("fonts", {}).get("max_px") == max(sizes.values()),
              "self_check font min/max")
    ok_layout(sc.get("fonts", {}).get("size_count") == len(sizes),
              "self_check font size count")
    ok_layout(sc.get("key_geometry_max_dev_pct", 99) <= 3.0,
              "self_check key geometry <= 3%")
    ok_layout(sc.get("reference_shipped") is False, "reference is not shipped")
    ok_layout(all(k in nodes for k in sc.get("added_controls", [])),
              "added controls are listed as real nodes")

    # determinism block
    det = doc.get("determinism", {})
    for k in ("layout", "ordering", "random", "screenshot", "locale", "time"):
        ok_layout(k in det, f"determinism.{k} present")

    print(f"layout: {layout_checks} checks, {len(layout_fails)} failures, "
          f"nodes={len(nodes)}, motion={len(motion)}, norm_err={normalized_max_error:.2e}")
    return doc


# ---------------------------------------------------------------- manifest
def validate_manifest() -> dict:
    if not MANIFEST.exists():
        ok_manifest(False, f"missing {MANIFEST}")
        return {}
    try:
        doc = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        ok_manifest(False, f"invalid JSON: {e}")
        return {}

    ok_manifest(isinstance(doc, dict), "top level is an object")
    ok_manifest(str(doc.get("schema", "")).startswith("modelfw.inventory.assets/"),
                "schema is modelfw.inventory.assets/*")
    lic = doc.get("license", {})
    ok_manifest(lic.get("reference_included") is False, "reference assets not included")
    ok_manifest(lic.get("third_party_art") == "none", "no third-party art")
    ok_manifest(bool(lic.get("statement")) and bool(lic.get("project_license")),
                "license statement/project license present")
    ok_manifest(isinstance(doc.get("naming"), dict) and isinstance(doc.get("conventions"), dict),
                "naming/conventions present")
    ok_manifest("nine_slice_policy" in doc.get("conventions", {}),
                "nine-slice policy present")

    assets = doc.get("assets", [])
    ok_manifest(isinstance(assets, list) and len(assets) == 29,
                "29 assets listed")
    ids, paths = set(), set()
    icons = []
    ui = []
    for a in assets:
        aid = a.get("id")
        rel = a.get("path")
        ok_manifest(isinstance(aid, str) and bool(aid), f"asset id present ({aid})")
        ok_manifest(isinstance(rel, str) and bool(rel), f"asset path present ({aid})")
        if not (isinstance(rel, str) and rel):
            continue
        ok_manifest(aid not in ids, f"duplicate id: {aid}")
        ok_manifest(rel not in paths, f"duplicate path: {rel}")
        ids.add(aid)
        paths.add(rel)
        ok_manifest("htz_imgs" not in rel and "19.png" not in rel and not rel.startswith("/tmp"),
                    f"{aid}: no reference image path")
        p = ROOT / rel
        ok_manifest(p.exists(), f"{aid}: path exists ({rel})")
        if not p.exists():
            continue
        ok_manifest("nine_slice_margin_px" in a, f"{aid}: nine_slice_margin_px field present")
        ok_manifest(isinstance(a.get("usage"), str) and bool(a["usage"]), f"{aid}: usage present")
        ok_manifest(a.get("license") == "original" and a.get("license_ref") == "CREDITS.md",
                    f"{aid}: original license + CREDITS ref")
        src = a.get("source_size_px")
        ok_manifest(isinstance(src, list) and len(src) == 2 and all(isinstance(v, int) for v in src),
                    f"{aid}: source_size_px is 2 ints")
        if not (isinstance(src, list) and len(src) == 2):
            continue
        suffix = p.suffix.lower()
        if suffix == ".png":
            ok_manifest(a.get("type") == "image/png", f"{aid}: type image/png")
            actual = png_size(p)
            ok_manifest(actual == src, f"{aid}: PNG dimensions {actual} == manifest {src}")
            ui.append(a) if rel.startswith("assets/ui/") else None
        elif suffix == ".svg":
            ok_manifest(a.get("type") == "image/svg+xml", f"{aid}: type image/svg+xml")
            actual, vb = svg_size(p)
            ok_manifest(actual == src, f"{aid}: SVG dimensions {actual} == manifest {src}")
            ok_manifest(a.get("view_box") == vb, f"{aid}: viewBox matches")
            if a.get("role") == "item_icon":
                icons.append(a)
        else:
            ok_manifest(False, f"{aid}: unsupported asset extension {suffix}")
        disp = a.get("display_size_px", "missing")
        ok_manifest(disp is None or (isinstance(disp, list) and len(disp) == 2),
                    f"{aid}: display_size_px is null or 2 numbers")

    ok_manifest(len(icons) == 20, "20 item icons")
    ok_manifest(len(ui) == 7, "7 UI textures")
    for a in icons:
        ok_manifest(a.get("icon_key") == a["id"][len("icon_"):], f"{a['id']}: icon_key")
        ok_manifest(a.get("source_size_px") == [256, 256], f"{a['id']}: 256x256")
        ok_manifest(a.get("display_size_px") == [78, 78], f"{a['id']}: primary display 78x78")
    icon_keys = {a["icon_key"] for a in icons}
    for k in ["sword", "armor", "helmet", "necklace", "ring", "boots", "bell", "tome"]:
        ok_manifest(k in icon_keys, f"equipment icon key present: {k}")
    panel = next((a for a in assets if a.get("id") == "ui_panel"), {})
    ok_manifest(panel.get("source_size_px") == [2386, 1318], "panel source 2386x1318")
    ok_manifest(panel.get("display_size_px") == [1193, 659], "panel display 1193x659")
    close = next((a for a in assets if a.get("id") == "ui_close"), {})
    ok_manifest(close.get("display_size_px") == [72, 72], "close display 72x72")

    fonts = doc.get("fonts", [])
    ok_manifest(isinstance(fonts, list) and len(fonts) >= 2, "2+ font entries")
    ok_manifest(all(f.get("bundled") is False and f.get("path") is None for f in fonts),
                "fonts not bundled and have no path")
    ok_manifest(all(bool(f.get("family_stack")) for f in fonts), "font stacks present")

    data = doc.get("data", [])
    ok_manifest(isinstance(data, list) and len(data) == 1, "one data file")
    if data:
        d = data[0]
        dp = ROOT / d.get("path", "")
        ok_manifest(dp.exists(), f"data path exists ({d.get('path')})")
        if dp.exists():
            items = json.loads(dp.read_text(encoding="utf-8"))
            counts = d.get("counts", {})
            ok_manifest(counts.get("items") == len(items.get("items", [])),
                        "data item count matches")
            ok_manifest(counts.get("equipment_slots") == len(items.get("equipment_slots", [])),
                        "data equipment count matches")
            pages = {}
            cats = {}
            for it in items.get("items", []):
                pages[str(it["page"])] = pages.get(str(it["page"]), 0) + 1
                cats[it["category"]] = cats.get(it["category"], 0) + 1
            ok_manifest(counts.get("page_counts") == pages, "data page counts match")
            ok_manifest(counts.get("categories") == cats, "data category counts match")
            ok_manifest(counts.get("capacity") == items["player"]["capacity"],
                        "data capacity matches")
            ok_manifest(len(items.get("items", [])) == 35, "35 items in data")
            ok_manifest(len(items.get("equipment_slots", [])) == 8, "8 equipment in data")

    runtime = doc.get("runtime_drawn", [])
    ok_manifest(isinstance(runtime, list) and len(runtime) >= 4,
                "runtime-drawn recipes documented")
    ok_manifest(all("nine_slice_margin_px" in r for r in runtime),
                "runtime recipes declare nine-slice field")

    counts = doc.get("counts", {})
    ok_manifest(counts.get("total_files") == len(assets), "counts.total_files matches")
    ok_manifest(counts.get("icons") == len(icons), "counts.icons matches")
    ok_manifest(counts.get("ui_textures") == len(ui), "counts.ui_textures matches")
    ok_manifest(counts.get("data_files") == len(data), "counts.data_files matches")
    ok_manifest(counts.get("fonts_bundled") == 0, "no bundled fonts")

    sc = doc.get("self_check", {})
    ok_manifest(sc.get("paths_must_exist") is True, "self_check paths_must_exist")
    ok_manifest(sc.get("dimensions_must_match") is True, "self_check dimensions_must_match")
    ok_manifest(sc.get("icons_expected") == 20, "self_check icons_expected")
    ok_manifest(sc.get("reference_assets_present") is False, "self_check no reference assets")
    ok_manifest(sc.get("nine_slice_field_present_on_every_asset") is True,
                "self_check nine-slice field")

    print(f"manifest: {manifest_checks} checks, {len(manifest_fails)} failures, "
          f"assets={len(assets)}, icons={len(icons)}, ui={len(ui)}")
    return doc


# ---------------------------------------------------------------- links
LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


def validate_links() -> None:
    files = [ROOT / "README.md", ROOT / "CREDITS.md"]
    files += sorted((ROOT / "docs").glob("*.md"))
    files += sorted((ROOT / "export").glob("*.md"))
    for md in files:
        if not md.exists():
            ok_link(False, f"markdown file missing: {md}")
            continue
        text = md.read_text(encoding="utf-8")
        for raw in LINK_RE.findall(text):
            target = raw.strip().strip("<>")
            if not target or target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target = target.split("#", 1)[0]
            if not target:
                continue
            resolved = (md.parent / target).resolve()
            inside_root = str(resolved).startswith(str(ROOT.resolve()))
            ok_link(inside_root, f"{md.name}: link stays inside project ({raw})")
            ok_link(resolved.exists(), f"{md.name}: link exists ({raw})")
    print(f"links: {link_checks} checks, {len(link_fails)} failures")


def main() -> int:
    print("== export validation ==")
    validate_layout()
    validate_manifest()
    validate_links()

    print()
    if layout_fails:
        print(f"EXPORT_LAYOUT_FAILED ({len(layout_fails)} failures)")
    else:
        print("EXPORT_LAYOUT_OK")
    if manifest_fails:
        print(f"EXPORT_MANIFEST_FAILED ({len(manifest_fails)} failures)")
    else:
        print("EXPORT_MANIFEST_OK")
    if link_fails:
        print(f"EXPORT_LINKS_FAILED ({len(link_fails)} failures)")
    else:
        print("EXPORT_LINKS_OK")

    return 0 if not (layout_fails or manifest_fails or link_fails) else 1


if __name__ == "__main__":
    sys.exit(main())
