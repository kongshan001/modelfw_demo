// The cyclist: a stylized low-poly rider in an orange jacket on a dark bike,
// leaning forward, legs pedalling with a simple two-bone IK, wheels spinning,
// a gentle bob, and a soft contact shadow on the cloud sea.

import * as THREE from '../vendor/three.module.js';
import { PALETTE } from './palette.js';

const UP = new THREE.Vector3(0, 1, 0);

function mat(hex) {
  return new THREE.MeshLambertMaterial({ color: hex, flatShading: true });
}

export function createRider(scene) {
  const M = {
    jacket: mat(PALETTE.jacket),
    trousers: mat(PALETTE.trousers),
    helmet: mat(PALETTE.helmet),
    bike: mat(PALETTE.bike),
    skin: mat(PALETTE.skin),
    bag: mat(PALETTE.backpack),
  };

  const group = new THREE.Group();
  group.position.set(0, 0.12, 0);
  scene.add(group);

  const bike = new THREE.Group();
  const rider = new THREE.Group();
  group.add(bike, rider);

  // --- helpers ---------------------------------------------------------
  function capsuleMesh(a, b, r, material) {
    const len = a.distanceTo(b);
    const geo = new THREE.CapsuleGeometry(r, Math.max(len - 2 * r, 0.001), 2, 10);
    const m = new THREE.Mesh(geo, material);
    const dir = new THREE.Vector3().subVectors(b, a);
    m.position.copy(a).addScaledVector(dir, 0.5);
    m.quaternion.setFromUnitVectors(UP, dir.normalize());
    m.userData.maxLen = len;
    return m;
  }
  function tubeMesh(a, b, r, material) {
    const len = a.distanceTo(b);
    const geo = new THREE.CylinderGeometry(r, r, len, 10);
    const m = new THREE.Mesh(geo, material);
    const dir = new THREE.Vector3().subVectors(b, a);
    m.position.copy(a).addScaledVector(dir, 0.5);
    m.quaternion.setFromUnitVectors(UP, dir.normalize());
    return m;
  }
  function sphereMesh(p, r, material, sy = 1) {
    const m = new THREE.Mesh(new THREE.SphereGeometry(r, 18, 14), material);
    m.position.copy(p);
    m.scale.set(1, sy, 1);
    return m;
  }
  function boxMesh(p, w, h, d, material, rz = 0) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
    m.position.copy(p);
    m.rotation.z = rz;
    return m;
  }
  // Repositions and reorients an existing limb mesh between two points.
  function placeLimb(m, a, b) {
    const dir = new THREE.Vector3().subVectors(b, a);
    const len = dir.length();
    m.position.copy(a).addScaledVector(dir, 0.5);
    m.quaternion.setFromUnitVectors(UP, dir.normalize());
    m.scale.set(1, len / m.userData.maxLen, 1);
  }

  // --- wheels -----------------------------------------------------------
  function makeWheel() {
    const w = new THREE.Group();
    w.add(new THREE.Mesh(new THREE.TorusGeometry(0.62, 0.05, 8, 26), M.bike));
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * Math.PI * 2;
      const s = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 1.02, 6), M.bike);
      s.position.set(Math.cos(a) * 0.5, Math.sin(a) * 0.5, 0);
      s.rotation.z = a + Math.PI / 2;
      w.add(s);
    }
    const hub = new THREE.Mesh(new THREE.CylinderGeometry(0.055, 0.055, 0.13, 8), M.bike);
    hub.rotation.x = Math.PI / 2;
    w.add(hub);
    return w;
  }
  const rearWheel = makeWheel();
  rearWheel.position.set(-0.8, 0.62, 0);
  const frontWheel = makeWheel();
  frontWheel.position.set(0.9, 0.62, 0);
  bike.add(rearWheel, frontWheel);

  // --- frame -------------------------------------------------------------
  const REAR = new THREE.Vector3(-0.8, 0.62, 0);
  const FRONT = new THREE.Vector3(0.9, 0.62, 0);
  const CRANK = new THREE.Vector3(0, 1.10, 0);
  const SEAT = new THREE.Vector3(-0.18, 2.02, 0);
  bike.add(tubeMesh(CRANK, new THREE.Vector3(0.90, 1.32, 0), 0.035, M.bike));   // down tube
  bike.add(tubeMesh(CRANK, SEAT, 0.035, M.bike));                               // seat tube
  bike.add(tubeMesh(SEAT, REAR, 0.03, M.bike));                                 // seat stay
  bike.add(tubeMesh(CRANK, REAR, 0.03, M.bike));                                // chain stay
  bike.add(tubeMesh(new THREE.Vector3(0.90, 1.32, 0), FRONT, 0.035, M.bike));   // fork
  bike.add(tubeMesh(SEAT, new THREE.Vector3(0.95, 1.92, 0), 0.04, M.bike));     // top tube
  bike.add(tubeMesh(new THREE.Vector3(0.87, 1.30, 0), new THREE.Vector3(0.98, 1.98, 0), 0.045, M.bike)); // head tube
  bike.add(tubeMesh(new THREE.Vector3(0.95, 1.92, 0), new THREE.Vector3(1.10, 2.00, 0), 0.028, M.bike)); // stem
  bike.add(boxMesh(new THREE.Vector3(-0.18, 2.06, 0), 0.17, 0.05, 0.26, M.bike)); // seat
  const grip = new THREE.Mesh(new THREE.CylinderGeometry(0.024, 0.024, 0.30, 8), M.bike);
  grip.rotation.x = Math.PI / 2;
  grip.position.set(1.11, 2.02, 0);
  bike.add(grip);

  // --- crank and pedals ----------------------------------------------------
  const crank = new THREE.Group();
  crank.position.copy(CRANK);
  bike.add(crank);
  const chainring = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.035, 14), M.bike);
  chainring.rotation.x = Math.PI / 2;
  crank.add(chainring);
  const armR = tubeMesh(new THREE.Vector3(0, 0, 0.05), new THREE.Vector3(0.26, 0, 0.05), 0.02, M.bike);
  const armL = tubeMesh(new THREE.Vector3(0, 0, -0.05), new THREE.Vector3(0.26, 0, -0.05), 0.02, M.bike);
  crank.add(armR, armL);
  const pedalR = boxMesh(new THREE.Vector3(0.26, 0, 0.05), 0.10, 0.03, 0.13, M.bike);
  const pedalL = boxMesh(new THREE.Vector3(0.26, 0, -0.05), 0.10, 0.03, 0.13, M.bike);
  crank.add(pedalR, pedalL);

  // --- rider body ------------------------------------------------------------
  const HIPS = new THREE.Vector3(-0.02, 2.02, 0);
  const SHOULDERS = new THREE.Vector3(0.55, 2.68, 0);
  rider.add(sphereMesh(HIPS, 0.19, M.trousers));                       // pelvis
  rider.add(capsuleMesh(HIPS, SHOULDERS, 0.205, M.jacket));            // torso
  rider.add(sphereMesh(SHOULDERS, 0.16, M.jacket));                    // shoulders
  rider.add(tubeMesh(SHOULDERS, new THREE.Vector3(0.64, 2.82, 0), 0.07, M.skin));  // neck
  rider.add(sphereMesh(new THREE.Vector3(0.76, 2.97, 0), 0.15, M.skin));          // head
  rider.add(sphereMesh(new THREE.Vector3(0.77, 3.03, 0), 0.20, M.helmet, 0.84));  // helmet
  rider.add(boxMesh(new THREE.Vector3(0.22, 2.60, -0.02), 0.30, 0.40, 0.22, M.bag, -0.70)); // backpack

  const SHOULDER_R = new THREE.Vector3(0.55, 2.68, 0.16);
  const SHOULDER_L = new THREE.Vector3(0.55, 2.68, -0.16);
  const ELBOW_R = new THREE.Vector3(0.84, 2.26, 0.13);
  const ELBOW_L = new THREE.Vector3(0.84, 2.26, -0.13);
  const HAND_R = new THREE.Vector3(1.08, 2.00, 0.10);
  const HAND_L = new THREE.Vector3(1.08, 2.00, -0.10);
  rider.add(capsuleMesh(SHOULDER_R, ELBOW_R, 0.065, M.jacket));
  rider.add(capsuleMesh(ELBOW_R, HAND_R, 0.052, M.skin));
  rider.add(capsuleMesh(SHOULDER_L, ELBOW_L, 0.065, M.jacket));
  rider.add(capsuleMesh(ELBOW_L, HAND_L, 0.052, M.skin));
  rider.add(sphereMesh(HAND_R, 0.055, M.skin));
  rider.add(sphereMesh(HAND_L, 0.055, M.skin));

  // --- legs (animated each frame with two-bone IK) ----------------------------
  const HIP_R = new THREE.Vector3(-0.05, 2.02, 0.10);
  const HIP_L = new THREE.Vector3(-0.05, 2.02, -0.10);
  const thighR = capsuleMesh(HIP_R, new THREE.Vector3(0.2, 1.6, 0.10), 0.085, M.trousers);
  const shinR = capsuleMesh(new THREE.Vector3(0.2, 1.6, 0.10), new THREE.Vector3(0.26, 1.10, 0.05), 0.072, M.trousers);
  const thighL = capsuleMesh(HIP_L, new THREE.Vector3(0.2, 1.6, -0.10), 0.085, M.trousers);
  const shinL = capsuleMesh(new THREE.Vector3(0.2, 1.6, -0.10), new THREE.Vector3(0.26, 1.10, -0.05), 0.072, M.trousers);
  const footR = boxMesh(new THREE.Vector3(0.26, 1.10, 0.05), 0.12, 0.05, 0.16, M.bike);
  const footL = boxMesh(new THREE.Vector3(0.26, 1.10, -0.05), 0.12, 0.05, 0.16, M.bike);
  rider.add(thighR, shinR, thighL, shinL, footR, footL);

  // --- contact shadow on the cloud sea ----------------------------------------
  const shadow = new THREE.Mesh(
    new THREE.CircleGeometry(1.0, 22),
    new THREE.MeshBasicMaterial({ color: 0x0a1626, transparent: true, opacity: 0.30, depthWrite: false })
  );
  shadow.rotation.x = -Math.PI / 2;
  shadow.position.set(0.3, 0.06, 0);
  shadow.scale.set(2.5, 1.35, 1);
  shadow.renderOrder = 15;
  scene.add(shadow);

  // --- animation ---------------------------------------------------------------
  const UPPER = 0.62;
  const LOWER = 0.62;

  function legKnee(hip, foot, side) {
    const d = new THREE.Vector3().subVectors(foot, hip);
    const dist = Math.min(Math.max(d.length(), 0.05), UPPER + LOWER - 0.02);
    const a = Math.acos(Math.min(Math.max((UPPER * UPPER + dist * dist - LOWER * LOWER) / (2 * UPPER * dist), -1), 1));
    const dir = d.normalize();
    const bend = new THREE.Vector3(1, 0, 0.35 * side);
    bend.addScaledVector(dir, -bend.dot(dir)).normalize();
    return hip.clone().addScaledVector(dir, UPPER * Math.cos(a)).addScaledVector(bend, UPPER * Math.sin(a));
  }

  const state = { crank: 0, wheel: 0 };
  const wheelSpeed = 6.0;      // riding speed, units/s
  const cadence = 6.4;         // pedalling, rad/s

  function update(t, dt) {
    state.crank += cadence * dt;
    state.wheel -= (wheelSpeed / 0.62) * dt;
    rearWheel.rotation.z = state.wheel;
    frontWheel.rotation.z = state.wheel;

    const ca = state.crank;
    const px = 0.26 * Math.cos(ca);
    const py = 0.26 * Math.sin(ca);
    chainring.rotation.z = ca;
    placeLimb(armR, new THREE.Vector3(0, 0, 0.05), new THREE.Vector3(px, py, 0.05));
    placeLimb(armL, new THREE.Vector3(0, 0, -0.05), new THREE.Vector3(-px, -py, -0.05));
    pedalR.position.set(px, py, 0.05);
    pedalL.position.set(-px, -py, -0.05);

    const footPosR = new THREE.Vector3(px, 1.10 + py, 0.05);
    const kneeR = legKnee(HIP_R, footPosR, 1);
    placeLimb(thighR, HIP_R, kneeR);
    placeLimb(shinR, kneeR, footPosR);
    footR.position.copy(footPosR);

    const footPosL = new THREE.Vector3(-px, 1.10 - py, -0.05);
    const kneeL = legKnee(HIP_L, footPosL, -1);
    placeLimb(thighL, HIP_L, kneeL);
    placeLimb(shinL, kneeL, footPosL);
    footL.position.copy(footPosL);

    // Gentle bob, twice per pedal cycle.
    group.position.y = 0.12 + 0.035 * Math.sin(t * 12.9);
    rider.rotation.z = 0.012 * Math.sin(t * 6.45);
  }

  return { group, update };
}
