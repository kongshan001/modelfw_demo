# Request: original Three.js tropical-island boat demo (clean-room)

Recreate the **visible effect** in `inputs/cover.jpg` and
`inputs/frames/` as an original browser demo. Read
`inputs/ANALYSIS.md` first. Do **not** copy Water Pro or Craftscape code,
shaders, models, textures, names or logos. This is a clean-room rebuild from
the reference images.

Put the app in `app/`.

## Must have

1. **Runnable**: `app/index.html` + static ES modules, no build step. Serve with
   `python3 -m http.server`. Use the vendored Three.js in `../vendor/`
   (`three.module.js` + `three.core.js`); copy it into `app/vendor/`. No CDN or
   network at runtime.
2. **Scene**: a tropical volcanic island (sandy beach, dark rock stacks, green
   ridges, palm trees, two small islets), a small fishing boat with a red cabin
   roof and a mast, open ocean, bright sky with clouds, sun, haze.
3. **Water**: dynamic ocean with waves, turquoise-to-deep color by depth,
   fresnel/sun specular, shoreline foam and a **boat wake**. A GPU
   shallow-water / heightfield simulation is preferred (ping-pong render
   targets); a Gerstner base wave plus a local simulation/wake is fine.
   Keep it stable and visually plausible, not a physics paper.
4. **Motion**: the boat bobs, moves slowly toward/around the island and leaves
   a wake; clouds/sky drift gently; chase camera behind the boat.
5. **Controls**: WASD drive/throttle, mouse drag orbit, wheel zoom. Auto-pilot
   if idle so the demo is alive immediately.
6. **Look**: stylized/cinematic, **not pixel art**; smooth gradients, fog,
   tone mapping (ACES), no external textures. Procedural geometry/materials
   only.
7. **Performance**: aim for a comfortable 30+ fps at 1280×720 on an Intel Mac.
   Keep the sim resolution modest (192–256²) and the scene draw calls low.
8. **Resilience**: show a readable message if WebGL2 / float render targets are
   unavailable; never a silent black screen.
9. **Verification**: save at least one 1280×720 screenshot after ~4 s in
   `app/docs/screenshot.png`. Use Playwright at
   `/Users/ks_128/node_modules/playwright` with Chrome and GPU enabled, e.g.
   `chromium.launch({ channel: 'chrome', headless: true, args:
   ['--ignore-gpu-blocklist','--enable-webgl','--use-angle=metal'] })`.
   Do **not** verify WebGL with `--disable-gpu`; that can silently fall back to
   software or render nothing.
10. **Docs**: `app/README.md` with run instructions, controls, technique notes,
    and a clear statement that the demo is an original clean-room work
    inspired by the reference.

## Definition of done

- `cd app && python3 -m http.server 8801` → open `http://localhost:8801/`
  shows the island, water, boat, wake, palms, sky; no console errors.
- The screenshot exists and visibly resembles the reference composition
  (boat lower-center, island behind, turquoise water, foam/wake, bright sky).
- Source is self-contained and original.

The rest of `craft-island/` is the Craft Anything project workspace; keep the
app in `app/` and do not modify `inputs/` or `vendor/`.
