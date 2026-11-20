// Ocean: a global Gerstner-wave mesh plus (when float render targets are
// available) a GPU heightfield simulation that follows the boat and produces
// the wake. Shore depth/foam comes from a one-time top-down bake of the
// island terrain into a half-float texture. Everything is procedural.
import * as THREE from '../vendor/three.module.js';
import { linVec } from './utils.js';

const PATCH = { size: 128, domain: 100, alpha: 0.0012, damp: 0.994 };
const BAKE = { size: 256, domain: 900 };

// Base waves (also mirrored in the shaders and in waterHeightAt).
const WAVES = [
  { dir: [0.72, 0.69], len: 22, amp: 0.42 },
  { dir: [-0.35, 0.94], len: 13.5, amp: 0.30 },
];
const FINE = { dir: [0.18, 0.98], len: 6.2, amp: 0.12 };

const HORIZON = '#c8d8e2';
const ZENITH = '#5789b6';
const DEEP = '#2e5451';
const SHALLOW = '#2ea79b';
const FOAM = '#f2f6f5';
const SUN = '#fff2d4';

// ---- CPU-side Gerstner (for boat bobbing) --------------------------------

export function waterHeightAt(x, z, t) {
  let h = 0;
  for (const w of WAVES) {
    const k = (Math.PI * 2) / w.len;
    const c = Math.sqrt(9.8 / k) * 0.9;
    h += w.amp * Math.cos((w.dir[0] * x + w.dir[1] * z) * k - c * k * t);
  }
  return h;
}

export function waterGradientAt(x, z, t) {
  let gx = 0, gz = 0;
  for (const w of WAVES) {
    const k = (Math.PI * 2) / w.len;
    const c = Math.sqrt(9.8 / k) * 0.9;
    const s = Math.sin((w.dir[0] * x + w.dir[1] * z) * k - c * k * t);
    gx -= w.dir[0] * k * w.amp * s;
    gz -= w.dir[1] * k * w.amp * s;
  }
  return [gx, gz];
}

// ---- shared GLSL pieces ----------------------------------------------------

const GERSTNER_GLSL = `
uniform float uTime;
vec2 gerstner2(vec2 p, out float h, out vec2 n, out float crest) {
  h = 0.0; n = vec2(0.0); crest = 0.0;
  vec2 d = vec2(0.72, 0.69); float k = 6.28318 / 22.0; float w = sqrt(9.8 * k) * 0.9;
  float ph = dot(d, p) * k - w * uTime;
  h += 0.42 * cos(ph); n += d * (k * 0.42 * sin(ph)); crest += k * k * 0.42 * cos(ph);
  d = vec2(-0.35, 0.94); k = 6.28318 / 13.5; w = sqrt(9.8 * k) * 0.9;
  ph = dot(d, p) * k - w * uTime;
  h += 0.30 * cos(ph); n += d * (k * 0.30 * sin(ph)); crest += k * k * 0.30 * cos(ph);
  return p;
}
`;

const WATER_VERT = `
${GERSTNER_GLSL}
uniform vec2 uPatchCenter;
uniform float uPatchDomain;
uniform sampler2D tSim;
varying vec3 vWorld;
varying vec3 vNormal;
varying float vCrest;
varying vec2 vSimUV;
varying float vPatchBlend;

void main() {
  vec3 wp = (modelMatrix * vec4(position, 1.0)).xyz;
  vec2 p = wp.xz;
  float h = 0.0; vec2 n2 = vec2(0.0); float crest = 0.0;
  gerstner2(p, h, n2, crest);
  float blend = 0.0;
  vec2 simUV = vec2(0.5);
#ifdef PATCH_MODE
  {
    float pr = length(p - uPatchCenter);
    blend = 1.0 - smoothstep(38.0, 47.0, pr);
    simUV = (p - uPatchCenter) / uPatchDomain + 0.5;
    // fine ripple inside the patch, faded at its edge
    vec2 d = vec2(0.18, 0.98); float k = 6.28318 / 6.2; float w = sqrt(9.8 * k) * 0.9;
    float ph = dot(d, p) * k - w * uTime;
    h += 0.12 * cos(ph) * blend;
    n2 += d * (k * 0.12 * sin(ph)) * blend;
    // simulated height + normal
    vec2 te = vec2(1.0 / 128.0);
    float hC = texture2D(tSim, simUV).x;
    float hL = texture2D(tSim, simUV + vec2(-te.x, 0.0)).x;
    float hR = texture2D(tSim, simUV + vec2(te.x, 0.0)).x;
    float hT = texture2D(tSim, simUV + vec2(0.0, -te.y)).x;
    float hB = texture2D(tSim, simUV + vec2(0.0, te.y)).x;
    h += hC * blend;
    vec2 gs = vec2(hR - hL, hT - hB) / (2.0 * uPatchDomain / 128.0);
    n2 -= gs * blend;
  }
#endif
  wp.y += h;
  vWorld = wp;
  vNormal = vec3(n2.x, 1.0, n2.y);
  vCrest = smoothstep(0.094, 0.120, abs(crest)) * 0.22;
  vSimUV = simUV;
  vPatchBlend = blend;
  gl_Position = projectionMatrix * viewMatrix * vec4(wp, 1.0);
}
`;

const WATER_FRAG = `
uniform sampler2D tShore;
uniform vec2 uBakeCenter;
uniform float uBakeDomain;
uniform sampler2D tSim;
uniform vec2 uPatchCenter;
uniform float uPatchDomain;
uniform float uPatchOn;
uniform float uTime;
uniform vec3 uHorizon;
uniform vec3 uZenith;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform vec3 uDeep;
uniform vec3 uShallow;
uniform vec3 uFoam;
uniform float uFogDensity;
varying vec3 vWorld;
varying vec3 vNormal;
varying float vCrest;
varying vec2 vSimUV;
varying float vPatchBlend;

void main() {
#ifndef PATCH_MODE
  if (uPatchOn > 0.5) {
    float pr = length(vWorld.xz - uPatchCenter);
    if (1.0 - smoothstep(36.0, 47.0, pr) > 0.05) discard;
  }
#endif
  vec3 N = normalize(vNormal);
  vec3 V = normalize(cameraPosition - vWorld);
  // the bake camera's up resolves to world -Z, so the height texture is
  // flipped in V: sample with v = 0.5 - z/domain
  vec2 buv = vec2((vWorld.x - uBakeCenter.x) / uBakeDomain + 0.5, 0.5 - (vWorld.z - uBakeCenter.y) / uBakeDomain);
  float shoreH = texture2D(tShore, buv).x;
  float depth = max(-shoreH, 0.0);
  vec3 col = mix(uShallow, uDeep, smoothstep(0.5, 16.0, depth));
  // foam: shoreline wash, wave crests, wake (patch only)
  float foam = 1.0 - smoothstep(0.03, 0.28, depth);
  foam *= 0.72 + 0.28 * sin(uTime * 1.6 + vWorld.x * 0.35 + vWorld.z * 0.23);
  foam = max(foam, vCrest);
#ifdef PATCH_MODE
  {
    vec2 te = vec2(1.0 / 128.0);
    float hC = texture2D(tSim, vSimUV).x;
    float hL = texture2D(tSim, vSimUV + vec2(-te.x, 0.0)).x;
    float hR = texture2D(tSim, vSimUV + vec2(te.x, 0.0)).x;
    float hT = texture2D(tSim, vSimUV + vec2(0.0, -te.y)).x;
    float hB = texture2D(tSim, vSimUV + vec2(0.0, te.y)).x;
    float lap = hL + hR + hT + hB - 4.0 * hC;
    // foam only on crests (negative laplacian), so the wake reads as
    // bright streak lines instead of filling the whole disturbed patch
    foam = max(foam, smoothstep(0.50, 0.90, max(-lap, 0.0)) * vPatchBlend * 0.12);
  }
#endif
  col = mix(col, uFoam, clamp(foam, 0.0, 1.0) * 0.45);
  // fresnel reflection toward the sky
  float F = pow(1.0 - max(dot(N, V), 0.0), 3.0);
  vec3 skyRef = mix(uHorizon, uZenith, clamp(N.y * 1.35 + 0.38, 0.0, 1.0));
  col = mix(col, skyRef, F * 0.32);
  // sun specular
  vec3 H = normalize(uSunDir + V);
  float spec = pow(max(dot(N, H), 0.0), 300.0) * 2.5 + pow(max(dot(N, H), 0.0), 120.0) * 0.10;
  col += uSunColor * spec;
  // distance haze (matches scene fog)
  float d = distance(vWorld, cameraPosition);
  float fogF = 1.0 - exp(-pow(d * uFogDensity, 2.0));
  col = mix(col, uHorizon, fogF);
  gl_FragColor = vec4(col, 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}
`;

// ---- bake: terrain height -> R16F texture ----------------------------------

const BAKE_VERT = `
varying float vWorldY;
void main() {
  vec4 wp = vec4(position, 1.0);
#ifdef USE_INSTANCING
  wp = instanceMatrix * wp;
#else
  wp = modelMatrix * wp;
#endif
  vWorldY = wp.y;
  gl_Position = projectionMatrix * viewMatrix * wp;
}
`;
const BAKE_FRAG = `
varying float vWorldY;
void main() {
  gl_FragColor = vec4(vWorldY, 0.0, 0.0, 1.0);
}
`;

// ---- sim ---------------------------------------------------------------------

const SIM_VERT = `
varying vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = vec4(position.xy, 0.0, 1.0);
}
`;

const SIM_FRAG = `
uniform sampler2D tCur;
uniform sampler2D tPrev;
uniform float uAlpha;
uniform float uDamp;
uniform vec2 uVel;
varying vec2 vUv;
void main() {
  vec2 te = vec2(1.0 / 128.0);
  float hC = texture2D(tCur, vUv).x;
  float hL = texture2D(tCur, vUv + vec2(-te.x, 0.0)).x;
  float hR = texture2D(tCur, vUv + vec2(te.x, 0.0)).x;
  float hT = texture2D(tCur, vUv + vec2(0.0, -te.y)).x;
  float hB = texture2D(tCur, vUv + vec2(0.0, te.y)).x;
  // advection: keep features at world positions while the domain slides
  vec2 grad = vec2(hR - hL, hT - hB) / 2.0;
  float hA = hC + dot(uVel, grad);
  float hP = texture2D(tPrev, vUv).x;
  float lap = hL + hR + hT + hB - 4.0 * hC;
  float h = 2.0 * hA - hP + uAlpha * lap;
  h *= uDamp;
  h = clamp(h, -0.35, 0.35);
  vec2 d = vUv - 0.5;
  h *= 1.0 - smoothstep(0.40, 0.49, length(d));
  gl_FragColor = vec4(h, 0.0, 0.0, 1.0);
}
`;

// wake disturbance stamps, in patch-local meters (+X = boat forward)
const SPLAT_VERT = `
attribute float aAcross;
attribute float aAmp;
uniform float uHeading;
uniform float uAmpScale;
varying float vD;
varying float vAmp;
void main() {
  float c = cos(uHeading), s = sin(uHeading);
  vec2 lp = vec2(c * position.x - s * position.z, s * position.x + c * position.z);
  vD = aAcross;
  vAmp = aAmp * uAmpScale;
  vec2 uv = (lp + 50.0) / 100.0;
  gl_Position = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
}
`;
const SPLAT_FRAG = `
varying float vD;
varying float vAmp;
void main() {
  gl_FragColor = vec4(vAmp * exp(-(vD * vD) / 0.14), 0.0, 0.0, 1.0);
}
`;

function makeSimRT() {
  return new THREE.WebGLRenderTarget(PATCH.size, PATCH.size, {
    format: THREE.RedFormat,
    type: THREE.HalfFloatType,
    minFilter: THREE.LinearFilter,
    magFilter: THREE.LinearFilter,
    wrapS: THREE.ClampToEdgeWrapping,
    wrapT: THREE.ClampToEdgeWrapping,
    depthBuffer: false,
    stencilBuffer: false,
  });
}

// ---- Ocean -------------------------------------------------------------------

export class Ocean {
  constructor(renderer, scene, terrainGroup, opts) {
    this.renderer = renderer;
    this.scene = scene;
    this.simOn = !!opts.sim;
    this.t = 0;

    const lin = (hex) => linVec(hex);
    this.commonUniforms = {
      uTime: { value: 0 },
      uHorizon: { value: lin(HORIZON) },
      uZenith: { value: lin(ZENITH) },
      uSunDir: { value: [0.408, 0.259, 0.875] },
      uSunColor: { value: lin(SUN) },
      uDeep: { value: lin(DEEP) },
      uShallow: { value: lin(SHALLOW) },
      uFoam: { value: lin(FOAM) },
      uFogDensity: { value: 0.0007 },
      uBakeCenter: { value: [0, 0] },
      uBakeDomain: { value: BAKE.domain },
      uPatchCenter: { value: [0, 0] },
      uPatchDomain: { value: PATCH.domain },
      uPatchOn: { value: this.simOn ? 1 : 0 },
    };

    this.bake(terrainGroup);
    if (this.simOn) this.buildSim();
    this.buildGlobalMesh();
    if (this.simOn) this.buildPatchMesh();
    else this.buildWakeRibbon();
  }

  bake(terrainGroup) {
    const rt = new THREE.WebGLRenderTarget(BAKE.size, BAKE.size, {
      format: THREE.RedFormat,
      type: THREE.HalfFloatType,
      minFilter: THREE.LinearFilter,
      magFilter: THREE.LinearFilter,
      wrapS: THREE.ClampToEdgeWrapping,
      wrapT: THREE.ClampToEdgeWrapping,
      depthBuffer: false,
      stencilBuffer: false,
    });
    const cam = new THREE.OrthographicCamera(-450, 450, 450, -450, 100, 1600);
    cam.position.set(0, 800, 0);
    cam.lookAt(0, 0, 0);
    const fillMat = new THREE.ShaderMaterial({
      uniforms: { uVal: { value: -60 } },
      vertexShader: 'void main(){ gl_Position = vec4(position.xy, 0.0, 1.0); }',
      fragmentShader: 'uniform float uVal; void main(){ gl_FragColor = vec4(uVal, 0.0, 0.0, 1.0); }',
    });
    const fillQuad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), fillMat);
    const bakeMat = new THREE.ShaderMaterial({
      vertexShader: BAKE_VERT,
      fragmentShader: BAKE_FRAG,
    });
    const r = this.renderer;
    r.setRenderTarget(rt);
    // deep-water fill first (clear value is 0, which would read as shore)
    r.render(fillQuad, cam);
    // render the terrain with a height-writing material; overrideMaterial is
    // not applied to plain Groups, so swap the materials temporarily
    r.autoClear = false;
    const saved = [];
    terrainGroup.traverse((obj) => {
      if (obj.isMesh) {
        saved.push([obj, obj.material]);
        obj.material = bakeMat;
      }
    });
    r.render(terrainGroup, cam);
    r.autoClear = true;
    for (const [obj, mat] of saved) obj.material = mat;
    r.setRenderTarget(null);
    this.shoreTex = rt.texture;
  }

  buildSim() {
    this.rtA = makeSimRT();
    this.rtB = makeSimRT();
    this.rtC = makeSimRT();
    this.tCur = this.rtA;
    this.tPrev = this.rtB;
    this.tNext = this.rtC;
    this.updateMat = new THREE.ShaderMaterial({
      uniforms: {
        tCur: { value: null },
        tPrev: { value: null },
        uAlpha: { value: PATCH.alpha },
        uDamp: { value: PATCH.damp },
        uVel: { value: [0, 0] },
      },
      vertexShader: SIM_VERT,
      fragmentShader: SIM_FRAG,
      depthTest: false,
      depthWrite: false,
    });
    this.simQuad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.updateMat);
    this.simQuad.frustumCulled = false;
    this.simScene = new THREE.Scene();
    this.simScene.add(this.simQuad);
    this.orthoCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    // zero the three state targets before the first frame: an uninitialised
    // float target can contain NaNs that the wave equation would keep forever
    const zeroMat = new THREE.ShaderMaterial({
      vertexShader: 'void main(){ gl_Position = vec4(position.xy, 0.0, 1.0); }',
      fragmentShader: 'void main(){ gl_FragColor = vec4(0.0); }',
    });
    const zeroQuad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), zeroMat);
    const zeroScene = new THREE.Scene();
    zeroScene.add(zeroQuad);
    for (const rt of [this.rtA, this.rtB, this.rtC]) {
      this.renderer.setRenderTarget(rt);
      this.renderer.render(zeroScene, this.orthoCam);
    }
    this.renderer.setRenderTarget(null);

    // static stamp strips (patch-local, +X forward): bow bump + side troughs
    const pos = [], across = [], amp = [], idx = [];
    const strip = (x0, z0, x1, z1, halfW, a) => {
      const base = pos.length / 3;
      // perpendicular of the strip direction
      const dx = x1 - x0, dz = z1 - z0;
      const len = Math.hypot(dx, dz) || 1;
      const px = -dz / len, pz = dx / len;
      pos.push(x0 + px * halfW, 0, z0 + pz * halfW, x0 - px * halfW, 0, z0 - pz * halfW);
      pos.push(x1 + px * halfW, 0, z1 + pz * halfW, x1 - px * halfW, 0, z1 - pz * halfW);
      across.push(halfW, -halfW, halfW, -halfW);
      amp.push(a, a, a, a);
      idx.push(base, base + 1, base + 2, base + 2, base + 1, base + 3);
    };
    strip(2.6, 0, 3.9, 0, 0.35, 0.06);   // bow wave
    strip(0.8, -1.15, -10.0, -1.15, 0.16, -0.04); // port trough
    strip(0.8, 1.15, -10.0, 1.15, 0.16, -0.04);   // starboard trough
    strip(-3.4, 0, -4.4, 0, 0.30, 0.025); // prop wash (net zero overall)
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('aAcross', new THREE.Float32BufferAttribute(across, 1));
    geo.setAttribute('aAmp', new THREE.Float32BufferAttribute(amp, 1));
    geo.setIndex(idx);
    this.splatMat = new THREE.ShaderMaterial({
      uniforms: { uHeading: { value: 0 }, uAmpScale: { value: 0 } },
      vertexShader: SPLAT_VERT,
      fragmentShader: SPLAT_FRAG,
      blending: THREE.AdditiveBlending,
      depthTest: false,
      depthWrite: false,
    });
    this.splatMesh = new THREE.Mesh(geo, this.splatMat);
    this.splatScene = new THREE.Scene();
    this.splatScene.add(this.splatMesh);
  }

  buildGlobalMesh() {
    const geo = new THREE.PlaneGeometry(2400, 2400, 448, 448);
    geo.rotateX(-Math.PI / 2);
    const mat = new THREE.ShaderMaterial({
      uniforms: { ...this.commonUniforms, tShore: { value: this.shoreTex }, tSim: { value: null } },
      vertexShader: WATER_VERT,
      fragmentShader: WATER_FRAG,
    });
    this.globalMesh = new THREE.Mesh(geo, mat);
    this.globalMesh.frustumCulled = false;
    this.globalMesh.renderOrder = 1;
    this.scene.add(this.globalMesh);
  }

  buildPatchMesh() {
    const geo = new THREE.PlaneGeometry(PATCH.domain, PATCH.domain, PATCH.size, PATCH.size);
    geo.rotateX(-Math.PI / 2);
    const mat = new THREE.ShaderMaterial({
      uniforms: { ...this.commonUniforms, tShore: { value: this.shoreTex }, tSim: { value: this.tCur.texture } },
      vertexShader: WATER_VERT,
      fragmentShader: WATER_FRAG,
      defines: { PATCH_MODE: 1 },
    });
    this.patchMesh = new THREE.Mesh(geo, mat);
    this.patchMesh.frustumCulled = false;
    this.patchMesh.renderOrder = 2;
    this.scene.add(this.patchMesh);
  }

  buildWakeRibbon() {
    // Simple foam trail used only when the GPU simulation is unavailable.
    const N = 24, L = 24;
    const pos = [], a = [], idx = [];
    for (let i = 0; i <= N; i++) {
      const t = i / N;
      const x = -2 - t * L;
      const w = (1 - t) * 1.5 + 0.12;
      pos.push(x, 0.02, w, x, 0.02, -w);
      a.push(1 - t, 1 - t);
    }
    for (let i = 0; i < N; i++) {
      const b = i * 2;
      idx.push(b, b + 1, b + 2, b + 2, b + 1, b + 3);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('aFade', new THREE.Float32BufferAttribute(a, 1));
    geo.setIndex(idx);
    const mat = new THREE.ShaderMaterial({
      uniforms: { uFoam: { value: linVec(FOAM) }, uHorizon: { value: linVec(HORIZON) }, uFogDensity: { value: 0.0012 } },
      vertexShader: `
        attribute float aFade;
        varying float vFade;
        varying vec3 vWorld;
        void main() {
          vec3 wp = (modelMatrix * vec4(position, 1.0)).xyz;
          vWorld = wp;
          vFade = aFade;
          gl_Position = projectionMatrix * viewMatrix * vec4(wp, 1.0);
        }`,
      fragmentShader: `
        uniform vec3 uFoam;
        uniform vec3 uHorizon;
        uniform float uFogDensity;
        varying float vFade;
        varying vec3 vWorld;
        void main() {
          float d = distance(vWorld, cameraPosition);
          float fogF = 1.0 - exp(-pow(d * uFogDensity, 2.0));
          vec3 col = mix(uFoam, uHorizon, fogF);
          gl_FragColor = vec4(col, vFade * 0.75);
          #include <tonemapping_fragment>
          #include <colorspace_fragment>
        }`,
      transparent: true,
      depthWrite: false,
    });
    this.wakeRibbon = new THREE.Mesh(geo, mat);
    this.wakeRibbon.renderOrder = 3;
    this.scene.add(this.wakeRibbon);
  }

  update(dt, boat) {
    this.t += dt;
    this.commonUniforms.uTime.value = this.t;
    if (!this.simOn) {
      this.wakeRibbon.position.set(boat.x, waterHeightAt(boat.x, boat.z, this.t), boat.z);
      this.wakeRibbon.rotation.y = -boat.heading;
      return;
    }
    this.commonUniforms.uPatchCenter.value[0] = boat.x;
    this.commonUniforms.uPatchCenter.value[1] = boat.z;
    this.patchMesh.position.set(boat.x, 0, boat.z);

    const r = this.renderer;
    // 1. stamp the wake into the current height field (additive, no clear)
    const speed = Math.hypot(boat.vx, boat.vz);
    const ampScale = Math.min(1, Math.max(0, speed - 0.4) / 1.4);
    this.splatMat.uniforms.uHeading.value = boat.heading;
    this.splatMat.uniforms.uAmpScale.value = ampScale * Math.min(0.003, dt * 0.08);
    r.autoClear = false;
    r.setRenderTarget(this.tCur);
    r.render(this.splatScene, this.orthoCam);
    r.autoClear = true;

    // 2. wave-equation substeps (time-scaled so the sim speed is stable)
    const substeps = Math.max(1, Math.min(16, Math.round(dt * 240)));
    const cell = PATCH.domain / PATCH.size;
    this.updateMat.uniforms.uVel.value = [boat.vx * dt / (substeps * cell), boat.vz * dt / (substeps * cell)];
    for (let i = 0; i < substeps; i++) {
      this.updateMat.uniforms.tCur.value = this.tCur.texture;
      this.updateMat.uniforms.tPrev.value = this.tPrev.texture;
      r.setRenderTarget(this.tNext);
      r.render(this.simScene, this.orthoCam);
      const tmp = this.tCur;
      this.tCur = this.tNext;
      this.tPrev = tmp;
      this.tNext = this.tCur === this.rtA || this.tPrev === this.rtA
        ? (this.tCur === this.rtB || this.tPrev === this.rtB ? this.rtC : this.rtB)
        : this.rtA;
    }
    this.patchMesh.material.uniforms.tSim.value = this.tCur.texture;
    r.setRenderTarget(null);
  }
}
