// Original low-poly island and sailing ship. No scanned or licensed assets:
// every vertex is generated here.

import * as THREE from '../vendor/three.module.js';
import { cpuWaveHeight } from './ocean.js';

const smoothstep = (a, b, x) => {
  const t = THREE.MathUtils.clamp((x - a) / (b - a), 0, 1);
  return t * t * (3 - 2 * t);
};

function hash2(x, y) {
  const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453;
  return s - Math.floor(s);
}

function valueNoise2(x, y) {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const fx = x - xi;
  const fy = y - yi;
  const sx = fx * fx * (3 - 2 * fx);
  const sy = fy * fy * (3 - 2 * fy);
  const n00 = hash2(xi, yi);
  const n10 = hash2(xi + 1, yi);
  const n01 = hash2(xi, yi + 1);
  const n11 = hash2(xi + 1, yi + 1);
  const nx0 = n00 + (n10 - n00) * sx;
  const nx1 = n01 + (n11 - n01) * sx;
  return nx0 + (nx1 - nx0) * sy;
}

function fbm2(x, y, octaves = 4) {
  let sum = 0;
  let amp = 0.5;
  let norm = 0;
  let f = 1;
  for (let i = 0; i < octaves; i++) {
    sum += amp * valueNoise2(x * f, y * f);
    norm += amp;
    amp *= 0.5;
    f *= 2;
  }
  return sum / norm;
}

function islandHeight(x, z) {
  const r = Math.hypot(x, z);
  const dome = 3.2 * (1 - smoothstep(15, 34, r));
  const dunes = (fbm2(x * 0.075 + 4.2, z * 0.075 - 1.7, 4) - 0.42) * 3.0 *
    (1 - smoothstep(20, 35, r));
  const hill = 2.6 * Math.exp(-((x + 7.5) * (x + 7.5) + (z + 3.5) * (z + 3.5)) / 90);
  return dome + dunes + hill - 0.85 - 9.0 * smoothstep(30, 40, r);
}

function islandColor(height, slope, x, z) {
  const sand = new THREE.Color('#e2d0a6');
  const wetSand = new THREE.Color('#bba47b');
  const grass = new THREE.Color('#6d8446');
  const rock = new THREE.Color('#98705a');
  const out = new THREE.Color();

  if (height < 0.25) {
    out.copy(wetSand).lerp(sand, THREE.MathUtils.clamp((height + 0.8) / 1.05, 0, 1));
  } else {
    out.copy(sand).lerp(grass, smoothstep(1.35, 2.7, height) * 0.9);
    const patch = fbm2(x * 0.22, z * 0.22, 3);
    out.lerp(grass, smoothstep(0.40, 0.75, patch) * 0.4);
  }
  out.lerp(rock, smoothstep(1.15, 2.2, slope) * 0.8);
  const grain = 0.92 + fbm2(x * 0.7, z * 0.7, 2) * 0.16;
  out.multiplyScalar(grain);
  return out;
}

function createIsland() {
  const group = new THREE.Group();
  group.name = 'island';

  const size = 84;
  const segments = 76;
  const geometry = new THREE.PlaneGeometry(size, size, segments, segments);
  geometry.rotateX(-Math.PI / 2);
  const pos = geometry.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const heights = new Float32Array(pos.count);
  const color = new THREE.Color();

  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    const h = islandHeight(x, z);
    heights[i] = h;
    pos.setY(i, h);
  }

  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    const h = heights[i];
    const step = size / segments;
    const hx = islandHeight(x + step, z) - islandHeight(x - step, z);
    const hz = islandHeight(x, z + step) - islandHeight(x, z - step);
    const slope = Math.hypot(hx, hz) / (2 * step);
    color.copy(islandColor(h, slope, x, z));
    colors[i * 3] = color.r;
    colors[i * 3 + 1] = color.g;
    colors[i * 3 + 2] = color.b;
  }

  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geometry.computeVertexNormals();

  const material = new THREE.MeshStandardMaterial({
    vertexColors: true,
    roughness: 0.94,
    metalness: 0.0,
    flatShading: true
  });
  const terrain = new THREE.Mesh(geometry, material);
  terrain.receiveShadow = true;
  group.add(terrain);

  const rockMaterial = new THREE.MeshStandardMaterial({
    color: '#8a5a42',
    roughness: 0.9,
    metalness: 0.0,
    flatShading: true
  });
  const rockGeo = new THREE.DodecahedronGeometry(1, 0);
  const rocks = [
    [-22, 3.5, 2.2, 3.1, 1.8],
    [-18, -11, 1.6, 2.4, 1.4],
    [16, -14, 2.4, 3.8, 2.0],
    [24, 2, 1.5, 2.0, 1.2],
    [8, 18, 2.0, 2.8, 1.6],
    [-9, 19, 1.2, 1.8, 1.0],
    [20, 14, 1.8, 2.6, 1.4],
    [-25, -2, 1.1, 1.7, 0.9],
    [12, -6, 0.9, 1.5, 0.8]
  ];
  for (const [x, z, sx, sy, sz] of rocks) {
    const rock = new THREE.Mesh(rockGeo, rockMaterial);
    rock.position.set(x, Math.max(0.15, islandHeight(x, z)) - 0.35, z);
    rock.scale.set(sx, sy, sz);
    rock.rotation.set(hash2(x, z) * 1.2, hash2(z, x) * 6.28, hash2(x + 9, z) * 0.8);
    group.add(rock);
  }

  const trunkMaterial = new THREE.MeshStandardMaterial({
    color: '#6b4a2d',
    roughness: 0.95,
    flatShading: true
  });
  const leafMaterial = new THREE.MeshStandardMaterial({
    color: '#567538',
    roughness: 0.85,
    side: THREE.DoubleSide,
    flatShading: true
  });

  const palms = [
    [7.5, -3.5, 8.0, 0.3],
    [-6.5, 4.5, 6.6, -0.4],
    [2.0, 8.0, 5.8, 0.8],
    [10.0, 5.0, 5.2, -0.2]
  ];
  for (const [x, z, height, lean] of palms) {
    const palm = new THREE.Group();
    const base = Math.max(0.1, islandHeight(x, z));
    const trunkGeo = new THREE.CylinderGeometry(0.18, 0.34, height, 6, 6);
    const tp = trunkGeo.attributes.position;
    for (let i = 0; i < tp.count; i++) {
      const t = tp.getY(i) / height + 0.5;
      tp.setX(i, tp.getX(i) + lean * t * t * height * 0.12);
      tp.setZ(i, tp.getZ(i) + lean * t * t * height * 0.06);
    }
    trunkGeo.computeVertexNormals();
    const trunk = new THREE.Mesh(trunkGeo, trunkMaterial);
    trunk.position.y = height * 0.5;
    palm.add(trunk);

    for (let i = 0; i < 9; i++) {
      const frondGeo = new THREE.PlaneGeometry(1.15, 3.9, 1, 4);
      const fp = frondGeo.attributes.position;
      for (let j = 0; j < fp.count; j++) {
        const y = fp.getY(j);
        const t = y / 3.9 + 0.5;
        fp.setX(j, fp.getX(j) * (1 - t * 0.7));
        fp.setZ(j, Math.sin(t * Math.PI) * 0.35);
      }
      frondGeo.computeVertexNormals();
      const frond = new THREE.Mesh(frondGeo, leafMaterial);
      frond.position.set(lean * height * 0.12, height + 0.15, lean * height * 0.06);
      frond.rotation.order = 'YXZ';
      frond.rotation.y = (i / 7) * Math.PI * 2;
      frond.rotation.x = -Math.PI / 2 + 0.62 + (i % 3) * 0.10;
      frond.translateY(1.9);
      palm.add(frond);
    }
    palm.position.set(x, base, z);
    group.add(palm);
  }

  return group;
}

function buildHullGeometry() {
  const sections = 9;
  const ring = [];
  for (let i = 0; i < sections; i++) {
    const t = i / (sections - 1);
    const z = -7 + 14 * t;
    const w = 2.35 * Math.sin(Math.PI * (0.06 + 0.88 * t));
    ring.push([
      [0, -1.45, z],
      [-w * 0.72, -0.55, z],
      [-w, 0.9, z],
      [w, 0.9, z],
      [w * 0.72, -0.55, z]
    ]);
  }

  const vertices = [];
  const pushTri = (a, b, c) => vertices.push(...a, ...b, ...c);
  for (let i = 0; i < sections - 1; i++) {
    const A = ring[i];
    const B = ring[i + 1];
    for (let k = 0; k < 4; k++) {
      pushTri(A[k], B[k], B[k + 1]);
      pushTri(A[k], B[k + 1], A[k + 1]);
    }
  }
  // Stern cap.
  const stern = ring[sections - 1];
  for (let k = 1; k < 4; k++) pushTri(stern[0], stern[k], stern[k + 1]);
  // Bow cap.
  const bow = ring[0];
  for (let k = 1; k < 4; k++) pushTri(bow[0], bow[k + 1], bow[k]);

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  geometry.computeVertexNormals();
  return geometry;
}

function createSail(width, height, bulge = 0.55) {
  const geo = new THREE.PlaneGeometry(width, height, 7, 5);
  const p = geo.attributes.position;
  for (let i = 0; i < p.count; i++) {
    const u = p.getX(i) / width + 0.5;
    const v = p.getY(i) / height + 0.5;
    p.setZ(i, Math.sin(u * Math.PI) * Math.sin(v * Math.PI) * bulge);
  }
  geo.computeVertexNormals();
  return geo;
}

function createBoat() {
  const group = new THREE.Group();
  group.name = 'boat';

  const hullMaterial = new THREE.MeshStandardMaterial({
    color: '#5a3925',
    roughness: 0.82,
    metalness: 0.02,
    flatShading: true
  });
  const trimMaterial = new THREE.MeshStandardMaterial({
    color: '#25160f',
    roughness: 0.85,
    flatShading: true
  });
  const sailMaterial = new THREE.MeshStandardMaterial({
    color: '#f2e9d6',
    roughness: 0.88,
    side: THREE.DoubleSide,
    emissive: '#8a7a62',
    emissiveIntensity: 0.55
  });
  const mastMaterial = new THREE.MeshStandardMaterial({
    color: '#3a2618',
    roughness: 0.9
  });

  const hull = new THREE.Mesh(buildHullGeometry(), hullMaterial);
  group.add(hull);

  const deck = new THREE.Mesh(new THREE.BoxGeometry(3.1, 0.18, 9.6), hullMaterial);
  deck.position.set(0, 0.9, 0.2);
  group.add(deck);

  const castle = new THREE.Mesh(new THREE.BoxGeometry(2.9, 1.5, 2.4), trimMaterial);
  castle.position.set(0, 1.65, 4.4);
  group.add(castle);

  const bowsprit = new THREE.Mesh(new THREE.CylinderGeometry(0.10, 0.16, 5.0, 6), mastMaterial);
  bowsprit.rotation.x = Math.PI / 2 - 0.32;
  bowsprit.position.set(0, 1.25, -8.2);
  group.add(bowsprit);

  const mastSpecs = [
    { z: -2.6, height: 9.5, sailW: 5.4, sailH: 4.4, sailY: 5.9 },
    { z: 1.0, height: 12.0, sailW: 6.2, sailH: 5.2, sailY: 7.2 },
    { z: 4.2, height: 8.2, sailW: 3.8, sailH: 3.6, sailY: 5.2 }
  ];
  const sailGeo = new Map();
  for (const spec of mastSpecs) {
    const mast = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.20, spec.height, 6), mastMaterial);
    mast.position.set(0, 0.9 + spec.height * 0.5, spec.z);
    group.add(mast);

    const yard = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, spec.sailW + 1.2, 5), mastMaterial);
    yard.rotation.z = Math.PI / 2;
    yard.position.set(0, spec.sailY + spec.sailH * 0.5, spec.z);
    group.add(yard);

    const key = `${spec.sailW}x${spec.sailH}`;
    if (!sailGeo.has(key)) sailGeo.set(key, createSail(spec.sailW, spec.sailH));
    const sail = new THREE.Mesh(sailGeo.get(key), sailMaterial);
    sail.position.set(0, spec.sailY, spec.z + 0.05);
    group.add(sail);
  }

  const jibGeo = new THREE.BufferGeometry();
  jibGeo.setAttribute('position', new THREE.Float32BufferAttribute([
    0, 6.6, -3.0,
    0, 1.8, -8.8,
    0, 3.0, -4.4
  ], 3));
  jibGeo.computeVertexNormals();
  const jib = new THREE.Mesh(jibGeo, sailMaterial);
  group.add(jib);

  const rigPoints = [];
  const rig = (x1, y1, z1, x2, y2, z2) => rigPoints.push(x1, y1, z1, x2, y2, z2);
  rig(0, 12.85, 1.0, 0, 1.6, -10.4);
  rig(0, 12.85, 1.0, 0, 10.35, -2.6);
  rig(0, 10.35, -2.6, 0, 1.6, -10.4);
  rig(0, 12.85, 1.0, 0, 9.05, 4.2);
  rig(0, 12.85, 1.0, 0, 1.8, 6.8);
  rig(0, 1.8, 6.8, 0, 9.05, 4.2);
  const rigGeo = new THREE.BufferGeometry();
  rigGeo.setAttribute('position', new THREE.Float32BufferAttribute(rigPoints, 3));
  group.add(new THREE.LineSegments(rigGeo, new THREE.LineBasicMaterial({ color: 0x1c1510 })));

  const flag = new THREE.Mesh(
    new THREE.PlaneGeometry(1.6, 0.7, 4, 1),
    new THREE.MeshStandardMaterial({ color: '#8f2a2a', side: THREE.DoubleSide, roughness: 0.9 })
  );
  flag.position.set(0, 13.05, 1.0);
  group.add(flag);

  const lantern = new THREE.Mesh(
    new THREE.SphereGeometry(0.18, 8, 6),
    new THREE.MeshStandardMaterial({ color: '#ffd9a0', emissive: '#ff9b45', emissiveIntensity: 2.4 })
  );
  lantern.position.set(0, 2.6, 5.2);
  group.add(lantern);
  const lanternLight = new THREE.PointLight('#ffb066', 18, 24, 2);
  lanternLight.position.copy(lantern.position);
  group.add(lanternLight);

  group.userData.lanternLight = lanternLight;
  group.position.set(26, 0, 42);
  group.rotation.y = -0.6;
  group.scale.setScalar(1.15);
  return group;
}

export function createProps() {
  const group = new THREE.Group();
  const island = createIsland();
  const boat = createBoat();
  group.add(island, boat);

  const boatBase = boat.position.clone();
  const boatRotationY = boat.rotation.y;

  function update(time) {
    const h = cpuWaveHeight(boatBase.x, boatBase.z, time);
    const eps = 1.5;
    const hx = cpuWaveHeight(boatBase.x + eps, boatBase.z, time) -
      cpuWaveHeight(boatBase.x - eps, boatBase.z, time);
    const hz = cpuWaveHeight(boatBase.x, boatBase.z + eps, time) -
      cpuWaveHeight(boatBase.x, boatBase.z - eps, time);
    boat.position.y = h * 0.72 - 0.25;
    boat.rotation.z = THREE.MathUtils.clamp(-hx * 0.055, -0.09, 0.09);
    boat.rotation.x = THREE.MathUtils.clamp(hz * 0.045, -0.07, 0.07);
    boat.rotation.y = boatRotationY + Math.sin(time * 0.16) * 0.025;
  }

  return { group, island, boat, update };
}
