// Shared helpers: color conversion and deterministic noise.
import * as THREE from '../vendor/three.module.js';

// sRGB hex -> linear-space THREE.Color (ShaderMaterial uniforms and vertex
// colors must be linear; tone mapping happens at the end of the pipeline).
// THREE.Color already converts hex into the working (linear) color space on
// construction, so no extra conversion is needed here — calling
// convertSRGBToLinear() again would double-darken the color.
export function lin(hex) {
  return new THREE.Color(hex);
}

export function linVec(hex) {
  const c = lin(hex);
  return [c.r, c.g, c.b];
}

export function smoothstep(a, b, x) {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
}

export function clamp(x, a, b) {
  return Math.min(b, Math.max(a, x));
}

// Deterministic 2D value noise (hash-based, no lookup tables).
export function makeNoise2(seed) {
  const hash = (x, y) => {
    const s = Math.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453;
    return s - Math.floor(s);
  };
  const sm = (t) => t * t * (3 - 2 * t);
  return (x, y) => {
    const xi = Math.floor(x), yi = Math.floor(y);
    const xf = x - xi, yf = y - yi;
    const a = hash(xi, yi), b = hash(xi + 1, yi);
    const c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1);
    const u = sm(xf), v = sm(yf);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  };
}

// Fractal noise, result in [0, 1].
export function fbm2(noise, x, y, octaves, pers = 0.5) {
  let s = 0, amp = 1, f = 1, norm = 0;
  for (let i = 0; i < octaves; i++) {
    s += amp * noise(x * f, y * f);
    norm += amp;
    amp *= pers;
    f *= 2;
  }
  return s / norm;
}

// Small deterministic PRNG for placement.
export function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
