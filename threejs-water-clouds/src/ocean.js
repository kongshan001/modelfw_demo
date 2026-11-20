// Gerstner ocean: radial LOD mesh, analytic wave normals, sky-cube reflection,
// sun glitter, depth tint and foam. The CPU wave sampler is shared by the boat.

import * as THREE from '../vendor/three.module.js';

const WAVE_DATA = [
  [0.940, 0.342, 0.85, 61.0],
  [0.640, 0.768, 0.55, 37.0],
  [-0.174, 0.985, 0.38, 24.0],
  [0.985, -0.174, 0.25, 16.0],
  [0.287, 0.958, 0.16, 10.5],
  [-0.640, 0.768, 0.10, 7.2],
  [0.848, 0.530, 0.064, 4.9],
  [0.259, -0.966, 0.040, 3.3]
].map(([x, z, amp, len]) => {
  const n = Math.hypot(x, z);
  return new THREE.Vector4(x / n, z / n, amp, len);
});

const GRAVITY = 9.81;
const TIME_SCALE = 0.75;

const WAVE_VERTEX = /* glsl */ `
#define NW 8
uniform vec4 uWaves[NW];
uniform float uTime;

varying vec3 vWorldPos;
varying vec3 vNormal;
varying float vCrest;
varying float vCompression;
varying float vWaveHeight;

void main() {
  vec3 p = position;
  vec3 tangent = vec3(1.0, 0.0, 0.0);
  vec3 binormal = vec3(0.0, 0.0, 1.0);
  float crest = 0.0;
  float compression = 0.0;

  float dist = distance(cameraPosition.xz, position.xz);
  float lod = 1.0 - smoothstep(220.0, 1500.0, dist);

  for (int i = 0; i < NW; i++) {
    vec2 d = normalize(uWaves[i].xy);
    float amplitude = uWaves[i].z;
    float wavelength = uWaves[i].w;
    if (wavelength < 28.0) amplitude *= lod;

    float k = 6.2831853 / wavelength;
    float omega = sqrt(9.81 * k) * 0.75;
    float phase = k * dot(d, position.xz) - omega * uTime;
    float S = sin(phase);
    float C = cos(phase);
    float Q = 0.42;
    float WA = k * amplitude;

    p.x += Q * amplitude * d.x * C;
    p.z += Q * amplitude * d.y * C;
    p.y += amplitude * S;

    tangent += vec3(-Q * d.x * d.x * WA * S, d.x * WA * C, -Q * d.x * d.y * WA * S);
    binormal += vec3(-Q * d.x * d.y * WA * S, d.y * WA * C, -Q * d.y * d.y * WA * S);
    crest += amplitude * S;
    compression += Q * WA * S;
  }

  vec3 normal = normalize(cross(binormal, tangent));
  vNormal = normal;
  vWorldPos = p;
  vCrest = crest;
  vCompression = max(compression, 0.0);
  vWaveHeight = p.y;

  gl_Position = projectionMatrix * viewMatrix * vec4(p, 1.0);
}
`;

const WAVE_FRAGMENT = /* glsl */ `
uniform samplerCube uSkyCube;
uniform sampler2D uDetailTex;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform vec3 uDeepColor;
uniform vec3 uShallowColor;
uniform vec3 uSandColor;
uniform vec3 uFoamColor;
uniform vec3 uHorizonColor;
uniform vec2 uIslandCenter;
uniform float uShoreRadius;
uniform float uTime;

varying vec3 vWorldPos;
varying vec3 vNormal;
varying float vCrest;
varying float vCompression;
varying float vWaveHeight;

void main() {
  vec3 V = normalize(cameraPosition - vWorldPos);
  vec2 uv1 = vWorldPos.xz * 0.020 + vec2(uTime * 0.0035, uTime * 0.0021);
  vec2 uv2 = vWorldPos.xz * 0.049 - vec2(uTime * 0.006, uTime * 0.004);
  vec3 d1 = texture2D(uDetailTex, uv1).rgb;
  vec3 d2 = texture2D(uDetailTex, uv2).rgb;
  vec2 slope = ((d1.rg + d2.rg) - 1.0) * 0.16;

  vec3 N = normalize(vec3(vNormal.x + slope.x, vNormal.y, vNormal.z + slope.y));
  float ndv = clamp(dot(N, V), 0.0, 1.0);
  float fresnel = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);

  vec3 ray = reflect(-V, N);
  ray.y = max(ray.y, 0.012);
  vec3 reflection = textureCube(uSkyCube, ray).rgb;

  float shoreDist = length(vWorldPos.xz - uIslandCenter);
  float shallow = smoothstep(70.0, 28.0, shoreDist);
  float sand = smoothstep(38.0, 24.0, shoreDist);

  vec3 body = mix(uDeepColor, uShallowColor, shallow);
  body = mix(body, uSandColor, sand * 0.55);
  body *= 0.86 + 0.14 * smoothstep(-0.8, 1.0, vWaveHeight);

  float sunUp = clamp(uSunDir.y * 5.0 + 0.15, 0.0, 1.0);
  float crestLight = clamp(vCrest * 0.55 + 0.15, 0.0, 1.0);
  body += uShallowColor * uSunColor * 0.045 * crestLight * sunUp;
  body += uSunColor * 0.010 * sunUp;

  // Sun glitter: two lobes plus detail-driven sparkles.
  vec3 H = normalize(uSunDir + V);
  float ndh = max(dot(N, H), 0.0);
  float broad = pow(ndh, 80.0) * 0.30;
  float sharp = pow(ndh, 1200.0) * 3.2;
  float sparkle = smoothstep(0.48, 0.82, d1.b * 0.5 + d2.b * 0.5) * pow(ndh, 700.0);
  vec3 glintRay = reflect(-V, N);
  float path = pow(max(dot(glintRay, uSunDir), 0.0), 10.0);
  vec3 specular = uSunColor * sunUp * (broad + sharp + sparkle * 2.2 + path * 0.10) * 0.55;

  vec3 tinted = reflection * 0.78 * mix(vec3(0.25, 0.45, 0.58), vec3(1.0), 0.10);
  vec3 color = mix(body, tinted, clamp(fresnel * 0.86, 0.0, 0.62));
  color += specular * (0.35 + 0.65 * fresnel);

  // Crest foam and a noisy band along the shoreline.
  float foamNoise = d1.b * 0.6 + d2.b * 0.4;
  float crestFoam = smoothstep(0.32, 0.68, vCompression + vCrest * 0.10 + (foamNoise - 0.5) * 0.16);
  float shoreBand = smoothstep(uShoreRadius + 6.0, uShoreRadius - 0.5, shoreDist);
  float shorePulse = 0.55 + 0.45 * sin(uTime * 1.6 + shoreDist * 0.9 + foamNoise * 6.0);
  float shoreFoam = shoreBand * shorePulse * smoothstep(0.30, 0.62, foamNoise);
  float foam = clamp(crestFoam * 0.52 + shoreFoam * 0.9, 0.0, 1.0);

  vec3 foamColor = uFoamColor * (0.55 + 0.45 * max(dot(N, uSunDir), 0.0));
  foamColor += reflection * 0.15;
  color = mix(color, foamColor, foam);

  float fog = smoothstep(2200.0, 12000.0, distance(cameraPosition, vWorldPos));
  color = mix(color, uHorizonColor, fog * 0.88);

  gl_FragColor = vec4(max(color, 0.0), 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}
`;

function buildRadialGeometry(rings = 200, segments = 256, maxRadius = 18000) {
  const positions = new Float32Array(rings * segments * 3);
  let ptr = 0;
  for (let i = 0; i < rings; i++) {
    const r = maxRadius * Math.pow((i + 1) / rings, 2.2);
    for (let j = 0; j < segments; j++) {
      const a = (j / segments) * Math.PI * 2;
      positions[ptr++] = Math.cos(a) * r;
      positions[ptr++] = 0;
      positions[ptr++] = Math.sin(a) * r;
    }
  }

  const indices = [];
  for (let i = 0; i < rings - 1; i++) {
    for (let j = 0; j < segments; j++) {
      const jn = (j + 1) % segments;
      const a = i * segments + j;
      const b = i * segments + jn;
      const c = (i + 1) * segments + jn;
      const d = (i + 1) * segments + j;
      indices.push(a, b, c, a, c, d);
    }
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setIndex(indices);
  geometry.computeBoundingSphere();
  return geometry;
}

export function cpuWaveHeight(x, z, time) {
  let height = 0;
  for (const wave of WAVE_DATA) {
    const k = (Math.PI * 2) / wave.w;
    const omega = Math.sqrt(GRAVITY * k) * TIME_SCALE;
    const phase = k * (wave.x * x + wave.y * z) - omega * time;
    height += wave.z * Math.sin(phase);
  }
  return height;
}

export function createOcean({ detailTexture, skyCube }) {
  const uniforms = {
    uWaves: { value: WAVE_DATA },
    uTime: { value: 0 },
    uSkyCube: { value: skyCube },
    uDetailTex: { value: detailTexture },
    uSunDir: { value: new THREE.Vector3(0, 1, 0) },
    uSunColor: { value: new THREE.Color(1, 1, 1) },
    uDeepColor: { value: new THREE.Color('#0a3142') },
    uShallowColor: { value: new THREE.Color('#1d8f8c') },
    uSandColor: { value: new THREE.Color('#9bc9ba') },
    uFoamColor: { value: new THREE.Color('#d9ecec') },
    uHorizonColor: { value: new THREE.Color('#bcd6e6') },
    uIslandCenter: { value: new THREE.Vector2(0, 0) },
    uShoreRadius: { value: 27.0 }
  };

  const material = new THREE.ShaderMaterial({
    uniforms,
    vertexShader: WAVE_VERTEX,
    fragmentShader: WAVE_FRAGMENT,
    toneMapped: true,
    fog: false
  });

  const mesh = new THREE.Mesh(buildRadialGeometry(), material);
  mesh.frustumCulled = false;
  mesh.name = 'ocean';

  return { mesh, material, uniforms };
}
