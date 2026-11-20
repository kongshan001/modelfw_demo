// Damped orbit camera: drag to orbit, wheel to dolly, slow drift when idle.

import * as THREE from '../vendor/three.module.js';

export class OrbitRig {
  constructor(camera, element, target = new THREE.Vector3()) {
    this.camera = camera;
    this.element = element;
    this.target = target.clone();
    this.theta = 0.55;
    this.phi = 1.41;
    this.radius = 96;

    this.desired = { theta: this.theta, phi: this.phi, radius: this.radius };
    this.limits = { minRadius: 34, maxRadius: 165, minPhi: 0.22, maxPhi: 1.46 };

    this.dragging = false;
    this.lastX = 0;
    this.lastY = 0;
    this.lastInteraction = -100;
    this.autoOrbit = true;
    this.elapsed = 0;

    this._onPointerDown = this.onPointerDown.bind(this);
    this._onPointerMove = this.onPointerMove.bind(this);
    this._onPointerUp = this.onPointerUp.bind(this);
    this._onWheel = this.onWheel.bind(this);
    this._onContextMenu = (event) => event.preventDefault();

    element.addEventListener('pointerdown', this._onPointerDown);
    element.addEventListener('pointermove', this._onPointerMove);
    element.addEventListener('pointerup', this._onPointerUp);
    element.addEventListener('pointercancel', this._onPointerUp);
    element.addEventListener('wheel', this._onWheel, { passive: false });
    element.addEventListener('contextmenu', this._onContextMenu);

    this.apply(1);
  }

  onPointerDown(event) {
    if (event.button !== 0 && event.button !== 2) return;
    this.dragging = true;
    this.lastX = event.clientX;
    this.lastY = event.clientY;
    this.lastInteraction = this.elapsed;
    this.element.setPointerCapture(event.pointerId);
  }

  onPointerMove(event) {
    if (!this.dragging) return;
    const dx = event.clientX - this.lastX;
    const dy = event.clientY - this.lastY;
    this.lastX = event.clientX;
    this.lastY = event.clientY;
    this.desired.theta -= dx * 0.0042;
    this.desired.phi = THREE.MathUtils.clamp(
      this.desired.phi - dy * 0.0034,
      this.limits.minPhi,
      this.limits.maxPhi
    );
    this.lastInteraction = this.elapsed;
  }

  onPointerUp(event) {
    this.dragging = false;
    if (this.element.hasPointerCapture(event.pointerId)) {
      this.element.releasePointerCapture(event.pointerId);
    }
  }

  onWheel(event) {
    event.preventDefault();
    const scale = Math.exp(event.deltaY * 0.0011);
    this.desired.radius = THREE.MathUtils.clamp(
      this.desired.radius * scale,
      this.limits.minRadius,
      this.limits.maxRadius
    );
    this.lastInteraction = this.elapsed;
  }

  reset() {
    this.desired.theta = 0.55;
    this.desired.phi = 1.41;
    this.desired.radius = 96;
  }

  update(dt) {
    this.elapsed += dt;
    if (this.autoOrbit && !this.dragging && this.elapsed - this.lastInteraction > 12) {
      this.desired.theta += dt * 0.018;
    }
    const k = 1 - Math.exp(-dt * 7);
    this.theta += (this.desired.theta - this.theta) * k;
    this.phi += (this.desired.phi - this.phi) * k;
    this.radius += (this.desired.radius - this.radius) * k;
    this.apply(1);
  }

  apply() {
    const sinPhi = Math.sin(this.phi);
    this.camera.position.set(
      this.target.x + this.radius * sinPhi * Math.sin(this.theta),
      this.target.y + this.radius * Math.cos(this.phi),
      this.target.z + this.radius * sinPhi * Math.cos(this.theta)
    );
    this.camera.lookAt(this.target);
  }
}
