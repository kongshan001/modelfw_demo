#!/usr/bin/env python3
"""Verify the four demo generators: determinism, connectivity and invariants.

Usage:
    python3 verify.py               # summary
    python3 verify.py --maps        # summary + ASCII previews for seed 2137
    python3 verify.py --seed 42     # use another demo seed

Exit code is 0 only when every assertion passes.
"""

from __future__ import annotations

import argparse
import time

import generators as gen


GENERATORS = {
    "ca": gen.generate_ca,
    "golden_path": gen.generate_golden_path,
    "bsp": gen.generate_bsp,
    "drunkard": gen.generate_drunkard,
}


def variant_pairs(gm: gen.GeneratedMap):
    if gm.name == "bsp":
        rooms = gm.meta["room_rects"]
        for i, (x, y, w, h) in enumerate(rooms):
            for j in range(i + 1, len(rooms)):
                xx, yy, ww, hh = rooms[j]
                overlap = not (x + w <= xx or xx + ww <= x or y + h <= yy or yy + hh <= y)
                assert not overlap, f"BSP rooms {i} and {j} overlap"
        yield "no-overlap", True
    if gm.name == "golden-path":
        path = gm.meta["path"]
        assert path[0][0] == 0, "entrance must be on the top row"
        assert path[-1][0] == gm.meta["rooms"] - 1, "exit must be on the bottom row"
        for (r1, c1), (r2, c2) in zip(path, path[1:]):
            assert abs(r1 - r2) + abs(c1 - c2) == 1, "golden path must be 4-connected"
        yield "path-monotonic", True
        yield "path-length", len(path)


def check(gm: gen.GeneratedMap) -> None:
    comps = gen.floor_components(gm.grid)
    assert comps, "map has no floor"
    assert len(comps) == 1, f"expected one floor component, got {len(comps)}"
    dist = gen.bfs_distances(gm.grid, gm.start)
    assert gm.exit in dist, "exit is not reachable from start"
    assert gm.grid[gm.start[1]][gm.start[0]] == gen.FLOOR
    assert gm.grid[gm.exit[1]][gm.exit[0]] == gen.FLOOR
    list(variant_pairs(gm))


def same_layout(a: gen.GeneratedMap, b: gen.GeneratedMap) -> None:
    assert a.grid == b.grid, "same seed produced a different grid"
    assert a.start == b.start and a.exit == b.exit, "same seed changed start/exit"
    assert a.signature() == b.signature()


def fmt_meta(gm: gen.GeneratedMap) -> str:
    m = gm.meta
    if gm.name == "cellular-automata":
        return (
            f"components {m['components_before_repair']}->1, "
            f"corridors +{m['corridors_added']}, floor {m['floor_ratio']:.1%}"
        )
    if gm.name == "golden-path":
        return f"{m['rooms']}x{m['rooms']} rooms, path {m['path_length']}, floor {m['floor_ratio']:.1%}"
    if gm.name == "bsp":
        return f"{m['rooms']} rooms, corridor tiles {m['corridor_tiles']}, floor {m['floor_ratio']:.1%}"
    if gm.name == "drunkard":
        return f"{m['steps']} steps, floor {m['floor_ratio']:.1%}"
    return ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=2137, help="demo seed (video shows 2137)")
    ap.add_argument("--maps", action="store_true", help="print ASCII maps for the demo seed")
    args = ap.parse_args()

    print("PROCEDURAL GENERATION DEMOS · deterministic verification")
    print(f"demo seed = {args.seed} (video 0:27-0:36 shows SEED: 2137)")
    print("=" * 74)

    for key, fn in GENERATORS.items():
        t0 = time.perf_counter()
        a = fn(args.seed)
        b = fn(args.seed)
        c = fn(args.seed + 1)
        ms = (time.perf_counter() - t0) * 1000 / 3
        same_layout(a, b)
        assert a.signature() != c.signature(), "different seeds produced the same map"
        check(a)
        print(
            f"PASS {key:<11} {a.width}x{a.height}  {fmt_meta(a):<42} "
            f"sig={a.signature()}  {ms:5.1f}ms"
        )
        if key == "golden_path":
            print("     room path:")
            for row in a.meta["room_grid"]:
                print("       " + " ".join(row))
        if args.maps:
            print(gen.ascii_map(a))
            print("-" * 74)

    # The video's "change one number to 4" experiment (B站版 2:00-2:21):
    # a single threshold produces scattered pockets; corridors join them.
    sparse = gen.generate_ca(2137, wall_keep=4, floor_become=4)
    check(sparse)
    sm = sparse.meta
    print(
        f"CA VARIANT  single-threshold 4: components {sm['components_before_repair']}->1, "
        f"corridors +{sm['corridors_added']}, floor {sm['floor_ratio']:.1%} "
        f"(video 2:00-2:21)"
    )
    print("=" * 74)
    # Cross-seed connectivity: the generator must not rely on one lucky seed.
    seeds = [args.seed] + list(range(1, 21))
    for key, fn in GENERATORS.items():
        for s in seeds:
            gm = fn(s)
            comps = gen.floor_components(gm.grid)
            assert len(comps) == 1, f"{key} seed {s}: {len(comps)} components"
            assert gm.exit in gen.bfs_distances(gm.grid, gm.start), f"{key} seed {s}: exit unreachable"
        print(f"SEEDS OK {key:<11} {len(seeds)}/{len(seeds)} seeds connected")

    print("REPRODUCIBLE same seed -> same signature; adjacent seed -> different signature")
    print("ALL_GENERATORS_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
