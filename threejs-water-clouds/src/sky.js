// Sky dome + raymarched cumulus layer.
// The same shader renders the half-resolution background and the small sky
// cubemap that the ocean uses for reflection.

import * as THREE from '../vendor/three.module.js';

const SKY_VERTEX = /* glsl */ `
varying vec3 vWorldPos;
void main() {
  vec4 world = modelMatrix * vec4(position, 1.0);
  vWorldPos = world.xyz;
  gl_Position = projectionMatrix * viewMatrix * world;
}
`;

const SKY_FRAGMENT = /* glsl */ `
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform vec3 uZenith;
uniform vec3 uHorizon;
uniform vec3 uGround;
uniform float uCoverage;
uniform float uTime;
uniform float uSteps;
uniform float uSunDisk;
uniform float uNoiseScale;
uniform float uWeatherScale;
uniform float uDensity;
uniform float uCloudBase;
uniform float uCloudTop;
uniform sampler3D uNoise;
uniform sampler2D uWeather;

varying vec3 vWorldPos;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float hgPhase(float c, float g) {
  float g2 = g * g;
  return (1.0 - g2) / (12.5663706 * pow(max(1.0 + g2 - 2.0 * g * c, 0.0001), 1.5));
}

// Cloud slab density. One 3D texture fetch per sample; weather comes from a
// slowly drifting 2D map so the cloudscape changes over time.
float cloudDensity(vec3 p, out float height01) {
  height01 = clamp((p.y - uCloudBase) / (uCloudTop - uCloudBase), 0.0, 1.0);
  if (p.y < uCloudBase || p.y > uCloudTop) return 0.0;

  vec2 wuv = p.xz / uWeatherScale + vec2(uTime * 0.0011, uTime * 0.00035);
  float weather = texture2D(uWeather, wuv).r;
  float coverage = clamp(uCoverage * mix(0.48, 1.62, weather), 0.0, 1.0);

  vec3 q = p * uNoiseScale + vec3(uTime * 0.0008, 0.0, uTime * 0.00035);
  vec4 n = texture(uNoise, q);
  vec4 d = texture(uNoise, q * 3.2 + vec3(0.17, 0.41, 0.73));

  float profile = smoothstep(0.0, 0.07, height01) * (1.0 - smoothstep(0.50, 1.0, height01));
  float shape = n.r * profile;
  float threshold = 1.0 - coverage * 0.94;
  float density = smoothstep(threshold, threshold + 0.10, shape);

  float erosion = n.g * 0.35 + d.g * 0.35 + n.b * 0.30;
  density *= smoothstep(0.24, 0.62, erosion + 0.30);
  density *= smoothstep(0.10, 0.42, d.b * 0.65 + 0.30);
  density *= 0.72 + 0.28 * n.a;
  return density * uDensity;
}

float cloudLight(vec3 p) {
  float optical = 0.0;
  const float stepSize = 190.0;
  for (int i = 0; i < 5; i++) {
    vec3 q = p + uSunDir * (stepSize * (float(i) + 0.5));
    float h;
    optical += cloudDensity(q, h) * stepSize;
  }
  return exp(-optical * 0.0085);
}

vec3 skyGradient(vec3 dir) {
  float h = dir.y;
  float up = pow(clamp(h, 0.0, 1.0), 0.32);
  vec3 color = mix(uHorizon, uZenith, up);
  color = mix(color, uGround, smoothstep(0.0, -0.16, h));
  float sunAmount = max(dot(dir, uSunDir), 0.0);
  color += uSunColor * pow(sunAmount, 10.0) * 0.022;
  color += uSunColor * pow(sunAmount, 120.0) * 0.14;
  color += uSunColor * exp(-abs(h) * 13.0) * pow(sunAmount, 4.0) * 0.075;
  return color;
}

void main() {
  vec3 dir = normalize(vWorldPos - cameraPosition);
  vec3 sky = skyGradient(dir);

  float transmittance = 1.0;
  vec3 scatter = vec3(0.0);

  if (dir.y > 0.002) {
    float t0 = (uCloudBase - cameraPosition.y) / dir.y;
    float t1 = (uCloudTop - cameraPosition.y) / dir.y;
    t0 = max(t0, 0.0);
    float tEnd = min(t1, t0 + 18000.0);
    float dt = max((tEnd - t0) / uSteps, 12.0);
    float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    float t = t0 + dt * jitter;

    float cosTheta = dot(dir, uSunDir);
    float phase = mix(hgPhase(cosTheta, 0.72), hgPhase(cosTheta, -0.16), 0.32);

    for (int i = 0; i < 40; i++) {
      if (float(i) >= uSteps || transmittance < 0.025) break;
      vec3 p = cameraPosition + dir * t;
      float h;
      float density = cloudDensity(p, h);
      if (density > 0.003) {
        float sun = cloudLight(p);
        vec3 ambient = mix(uHorizon * 0.75, uZenith * 1.10, h) * (0.55 + 0.45 * sun);
        vec3 lit = uSunColor * (0.05 + 1.65 * phase) * sun;
        vec3 cloudColor = ambient + lit + uSunColor * 0.02 * (0.4 + 0.6 * sun);
        cloudColor *= mix(0.32, 1.0, 1.0 - exp(-density * 6.0));

        float aerial = 1.0 - exp(-t * 0.000022);
        cloudColor = mix(cloudColor, uHorizon * 0.55, aerial);

        float extinction = density * 0.090;
        float stepT = exp(-extinction * dt);
        scatter += transmittance * cloudColor * (1.0 - stepT);
        transmittance *= stepT;
      }
      t += dt;
    }
  }

  float sunAmount = max(dot(dir, uSunDir), 0.0);
  float disk = smoothstep(0.99984, 0.99994, sunAmount);
  vec3 color = sky * transmittance + scatter;
  color += uSunColor * uSunDisk * disk * transmittance;
  color += (hash12(gl_FragCoord.xy) - 0.5) * (0.8 / 255.0);

  gl_FragColor = vec4(max(color, 0.0), 1.0);
}
`;

function renderTargetType(renderer) {
  // Half float keeps the sky HDR enough for the sun disk and cloud highlights.
  return renderer.extensions.has('EXT_color_buffer_float') ||
    renderer.extensions.has('EXT_color_buffer_half_float')
    ? THREE.HalfFloatType
    : THREE.UnsignedByteType;
}

export function createSky(renderer, { noiseTexture, weatherTexture }) {
  const uniforms = {
    uSunDir: { value: new THREE.Vector3(0.3, 0.3, -1).normalize() },
    uSunColor: { value: new THREE.Color(1, 0.95, 0.85).multiplyScalar(3.0) },
    uZenith: { value: new THREE.Color('#2f6ea8') },
    uHorizon: { value: new THREE.Color('#bcd6e6') },
    uGround: { value: new THREE.Color('#6d8797') },
    uCoverage: { value: 0.45 },
    uTime: { value: 0 },
    uSteps: { value: 28 },
    uSunDisk: { value: 26 },
    uNoiseScale: { value: 1 / 11000 },
    uWeatherScale: { value: 19000 },
    uDensity: { value: 1.0 },
    uCloudBase: { value: 1450 },
    uCloudTop: { value: 2950 },
    uNoise: { value: noiseTexture },
    uWeather: { value: weatherTexture }
  };

  const material = new THREE.ShaderMaterial({
    uniforms,
    vertexShader: SKY_VERTEX,
    fragmentShader: SKY_FRAGMENT,
    side: THREE.BackSide,
    depthWrite: false,
    depthTest: false,
    toneMapped: false,
    fog: false
  });

  const scene = new THREE.Scene();
  const dome = new THREE.Mesh(new THREE.SphereGeometry(26000, 48, 24), material);
  dome.frustumCulled = false;
  dome.renderOrder = -1000;
  scene.add(dome);

  const type = renderTargetType(renderer);
  const cubeRT = new THREE.WebGLCubeRenderTarget(128, {
    type,
    format: THREE.RGBAFormat,
    generateMipmaps: true,
    minFilter: THREE.LinearMipmapLinearFilter,
    magFilter: THREE.LinearFilter
  });
  cubeRT.texture.colorSpace = THREE.LinearSRGBColorSpace;
  const cubeCamera = new THREE.CubeCamera(1, 36000, cubeRT);
  cubeCamera.position.set(0, 20, 0);
  scene.add(cubeCamera);

  function renderBackground(rendererRef, camera, target) {
    dome.position.copy(camera.position);
    material.uniforms.uSteps.value = qualitySteps;
    rendererRef.setRenderTarget(target);
    rendererRef.render(scene, camera);
  }

  let qualitySteps = 28;

  function updateCube(rendererRef, camera) {
    dome.position.copy(camera.position);
    cubeCamera.position.copy(camera.position);
    const previous = material.uniforms.uSteps.value;
    material.uniforms.uSteps.value = Math.min(previous, 18);
    cubeCamera.update(rendererRef, scene);
    material.uniforms.uSteps.value = previous;
  }

  function setQualitySteps(steps) {
    qualitySteps = steps;
    material.uniforms.uSteps.value = steps;
  }

  return {
    uniforms,
    material,
    scene,
    dome,
    cubeRT,
    cubeCamera,
    renderBackground,
    updateCube,
    setQualitySteps
  };
}
