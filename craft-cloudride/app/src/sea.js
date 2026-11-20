// The cloud sea: a flat reflective surface that samples a real planar reflection
// (the camera mirrored across the sea plane, rendered into a render target),
// veiled by a translucent procedural cloud layer and fading into the horizon haze.

import * as THREE from '../vendor/three.module.js';
import { PALETTE } from './palette.js';

const NOISE_GLSL = /* glsl */`
  float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
  float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
  }
  float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
      v += a * vnoise(p);
      p = p * 2.17 + vec2(13.7, 7.1);
      a *= 0.5;
    }
    return v;
  }
`;

export function createSea(scene, renderer) {
  const mirrorCam = new THREE.PerspectiveCamera();
  const rt = new THREE.WebGLRenderTarget(512, 288, {
    minFilter: THREE.LinearFilter,
    magFilter: THREE.LinearFilter,
  });
  // The target stores raw linear values (render targets skip the output
  // color-space encode), and tone mapping is disabled for the mirrored pass
  // below, so the sea shader tone-maps the mix exactly once.
  rt.texture.colorSpace = THREE.LinearSRGBColorSpace;

  const texMatrix = new THREE.Matrix4();
  const bias = new THREE.Matrix4().set(
    0.5, 0, 0, 0.5,
    0, 0.5, 0, 0.5,
    0, 0, 0.5, 0.5,
    0, 0, 0, 1
  );
  const flip = new THREE.Matrix4();
  const tmpM = new THREE.Matrix4();
  const q = new THREE.Quaternion();
  const sizeV = new THREE.Vector2();

  const surface = new THREE.Mesh(
    new THREE.PlaneGeometry(1200, 1200),
    new THREE.ShaderMaterial({
      fog: false,
      uniforms: {
        uReflect: { value: rt.texture },
        uReflectMatrix: { value: new THREE.Matrix4() },
        uShallow: { value: new THREE.Color(PALETTE.seaShallow) },
        uDeep: { value: new THREE.Color(PALETTE.seaDeep) },
        uHorizon: { value: new THREE.Color(PALETTE.horizon) },
        uTime: { value: 0 },
      },
      vertexShader: /* glsl */`
        varying vec3 vWorld;
        void main() {
          vec4 wp = modelMatrix * vec4(position, 1.0);
          vWorld = wp.xyz;
          gl_Position = projectionMatrix * viewMatrix * wp;
        }
      `,
      fragmentShader: /* glsl */`
        uniform sampler2D uReflect;
        uniform mat4 uReflectMatrix;
        uniform vec3 uShallow;
        uniform vec3 uDeep;
        uniform vec3 uHorizon;
        uniform float uTime;
        varying vec3 vWorld;
        ${NOISE_GLSL}
        void main() {
          vec4 rp = uReflectMatrix * vec4(vWorld, 1.0);
          vec2 uv = rp.xy / rp.w;
          float rip = vnoise(vWorld.xz * 0.30 + vec2(uTime * 0.18, 0.0));
          uv += (vec2(rip, fbm(vWorld.xz * 0.42 + vec2(0.0, uTime * 0.12))) - 0.5) * 0.010;

          vec3 refl = texture2D(uReflect, uv).rgb * 0.5
                    + texture2D(uReflect, uv + vec2(0.0016, 0.0)).rgb * 0.25
                    + texture2D(uReflect, uv + vec2(0.0, 0.0016)).rgb * 0.25;

          float dist = distance(vWorld.xz, cameraPosition.xz);
          vec3 sea = mix(uShallow, uDeep, smoothstep(12.0, 80.0, dist));

          float fluff = fbm(vWorld.xz * 0.055 + vec2(uTime * 0.05, uTime * 0.03));
          fluff = smoothstep(0.60, 0.78, fluff);

          vec3 col = mix(sea, vec3(0.98), fluff * 0.6);
          col = mix(refl, col, 0.38 + fluff * 0.25);

          col = mix(col, uHorizon, smoothstep(55.0, 250.0, dist));
          gl_FragColor = vec4(col, 1.0);
          #include <tonemapping_fragment>
          #include <colorspace_fragment>
        }
      `,
    })
  );
  surface.rotation.x = -Math.PI / 2;
  surface.renderOrder = 5;
  scene.add(surface);

  const veil = new THREE.Mesh(
    new THREE.PlaneGeometry(800, 800),
    new THREE.ShaderMaterial({
      transparent: true,
      depthWrite: false,
      fog: false,
      uniforms: {
        uTime: { value: 0 },
      },
      vertexShader: /* glsl */`
        varying vec3 vWorld;
        void main() {
          vec4 wp = modelMatrix * vec4(position, 1.0);
          vWorld = wp.xyz;
          gl_Position = projectionMatrix * viewMatrix * wp;
        }
      `,
      fragmentShader: /* glsl */`
        uniform float uTime;
        varying vec3 vWorld;
        ${NOISE_GLSL}
        void main() {
          float p1 = fbm(vWorld.xz * 0.09 + vec2(uTime * 0.07, uTime * 0.05));
          p1 = smoothstep(0.52, 0.80, p1);
          float p2 = fbm(vWorld.xz * 0.05 + vec2(uTime * 0.04, -uTime * 0.03));
          p2 = smoothstep(0.58, 0.86, p2);
          float a = (p1 * 0.6 + p2 * 0.25) * 0.34;
          gl_FragColor = vec4(vec3(0.985), a);
          #include <tonemapping_fragment>
          #include <colorspace_fragment>
        }
      `,
    })
  );
  veil.rotation.x = -Math.PI / 2;
  veil.position.y = 0.03;
  veil.renderOrder = 20;
  scene.add(veil);

  function resize() {
    renderer.getDrawingBufferSize(sizeV);
    const w = Math.max(1, Math.min(Math.floor(sizeV.x / 2), 1280));
    const h = Math.max(1, Math.min(Math.floor(sizeV.y / 2), 720));
    if (rt.width !== w || rt.height !== h) rt.setSize(w, h);
  }

  // Renders the world into the reflection target with a camera mirrored across
  // the sea plane (y = 0), then refreshes the texture-projection matrix the
  // sea shader samples with.
  function renderReflection(scene, camera) {
    resize();
    surface.visible = false;
    veil.visible = false;

    camera.updateMatrixWorld();
    mirrorCam.aspect = camera.aspect;
    mirrorCam.fov = camera.fov;
    mirrorCam.near = camera.near;
    mirrorCam.far = camera.far;
    mirrorCam.updateProjectionMatrix();
    mirrorCam.position.copy(camera.position);
    mirrorCam.position.y = -mirrorCam.position.y;
    flip.makeScale(1, -1, 1);
    tmpM.multiplyMatrices(flip, camera.matrixWorld);
    q.setFromRotationMatrix(tmpM);
    mirrorCam.quaternion.copy(q);
    mirrorCam.updateMatrixWorld(true);

    // Tone mapping is applied once, in the sea shader (the reflection is
    // mixed with the sea colour there), so the mirrored pass stores raw
    // linear colour.
    const prevToneMapping = renderer.toneMapping;
    renderer.toneMapping = THREE.NoToneMapping;
    renderer.setRenderTarget(rt);
    renderer.render(scene, mirrorCam);
    renderer.setRenderTarget(null);
    renderer.toneMapping = prevToneMapping;

    texMatrix.multiplyMatrices(bias, mirrorCam.projectionMatrix).multiply(mirrorCam.matrixWorldInverse);
    surface.material.uniforms.uReflectMatrix.value.copy(texMatrix);

    surface.visible = true;
    veil.visible = true;
  }

  function update(t) {
    surface.material.uniforms.uTime.value = t;
    veil.material.uniforms.uTime.value = t;
  }

  return { surface, veil, renderReflection, update, resize };
}
