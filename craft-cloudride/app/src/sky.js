// Bright blue sky dome with a hazy horizon and a soft sun glow from the upper left.

import * as THREE from '../vendor/three.module.js';
import { PALETTE } from './palette.js';

export function createSky(scene) {
  const geometry = new THREE.SphereGeometry(550, 48, 24);
  const material = new THREE.ShaderMaterial({
    side: THREE.BackSide,
    depthWrite: false,
    fog: false,
    uniforms: {
      uZenith: { value: new THREE.Color(PALETTE.skyTop) },
      uMid: { value: new THREE.Color(PALETTE.skyMid) },
      uHorizon: { value: new THREE.Color(PALETTE.horizon) },
      uSun: { value: new THREE.Color(PALETTE.sun) },
      uSunDir: { value: new THREE.Vector3(-0.5, 0.62, -0.3).normalize() },
    },
    vertexShader: /* glsl */`
      varying vec3 vDir;
      void main() {
        vDir = position;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: /* glsl */`
      uniform vec3 uZenith;
      uniform vec3 uMid;
      uniform vec3 uHorizon;
      uniform vec3 uSun;
      uniform vec3 uSunDir;
      varying vec3 vDir;
      void main() {
        vec3 dir = normalize(vDir);
        float h = clamp(dir.y, -1.0, 1.0);
        vec3 col = mix(uHorizon, uMid, smoothstep(0.0, 0.20, h));
        col = mix(col, uZenith, smoothstep(0.20, 0.70, h));
        float s = max(dot(dir, uSunDir), 0.0);
        col += uSun * (pow(s, 28.0) * 0.85 + pow(s, 6.0) * 0.20);
        gl_FragColor = vec4(col, 1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }
    `,
  });
  const dome = new THREE.Mesh(geometry, material);
  dome.renderOrder = -20;
  scene.add(dome);
  return dome;
}
