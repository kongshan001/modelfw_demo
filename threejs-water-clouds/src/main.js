// Entry point: renderer, palette transitions, sky target + blit, loop, input.
// Static ES modules only; Three.js is vendored in ../vendor.

import * as THREE from '../vendor/three.module.js';
import { buildCloudNoise, buildWeatherTexture, buildWaterDetailTexture } from './noise.js';
import { createSky } from './sky.js';
import { createOcean } from './ocean.js';
import { createProps } from './props.js';
import { OrbitRig } from './controls.js';

const canvas = document.getElementById('scene');
const ui = document.getElementById('ui');
const fpsEl = document.getElementById('fps');
const qualityEl = document.getElementById('quality');
const scaleEl = document.getElementById('resolution');
const loadingEl = document.getElementById('loading');
const loadingText = document.getElementById('loading-text');

const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  powerPreference: 'high-performance',
  alpha: false,
  stencil: false
});
renderer.setPixelRatio(1);
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.08;
renderer.autoClear = false;

const camera = new THREE.PerspectiveCamera(55, window.innerWidth / window.innerHeight, 0.5, 40000);
const rig = new OrbitRig(camera, canvas, new THREE.Vector3(0, 4.0, 0));

const world = new THREE.Scene();
world.fog = new THREE.FogExp2(0xbcd6e6, 0.00016);

const sunLight = new THREE.DirectionalLight(0xfff2dd, 3.4);
sunLight.position.set(-400, 900, -800);
world.add(sunLight);
world.add(sunLight.target);
const hemiLight = new THREE.HemisphereLight(0xbcd6e6, 0x2b4a52, 1.0);
world.add(hemiLight);
const ambientLight = new THREE.AmbientLight(0xffe8d0, 0.32);
world.add(ambientLight);
const fillLight = new THREE.DirectionalLight(0x9fb9cc, 0.55);
fillLight.position.set(600, 300, 900);
world.add(fillLight);

const SUN_DISTANCE = 1600;

const PRESETS = {
  day: {
    sunDir: new THREE.Vector3(-0.30, 0.72, -0.62).normalize(),
    sunColor: new THREE.Color('#fff2dd'),
    sunIntensity: 3.3,
    sunDisk: 30,
    zenith: new THREE.Color('#2f6fae'),
    horizon: new THREE.Color('#c9dde8'),
    ground: new THREE.Color('#6f8898'),
    coverage: 0.24,
    exposure: 1.04,
    dirIntensity: 3.4,
    hemiIntensity: 1.15,
    waterDeep: new THREE.Color('#063047'),
    waterShallow: new THREE.Color('#1c9195'),
    waterSand: new THREE.Color('#82b9ab'),
    waterFoam: new THREE.Color('#e2f1f0'),
    waterHorizon: new THREE.Color('#c7dce8'),
    lantern: 2
  },
  sunset: {
    sunDir: new THREE.Vector3(-0.50, 0.16, -0.85).normalize(),
    sunColor: new THREE.Color('#ffb06a'),
    sunIntensity: 3.2,
    sunDisk: 55,
    zenith: new THREE.Color('#263c72'),
    horizon: new THREE.Color('#ef8f5d'),
    ground: new THREE.Color('#363044'),
    coverage: 0.28,
    exposure: 1.08,
    dirIntensity: 2.7,
    hemiIntensity: 1.15,
    waterDeep: new THREE.Color('#05232f'),
    waterShallow: new THREE.Color('#1c8082'),
    waterSand: new THREE.Color('#6fa69a'),
    waterFoam: new THREE.Color('#f2dfc9'),
    waterHorizon: new THREE.Color('#a86f52'),
    lantern: 14
  },
  dusk: {
    sunDir: new THREE.Vector3(-0.56, 0.018, -0.83).normalize(),
    sunColor: new THREE.Color('#ff6a45'),
    sunIntensity: 0.9,
    sunDisk: 0,
    zenith: new THREE.Color('#0c1428'),
    horizon: new THREE.Color('#9a4a48'),
    ground: new THREE.Color('#242434'),
    coverage: 0.38,
    exposure: 1.16,
    dirIntensity: 0.55,
    hemiIntensity: 0.55,
    waterDeep: new THREE.Color('#041822'),
    waterShallow: new THREE.Color('#0e4d55'),
    waterSand: new THREE.Color('#46655d'),
    waterFoam: new THREE.Color('#c6d3cf'),
    waterHorizon: new THREE.Color('#784851'),
    lantern: 24
  }
};

function clonePalette(source) {
  const out = {};
  for (const [key, value] of Object.entries(source)) {
    if (value instanceof THREE.Color) out[key] = value.clone();
    else if (value instanceof THREE.Vector3) out[key] = value.clone();
    else out[key] = value;
  }
  return out;
}

let current = clonePalette(PRESETS.sunset);
let target = clonePalette(PRESETS.sunset);
let presetName = 'sunset';

const QUALITY = {
  low: { steps: 20, scale: 0.42 },
  medium: { steps: 30, scale: 0.60 },
  high: { steps: 38, scale: 0.72 }
};
const QUALITY_ORDER = ['low', 'medium', 'high'];
let qualityName = 'medium';

const hdrType = renderer.extensions.has('EXT_color_buffer_float') ||
  renderer.extensions.has('EXT_color_buffer_half_float')
  ? THREE.HalfFloatType
  : THREE.UnsignedByteType;

let skyTarget = null;
let sky = null;
let ocean = null;
let props = null;
let cubeDirty = true;

function createSkyTarget(scale) {
  if (skyTarget) skyTarget.dispose();
  const size = renderer.getDrawingBufferSize(new THREE.Vector2());
  const width = Math.max(2, Math.round(size.x * scale));
  const height = Math.max(2, Math.round(size.y * scale));
  skyTarget = new THREE.WebGLRenderTarget(width, height, {
    type: hdrType,
    format: THREE.RGBAFormat,
    depthBuffer: false,
    minFilter: THREE.LinearFilter,
    magFilter: THREE.LinearFilter
  });
  skyTarget.texture.colorSpace = THREE.LinearSRGBColorSpace;
  if (scaleEl) scaleEl.textContent = `${width}×${height}`;
}

function applyQuality(name) {
  qualityName = name;
  sky.setQualitySteps(QUALITY[name].steps);
  createSkyTarget(QUALITY[name].scale);
  if (qualityEl) qualityEl.textContent = name.toUpperCase();
  document.querySelectorAll('[data-quality]').forEach((button) => {
    button.classList.toggle('active', button.dataset.quality === name);
  });
  if (sky) sky.updateCube(renderer, camera);
  cubeDirty = true;
}

function setPreset(name) {
  if (!PRESETS[name]) return;
  presetName = name;
  target = clonePalette(PRESETS[name]);
  document.querySelectorAll('[data-preset]').forEach((button) => {
    button.classList.toggle('active', button.dataset.preset === name);
  });
  cubeDirty = true;
}

const blitScene = new THREE.Scene();
const blitCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
const blitMaterial = new THREE.ShaderMaterial({
  uniforms: { uTex: { value: null } },
  vertexShader: /* glsl */ `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = vec4(position.xy, 0.0, 1.0);
    }
  `,
  fragmentShader: /* glsl */ `
    uniform sampler2D uTex;
    varying vec2 vUv;
    void main() {
      vec2 texel = 1.0 / vec2(textureSize(uTex, 0));
      vec3 c = texture2D(uTex, vUv).rgb * 0.36;
      c += texture2D(uTex, vUv + vec2(texel.x, 0.0)).rgb * 0.16;
      c += texture2D(uTex, vUv + vec2(-texel.x, 0.0)).rgb * 0.16;
      c += texture2D(uTex, vUv + vec2(0.0, texel.y)).rgb * 0.16;
      c += texture2D(uTex, vUv + vec2(0.0, -texel.y)).rgb * 0.16;
      gl_FragColor = vec4(c, 1.0);
      #include <tonemapping_fragment>
      #include <colorspace_fragment>
    }
  `,
  depthTest: false,
  depthWrite: false,
  toneMapped: true
});
const blitQuad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), blitMaterial);
blitQuad.frustumCulled = false;
blitScene.add(blitQuad);

function approachPalette(k) {
  for (const key of Object.keys(target)) {
    const from = current[key];
    const to = target[key];
    if (from instanceof THREE.Color) {
      from.lerp(to, k);
    } else if (from instanceof THREE.Vector3) {
      from.lerp(to, k).normalize();
    } else {
      current[key] = from + (to - from) * k;
    }
  }
}

let cloudTime = 0;
let waveTime = 0;
let paused = false;

function syncUniforms() {
  const p = current;
  const sunHDR = p.sunColor.clone().multiplyScalar(p.sunIntensity);

  sky.uniforms.uSunDir.value.copy(p.sunDir);
  sky.uniforms.uSunColor.value.copy(sunHDR);
  sky.uniforms.uZenith.value.copy(p.zenith);
  sky.uniforms.uHorizon.value.copy(p.horizon);
  sky.uniforms.uGround.value.copy(p.ground);
  sky.uniforms.uCoverage.value = p.coverage;
  sky.uniforms.uTime.value = cloudTime;
  sky.uniforms.uSunDisk.value = p.sunDisk;

  ocean.uniforms.uSunDir.value.copy(p.sunDir);
  ocean.uniforms.uSunColor.value.copy(sunHDR);
  ocean.uniforms.uDeepColor.value.copy(p.waterDeep);
  ocean.uniforms.uShallowColor.value.copy(p.waterShallow);
  ocean.uniforms.uSandColor.value.copy(p.waterSand);
  ocean.uniforms.uFoamColor.value.copy(p.waterFoam);
  ocean.uniforms.uHorizonColor.value.copy(p.waterHorizon);
  ocean.uniforms.uTime.value = waveTime;

  sunLight.color.copy(p.sunColor);
  sunLight.intensity = p.dirIntensity;
  sunLight.position.copy(p.sunDir).multiplyScalar(SUN_DISTANCE);

  hemiLight.color.copy(p.horizon);
  hemiLight.groundColor.copy(p.ground);
  hemiLight.intensity = p.hemiIntensity;
  fillLight.intensity = 0.38 + p.hemiIntensity * 0.18;

  renderer.toneMappingExposure = p.exposure;
  world.fog.color.copy(p.horizon);
  world.fog.density = 0.00014 + (1 - p.coverage) * 0.00004;

  if (props) {
    props.boat.userData.lanternLight.intensity = p.lantern;
  }
}

function renderFrame() {
  sky.renderBackground(renderer, camera, skyTarget);

  blitMaterial.uniforms.uTex.value = skyTarget.texture;
  renderer.setRenderTarget(null);
  renderer.autoClear = true;
  renderer.clear(true, true, true);
  renderer.render(blitScene, blitCamera);

  renderer.autoClear = false;
  renderer.render(world, camera);
  renderer.autoClear = true;
}

function updateStats() {
  window.__stats.fps = fps;
  window.__stats.quality = qualityName;
  window.__stats.skyTarget = skyTarget ? [skyTarget.width, skyTarget.height] : null;
  window.__stats.frames = totalFrames;
  window.__stats.preset = presetName;
  if (fpsEl) fpsEl.textContent = fps.toFixed(0);
}

let lastTime = performance.now();
let fpsFrames = 0;
let fpsAccum = 0;
let fps = 0;
let totalFrames = 0;
let adaptTimer = 0;
let ready = false;
let bootStart = performance.now();

function animate(now) {
  requestAnimationFrame(animate);
  const rawDt = Math.min((now - lastTime) / 1000, 0.05);
  lastTime = now;
  const dt = paused ? 0 : rawDt;

  if (!paused) {
    cloudTime += dt;
    waveTime += dt;
  }

  approachPalette(1 - Math.exp(-rawDt * 2.2));
  rig.update(dt);
  syncUniforms();
  props.update(waveTime);

  if (cubeDirty || totalFrames % 24 === 0) {
    sky.updateCube(renderer, camera);
    cubeDirty = false;
  }

  renderFrame();
  totalFrames++;

  if (!ready && totalFrames > 3) {
    ready = true;
    window.__ready = true;
    loadingEl.classList.add('hidden');
    window.__bootMs = Math.round(performance.now() - bootStart);
  }

  fpsFrames++;
  fpsAccum += rawDt;
  if (fpsAccum >= 0.5) {
    fps = fpsFrames / fpsAccum;
    fpsFrames = 0;
    fpsAccum = 0;
    updateStats();
  }

  if (paused) {
    adaptTimer = 0;
  } else {
    adaptTimer += rawDt;
    if (adaptTimer > 2.5) {
      adaptTimer = 0;
      const index = QUALITY_ORDER.indexOf(qualityName);
      if (fps > 0 && fps < 27 && index > 0) {
        applyQuality(QUALITY_ORDER[index - 1]);
      }
    }
  }
}

window.__stats = {
  fps: 0,
  quality: qualityName,
  gpu: 'unknown',
  skyTarget: null,
  frames: 0,
  preset: presetName
};

function bindUi() {
  document.querySelectorAll('[data-preset]').forEach((button) => {
    button.addEventListener('click', () => setPreset(button.dataset.preset));
  });
  document.querySelectorAll('[data-quality]').forEach((button) => {
    button.addEventListener('click', () => applyQuality(button.dataset.quality));
  });
  window.addEventListener('keydown', (event) => {
    if (event.code === 'Digit1') setPreset('day');
    if (event.code === 'Digit2') setPreset('sunset');
    if (event.code === 'Digit3') setPreset('dusk');
    if (event.code === 'KeyR') rig.reset();
    if (event.code === 'Space') {
      event.preventDefault();
      rig.autoOrbit = !rig.autoOrbit;
    }
    if (event.code === 'KeyH') ui.classList.toggle('hidden');
    if (event.code === 'KeyQ') {
      const index = QUALITY_ORDER.indexOf(qualityName);
      applyQuality(QUALITY_ORDER[(index + 1) % QUALITY_ORDER.length]);
    }
  });

  window.addEventListener('resize', () => {
    const width = window.innerWidth;
    const height = window.innerHeight;
    renderer.setSize(width, height);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    createSkyTarget(QUALITY[qualityName].scale);
  });
}

async function boot() {
  if (!renderer.capabilities.isWebGL2) {
    loadingText.textContent = 'WebGL2 不可用';
    return;
  }

  loadingText.textContent = '生成体积云噪声';
  await new Promise((resolve) => setTimeout(resolve, 40));

  const cloudNoise = buildCloudNoise(96);
  const weatherTexture = buildWeatherTexture(256);
  const detailTexture = buildWaterDetailTexture(256);

  loadingText.textContent = '构建天空与海面';
  await new Promise((resolve) => setTimeout(resolve, 20));

  sky = createSky(renderer, { noiseTexture: cloudNoise, weatherTexture });
  ocean = createOcean({ detailTexture, skyCube: sky.cubeRT.texture });
  props = createProps();

  world.add(ocean.mesh, props.group);

  createSkyTarget(QUALITY[qualityName].scale);
  applyQuality(qualityName);
  setPreset('sunset');
  syncUniforms();
  sky.updateCube(renderer, camera);

  const gl = renderer.getContext();
  const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
  const gpu = debugInfo ? gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL) : 'webgl2';
  window.__stats.gpu = gpu;

  window.__demo = {
    setPreset,
    applyQuality,
    pause(value) { paused = Boolean(value); },
    resetCamera() { rig.reset(); },
    snapPalette(name) {
      if (!PRESETS[name]) return;
      setPreset(name);
      current = clonePalette(target);
      syncUniforms();
    },
    step(seconds = 1 / 12) {
      paused = true;
      waveTime += seconds;
      cloudTime += seconds;
    },
    setCamera({ theta, phi, radius } = {}) {
      if (theta !== undefined) rig.theta = rig.desired.theta = theta;
      if (phi !== undefined) rig.phi = rig.desired.phi = phi;
      if (radius !== undefined) rig.radius = rig.desired.radius = radius;
      rig.apply();
    },
    get fps() { return fps; },
    get quality() { return qualityName; },
    get preset() { return presetName; },
    debug: {
      get current() { return current; },
      get target() { return target; },
      get sky() { return sky; },
      get ocean() { return ocean; },
      renderer
    }
  };

  bindUi();
  updateStats();
  bootStart = performance.now();
  lastTime = performance.now();
  requestAnimationFrame(animate);
}

boot().catch((error) => {
  console.error(error);
  loadingText.textContent = '初始化失败，见控制台';
});
