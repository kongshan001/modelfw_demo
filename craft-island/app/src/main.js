// Tropical Isle — clean-room Three.js demo.
// Island + islets + rocks + palms, GPU water simulation with boat wake,
// procedural fishing boat, sky with drifting clouds, chase camera and
// WASD / drag / wheel controls with idle autopilot.
import * as THREE from '../vendor/three.module.js';
import { buildIsland } from './island.js';
import { Ocean, waterHeightAt, waterGradientAt } from './water.js';
import { buildSky } from './sky.js';
import { buildBoat } from './boat.js';
import { clamp } from './utils.js';

const canvas = document.getElementById('scene');
const shotMode = new URLSearchParams(location.search).has('shot');

function fatal(title, text) {
  const el = document.getElementById('fatal');
  document.getElementById('fatal-title').textContent = title;
  document.getElementById('fatal-text').textContent = text;
  el.style.display = 'flex';
  canvas.style.display = 'none';
}

let renderer;
try {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
} catch (err) {
  fatal('WebGL is not available', 'This demo needs a browser with WebGL enabled and hardware acceleration turned on.');
  throw err;
}
const gl = renderer.getContext();
if (!renderer.capabilities.isWebGL2) {
  fatal('WebGL 2 is required', 'This demo needs a browser with WebGL 2 support. Please update your browser or enable hardware acceleration.');
  throw new Error('WebGL2 unavailable');
}
const simOK = !!gl.getExtension('EXT_color_buffer_float') && !new URLSearchParams(location.search).has('nosim');
if (!simOK) {
  document.getElementById('badge').style.display = 'block';
}

renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.12;

const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0xc8d8e2, 0.0012);

// lighting: soft sky ambient + a warm sun key light
const SUN_DIR = [0.408, 0.259, 0.875];
scene.add(new THREE.HemisphereLight(0xcfe3ee, 0x2a4a4a, 0.9));
const sunLight = new THREE.DirectionalLight(0xfff2d4, 2.2);
sunLight.position.set(SUN_DIR[0] * 400, SUN_DIR[1] * 400, SUN_DIR[2] * 400);
scene.add(sunLight);

const camera = new THREE.PerspectiveCamera(55, window.innerWidth / window.innerHeight, 0.3, 6000);
camera.position.set(-50, 6, -267);

// ---- world ----------------------------------------------------------------

const terrainGroup = buildIsland(scene);
const ocean = new Ocean(renderer, scene, terrainGroup, { sim: simOK });
const sky = buildSky(scene);
const boatGroup = buildBoat(scene);

// ---- boat state -----------------------------------------------------------

const boat = {
  x: -42, z: -246, heading: Math.atan2(246, 42), speed: 0,
  target: 4.4, vx: 0, vz: 0, throttle: 0, rudder: 0, manual: false,
};

const ORBIT_R = 250;

function steerToward(desired, rate, dt) {
  let d = desired - boat.heading;
  d = Math.atan2(Math.sin(d), Math.cos(d));
  boat.heading += clamp(d, -rate * dt, rate * dt);
}

let autoT = 0;
function autopilot(dt) {
  autoT += dt;
  const phi = Math.atan2(boat.z, boat.x);
  const lookahead = 0.12;
  const wpX = Math.cos(phi + lookahead) * ORBIT_R;
  const wpZ = Math.sin(phi + lookahead) * ORBIT_R;
  // ease onto the orbit: first cruise toward the island, then arc around it
  const k = Math.min(1, autoT / 22);
  const islandDirX = -boat.x, islandDirZ = -boat.z;
  const il = Math.hypot(islandDirX, islandDirZ) || 1;
  const dx = islandDirX / il * (1 - k) + (wpX - boat.x) * k / (Math.hypot(wpX - boat.x, wpZ - boat.z) || 1);
  const dz = islandDirZ / il * (1 - k) + (wpZ - boat.z) * k / (Math.hypot(wpX - boat.x, wpZ - boat.z) || 1);
  const desired = Math.atan2(dz, dx);
  steerToward(desired, 0.34, dt);
  boat.target = 4.4;
}

// ---- controls -------------------------------------------------------------

const keys = new Set();
let lastKeyTime = -10;
window.addEventListener('keydown', (e) => {
  keys.add(e.code);
  lastKeyTime = clock.elapsedTime;
});
window.addEventListener('keyup', (e) => keys.delete(e.code));

let userYaw = 0.18, userEl = 0.24, dist = 24;
let dragging = false, lastX = 0, lastY = 0;
canvas.addEventListener('pointerdown', (e) => {
  dragging = true; lastX = e.clientX; lastY = e.clientY;
  canvas.setPointerCapture(e.pointerId);
});
canvas.addEventListener('pointermove', (e) => {
  if (!dragging) return;
  userYaw -= (e.clientX - lastX) * 0.0052;
  userEl = clamp(userEl + (e.clientY - lastY) * 0.0045, 0.04, 0.9);
  lastX = e.clientX; lastY = e.clientY;
});
canvas.addEventListener('pointerup', () => { dragging = false; });
canvas.addEventListener('wheel', (e) => {
  dist = clamp(dist * (1 + e.deltaY * 0.001), 10, 55);
  e.preventDefault();
}, { passive: false });

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

// ---- HUD -------------------------------------------------------------------

if (shotMode) {
  document.getElementById('hud').style.display = 'none';
  document.getElementById('badge').style.display = 'none';
} else {
  setTimeout(() => document.getElementById('hud').classList.add('faded'), 9000);
}

// ---- main loop -------------------------------------------------------------

const clock = new THREE.Clock();
let fpsAcc = 0, fpsN = 0;
window.__fps = 0;

function tick() {
  requestAnimationFrame(tick);
  // cap only guards against multi-second stalls (tab switches, software GL);
  // at normal frame rates dt stays well below it
  const rawDt = Math.min(clock.getDelta(), 0.25);
  const elapsed = clock.elapsedTime;
  // screenshot mode freezes the simulation at a fixed time so captures are
  // deterministic even when frames render very slowly (software GL)
  const FREEZE_AT = 4.5;
  const freeze = shotMode && elapsed >= FREEZE_AT;
  const dt = freeze ? 0 : rawDt;
  const t = Math.min(elapsed, FREEZE_AT);

  // boat input (manual while keys are held or recently used; autopilot otherwise)
  boat.manual = t - lastKeyTime < 6;
  if (keys.has('KeyW') || keys.has('ArrowUp')) boat.target = 6.2;
  else if (keys.has('KeyS') || keys.has('ArrowDown')) boat.target = -1.0;
  else if (boat.manual) boat.target = 0;
  let rudder = 0;
  if (keys.has('KeyA') || keys.has('ArrowLeft')) rudder += 1;
  if (keys.has('KeyD') || keys.has('ArrowRight')) rudder -= 1;
  if (!boat.manual) autopilot(dt);
  else {
    const rate = 0.5 * clamp(0.25 + boat.speed * 0.09, 0.2, 1);
    boat.heading += rudder * rate * dt;
  }
  boat.speed += (boat.target - boat.speed) * Math.min(1, dt * 0.9);
  const fx = Math.cos(boat.heading), fz = Math.sin(boat.heading);
  boat.x += fx * boat.speed * dt;
  boat.z += fz * boat.speed * dt;
  boat.vx = fx * boat.speed;
  boat.vz = fz * boat.speed;
  // keep the boat within the visible world
  const r = Math.hypot(boat.x, boat.z);
  if (r > 560) {
    boat.heading = Math.atan2(-boat.z, -boat.x);
    boat.target = 4.4;
  }

  // bob + tilt from the water surface
  const hy = waterHeightAt(boat.x, boat.z, t);
  const [gx, gz] = waterGradientAt(boat.x, boat.z, t);
  boatGroup.position.set(boat.x, hy, boat.z);
  boatGroup.rotation.y = -boat.heading;
  boatGroup.rotation.z = clamp(gx * fx + gz * fz, -0.3, 0.3) * 0.7;
  boatGroup.rotation.x = clamp(gx * fz - gz * fx, -0.3, 0.3) * 0.7;
  for (const b of boatGroup.userData.buoys) {
    b.position.y = -0.02 + Math.sin(t * 2.1 + b.userData.phase) * 0.05;
  }

  // chase camera: sits behind the boat, orbited by userYaw; the look point
  // rotates with the same yaw so the boat stays centered in the view
  const el = userEl;
  const dir = boat.heading + Math.PI - userYaw;
  const camT = new THREE.Vector3(
    boat.x + Math.cos(el) * Math.cos(dir) * dist,
    hy + Math.sin(el) * dist + 1.1,
    boat.z + Math.cos(el) * Math.sin(dir) * dist
  );
  const k = freeze ? 1 : 1 - Math.exp(-3.2 * dt);
  camera.position.lerp(camT, k);
  // the look point rotates with the yaw so the boat stays centered while
  // the camera orbits around it
  const cy = Math.cos(userYaw), sy = Math.sin(userYaw);
  const look = new THREE.Vector3(
    boat.x + (fx * cy + fz * sy) * 9,
    hy + 3.6,
    boat.z + (-fx * sy + fz * cy) * 9
  );
  camera.lookAt(look);
  const fwdAfterLookAt = new THREE.Vector3();
  camera.getWorldDirection(fwdAfterLookAt);

  sky.setCameraPos(camera.position);
  sky.update(dt, t);
  ocean.update(dt, boat);

  renderer.render(scene, camera);

  fpsAcc += 1; fpsN += rawDt;
  if (fpsN >= 1) {
    window.__fps = fpsAcc / fpsN;
    fpsAcc = 0; fpsN = 0;
  }
  window.__frames = (window.__frames || 0) + 1;
  window.__simT = t;

  // debug: project key objects to screen space for capture verification
  if (shotMode) {
    const proj = (wx, wy, wz) => {
      const v = new THREE.Vector3(wx, wy, wz).project(camera);
      return [Math.round((v.x + 1) / 2 * window.innerWidth), Math.round((1 - v.y) / 2 * window.innerHeight), v.z];
    };
    const fwd = new THREE.Vector3();
    camera.getWorldDirection(fwd);
    window.__dbg = {
      cam: [camera.position.x.toFixed(1), camera.position.y.toFixed(1), camera.position.z.toFixed(1)],
      camFwd: [fwd.x.toFixed(3), fwd.y.toFixed(3), fwd.z.toFixed(3)],
      fwdAfterLookAt: [fwdAfterLookAt.x.toFixed(3), fwdAfterLookAt.y.toFixed(3), fwdAfterLookAt.z.toFixed(3)],
      quat: [camera.quaternion.x.toFixed(3), camera.quaternion.y.toFixed(3), camera.quaternion.z.toFixed(3), camera.quaternion.w.toFixed(3)],
      boat: [boat.x.toFixed(1), boat.z.toFixed(1), boat.heading.toFixed(3), boat.speed.toFixed(2)],
      boatPx: proj(boat.x, hy + 1.2, boat.z),
      islandPx: proj(0, 30, 0),
      islet1Px: proj(252, 12, 62),
      islet2Px: proj(-318, 8, -186),
      lookPx: proj(boat.x + fx * 30, hy + 3.6, boat.z + fz * 30),
    };
  }
}
tick();
