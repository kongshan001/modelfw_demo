// Procedural tropical volcanic island: heightfield terrain with vertex colors,
// rock stacks (instanced), islets and merged palm trees. All geometry and
// colors are generated from noise; nothing is loaded from disk.
import * as THREE from '../vendor/three.module.js';
import { lin, makeNoise2, fbm2, mulberry32, clamp } from './utils.js';

const noiseA = makeNoise2(11);
const noiseB = makeNoise2(23);
const noiseC = makeNoise2(47);

const GRASS_A = '#4e7a3c';
const GRASS_B = '#2e5330';
const ROCK = '#4a4742';
const SAND = '#d8c69a';
const SAND_DARK = '#c0ac7f';

// ---- height functions ----------------------------------------------------

function islandHeight(peak, radius, x, z, nA, nB) {
  const r = Math.hypot(x, z);
  const t = r / radius;
  if (t > 1.5) return -30; // deep bed far from the island
  const cone = peak * Math.pow(Math.max(0, 1 - t * t), 1.3);
  const ridge = fbm2(nA, x * 0.045 + 3.1, z * 0.045 + 7.7, 4);
  const detail = fbm2(nB, x * 0.16, z * 0.16, 3);
  let h = cone * (0.55 + 0.55 * ridge) + detail * 1.7 * Math.max(0, cone / peak);
  // gentle beach / underwater shelf
  if (h < 0) h *= 0.45;
  else {
    const bt = smoothBeach(2.5, 10, h);
    h *= 0.42 + 0.58 * bt;
  }
  // steep underwater drop-off past the shoreline
  if (t > 1.02) {
    const d = (t - 1.02) / 0.5;
    h = Math.min(h, -2 - 16 * d * d);
  }
  return h;
}

function smoothBeach(a, b, x) {
  const t = clamp((x - a) / (b - a), 0, 1);
  return t * t * (3 - 2 * t);
}

export const mainIslandHeight = (x, z) => islandHeight(36, 130, x, z, noiseA, noiseB);
const islet1Height = (x, z) => islandHeight(15, 26, x, z, noiseB, noiseC);
const islet2Height = (x, z) => islandHeight(10, 18, x, z, noiseC, noiseA);

const ISLET1 = { x: 252, z: 62 };
const ISLET2 = { x: -318, z: -186 };

// ---- terrain mesh builder ------------------------------------------------

function buildHeightfield(n, extent, cx, cz, hFn, seed) {
  const pos = [], col = [], idx = [];
  const hs = [];
  const step = extent / (n - 1);
  for (let j = 0; j < n; j++) {
    hs.push([]);
    for (let i = 0; i < n; i++) {
      const x = -extent / 2 + i * step;
      const z = -extent / 2 + j * step;
      // hFn takes coordinates relative to the heightfield center
      hs[j].push(hFn(x, z));
    }
  }
  const sandN = makeNoise2(seed);
  const vegN = makeNoise2(seed + 9);
  for (let j = 0; j < n; j++) {
    for (let i = 0; i < n; i++) {
      const x = -extent / 2 + i * step;
      const z = -extent / 2 + j * step;
      const h = hs[j][i];
      pos.push(x + cx, h, z + cz);
      // slope from finite differences
      const hx = hs[j][clamp(i + 1, 0, n - 1)] - hs[j][clamp(i - 1, 0, n - 1)];
      const hz = (hs[clamp(j + 1, 0, n - 1)][i] || 0) - (hs[clamp(j - 1, 0, n - 1)][i] || 0);
      const slope = Math.hypot(hx, hz) / (2 * step);
      const c = terrainColor(h, slope, sandN(x * 0.5, z * 0.5), vegN(x * 0.35, z * 0.35));
      col.push(c[0], c[1], c[2]);
    }
  }
  for (let j = 0; j < n - 1; j++) {
    for (let i = 0; i < n - 1; i++) {
      const a = j * n + i, b = a + 1, c = a + n, d = c + 1;
      idx.push(a, c, b, b, c, d);
    }
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  geo.setIndex(idx);
  geo.computeVertexNormals();
  const mat = new THREE.MeshStandardMaterial({
    vertexColors: true, roughness: 1, metalness: 0,
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.userData.isTerrain = true;
  return mesh;
}

function terrainColor(h, slope, sandV, vegV) {
  // Returns linear RGB triple.
  if (h < 1.6) {
    return lin(sandV > 0.5 ? SAND : SAND_DARK).toArray();
  }
  if (slope > 0.72) {
    return lin(ROCK).toArray();
  }
  if (h < 4.0) {
    const c = new THREE.Color();
    c.lerpColors(lin(SAND), lin(GRASS_A), (h - 1.6) / 2.4);
    return c.toArray();
  }
  if (h > 24) {
    const c = new THREE.Color();
    c.lerpColors(lin(GRASS_B), lin(ROCK), clamp((h - 24) / 12, 0, 1));
    return c.toArray();
  }
  return lin(vegV > 0.5 ? GRASS_A : GRASS_B).toArray();
}

// ---- rock stacks (instanced) ---------------------------------------------

function makeRockGeometry() {
  const base = new THREE.ConeGeometry(1, 1.7, 5, 3);
  const p = base.attributes.position;
  const rnd = makeNoise2(5);
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), y = p.getY(i), z = p.getZ(i);
    const j = 0.75 + 0.45 * rnd(x * 2.1, z * 2.1);
    p.setXYZ(i, x * j, y * (0.9 + 0.2 * rnd(y * 3, z)), z * j);
  }
  base.computeVertexNormals();
  return base;
}

function buildRocks(scene) {
  const rnd = mulberry32(77);
  const spots = [];
  // ring of boulders near the main shore
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2 + rnd() * 0.4;
    const r = 128 + rnd() * 34;
    const x = Math.cos(a) * r, z = Math.sin(a) * r;
    const h = mainIslandHeight(x, z);
    if (h < -2 || h > 9) continue;
    spots.push({ x, z, y: h, s: 0.9 + rnd() * 1.5, sy: 0.8 + rnd() * 1.6, rot: rnd() * 6.28 });
  }
  // tall sea stacks further out
  for (let i = 0; i < 4; i++) {
    const a = 0.7 + i * 1.7 + rnd() * 0.5;
    const r = 165 + rnd() * 60;
    spots.push({
      x: Math.cos(a) * r, z: Math.sin(a) * r, y: -3.2 - rnd() * 2,
      s: 0.7 + rnd() * 0.8, sy: 4.5 + rnd() * 4.5, rot: rnd() * 6.28,
    });
  }
  // small rocks around the islets
  for (const isl of [ISLET1, ISLET2]) {
    for (let i = 0; i < 3; i++) {
      const a = rnd() * 6.28, r = 20 + rnd() * 12;
      const x = isl.x + Math.cos(a) * r, z = isl.z + Math.sin(a) * r;
      spots.push({ x, z, y: -1.5 - rnd() * 2, s: 0.6 + rnd() * 1.0, sy: 0.9 + rnd() * 1.4, rot: rnd() * 6.28 });
    }
  }
  const geo = makeRockGeometry();
  const mat = new THREE.MeshStandardMaterial({ roughness: 1, metalness: 0 });
  const inst = new THREE.InstancedMesh(geo, mat, spots.length);
  const m = new THREE.Matrix4();
  const col = new THREE.Color();
  const rockC = lin(ROCK);
  spots.forEach((s, i) => {
    m.makeRotationY(s.rot);
    m.scale(new THREE.Vector3(s.s, s.sy, s.s));
    m.setPosition(s.x, s.y, s.z);
    inst.setMatrixAt(i, m);
    const v = 0.86 + 0.28 * rnd();
    col.setRGB(rockC.r * v, rockC.g * v, rockC.b * v);
    inst.setColorAt(i, col);
  });
  inst.userData.isTerrain = true;
  scene.add(inst);
  return inst;
}

// ---- palms (merged into one draw call) -----------------------------------

class GeoBuilder {
  constructor() {
    this.pos = []; this.nor = []; this.col = []; this.idx = [];
  }
  add(geo, matrix, colorHex) {
    const p = geo.attributes.position;
    const n = geo.attributes.normal;
    const hasColor = !!geo.attributes.color;
    const base = this.pos.length / 3;
    const v = new THREE.Vector3();
    const nv = new THREE.Vector3();
    const cv = new THREE.Color();
    const cLinear = colorHex != null ? lin(colorHex) : null;
    for (let i = 0; i < p.count; i++) {
      v.fromBufferAttribute(p, i).applyMatrix4(matrix);
      nv.fromBufferAttribute(n, i).transformDirection(matrix);
      this.pos.push(v.x, v.y, v.z);
      this.nor.push(nv.x, nv.y, nv.z);
      if (cLinear) {
        this.col.push(cLinear.r, cLinear.g, cLinear.b);
      } else if (hasColor) {
        cv.fromBufferAttribute(geo.attributes.color, i);
        this.col.push(cv.r, cv.g, cv.b);
      } else {
        this.col.push(1, 1, 1);
      }
    }
    const idx = geo.index;
    for (let i = 0; i < idx.count; i++) this.idx.push(base + idx.getX(i));
  }
  build() {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(this.pos, 3));
    geo.setAttribute('normal', new THREE.Float32BufferAttribute(this.nor, 3));
    geo.setAttribute('color', new THREE.Float32BufferAttribute(this.col, 3));
    geo.setIndex(this.idx);
    return geo;
  }
}

const FROND_BASE = '#2e5330';
const FROND_TIP = '#6a9450';

function makeFrondGeometry() {
  // A tapered ribbon along +Y drooping toward +X, vertex-colored base->tip.
  const N = 8, L = 3.0, droop = 1.15;
  const pos = [], col = [], idx = [];
  const base = lin(FROND_BASE), tip = lin(FROND_TIP);
  const c = new THREE.Color();
  for (let i = 0; i <= N; i++) {
    const t = i / N;
    const y = t * L;
    const dx = Math.pow(t, 1.9) * droop;
    const w = 0.26 * (1 - t) + 0.03;
    pos.push(dx, y, w, dx, y, -w);
    c.lerpColors(base, tip, t * 0.85 + 0.15 * (i % 2));
    col.push(c.r, c.g, c.b, c.r, c.g, c.b);
  }
  for (let i = 0; i < N; i++) {
    const a = i * 2, b = a + 1, c = a + 2, d = a + 3;
    idx.push(a, c, b, b, c, d);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  geo.setIndex(idx);
  geo.computeVertexNormals();
  return geo;
}

function placePalms(hFn, count, seed, out, cx, cz) {
  const rnd = mulberry32(seed);
  const tries = count * 30;
  for (let k = 0; k < tries && out.length < count; k++) {
    const a = rnd() * Math.PI * 2;
    const r = Math.sqrt(rnd()) * 112;
    const x = cx + Math.cos(a) * r;
    const z = cz + Math.sin(a) * r;
    const h = hFn(x - cx, z - cz);
    if (h < 1.4 || h > 9) continue;
    out.push({ x, z, y: h, lean: 0.06 + rnd() * 0.14, dir: rnd() * 6.28, rot: rnd() * 6.28, s: 1.15 + rnd() * 0.45 });
  }
  return out;
}

function buildPalms(scene) {
  const spots = [];
  placePalms(mainIslandHeight, 30, 31, spots, 0, 0);
  placePalms((x, z) => islet1Height(x, z), 2, 32, spots, ISLET1.x, ISLET1.z);
  placePalms((x, z) => islet2Height(x, z), 1, 33, spots, ISLET2.x, ISLET2.z);

  const b = new GeoBuilder();
  const trunkGeo = new THREE.CylinderGeometry(0.085, 0.16, 1, 6);
  const frondGeo = makeFrondGeometry();
  const nutGeo = new THREE.SphereGeometry(0.13, 5, 4);
  const m = new THREE.Matrix4();
  const mx = new THREE.Matrix4();
  const v = new THREE.Vector3();
  const rnd = mulberry32(91);

  for (const s of spots) {
    // trunk: three stacked segments leaning one way
    const leanX = Math.cos(s.dir) * s.lean, leanZ = Math.sin(s.dir) * s.lean;
    const top = new THREE.Vector3(s.x + leanX * 4.5, s.y + 4.5, s.z + leanZ * 4.5);
    for (let k = 0; k < 3; k++) {
      m.identity();
      m.scale(v.set(s.s, s.s * 1.5, s.s));
      m.setPosition(s.x + leanX * (k + 0.5) * 1.5, s.y + (k + 0.5) * 1.5, s.z + leanZ * (k + 0.5) * 1.5);
      b.add(trunkGeo, m, '#8a6a4a');
    }
    // fronds
    const frondCount = 7;
    for (let i = 0; i < frondCount; i++) {
      const yaw = (i / frondCount) * Math.PI * 2 + s.rot + (rnd() - 0.5) * 0.3;
      m.makeRotationY(yaw);
      mx.makeRotationX(-0.42);
      m.multiply(mx);
      m.scale(v.set(s.s, s.s, s.s));
      m.setPosition(top.x, top.y, top.z);
      b.add(frondGeo, m, null);
    }
    // coconuts
    for (let i = 0; i < 2; i++) {
      m.identity();
      m.makeRotationY(s.rot + i * 2.4);
      m.scale(v.set(s.s, s.s, s.s));
      m.setPosition(top.x, top.y - 0.12, top.z);
      b.add(nutGeo, m, '#5a4632');
    }
  }
  const geo = b.build();
  const mat = new THREE.MeshStandardMaterial({
    vertexColors: true, roughness: 1, metalness: 0, side: THREE.DoubleSide,
  });
  const palms = new THREE.Mesh(geo, mat);
  palms.frustumCulled = false;
  scene.add(palms);
  return palms;
}

// ---- entry ---------------------------------------------------------------

export function buildIsland(scene) {
  const terrainGroup = new THREE.Group();
  terrainGroup.add(buildHeightfield(128, 300, 0, 0, mainIslandHeight, 13));
  terrainGroup.add(buildHeightfield(40, 64, ISLET1.x, ISLET1.z, islet1Height, 17));
  terrainGroup.add(buildHeightfield(36, 48, ISLET2.x, ISLET2.z, islet2Height, 19));
  terrainGroup.add(buildRocks(scene));
  scene.add(terrainGroup);
  buildPalms(scene);
  return terrainGroup;
}
