# Iterations

A short, dated record of what changed, what broke, and what the measurements
were. Every screenshot/GIF/MP4 in `../docs/` was produced by this project's own
renderer; no frame from the reference video is redistributed.

## 2026-11-19 — identification

- `yt-dlp -J` on `BV1BRHw6fEfW`: title, uploader **可爱的管哥哥**, 29.43 s,
  upload date 2026-10-24. The description contains
  `https://gitee.com/tube-brother/vue3-threejs`.
- Downloaded the video and made a 1 fps contact sheet plus frames at 2/12/18/22/27 s
  with ffmpeg. No subtitles; the on-screen UI and the description carry the
  source link.
- Cloned the Gitee repo. `package.json`: Three 0.177, `@takram/three-clouds`
  0.7.6, `@takram/three-atmosphere` 0.19.1, `postprocessing` 6.39.5, Vue 3.
  `docs/water-scene.md` describes JONSWAP + FFT water, Takram clouds and the
  commercial Water Pro reference. No LICENSE file; Gitee API `license: null`
  (12 stars / 11 forks on this date).
- License decision: **clean-room**. Public repo without a license means no reuse.
  Takram is MIT (verified on npm and GitHub); Three.js is MIT. The commercial
  Water Pro/Sky Pro code and the ripped GLB assets are not used.

## First render / environment

- Started with a 64³ volume, 28-step sky at 0.52×, 8 Gerstner waves, procedural
  island and ship, and a sky cubemap.
- Headless Chrome on this machine reports
  `ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)), SwiftShader driver)`
  and renders at roughly 1 fps. The requested `--use-angle=metal` also selects
  SwiftShader on the Intel HD 6000.
- Headed Chrome with `--use-angle=gl` reaches the real GPU:
  `ANGLE (Intel Inc., Intel(R) HD Graphics 6000, OpenGL 4.1)`, ~60 fps at the
  first render. The verifier therefore probes Metal, records the SwiftShader
  fallback, and relaunches with GL.

## Composition pass

- First screenshot had the island filling the frame and the ship overlapping
  it. Pulled the orbit back (radius 62 → 96 m), moved the ship from (13, 9) to
  (26, 42), then to a 1.15× scale; raised the target to y=4.
- Lowered the camera pitch from polar 1.29 to 1.41 rad so the horizon sits at
  roughly one third of the frame (closer to the reference's framing) and the
  ship's masts overlap the sky.
- The island looked muddy. Sand/grass/rock vertex colours were lightened,
  the rock-slope threshold raised, and the palms widened (9 fronds, taller).
  Added a cool fill light and a small ambient lift so the backlit sails read.

## Sky / cloud pass

- Initial 64³ noise at 1/7000 scale produced an overcast beige wall with a
  visible rectangular lattice. Fixes, in order:
  1. domain-warped the tileable noise at generation time;
  2. raised the volume to 96³;
  3. added a second 3D fetch at 3.2× frequency for high-frequency erosion;
  4. raised the cloud base from 950 m to 1450 m, narrowed coverage
     (0.40 → 0.28 at sunset), and sharpened the density threshold;
  5. brightened cloud ambient with the sky palette and kept a warm sun term.
- A very visible bug: `window.__demo.pause(true)` froze palette transitions
  because `approachPalette()` used the simulation `dt`. Switched it to the
  real frame delta (rawDt) so screenshots can pause waves/clouds without
  freezing a preset cross-fade.
- The sky target started at 0.52×; it is now 0.60× / 30 steps at medium, with a
  5-tap tent filter in the blit. This removed most of the upscale grain while
  staying at 45–52 fps.

## Water pass

- The first water reflected an orange sunset sky at full strength and looked
  brown. Added a blue-tinted, 0.78× reflection, capped the Fresnel mix at 0.62,
  deepened the body colours, and reduced the procedural normal strength
  (0.55 → 0.16).
- Tightened the turquoise lagoon from 135/170 m to 70 m and the sand tint to
  38 m, so the foreground is deep teal while the island keeps a shelf.
- Added a reflection-path term for the sun glitter column.
- **Underwater terrain artifact**: the 84×84 island plane sat only 0.85 m below
  y=0; wave troughs exposed it as brown polygons in the foreground. Sinking the
  plane edge by 9 m removed them.
- **Horizon seam**: the water disc ended at 8 km and the sky dome at 9 km,
  producing a hard edge. The disc is now 18 km, the dome 26 km, the camera/far
  cubes 36–40 km, and the water fog runs to 12 km.

## Verification harness

- Attempted Playwright `recordVideo` in a headed context. The recording was
  frozen on the loading screen at 1280×720 even though the page itself reported
  `window.__ready === true` and was visible. Checked 8 frames over 7.5 s: all
  loading screen. Cause is the headed window being occluded on macOS; Playwright's
  screencast did not receive new compositor frames.
- Replaced it with deterministic stepped screenshots: pause the clock, step
  `waveTime/cloudTime` by 1/12 s, set the camera/preset, and capture 90 frames.
  ffmpeg encodes MP4 (1280×720, 12 fps, 7.5 s) and GIF (960×540, 12 fps, 7.5 s).
  Added a mid-clip average-colour check so a frozen/black capture fails.
- `verify.sh` starts its own server, runs the harness, and re-validates the PNG
  header, FPS, durations, dimensions, console errors, page errors, external
  requests, and the JSON report.

## Final verification (2026-11-19 20:40–20:49)

```
GPU (Metal probe): ANGLE (... SwiftShader ...)
GPU (final):       ANGLE (Intel Inc., Intel(R) HD Graphics 6000, OpenGL 4.1)
GPU fallback:      ANGLE Metal selected SwiftShader; retried with ANGLE GL.
day    fps=50.7  quality=medium  skyRT=768x432
sunset fps=45.3  quality=medium  skyRT=768x432
dusk   fps=52.0  quality=medium  skyRT=768x432
console errors: 0
external requests: 0
mp4: 1280x720 7.50 s
gif: 960x540 7.50 s
VERIFY: PASS
```

Artifacts: `docs/shots/waterpro-clouds-{day,sunset,dusk}.png`,
`docs/shots/waterpro-clouds-contact.png`,
`docs/waterpro-clouds-demo.mp4`, `docs/waterpro-clouds-demo.gif`,
`docs/waterpro-clouds-verification.json`.

## Repro notes

- Run from `threejs-water-clouds/`: `./verify.sh`.
- The script is headed by design (hardware WebGL); `HEADLESS=1` will usually
  fall back to SwiftShader on this Mac and fail the hardware check.
- The reference video and Gitee files live only in `/tmp` during analysis; they
  are not part of this project. No reference frames appear in the docs.
