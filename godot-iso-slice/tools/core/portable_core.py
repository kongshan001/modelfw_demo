"""Reference implementation of the portable core (Python).

Contract: spec/functions.md; golden vectors: spec/golden.json.
Must stay bit-identical with impl/gdscript/portable_core.gd and
impl/js/portable_core.mjs. Run tests/test_python.py to verify.
"""

import math


def screen_motion(x: float, y: float) -> tuple[float, float]:
    """2:1 isometric input -> world motion. Screen Y moves half as far."""
    return (x, y * 0.5)


def dir_index(x: float, y: float) -> int:
    """Screen direction -> 8-way sector (0=right, 2=down, 4=left, 6=up)."""
    if x * x + y * y < 0.0001:
        return 0
    sector = math.floor((math.degrees(math.atan2(y, x)) + 22.5) / 45.0)
    return int(sector % 8)


def hash32(x: int, y: int, seed: int) -> int:
    """Deterministic 32-bit hash. Integer-only; overflow is masked to uint32."""
    v = (x * 374761393 + y * 668265263
         + (seed & 0xFFFFFFFF) * 1013904223) & 0xFFFFFFFF
    v = (v ^ (v >> 13)) & 0xFFFFFFFF
    v = (v * 1274126177) & 0xFFFFFFFF
    v = (v ^ (v >> 16)) & 0xFFFFFFFF
    return v
