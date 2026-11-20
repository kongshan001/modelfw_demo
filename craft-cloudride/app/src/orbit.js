// Simple orbit camera: drag to orbit around the rider, wheel (or pinch) to
// zoom, Space to pause/resume the ride. A gentle idle sway keeps the framing
// alive even when untouched.

import * as THREE from '../vendor/three.module.js';

function clamp(v, lo, hi) {
  return Math.min(Math.max(v, lo), hi);
}

export function createOrbit(camera, dom) {
  const state = {
    yaw: -0.42,
    pitch: 0.028,
    dist: 23.5,
    target: new THREE.Vector3(1.0, 0.40, 0),
    paused: false,
    dragging: false,
    baseYaw: 0,
    basePitch: 0,
    startX: 0,
    startY: 0,
    baseDist: 0,
    pinchDist: 0,
    pointers: new Map(),
  };

  function apply(t) {
    const swayYaw = state.dragging ? 0 : Math.sin(t * 0.12) * 0.006;
    const swayPitch = state.dragging ? 0 : Math.sin(t * 0.09 + 1.3) * 0.003;
    const yaw = state.yaw + swayYaw;
    const pitch = state.pitch + swayPitch;
    const cp = Math.cos(pitch);
    camera.position.set(
      state.target.x + Math.sin(yaw) * cp * state.dist,
      state.target.y + Math.sin(pitch) * state.dist,
      state.target.z + Math.cos(yaw) * cp * state.dist
    );
    if (camera.position.y < 0.7) camera.position.y = 0.7;
    camera.lookAt(state.target);
  }

  function beginDrag(e) {
    state.dragging = true;
    dom.classList.add('dragging');
    state.baseYaw = state.yaw;
    state.basePitch = state.pitch;
    state.startX = e.clientX;
    state.startY = e.clientY;
  }

  dom.addEventListener('pointerdown', (e) => {
    dom.setPointerCapture(e.pointerId);
    state.pointers.set(e.pointerId, [e.clientX, e.clientY]);
    if (state.pointers.size === 1) {
      beginDrag(e);
    } else if (state.pointers.size === 2) {
      state.dragging = false;
      dom.classList.remove('dragging');
      const pts = [...state.pointers.values()];
      state.pinchDist = Math.hypot(pts[0][0] - pts[1][0], pts[0][1] - pts[1][1]);
      state.baseDist = state.dist;
    }
  });

  dom.addEventListener('pointermove', (e) => {
    if (!state.pointers.has(e.pointerId)) return;
    state.pointers.set(e.pointerId, [e.clientX, e.clientY]);
    if (state.pointers.size === 1 && state.dragging) {
      state.yaw = state.baseYaw - (e.clientX - state.startX) * 0.006;
      state.pitch = clamp(state.basePitch + (e.clientY - state.startY) * 0.004, -0.10, 0.55);
    } else if (state.pointers.size === 2) {
      const pts = [...state.pointers.values()];
      const d = Math.hypot(pts[0][0] - pts[1][0], pts[0][1] - pts[1][1]);
      state.dist = clamp(state.baseDist * (state.pinchDist / Math.max(d, 1)), 14, 46);
    }
  });

  function endPointer(e) {
    state.pointers.delete(e.pointerId);
    if (state.pointers.size === 1) {
      const last = [...state.pointers.values()][0];
      state.dragging = true;
      state.baseYaw = state.yaw;
      state.basePitch = state.pitch;
      state.startX = last[0];
      state.startY = last[1];
    } else if (state.pointers.size === 0) {
      state.dragging = false;
      dom.classList.remove('dragging');
    }
  }
  dom.addEventListener('pointerup', endPointer);
  dom.addEventListener('pointercancel', endPointer);

  dom.addEventListener(
    'wheel',
    (e) => {
      e.preventDefault();
      state.dist = clamp(state.dist * Math.exp(e.deltaY * 0.0012), 14, 46);
    },
    { passive: false }
  );

  window.addEventListener('keydown', (e) => {
    if (e.code === 'Space') {
      state.paused = !state.paused;
      e.preventDefault();
    }
  });

  return {
    get paused() {
      return state.paused;
    },
    update(_dt, t) {
      apply(t);
    },
  };
}
