#!/usr/bin/env python3
"""Golden-vector test for the Python reference implementation."""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "impl", "python"))

from portable_core import dir_index, hash32, screen_motion  # noqa: E402

EPS = 1e-9


def main() -> int:
    with open(os.path.join(ROOT, "spec", "golden.json"), encoding="utf-8") as f:
        golden = json.load(f)

    fails = []
    for case in golden["iso"]:
        x, y = case["in"]
        mx, my = screen_motion(x, y)
        ex, ey = case["motion"]
        if abs(mx - ex) > EPS or abs(my - ey) > EPS:
            fails.append(f"motion {case['in']} -> {(mx, my)} != {case['motion']}")
        got = dir_index(x, y)
        if got != case["dir"]:
            fails.append(f"dir {case['in']} -> {got} != {case['dir']}")

    for case in golden["hash"]:
        got = hash32(case["x"], case["y"], case["seed"])
        if got != case["out"]:
            fails.append(
                f"hash ({case['x']},{case['y']},{case['seed']}) -> {got} != {case['out']}"
            )

    if fails:
        for f in fails:
            print("PORTABLE_PY FAIL:", f, file=sys.stderr)
        return 1
    print(f"PORTABLE_PY_OK iso={len(golden['iso'])} hash={len(golden['hash'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
