# Request: original Three.js endless cloud ride (clean-room)

Recreate the **visible effect** in `inputs/cover.jpg` and `inputs/frames/` as
an original browser demo. Read `inputs/ANALYSIS.md` first. Do **not** copy the
original site's code, shaders, models, textures, logos, type, or the phrases
"The infinite ride" / "uyuni". Put the app in `app/`.

## Must have

1. **Runnable**: `app/index.html` + static ES modules, no build step. Serve
   with `python3 -m http.server`. Use the vendored Three.js in `../vendor/`
   (`three.module.js` + `three.core.js`); copy it into `app/vendor/`. No CDN or
   runtime network. WebGL 2, readable fallback message if unsupported.
2. **Scene**: a stylized cyclist (orange jacket, dark trousers, white helmet,
   small backpack) on a dark bicycle, riding across a **sea of soft low-poly
   clouds** under a bright blue sky. A **mirror reflection** of the cyclist and
   clouds in the cloud sea; scattered floating cloud puffs; a hazy horizon.
   No branding or text from the original; use an original title
   ("ENDLESS DRIFT") or none.
3. **Reflection**: a real planar reflection is preferred (reflect the camera
   across the cloud-sea plane into an RTT and sample it in the sea shader),
   softened by a translucent/procedural cloud layer. A mirrored clone is an
   acceptable fallback if it reads convincingly. The reflection is the key
   visual, not an afterthought.
4. **Motion**: the bike rides forward; wheels spin; the legs pedal; the cyclist
   bobs; clouds drift slowly; the camera tracks from a side/three-quarter view.
   Seamless loop; no user input required.
5. **Controls**: mouse drag to orbit, wheel to zoom, Space to pause/resume.
   Auto-ride on load.
6. **Look**: dreamy pastel low-poly, smooth gradients, fog/haze, ACES tone
   mapping; procedural geometry/materials only, no external textures, **not
   pixel art**.
7. **Performance**: 30+ fps at 1280×720 on an Intel Mac; modest draw calls.
8. **Verification**: save a 1280×720 screenshot after ~4 s to
   `app/docs/screenshot.png`. Use Playwright at
   `/Users/ks_128/node_modules/playwright` with Chrome and GPU enabled:
   `chromium.launch({ channel: 'chrome', headless: true, args:
   ['--ignore-gpu-blocklist','--enable-webgl','--use-angle=metal'] })`.
   Do not verify WebGL with `--disable-gpu`.
9. **Docs**: `app/README.md` with run instructions, controls, technique notes,
   and a clear statement that it is an original clean-room work inspired by
   the visible reference only.

## Definition of done

- `cd app && python3 -m http.server 8801` → open `http://localhost:8801/`
  shows the cyclist, cloud sea, reflection, floating clouds and blue sky; no
  console errors.
- The screenshot exists and resembles the reference composition (cyclist
  riding through clouds, mirrored below, airy sky).
- Source is self-contained and original.

Keep the app in `app/`; do not modify `inputs/` or `vendor/`.
