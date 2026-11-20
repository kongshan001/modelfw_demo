# ENDLESS DRIFT — an endless cloud ride

A stylized cyclist rides across a sea of soft low-poly clouds under a bright
blue sky, mirrored in the cloud sea below. Dreamy, pastel, editorial — and
fully self-contained.

**This is an original clean-room work.** It was rebuilt from the visible
reference only (scene composition, palette and motion described in the
project's input analysis). No code, shaders, models, textures, logos, type or
text from the original were copied or consulted; all geometry, shading and
motion are written from scratch, and the title is an original one.

## Run

No build step, no network access at runtime — plain static ES modules:

```sh
cd app
python3 -m http.server 8801
```

Then open <http://localhost:8801/>. WebGL 2 is required; a readable fallback
message is shown if the browser does not support it.

The folder also contains a small std-only Rust launcher (`cargo build`, then
`./target/debug/cloudride`) that serves the same demo on the same port —
that is the program the project's automated check builds and runs. With
`cloudride --screenshot <file.png>` it serves the demo, captures it with the
same Playwright run as the verification step below, saves the picture to the
given path and exits.

## Controls

- The ride starts automatically; no input is needed.
- **Drag** — orbit the camera around the rider.
- **Mouse wheel** (or two-finger pinch) — zoom in and out.
- **Space** — pause / resume the ride.

## Technique notes

- **Scene**: bright blue sky dome with a hazy horizon and a soft sun glow from
  the upper left; large cumulus masses drift across the right of the sky with
  smaller clouds on the left; wide flattened banks straddle the horizon;
  scattered puffs float around the rider, some close to the camera for depth.
- **Reflection**: a real planar reflection — the camera is mirrored across the
  cloud-sea plane into a half-resolution render target, and the sea surface
  samples it with a soft two-tap blur and a gentle ripple distortion. A
  translucent procedural cloud layer veils the mirror, and the surface fades
  into horizon haze with distance.
- **Cyclist**: built from procedural low-poly primitives (capsules, spheres,
  cylinders, boxes). The legs pedal through a simple two-bone IK with the feet
  locked to the crank; wheels spin, the body bobs gently, and a soft contact
  shadow grounds the bike on the cloud sea.
- **Look**: flat-shaded low-poly geometry, vertex-coloured clouds
  (white tops, blue-grey undersides), hemisphere + directional sunlight,
  ACES filmic tone mapping, sRGB output and distance fog.
- **Performance**: one draw call per cloud (instancing for the floating puffs),
  a half-resolution reflection target, and a modest total draw-call count —
  comfortably above 30 fps at 1280×720 on an Intel Mac.

## Verify

With the app served on port 8801:

```sh
node tools/screenshot.cjs
```

saves a 1280×720 screenshot taken ~4 s after load to `docs/screenshot.png`
(Playwright + Chrome, GPU enabled) and fails loudly if the page logged any
console errors. A GPU-recorded 8.6 s clip of the ride is in `docs/demo.mp4`.

## Credits

- Three.js r180 (MIT, © Three.js Authors) — vendored in `vendor/`, with
  license. Everything else here is original.
