// Procedural textures for the sky / cloud raymarch and the water surface.
// Everything is generated at boot so the demo has no binary or network assets.

import * as THREE from '../vendor/three.module.js';

const F32 = 1 / 4294967295;

function hash3i(x, y, z, seed) {
  let h = seed | 0;
  h = Math.imul(h ^ (x | 0), 0x27d4eb2d);
  h = Math.imul(h ^ (y | 0), 0x165667b1);
  h = Math.imul(h ^ (z | 0), 0x9e3779b1);
  h ^= h >>> 15;
  h = Math.imul(h, 0x85ebca6b);
  h ^= h >>> 13;
  return (h >>> 0) * F32;
}

function hash2i(x, y, seed) {
  let h = seed | 0;
  h = Math.imul(h ^ (x | 0), 0x27d4eb2d);
  h = Math.imul(h ^ (y | 0), 0x165667b1);
  h ^= h >>> 15;
  h = Math.imul(h, 0x85ebca6b);
  h ^= h >>> 13;
  return (h >>> 0) * F32;
}

const wrap = (n, p) => ((n % p) + p) % p;
const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);

function valueNoise3(u, v, w, period, seed) {
  const xi = Math.floor(u);
  const yi = Math.floor(v);
  const zi = Math.floor(w);
  const fx = fade(u - xi);
  const fy = fade(v - yi);
  const fz = fade(w - zi);

  const x0 = wrap(xi, period);
  const y0 = wrap(yi, period);
  const z0 = wrap(zi, period);
  const x1 = wrap(xi + 1, period);
  const y1 = wrap(yi + 1, period);
  const z1 = wrap(zi + 1, period);

  const c000 = hash3i(x0, y0, z0, seed);
  const c100 = hash3i(x1, y0, z0, seed);
  const c010 = hash3i(x0, y1, z0, seed);
  const c110 = hash3i(x1, y1, z0, seed);
  const c001 = hash3i(x0, y0, z1, seed);
  const c101 = hash3i(x1, y0, z1, seed);
  const c011 = hash3i(x0, y1, z1, seed);
  const c111 = hash3i(x1, y1, z1, seed);

  const nx00 = c000 + (c100 - c000) * fx;
  const nx10 = c010 + (c110 - c010) * fx;
  const nx01 = c001 + (c101 - c001) * fx;
  const nx11 = c011 + (c111 - c011) * fx;
  const nxy0 = nx00 + (nx10 - nx00) * fy;
  const nxy1 = nx01 + (nx11 - nx01) * fy;
  return nxy0 + (nxy1 - nxy0) * fz;
}

function valueNoise2(u, v, period, seed) {
  const xi = Math.floor(u);
  const yi = Math.floor(v);
  const fx = fade(u - xi);
  const fy = fade(v - yi);
  const x0 = wrap(xi, period);
  const y0 = wrap(yi, period);
  const x1 = wrap(xi + 1, period);
  const y1 = wrap(yi + 1, period);
  const c00 = hash2i(x0, y0, seed);
  const c10 = hash2i(x1, y0, seed);
  const c01 = hash2i(x0, y1, seed);
  const c11 = hash2i(x1, y1, seed);
  const nx0 = c00 + (c10 - c00) * fx;
  const nx1 = c01 + (c11 - c01) * fx;
  return nx0 + (nx1 - nx0) * fy;
}

function fbm3(u, v, w, octaves, basePeriod, seed) {
  let sum = 0;
  let norm = 0;
  let amp = 0.5;
  let period = basePeriod;
  for (let o = 0; o < octaves; o++) {
    sum += amp * valueNoise3(u * period, v * period, w * period, period, seed + o * 131);
    norm += amp;
    amp *= 0.5;
    period *= 2;
  }
  return sum / norm;
}

function fbm2(u, v, octaves, basePeriod, seed) {
  let sum = 0;
  let norm = 0;
  let amp = 0.5;
  let period = basePeriod;
  for (let o = 0; o < octaves; o++) {
    sum += amp * valueNoise2(u * period, v * period, period, seed + o * 131);
    norm += amp;
    amp *= 0.5;
    period *= 2;
  }
  return sum / norm;
}

/**
 * A 64^3 RGBA tileable volume:
 *   R - low frequency fBm (cumulus shape)
 *   G - mid frequency fBm (erosion)
 *   B - billowed fBm (cauliflower detail)
 *   A - high frequency fBm (wisps)
 */
export function buildCloudNoise(size = 96) {
  const data = new Uint8Array(size * size * size * 4);
  let i = 0;
  for (let z = 0; z < size; z++) {
    const w = (z + 0.5) / size;
    for (let y = 0; y < size; y++) {
      const v = (y + 0.5) / size;
      for (let x = 0; x < size; x++) {
        const u = (x + 0.5) / size;
        const wx = fbm3(u, v, w, 2, 4, 503) - 0.5;
        const wy = fbm3(u, v, w, 2, 4, 577) - 0.5;
        const wz = fbm3(u, v, w, 2, 4, 641) - 0.5;
        const uu = u + wx * 0.07;
        const vv = v + wy * 0.07;
        const ww = w + wz * 0.07;
        const r = fbm3(uu, vv, ww, 4, 8, 11);
        const g = fbm3(uu, vv, ww, 3, 16, 37);
        const billowBase = fbm3(uu, vv, ww, 3, 8, 71);
        const billow = 1 - Math.abs(billowBase * 2 - 1);
        const fine = fbm3(uu, vv, ww, 3, 32, 97);
        data[i++] = Math.round(r * 255);
        data[i++] = Math.round(g * 255);
        data[i++] = Math.round(billow * 255);
        data[i++] = Math.round(fine * 255);
      }
    }
  }
  const tex = new THREE.Data3DTexture(data, size, size, size);
  tex.format = THREE.RGBAFormat;
  tex.type = THREE.UnsignedByteType;
  tex.minFilter = THREE.LinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.wrapR = THREE.RepeatWrapping;
  tex.unpackAlignment = 1;
  tex.needsUpdate = true;
  return tex;
}

/** 256^2 weather map: R coverage masses, G offset noise. */
export function buildWeatherTexture(size = 256) {
  const data = new Uint8Array(size * size * 4);
  let i = 0;
  for (let y = 0; y < size; y++) {
    const v = (y + 0.5) / size;
    for (let x = 0; x < size; x++) {
      const u = (x + 0.5) / size;
      const wx = fbm2(u, v, 2, 4, 419) - 0.5;
      const wy = fbm2(u, v, 2, 4, 467) - 0.5;
      const uu = u + wx * 0.06;
      const vv = v + wy * 0.06;
      const coverage = fbm2(uu, vv, 5, 4, 211);
      const offset = fbm2(uu, vv, 3, 8, 307);
      data[i++] = Math.round(THREE.MathUtils.clamp(0.2 + coverage * 0.9, 0, 1) * 255);
      data[i++] = Math.round(offset * 255);
      data[i++] = 255;
      data[i++] = 255;
    }
  }
  const tex = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.generateMipmaps = true;
  tex.anisotropy = 4;
  tex.needsUpdate = true;
  return tex;
}

/**
 * 256^2 RGBA water detail: RG slope of a tileable fBm height field,
 * B bubble/foam noise, A unused.
 */
export function buildWaterDetailTexture(size = 256) {
  const heights = new Float32Array(size * size);
  for (let y = 0; y < size; y++) {
    const v = (y + 0.5) / size;
    for (let x = 0; x < size; x++) {
      const u = (x + 0.5) / size;
      const h = fbm2(u, v, 5, 4, 521);
      const ridge = 1 - Math.abs(fbm2(u, v, 3, 16, 733) * 2 - 1);
      heights[y * size + x] = h * 0.75 + ridge * 0.25;
    }
  }
  const data = new Uint8Array(size * size * 4);
  let i = 0;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const hx0 = heights[y * size + wrap(x - 1, size)];
      const hx1 = heights[y * size + wrap(x + 1, size)];
      const hy0 = heights[wrap(y - 1, size) * size + x];
      const hy1 = heights[wrap(y + 1, size) * size + x];
      const nx = THREE.MathUtils.clamp((hx1 - hx0) * 14, -1, 1);
      const ny = THREE.MathUtils.clamp((hy1 - hy0) * 14, -1, 1);
      const u = (x + 0.5) / size;
      const v = (y + 0.5) / size;
      const bubbles = fbm2(u, v, 3, 32, 811);
      data[i++] = Math.round((nx * 0.5 + 0.5) * 255);
      data[i++] = Math.round((ny * 0.5 + 0.5) * 255);
      data[i++] = Math.round(bubbles * 255);
      data[i++] = 255;
    }
  }
  const tex = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.generateMipmaps = true;
  tex.anisotropy = 4;
  tex.needsUpdate = true;
  return tex;
}
