// The cloud field: big cumulus masses on the right of the sky, smaller ones on
// the left, wide banks sitting on the horizon line, scattered puffs around the
// rider (some close to the camera) and a small churned wake behind the bike.
// Everything is procedural: displaced low-poly blobs with vertex colours.

import * as THREE from '../vendor/three.module.js';
import { PALETTE } from './palette.js';

function hash3(x, y, z) {
  const s = Math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453;
  return s - Math.floor(s);
}

// One soft low-poly blob (unit radius), displaced and squashed.
function blobGeometry(seed, squash) {
  const geo = new THREE.IcosahedronGeometry(1, 1).toNonIndexed();
  const pos = geo.attributes.position;
  const v = new THREE.Vector3();
  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i);
    const d = 0.52 + 0.55 * hash3(v.x + seed, v.y + seed * 1.7, v.z + seed * 2.3);
    v.multiplyScalar(d);
    v.y *= squash;
    pos.setXYZ(i, v.x, v.y, v.z);
  }
  geo.computeVertexNormals();
  return geo;
}

// A cumulus cloud: several blobs merged into one geometry with vertex colours
// running from white on top to blue-grey underneath.
function cloudGeometry(blobs, seed, squash) {
  const positions = [];
  const normals = [];
  const colors = [];
  let minY = Infinity;
  let maxY = -Infinity;
  const top = new THREE.Color(PALETTE.cloudTop);
  const under = new THREE.Color(PALETTE.cloudUnder);
  for (const b of blobs) {
    const g = blobGeometry(seed + b[0] * 13.7 + b[1] * 7.1, squash);
    const p = g.attributes.position;
    const n = g.attributes.normal;
    for (let i = 0; i < p.count; i++) {
      const x = p.getX(i) * b[3] + b[0];
      const y = p.getY(i) * b[3] + b[1];
      const z = p.getZ(i) * b[3] + b[2];
      positions.push(x, y, z);
      normals.push(n.getX(i), n.getY(i), n.getZ(i));
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    g.dispose();
  }
  const spread = Math.max(maxY - minY, 0.001);
  const col = new THREE.Color();
  for (let i = 0; i < positions.length / 3; i++) {
    const x = positions[i * 3];
    const y = positions[i * 3 + 1];
    const z = positions[i * 3 + 2];
    const t = Math.min(Math.max((y - minY) / spread, 0), 1);
    col.copy(under).lerp(top, t);
    col.multiplyScalar(0.93 + 0.14 * hash3(x * 0.7 + seed, y + seed, z * 0.7));
    colors.push(col.r, col.g, col.b);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  return geo;
}

// A row of rounded lobes, largest in the middle.
function cumulus(count, seed) {
  const blobs = [];
  for (let i = 0; i < count; i++) {
    const fx = (i / Math.max(count - 1, 1)) * 2.0;
    const x = fx + (hash3(i, seed, 1) - 0.5) * 0.5;
    const y = Math.sin(fx * 1.1) * 0.55 + (hash3(i, seed, 2) - 0.5) * 0.25;
    const z = (hash3(i, seed, 3) - 0.5) * 0.8;
    const r = 0.62 + 0.42 * hash3(i, seed, 4);
    blobs.push([x, y, z, r]);
  }
  return blobs;
}

export function createClouds(scene) {
  const group = new THREE.Group();
  scene.add(group);

  const material = new THREE.MeshLambertMaterial({ vertexColors: true });
  const drifts = []; // { mesh, speed, minX, maxX }

  function addCloud(x, y, z, scale, blobs, speed, seed, squash = 0.62) {
    const mesh = new THREE.Mesh(cloudGeometry(blobs, seed, squash), material);
    mesh.position.set(x, y, z);
    mesh.scale.setScalar(scale);
    group.add(mesh);
    drifts.push({ mesh, speed, minX: -170, maxX: 170 });
    return mesh;
  }

  // Big cumulus masses across the right side of the sky.
  const right = [
    [30, 34, -150, 24], [55, 52, -120, 20], [80, 44, -140, 26],
    [105, 62, -95, 18], [125, 50, -130, 22], [150, 38, -110, 16],
  ];
  right.forEach((c, i) => addCloud(c[0], c[1], c[2], c[3], cumulus(5, 100 + i), 0.35 + 0.1 * i, 100 + i));

  // Smaller clouds on the left.
  const left = [[-85, 48, -130, 13], [-55, 60, -110, 11], [-30, 44, -145, 15]];
  left.forEach((c, i) => addCloud(c[0], c[1], c[2], c[3], cumulus(4, 200 + i), 0.4 + 0.08 * i, 200 + i));

  // Wide flattened banks straddling the horizon line.
  const banks = [[-70, 1.2, -115, 16], [-20, 2.4, -85, 20], [35, 1.6, -100, 15], [90, 2.8, -70, 22], [140, 2.0, -95, 18]];
  banks.forEach((c, i) => addCloud(c[0], c[1], c[2], c[3], cumulus(5, 300 + i), 0.5 + 0.08 * i, 300 + i, 0.42));

  // Scattered puffs around the rider; a few close to the camera for depth.
  const PUFFS = 30;
  const puffs = new THREE.InstancedMesh(
    cloudGeometry([[0, 0, 0, 1]], 900, 0.6),
    new THREE.MeshLambertMaterial({ vertexColors: true }),
    PUFFS
  );
  const puffData = [];
  const m4 = new THREE.Matrix4();
  const q4 = new THREE.Quaternion();
  const e3 = new THREE.Euler();
  const s3 = new THREE.Vector3();
  const p3 = new THREE.Vector3();
  const white = new THREE.Color(0xf4f8ff);
  const pale = new THREE.Color(0xdfe8f5);
  const tint = new THREE.Color();
  for (let i = 0; i < PUFFS; i++) {
    const near = i < 8;
    const x = near
      ? (i % 2 ? -1 : 1) * (8 + 14 * hash3(i, 7, 1))
      : -38 + 76 * hash3(i, 7, 2);
    const y = 2.5 + 11.5 * hash3(i, 7, 3) * (near ? 0.8 : 1);
    const z = near ? 9 + 6 * hash3(i, 7, 4) : -38 + 46 * hash3(i, 7, 5);
    const scale = near ? 2.5 + 3 * hash3(i, 7, 6) : 2 + 3.5 * hash3(i, 7, 7);
    puffData.push({
      x, y, z, scale,
      speed: near ? 1.5 + 0.8 * hash3(i, 7, 8) : 0.9 + 0.7 * hash3(i, 7, 9),
      phase: hash3(i, 7, 10) * Math.PI * 2,
      ry: hash3(i, 7, 11) * Math.PI * 2,
    });
    tint.lerpColors(pale, white, hash3(i, 7, 12));
    puffs.setColorAt(i, tint);
  }
  puffs.instanceColor.needsUpdate = true;
  group.add(puffs);

  // A soft churned wake trailing the rear wheel.
  const wakeMat = new THREE.MeshLambertMaterial({ color: 0xffffff, transparent: true, opacity: 0.5 });
  const wakes = [];
  for (let i = 0; i < 4; i++) {
    const w = new THREE.Mesh(blobGeometry(400 + i, 0.55), wakeMat);
    w.scale.setScalar(0.26 + 0.1 * i);
    w.renderOrder = 18;
    wakes.push(w);
    group.add(w);
  }

  function update(dt, t) {
    for (const d of drifts) {
      d.mesh.position.x -= d.speed * dt;
      if (d.mesh.position.x < d.minX) d.mesh.position.x += d.maxX - d.minX;
    }
    for (let i = 0; i < PUFFS; i++) {
      const p = puffData[i];
      p.x -= p.speed * dt;
      if (p.x < -60) p.x += 120;
      p3.set(p.x, p.y + Math.sin(t * 0.6 + p.phase) * 0.3, p.z);
      e3.set(0, p.ry, 0);
      q4.setFromEuler(e3);
      s3.setScalar(p.scale);
      m4.compose(p3, q4, s3);
      puffs.setMatrixAt(i, m4);
    }
    puffs.instanceMatrix.needsUpdate = true;
    for (let i = 0; i < wakes.length; i++) {
      const w = wakes[i];
      w.position.set(
        -2.0 - i * 0.62,
        0.24 + 0.07 * Math.sin(t * 2.2 + i * 1.7),
        (i % 2 ? 1 : -1) * (0.22 + 0.08 * Math.sin(t * 1.3 + i))
      );
      w.scale.setScalar((0.26 + 0.12 * i) * (1 + 0.12 * Math.sin(t * 2.2 + i * 2.1)));
    }
  }

  return { group, update };
}
