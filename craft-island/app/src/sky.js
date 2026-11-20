// Sky dome (gradient + sun + haze, shader-only) and drifting puffy clouds
// built from merged low-poly spheres with vertex-colored bases.
import * as THREE from '../vendor/three.module.js';
import { linVec, mulberry32 } from './utils.js';

const HORIZON = '#c8d8e2';
const ZENITH = '#5789b6';
const SUN = '#fff2d4';
const CLOUD_TOP = '#fbf8ef';
const CLOUD_BOTTOM = '#aebbc6';

const SKY_VERT = `
varying vec3 vDir;
void main() {
  vDir = position;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
`;

const SKY_FRAG = `
uniform vec3 uZenith;
uniform vec3 uHorizon;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform float uTime;
varying vec3 vDir;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float vnoise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 5; i++) {
    s += a * vnoise(p);
    p = p * 2.03 + vec2(11.7, 7.3);
    a *= 0.5;
  }
  return s;
}

void main() {
  vec3 d = normalize(vDir);
  vec3 col = mix(uHorizon, uZenith, pow(clamp(d.y, 0.0, 1.0), 0.55));
  col = mix(col, uHorizon, smoothstep(0.16, 0.0, d.y) * 0.75);

  // volumetric-ish cumulus projected on a high plane
  vec2 cuv = d.xz / (max(d.y, 0.0) + 0.16) * 1.25 + vec2(uTime * 0.002, uTime * 0.001);
  float warp = fbm(cuv * 0.5 + 3.0);
  float n = fbm(cuv * 0.85 + warp * 0.75 + 7.7);
  float cover = smoothstep(0.50, 0.72, n);
  float fade = smoothstep(0.015, 0.10, d.y) * (1.0 - smoothstep(0.78, 1.0, d.y) * 0.35);
  vec3 cloud = mix(vec3(0.55, 0.62, 0.70), vec3(1.0, 0.99, 0.96),
    smoothstep(0.42, 0.86, n));
  float s = dot(d, uSunDir);
  cloud = mix(cloud, uSunColor, pow(max(s, 0.0), 3.0) * 0.18);
  col = mix(col, cloud, cover * fade * 0.9);

  float disc = smoothstep(0.99935, 0.99975, s);
  float glow = pow(max(s, 0.0), 90.0) * 0.45 + pow(max(s, 0.0), 14.0) * 0.12;
  col += uSunColor * (disc + glow);
  gl_FragColor = vec4(col, 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}
`;

function makeCloudGeometry(rnd) {
  // A puffy cloud from a few squashed, jittered spheres.
  const parts = [];
  const count = 5 + Math.floor(rnd() * 3);
  for (let i = 0; i < count; i++) {
    const geo = new THREE.SphereGeometry(1, 10, 7);
    const p = geo.attributes.position;
    // squash vertically, tint vertices by local height
    const minY = -0.5, maxY = 0.5;
    const top = linVec(CLOUD_TOP), bot = linVec(CLOUD_BOTTOM);
    const colors = [];
    for (let k = 0; k < p.count; k++) {
      const y = p.getY(k) * 0.5;
      p.setY(k, y);
      const t = (y - minY) / (maxY - minY);
      const shade = 0.94 + rnd() * 0.08;
      colors.push(top[0] * shade * t + bot[0] * (1 - t), top[1] * shade * t + bot[1] * (1 - t), top[2] * shade * t + bot[2] * (1 - t));
    }
    geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geo.computeVertexNormals();
    parts.push(geo);
  }
  // merge with per-part transforms
  const pos = [], col = [], nor = [], idx = [];
  const m = new THREE.Matrix4();
  const q = new THREE.Quaternion();
  const s = new THREE.Vector3();
  const p = new THREE.Vector3();
  let base = 0;
  for (const geo of parts) {
    q.setFromEuler(new THREE.Euler(0, rnd() * 6.28, 0));
    s.set(7 + rnd() * 8, 2.6 + rnd() * 2.2, 6 + rnd() * 7);
    p.set((rnd() - 0.5) * 9, (rnd() - 0.5) * 1.2, (rnd() - 0.5) * 5);
    m.compose(p, q, s);
    const v = new THREE.Vector3();
    const n = new THREE.Vector3();
    for (let i = 0; i < geo.attributes.position.count; i++) {
      v.fromBufferAttribute(geo.attributes.position, i).applyMatrix4(m);
      n.fromBufferAttribute(geo.attributes.normal, i).transformDirection(m);
      pos.push(v.x, v.y, v.z);
      nor.push(n.x, n.y, n.z);
      col.push(geo.attributes.color.getX(i), geo.attributes.color.getY(i), geo.attributes.color.getZ(i));
    }
    for (let i = 0; i < geo.index.count; i++) idx.push(base + geo.index.getX(i));
    base += geo.attributes.position.count;
    geo.dispose();
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  out.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
  out.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  out.setIndex(idx);
  return out;
}

export function buildSky(scene) {
  const dome = new THREE.Mesh(
    new THREE.SphereGeometry(1500, 24, 12),
    new THREE.ShaderMaterial({
      uniforms: {
        uZenith: { value: linVec(ZENITH) },
        uHorizon: { value: linVec(HORIZON) },
        uSunDir: { value: [0.408, 0.259, 0.875] },
        uSunColor: { value: linVec(SUN) },
        uTime: { value: 0 },
      },
      vertexShader: SKY_VERT,
      fragmentShader: SKY_FRAG,
      side: THREE.BackSide,
      depthWrite: false,
      fog: false,
    })
  );
  dome.frustumCulled = false;
  dome.renderOrder = -10;
  scene.add(dome);

  const rnd = mulberry32(1234);
  const clouds = [];
  const cloudMat = new THREE.MeshBasicMaterial({ vertexColors: true });
  for (let i = 0; i < 14; i++) {
    const geo = makeCloudGeometry(rnd);
    const cloud = new THREE.Mesh(geo, cloudMat);
    const a = rnd() * Math.PI * 2;
    const r = 260 + rnd() * 380;
    cloud.position.set(Math.cos(a) * r, 42 + rnd() * 28, Math.sin(a) * r);
    cloud.scale.setScalar(2.2 + rnd() * 2.6);
    cloud.userData.drift = 0.3 + rnd() * 0.3;
    cloud.renderOrder = -5;
    clouds.push(cloud);
    scene.add(cloud);
  }

  return {
    dome,
    update(dt, t) {
      dome.material.uniforms.uTime.value = t;
      for (const c of clouds) {
        c.position.x += c.userData.drift * dt;
        if (c.position.x > 820) c.position.x -= 1640;
      }
    },
    setCameraPos(p) {
      dome.position.copy(p);
    },
  };
}
