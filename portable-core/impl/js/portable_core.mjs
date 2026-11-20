// Reference implementation of the portable core (JavaScript / Three.js side).
// Contract: spec/functions.md; golden vectors: spec/golden.json.
// Must stay bit-identical with impl/python/portable_core.py and
// impl/gdscript/portable_core.gd.

export function screenMotion(x, y) {
  // 2:1 isometric input -> world motion. Screen Y moves half as far.
  return [x, y * 0.5];
}

export function dirIndex(x, y) {
  // Screen direction -> 8-way sector (0=right, 2=down, 4=left, 6=up).
  if (x * x + y * y < 0.0001) return 0;
  const sector = Math.floor(((Math.atan2(y, x) * 180) / Math.PI + 22.5) / 45);
  return ((sector % 8) + 8) % 8;
}

export function hash32(x, y, seed) {
  // Deterministic 32-bit hash. Math.imul keeps the low 32 bits exact.
  let v = (Math.imul(x, 374761393)
    + Math.imul(y, 668265263)
    + Math.imul(seed | 0, 1013904223)) >>> 0;
  v = (v ^ (v >>> 13)) >>> 0;
  v = Math.imul(v, 1274126177) >>> 0;
  v = (v ^ (v >>> 16)) >>> 0;
  return v;
}
