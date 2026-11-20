// ENDLESS DRIFT — an original Three.js cloud ride, rebuilt clean-room from the
// visible reference only. Auto-rides on load; no input required.

import * as THREE from '../vendor/three.module.js';
import { PALETTE } from './palette.js';
import { createSky } from './sky.js';
import { createSea } from './sea.js';
import { createClouds } from './clouds.js';
import { createRider } from './rider.js';
import { createOrbit } from './orbit.js';

const canvas = document.getElementById('scene');
const fallback = document.getElementById('fallback');

let renderer = null;
try {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
} catch (err) {
  console.error('WebGL initialisation failed:', err);
}
if (!renderer || !renderer.capabilities.isWebGL2) {
  fallback.classList.add('show');
  canvas.style.display = 'none';
  throw new Error('WebGL 2 is not available in this browser.');
}

renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.15;

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(PALETTE.horizon, 55, 330);

const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.5, 1200);

scene.add(new THREE.HemisphereLight(PALETTE.hemiSky, PALETTE.hemiGround, 2.0));
const sun = new THREE.DirectionalLight(PALETTE.sun, 3.0);
sun.position.set(-30, 55, 26);
scene.add(sun);

createSky(scene);
const sea = createSea(scene, renderer);
const clouds = createClouds(scene);
const rider = createRider(scene);
const orbit = createOrbit(camera, canvas);

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  sea.resize();
});

const clock = new THREE.Clock();
let animT = 0; // ride time, frozen while paused
let wallT = 0;

function frame() {
  requestAnimationFrame(frame);
  const dt = Math.min(clock.getDelta(), 0.05);
  wallT += dt;
  orbit.update(dt, wallT);
  const adt = orbit.paused ? 0 : dt;
  if (adt > 0) {
    animT += adt;
    clouds.update(adt, animT);
    rider.update(animT, adt);
  }
  sea.update(animT);
  sea.renderReflection(scene, camera);
  renderer.render(scene, camera);
}
frame();
