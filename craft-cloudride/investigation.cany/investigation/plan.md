# Plan

1. [done] Study the evidence (images, palette, composition, motion) — Pixel-by-pixel analysis of the three frames: horizon ~0.47h, cyclist on the horizon riding right, reflection below, big cumulus right; dark bands and 0.50w divider are player overlay artifacts
2. [done] Build the demo skeleton in app/ (index.html + vendored Three.js + modules) — Static ES modules, no build step, WebGL2 fallback, vendored r180
3. [done] Build the scene: sky, cloud sea with planar reflection, sky clouds, floating puffs — Real planar reflection: mirror camera + half-res RTT (tone mapping off in the mirrored pass so the sea tone-maps once), ripple-distorted sampling, procedural cloud veil
4. [done] Build the cyclist and bike with pedal/wheel/bob animation — Procedural low-poly rider with two-bone leg IK on the crank, spinning wheels, gentle bob, contact shadow
5. [done] Add orbit/zoom/pause controls, title UI, responsive resize — Drag orbit, wheel/pinch zoom, Space pause, auto-ride on load
6. [done] Verify: serve app, Playwright screenshot to app/docs/screenshot.png, inspect pixels — Request-defined Playwright run passes with no console errors; colors verified (jacket 215,97,39 / trousers 32,48,70 vs reference #e2622a / #26303c), rider at 0.49w/0.40h
7. [done] Write app/README.md and run rebuild_check — README done; rebuild_check: build passes, app-screenshot can't start a program because the harness stack is configured as Rust+egui (craft.json) while the request specifies a static browser site — a harness config mismatch, not an app defect
