// Procedural fishing boat: lofted hull from cross-sections, deck, cabin with
// red roof and dark windows, mast, trailing red buoys and deck cargo.
// Local axes: +X forward, +Y up. Group origin sits at the waterline.
import * as THREE from '../vendor/three.module.js';
import { linVec } from './utils.js';

const HULL = '#e6e2d5';
const DECK = '#6b4a2f';
const CABIN = '#e0dccb';
const ROOF = '#a3211a';
const WINDOW = '#22303a';
const BUOY = '#b3302a';
const MAST = '#707070';
const CRATE = '#7a5c3e';

function buildHull() {
  // stations from stern (-X) to bow (+X): x, half width, gunwale height, keel height
  const st = [
    { x: -3.5, w: 0.66, gy: 0.80, ky: 0.38 },
    { x: -2.6, w: 0.95, gy: 0.74, ky: 0.24 },
    { x: -1.6, w: 1.10, gy: 0.72, ky: 0.13 },
    { x: -0.5, w: 1.13, gy: 0.72, ky: 0.07 },
    { x: 0.7, w: 1.05, gy: 0.73, ky: 0.10 },
    { x: 1.7, w: 0.82, gy: 0.76, ky: 0.19 },
    { x: 2.5, w: 0.52, gy: 0.82, ky: 0.31 },
    { x: 3.15, w: 0.20, gy: 0.92, ky: 0.50 },
  ];
  const pos = [], idx = [];
  const rows = st.map((s) => [
    [s.x, s.gy, -s.w], [s.x, s.gy, s.w],     // gunwale left/right
    [s.x, 0.30, -s.w * 0.62], [s.x, 0.30, s.w * 0.62], // chine
    [s.x, s.ky, 0],                          // keel
  ]);
  for (let r = 0; r < st.length - 1; r++) {
    const a = rows[r], b = rows[r + 1];
    for (let k = 0; k < 4; k++) {
      const i0 = a[k], i1 = a[k + 1], i2 = b[k], i3 = b[k + 1];
      const base = pos.length / 3;
      pos.push(...i0, ...i1, ...i2, ...i3);
      idx.push(base, base + 1, base + 2, base + 2, base + 1, base + 3);
    }
  }
  // bow tip fan
  {
    const last = rows[rows.length - 1];
    const tip = [3.45, 1.02, 0];
    const base = pos.length / 3;
    pos.push(...tip);
    for (let k = 0; k < 5; k++) {
      pos.push(...last[k]);
      const k2 = k === 4 ? 0 : k + 1;
      pos.push(...last[k2]);
      idx.push(base, base + 1 + k * 2, base + 2 + k * 2);
    }
  }
  // stern transom
  {
    const f = rows[0];
    const base = pos.length / 3;
    pos.push(...f[0], ...f[1], ...f[2], ...f[3], ...f[4]);
    idx.push(base, base + 2, base + 1, base + 1, base + 2, base + 3, base + 2, base + 4, base + 3);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  const colors = [];
  for (let i = 0; i < pos.length; i += 3) {
    const y = pos[i + 1];
    let c;
    if (y < 0.30) c = [0.42, 0.10, 0.07];
    else if (y < 0.37) c = [0.13, 0.11, 0.10];
    else c = [0.90, 0.89, 0.84];
    colors.push(...c);
  }
  geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  geo.setIndex(idx);
  geo.computeVertexNormals();
  return geo;
}

function ropeBetween(p0, p1, radius, mat) {
  const dir = new THREE.Vector3().subVectors(p1, p0);
  const len = dir.length();
  const rope = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, 1, 6), mat);
  const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize());
  rope.position.copy(p0).add(p1).multiplyScalar(0.5);
  rope.quaternion.copy(q);
  rope.scale.set(1, len, 1);
  return rope;
}

export function buildBoat(scene) {
  const group = new THREE.Group();
  const mat = (hex, extra = {}) =>
    new THREE.MeshStandardMaterial({ color: hex, roughness: 0.85, metalness: 0.05, ...extra });

  const hull = new THREE.Mesh(buildHull(), new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.85, metalness: 0.05 }));
  group.add(hull);

  const deck = new THREE.Mesh(new THREE.BoxGeometry(5.6, 0.08, 1.86), mat(DECK));
  deck.position.set(-0.25, 0.66, 0);
  group.add(deck);

  const cabin = new THREE.Mesh(new THREE.BoxGeometry(1.8, 1.0, 1.7), mat(CABIN));
  cabin.position.set(-1.25, 1.18, 0);
  group.add(cabin);

  const roof = new THREE.Mesh(new THREE.BoxGeometry(2.15, 0.16, 1.95), mat(ROOF, { roughness: 0.7 }));
  roof.position.set(-1.25, 1.76, 0);
  group.add(roof);

  const glass = mat(WINDOW, { roughness: 0.3, metalness: 0.4 });
  const winF = new THREE.Mesh(new THREE.PlaneGeometry(1.5, 0.66), glass);
  winF.rotation.y = Math.PI / 2;
  winF.position.set(-0.34, 1.2, 0);
  group.add(winF);
  for (const z of [-1, 1]) {
    const winS = new THREE.Mesh(new THREE.PlaneGeometry(1.3, 0.66), glass);
    winS.position.set(-1.25, 1.2, 0.86 * z);
    winS.rotation.y = z > 0 ? 0 : Math.PI;
    group.add(winS);
  }

  const mast = new THREE.Mesh(new THREE.CylinderGeometry(0.022, 0.022, 4.4, 6), mat(MAST, { metalness: 0.6 }));
  mast.position.set(1.25, 2.9, 0);
  group.add(mast);
  const light = new THREE.Mesh(
    new THREE.SphereGeometry(0.07, 8, 6),
    new THREE.MeshBasicMaterial({ color: '#fff6dc' })
  );
  light.position.set(1.25, 5.14, 0);
  group.add(light);

  // red buoys trailing on ropes at the stern
  const ropeMat = mat('#8d8d8d');
  for (const z of [-1, 1]) {
    const buoy = new THREE.Mesh(new THREE.SphereGeometry(0.17, 10, 8), mat(BUOY, { roughness: 0.6 }));
    buoy.position.set(-3.6, -0.02, 1.0 * z);
    buoy.userData.phase = z > 0 ? 0 : Math.PI;
    group.add(buoy);
    group.add(ropeBetween(
      new THREE.Vector3(-3.25, 0.55, 0.7 * z),
      new THREE.Vector3(-3.58, 0.03, 0.99 * z),
      0.012, ropeMat
    ));
  }

  // small deck cargo
  const crate1 = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.55, 0.55), mat(CRATE));
  crate1.position.set(0.95, 0.98, 0.35);
  crate1.rotation.y = 0.4;
  group.add(crate1);
  const crate2 = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.42, 0.5), mat('#8a6844'));
  crate2.position.set(1.62, 0.91, -0.42);
  crate2.rotation.y = -0.25;
  group.add(crate2);
  const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 0.5, 8), mat('#5d4632'));
  barrel.position.set(-0.05, 0.95, 0.5);
  group.add(barrel);

  group.userData.buoys = group.children.filter((c) => c.userData.phase !== undefined);
  scene.add(group);
  return group;
}
