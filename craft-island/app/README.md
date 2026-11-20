# Tropical Isle — clean-room Three.js demo

A tropical volcanic island with a small fishing boat, open ocean with a
simulated wake, and a bright hazy sky. **This is an original clean-room work
inspired by the reference imagery only**: all geometry, shading and motion are
procedural, written from scratch, and no code, models, textures, names or
logos were copied from the original.

## Run

No build step — just serve the folder and open it:

```sh
cd app
python3 -m http.server 8801
# open http://localhost:8801/
```

Needs a browser with WebGL 2 (Chrome, Edge, Firefox, Safari 15+). If float
render targets are unavailable the demo switches to a simpler water mode
(Gerstner waves only, painted wake) and shows a small note instead of failing.
If WebGL 2 itself is missing, a readable message is shown.

There is also an optional launcher binary (not needed for the demo — the page
itself has no build step). `cargo build` builds it; running it serves the
folder like the Python command above and opens the browser when run from a
terminal, and `./target/debug/tropical-isle --screenshot out.png` saves a
capture of the demo and exits.

## Controls

- **W / S** or **Up / Down** — throttle (forward / gentle reverse)
- **A / D** or **Left / Right** — steer
- **Mouse drag** — orbit the camera
- **Mouse wheel** — zoom in/out
- After ~6 s of no input the boat returns to **auto-pilot**, cruising around
  the island, so the demo stays alive on its own.

## Technique notes

- **Water**: a Gerstner wave field (two analytic base waves, one fine ripple)
  on a large displaced mesh, plus a **GPU heightfield simulation**
  (128² ping-pong half-float render targets) in a patch that follows the boat.
  The shallow-water wave equation runs at ~240 substeps/s with a velocity
  advection term, so the boat's wake is a real simulated V-wake, not a sprite.
  Foam comes from wave curvature, shoreline wash and the simulated wake.
- **Shore**: the island terrain is baked once from above into a height
  texture; the water shader uses it for turquoise-to-deep color by depth,
  shoreline foam and bed drop-off.
- **Island**: noise-driven heightfield (volcanic cone + fBm ridges) with
  vertex colors for sand / vegetation / rock, instanced rock stacks and sea
  stacks, two islets, and palm trees merged into a single draw call.
- **Boat**: lofted hull from cross-sections, deck, cabin with red roof and
  dark windows, mast, trailing red buoys and deck cargo. It bobs and tilts
  with the analytic water surface.
- **Sky**: shader dome gradient with sun and horizon haze, plus drifting
  puffy clouds from merged low-poly spheres with vertex-colored bases.
- **Look**: ACES filmic tone mapping, exp² distance haze matching the horizon
  color, all colors specified in sRGB and converted to linear internally.
- **Performance**: ~35 draw calls, 128² simulation; comfortable on integrated
  GPUs at 1280×720.

## Verification

`docs/shot.mjs` serves the folder on port 8801, opens Chrome (GPU/Metal),
waits until the page's simulation clock reaches ~4.5 s (on machines where
Chrome falls back to software WebGL this takes longer than 4.5 s of wall
clock, up to the cap) and saves a 1280×720 screenshot to
`docs/screenshot.png`:

```sh
node docs/shot.mjs [out.png] [wall-clock cap in ms, default 60000]
```

The URL parameter `?shot=1` hides the HUD and freezes the simulation at the
fixed capture time so the screenshot is deterministic.

## GPU verification

`docs/screenshot.png` and `docs/demo.mp4` were captured on this machine with
Playwright + Chrome (Metal) at 1280×720. The first real-GPU capture exposed
three runtime issues that the software-WebGL check could not see: uninitialised
simulation targets, per-frame wake accumulation, and foam thresholds that
whitewashed the sea. They are fixed: the sim targets are zero-initialised, the
wake stamps are dt-scaled and the height field is clamped, and foam is limited
to the wake / shoreline. See `../docs/迭代记录.md`.

## Credits

- Engine: Three.js r180, MIT license (see `vendor/LICENSE-three.txt`).
- Reference: visible imagery only (analysis notes in the parent project);
  this demo shares no code or assets with the original.
