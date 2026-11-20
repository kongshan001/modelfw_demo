"""Minimal deterministic dungeon generators for the procedural-generation teardown.

Companion to docs/procedural-generation-teardown.md. Four algorithms from the
video are reduced to their smallest useful form:

  * generate_ca          -- cellular automata, the 4-5 rule
  * generate_golden_path -- Spelunky-style guaranteed path + room templates
  * generate_bsp         -- binary space partitioning
  * generate_drunkard    -- drunkard's walk

Rules for this file:
  * every random choice goes through XorShift32(seed); the global random module
    is never used, so a seed fully determines the map;
  * the grid is row-major: 0 = floor, 1 = wall;
  * every generator returns a GeneratedMap with a start and an exit;
  * verification (connectivity, reproducibility) lives in verify.py.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
import hashlib

WALL = 1
FLOOR = 0


class XorShift32:
    """Tiny deterministic RNG. Same sequence in Python and JS for a given seed.

    This is a demo RNG, not a production cryptographic RNG. It is enough to make
    the point that *all* level randomness must be seeded and injectable.
    """

    def __init__(self, seed: int) -> None:
        self.state = (seed & 0xFFFFFFFF) or 0x9E3779B9

    def next_u32(self) -> int:
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        self.state = x & 0xFFFFFFFF
        return self.state

    def randint(self, lo: int, hi: int) -> int:
        return lo + self.next_u32() % (hi - lo + 1)

    def chance(self, percent: int) -> bool:
        return self.next_u32() % 100 < percent

    def choice(self, seq):
        return seq[self.next_u32() % len(seq)]


@dataclass
class GeneratedMap:
    name: str
    seed: int
    grid: list[list[int]]
    start: tuple[int, int]
    exit: tuple[int, int]
    meta: dict = field(default_factory=dict)

    @property
    def width(self) -> int:
        return len(self.grid[0])

    @property
    def height(self) -> int:
        return len(self.grid)

    def signature(self) -> str:
        rows = "\n".join("".join("1" if v == WALL else "0" for v in row) for row in self.grid)
        return hashlib.sha256(rows.encode("ascii")).hexdigest()[:12]


# ---------------------------------------------------------------------------
# Grid utilities


def new_grid(width: int, height: int, fill: int = WALL) -> list[list[int]]:
    return [[fill for _ in range(width)] for _ in range(height)]


def inside(grid: list[list[int]], x: int, y: int) -> bool:
    return 0 <= y < len(grid) and 0 <= x < len(grid[0])


def carve(grid: list[list[int]], x: int, y: int) -> None:
    if inside(grid, x, y):
        grid[y][x] = FLOOR


def carve_rect(grid: list[list[int]], x: int, y: int, w: int, h: int) -> None:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            carve(grid, xx, yy)


def carve_l(grid: list[list[int]], a: tuple[int, int], b: tuple[int, int], rng: XorShift32) -> int:
    """Carve a 1-tile L-shaped corridor between two points; return new floor tiles."""
    before = count_floor(grid)
    ax, ay = a
    bx, by = b
    if rng.chance(50):
        for x in range(min(ax, bx), max(ax, bx) + 1):
            carve(grid, x, ay)
        for y in range(min(ay, by), max(ay, by) + 1):
            carve(grid, bx, y)
    else:
        for y in range(min(ay, by), max(ay, by) + 1):
            carve(grid, ax, y)
        for x in range(min(ax, bx), max(ax, bx) + 1):
            carve(grid, x, by)
    return count_floor(grid) - before


def flood_fill(grid: list[list[int]], start: tuple[int, int]) -> set[tuple[int, int]]:
    """4-neighbour flood fill over floor tiles."""
    sx, sy = start
    if not inside(grid, sx, sy) or grid[sy][sx] != FLOOR:
        return set()
    seen = {(sx, sy)}
    queue = deque([(sx, sy)])
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if inside(grid, nx, ny) and grid[ny][nx] == FLOOR and (nx, ny) not in seen:
                seen.add((nx, ny))
                queue.append((nx, ny))
    return seen


def floor_components(grid: list[list[int]]) -> list[list[tuple[int, int]]]:
    """All 4-connected floor components, largest first (stable row-major ties)."""
    seen: set[tuple[int, int]] = set()
    comps: list[list[tuple[int, int]]] = []
    for y, row in enumerate(grid):
        for x, cell in enumerate(row):
            if cell == FLOOR and (x, y) not in seen:
                comp = flood_fill(grid, (x, y))
                seen |= comp
                comps.append(sorted(comp, key=lambda p: (p[1], p[0])))
    comps.sort(key=len, reverse=True)
    return comps


def drop_tiny_floor(grid: list[list[int]], minimum: int = 8) -> int:
    """Turn tiny isolated floor pockets into wall; return how many tiles changed."""
    changed = 0
    for comp in floor_components(grid):
        if len(comp) < minimum:
            for x, y in comp:
                grid[y][x] = WALL
                changed += 1
    return changed


def connect_components(grid: list[list[int]], rng: XorShift32) -> int:
    """Connect every remaining floor component to the largest one with L corridors.

    This is the "link them up with a few corridors" repair the video mentions
    after changing the cellular-automata thresholds. Returns corridor count.
    """
    comps = floor_components(grid)
    if len(comps) <= 1:
        return 0
    main = set(comps[0])
    links = 0
    for comp in comps[1:]:
        # deterministic nearest pair: row-major scan of both components
        best = None
        best_pair = None
        for bx, by in comp:
            for ax, ay in main:
                d = abs(ax - bx) + abs(ay - by)
                if best is None or d < best:
                    best = d
                    best_pair = ((ax, ay), (bx, by))
        assert best_pair is not None
        carve_l(grid, best_pair[0], best_pair[1], rng)
        # Re-read the largest component so the next nearest-pair scan includes
        # the corridor and the just-joined component.
        main = set(floor_components(grid)[0])
        links += 1
    return links


def bfs_distances(grid: list[list[int]], start: tuple[int, int]) -> dict[tuple[int, int], int]:
    dist = {start: 0}
    queue = deque([start])
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if inside(grid, nx, ny) and grid[ny][nx] == FLOOR and (nx, ny) not in dist:
                dist[(nx, ny)] = dist[(x, y)] + 1
                queue.append((nx, ny))
    return dist


def farthest_pair(grid: list[list[int]]) -> tuple[tuple[int, int], tuple[int, int], int]:
    """Double-BFS diameter approximation over floor tiles; deterministic."""
    comps = floor_components(grid)
    if not comps:
        raise ValueError("map has no floor tiles")
    seed = comps[0][0]
    d1 = bfs_distances(grid, seed)
    a = max(d1, key=lambda p: (d1[p], -p[1], -p[0]))
    d2 = bfs_distances(grid, a)
    b = max(d2, key=lambda p: (d2[p], -p[1], -p[0]))
    return a, b, d2[b]


def count_floor(grid: list[list[int]]) -> int:
    return sum(1 for row in grid for v in row if v == FLOOR)


def room_centers(rooms: list[tuple[int, int, int, int]]) -> list[tuple[int, int]]:
    return [(x + w // 2, y + h // 2) for x, y, w, h in rooms]


def farthest_room_pair(
    grid: list[list[int]], centers: list[tuple[int, int]]
) -> tuple[tuple[int, int], tuple[int, int], int]:
    """Pick the pair of room centers with the largest BFS distance."""
    best = None
    for i, a in enumerate(centers):
        dist = bfs_distances(grid, a)
        for b in centers[i + 1 :]:
            d = dist.get(b, -1)
            if best is None or d > best[2]:
                best = (a, b, d)
    if best is None or best[2] < 0:
        raise ValueError("rooms are not connected")
    return best


# ---------------------------------------------------------------------------
# 1. Cellular automata, 4-5 rule (video 0:43-2:48)


def generate_ca(
    seed: int,
    width: int = 60,
    height: int = 30,
    wall_percent: int = 45,
    iterations: int = 5,
    wall_keep: int = 4,
    floor_become: int = 5,
) -> GeneratedMap:
    rng = XorShift32(seed)
    grid = new_grid(width, height, WALL)
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            grid[y][x] = WALL if rng.chance(wall_percent) else FLOOR

    def wall_neighbors(g, x, y):
        # out of bounds counts as wall: the cave stays enclosed
        n = 0
        for yy in (y - 1, y, y + 1):
            for xx in (x - 1, x, x + 1):
                if (xx, yy) == (x, y):
                    continue
                if xx < 0 or yy < 0 or xx >= width or yy >= height or g[yy][xx] == WALL:
                    n += 1
        return n

    for _ in range(iterations):
        nxt = [row[:] for row in grid]
        for y in range(1, height - 1):
            for x in range(1, width - 1):
                n = wall_neighbors(grid, x, y)
                if grid[y][x] == WALL:
                    nxt[y][x] = WALL if n >= wall_keep else FLOOR
                else:
                    nxt[y][x] = WALL if n >= floor_become else FLOOR
        grid = nxt

    before = len(floor_components(grid))
    tiny = drop_tiny_floor(grid, minimum=8)
    links = connect_components(grid, rng)
    after = len(floor_components(grid))
    start, exit_, distance = farthest_pair(grid)

    return GeneratedMap(
        name="cellular-automata",
        seed=seed,
        grid=grid,
        start=start,
        exit=exit_,
        meta={
            "wall_percent": wall_percent,
            "iterations": iterations,
            "wall_keep": wall_keep,
            "floor_become": floor_become,
            "components_before_repair": before,
            "components_after_repair": after,
            "tiny_tiles_dropped": tiny,
            "corridors_added": links,
            "floor_ratio": count_floor(grid) / (width * height),
            "start_exit_distance": distance,
        },
    )


# ---------------------------------------------------------------------------
# 2. Guaranteed golden path + room templates (video 2:49-4:38)


_TEMPLATES = ("open", "pillars", "corners", "sparse")


def generate_golden_path(
    seed: int,
    rooms: int = 4,
    room_size: int = 5,
    max_horizontal: int = 3,
) -> GeneratedMap:
    """Spelunky-inspired: path first, decorate second.

    The path only moves left/right inside a row and down between rows, so an
    entrance on the top row and an exit on the bottom row are connected by
    construction. Templates are then placed in the path rooms without touching
    the centre cross that carries the corridor.
    """
    rng = XorShift32(seed)
    path: list[tuple[int, int]] = []
    col = rng.randint(0, rooms - 1)
    row = 0
    path.append((row, col))
    while row < rooms - 1:
        if rng.chance(65):
            target = max(0, min(rooms - 1, col + rng.randint(-max_horizontal, max_horizontal)))
            step = 1 if target > col else -1
            while col != target:
                col += step
                path.append((row, col))
        row += 1
        path.append((row, col))

    path_set = set(path)
    room_grid = [["." if (y, x) in path_set else "#" for x in range(rooms)] for y in range(rooms)]

    cell = room_size + 2
    width = rooms * cell + 1
    height = rooms * cell + 1
    grid = new_grid(width, height, WALL)
    room_rects: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    templates: dict[tuple[int, int], str] = {}

    for (r, c) in path:
        x = c * cell + 1
        y = r * cell + 1
        room_rects[(r, c)] = (x, y, room_size, room_size)
        carve_rect(grid, x, y, room_size, room_size)
        templates[(r, c)] = rng.choice(_TEMPLATES)

    # Connect consecutive path rooms through their centres.
    for (r1, c1), (r2, c2) in zip(path, path[1:]):
        x1, y1, w1, h1 = room_rects[(r1, c1)]
        x2, y2, w2, h2 = room_rects[(r2, c2)]
        carve_l(
            grid,
            (x1 + w1 // 2, y1 + h1 // 2),
            (x2 + w2 // 2, y2 + h2 // 2),
            rng,
        )

    # Decorate, but keep the centre row/column open so every template remains
    # traversable and the connector sockets are never blocked.
    for (r, c), (x, y, w, h) in room_rects.items():
        kind = templates[(r, c)]
        cx, cy = x + w // 2, y + h // 2
        spots = [(x + 1, y + 1), (x + w - 2, y + 1), (x + 1, y + h - 2), (x + w - 2, y + h - 2)]
        if kind == "pillars":
            for sx, sy in spots:
                grid[sy][sx] = WALL
        elif kind == "corners":
            for sx, sy in (spots[0], spots[3]):
                grid[sy][sx] = WALL
        elif kind == "sparse":
            grid[spots[1][1]][spots[1][0]] = WALL

    start_rect = room_rects[path[0]]
    exit_rect = room_rects[path[-1]]
    start = (start_rect[0] + start_rect[2] // 2, start_rect[1] + start_rect[3] // 2)
    exit_ = (exit_rect[0] + exit_rect[2] // 2, exit_rect[1] + exit_rect[3] // 2)

    return GeneratedMap(
        name="golden-path",
        seed=seed,
        grid=grid,
        start=start,
        exit=exit_,
        meta={
            "rooms": rooms,
            "room_size": room_size,
            "path": path,
            "room_grid": room_grid,
            "templates": templates,
            "path_length": len(path),
            "floor_ratio": count_floor(grid) / (width * height),
            "start_exit_distance": bfs_distances(grid, start).get(exit_, -1),
        },
    )


# ---------------------------------------------------------------------------
# 3. Binary space partitioning (video 4:39-5:28)


@dataclass
class _BSPNode:
    x: int
    y: int
    w: int
    h: int
    depth: int
    left: "_BSPNode | None" = None
    right: "_BSPNode | None" = None

    @property
    def leaf(self) -> bool:
        return self.left is None and self.right is None


def _split_bsp(node: _BSPNode, rng: XorShift32, min_leaf: int, max_depth: int) -> None:
    can_h = node.w >= min_leaf * 2
    can_v = node.h >= min_leaf * 2
    if node.depth >= max_depth or not (can_h or can_v):
        return
    horizontal = False
    if can_h and can_v:
        if node.w > node.h * 1.25:
            horizontal = True
        elif node.h > node.w * 1.25:
            horizontal = False
        else:
            horizontal = rng.chance(50)
    elif can_h:
        horizontal = True
    else:
        horizontal = False

    if horizontal:
        cut = rng.randint(min_leaf, node.w - min_leaf)
        node.left = _BSPNode(node.x, node.y, cut, node.h, node.depth + 1)
        node.right = _BSPNode(node.x + cut, node.y, node.w - cut, node.h, node.depth + 1)
    else:
        cut = rng.randint(min_leaf, node.h - min_leaf)
        node.left = _BSPNode(node.x, node.y, node.w, cut, node.depth + 1)
        node.right = _BSPNode(node.x, node.y + cut, node.w, node.h - cut, node.depth + 1)
    _split_bsp(node.left, rng, min_leaf, max_depth)
    _split_bsp(node.right, rng, min_leaf, max_depth)


def _leaves(node: _BSPNode, out: list[_BSPNode]) -> None:
    if node.leaf:
        out.append(node)
        return
    _leaves(node.left, out)
    _leaves(node.right, out)


def generate_bsp(
    seed: int,
    width: int = 64,
    height: int = 32,
    min_leaf: int = 8,
    max_depth: int = 5,
) -> GeneratedMap:
    rng = XorShift32(seed)
    root = _BSPNode(1, 1, width - 2, height - 2, 0)
    _split_bsp(root, rng, min_leaf, max_depth)
    leaves: list[_BSPNode] = []
    _leaves(root, leaves)

    grid = new_grid(width, height, WALL)
    rooms: list[tuple[int, int, int, int]] = []
    for leaf in leaves:
        if leaf.w < 4 or leaf.h < 4:
            continue
        rw = rng.randint(3, max(3, leaf.w - 2))
        rh = rng.randint(3, max(3, leaf.h - 2))
        rx = rng.randint(leaf.x, leaf.x + leaf.w - rw)
        ry = rng.randint(leaf.y, leaf.y + leaf.h - rh)
        rooms.append((rx, ry, rw, rh))
        carve_rect(grid, rx, ry, rw, rh)

    centers = room_centers(rooms)
    corridor_tiles = 0
    # Prim-style nearest-neighbour tree: every new room joins an already
    # connected room, so the whole layout is connected by construction.
    for i in range(1, len(centers)):
        best = None
        for j in range(i):
            d = abs(centers[i][0] - centers[j][0]) + abs(centers[i][1] - centers[j][1])
            if best is None or d < best[0]:
                best = (d, j)
        corridor_tiles += carve_l(grid, centers[best[1]], centers[i], rng)

    start, exit_, distance = farthest_room_pair(grid, centers)
    return GeneratedMap(
        name="bsp",
        seed=seed,
        grid=grid,
        start=start,
        exit=exit_,
        meta={
            "rooms": len(rooms),
            "room_rects": rooms,
            "min_leaf": min_leaf,
            "max_depth": max_depth,
            "corridor_tiles": corridor_tiles,
            "floor_ratio": count_floor(grid) / (width * height),
            "start_exit_distance": distance,
        },
    )


# ---------------------------------------------------------------------------
# 4. Drunkard's walk (video 5:29-5:41)


def generate_drunkard(
    seed: int,
    width: int = 60,
    height: int = 30,
    fill_target: float = 0.40,
    max_steps: int = 3000,
    brush: int = 3,
) -> GeneratedMap:
    rng = XorShift32(seed)
    grid = new_grid(width, height, WALL)
    x, y = width // 2, height // 2
    carved = 0
    steps = 0

    def stamp(cx: int, cy: int) -> int:
        added = 0
        half = brush // 2
        for yy in range(cy - half, cy + half + 1):
            for xx in range(cx - half, cx + half + 1):
                if inside(grid, xx, yy) and grid[yy][xx] == WALL:
                    grid[yy][xx] = FLOOR
                    added += 1
        return added

    carved += stamp(x, y)
    target = int(width * height * fill_target)
    while carved < target and steps < max_steps:
        # A little centre bias keeps the digger away from the border; the rest
        # is a plain random walk, exactly as the video describes.
        choices = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if x < 4:
            choices = [(1, 0), (1, 0), (0, 1), (0, -1)]
        elif x > width - 5:
            choices = [(-1, 0), (-1, 0), (0, 1), (0, -1)]
        if y < 4:
            choices = [(0, 1), (0, 1), (1, 0), (-1, 0)]
        elif y > height - 5:
            choices = [(0, -1), (0, -1), (1, 0), (-1, 0)]
        dx, dy = rng.choice(choices)
        x = max(1, min(width - 2, x + dx))
        y = max(1, min(height - 2, y + dy))
        carved += stamp(x, y)
        steps += 1

    start, exit_, distance = farthest_pair(grid)
    return GeneratedMap(
        name="drunkard",
        seed=seed,
        grid=grid,
        start=start,
        exit=exit_,
        meta={
            "fill_target": fill_target,
            "steps": steps,
            "brush": brush,
            "floor_ratio": count_floor(grid) / (width * height),
            "start_exit_distance": distance,
        },
    )


# ---------------------------------------------------------------------------
# Rendering helpers


def ascii_map(gm: GeneratedMap) -> str:
    lines = []
    for y, row in enumerate(gm.grid):
        chars = []
        for x, cell in enumerate(row):
            if (x, y) == gm.start:
                chars.append("S")
            elif (x, y) == gm.exit:
                chars.append("E")
            else:
                chars.append("#" if cell == WALL else ".")
        lines.append("".join(chars))
    return "\n".join(lines)
