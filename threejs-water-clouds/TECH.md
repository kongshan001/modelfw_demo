# TECH — Water Pro × Three.js volumetric clouds, clean-room study

## 1. Source identification

| Item | Finding | Confidence |
| --- | --- | --- |
| Video | Bilibili **BV1BRHw6fEfW**, 《waterpro+threejs体积云复刻，开源！！！》, uploader **可爱的管哥哥**, 29.43 s, uploaded 2026-10-24. Description: “将此项目开源，供大家参考… https://gitee.com/tube-brother/vue3-threejs”. No subtitles; the source link is in the description and the on-screen UI. | High |
| Repository | **Gitee `tube-brother/vue3-threejs`** (owner handle `tube-brother`; the video description links it — same identity not independently verified), description “threejs学习”. API on 2026-11-19: **12 stars, 11 forks, `license: null`**, created 2025-06-21, last commit 2026-11-13 (“更新岸边浮沫”), ~250 files. It is a Vue 3 + Vite + Three.js learning/demo project; the ocean scene is the default route. | High for metadata; high that no license file/field exists |
| Water reference | The scene UI and `docs/water-scene.md` reference **THREE.JS WATER PRO / Sky Pro** (`threejswaterpro.com`, `docs.threejswaterpro.com`). The Gitee doc states the sea is an independent WebGL2 implementation and that the paid product's code was **not** imported. The site is commercial; no public license was retrievable. | High that it is a commercial reference; license text unverified |
| Clouds | `@takram/three-clouds` **0.7.6**, `@takram/three-atmosphere` **0.19.1**, `@takram/three-geospatial` **0.9.1** (MIT). GitHub `takram-design-engineering/three-geospatial`: **MIT**, 1,777 stars on 2026-11-19. The Gitee repo vendors MIT cloud/atmosphere assets and uses `CloudsEffect` + `AerialPerspectiveEffect`. | High |
| Other dependencies | `three ^0.177.0`, `postprocessing 6.39.5`, Vue 3.5, Vite 6.2 (from `package.json`). The Gitee `ATTRIBUTION.md` says the ship/island/foam assets came from the commercial demo and that their redistribution license is unverified. | High |

### License conclusion

The Gitee repository is publicly readable but **has no license grant** (no
LICENSE file, `license: null` via the Gitee API). Public availability is not a
license. The video's “开源” claim therefore does not authorize reuse of its code
or its ripped assets. This project is a **clean-room implementation**:

- no code copied from `tube-brother/vue3-threejs`;
- no Water Pro / Sky Pro code or assets;
- no ship/island/foam assets from the commercial demo;
- the only third-party runtime code is **Three.js r180 (MIT)**, copied from the
  repository's existing `craft-island/app/vendor/`;
- Takram's MIT libraries are cited as a technique reference but are **not
  bundled**; our cloud shader is original.

This is the conservative reading of the requirement “先确认 license … 否则净室原创”.

## 2. What the reference actually does

The Gitee `docs/water-scene.md` and `src/components/water/*` describe a
substantially larger system than the clip can show:

### Water

- Three JONSWAP spectra at 256 m / 32 m / 4 m, evolved on the GPU with a 2D
  inverse FFT. Height and two horizontal displacement fields come from the same
  spectrum; derivatives and the Jacobian drive normals and crest compression.
- Foam: crest foam from elevated, compressed wave peaks, advected and decayed in
  a double-buffered coverage texture; filaments are extracted from a foam mask
  so gaps stay transparent. A separate shore-foam field is generated once from
  the island heightmap (~0–7 m band).
- Shading: wave-normal sky reflection, boat planar reflection with a depth
  mask, screen-depth refraction, depth absorption, Fresnel, GGX sun highlight,
  crest translucency, shore foam and a wake.
- Quality presets use 64²/128²/128²/256² FFT resolutions; the cloud reflection
  cubemap uses 128²/192²/256²/384² faces.
- CPU buoyancy samples the dominant wave mode for the ship/buoys.

### Clouds and sky

- Takram `CloudsEffect` + `AerialPerspectiveEffect`: 3D shape/detail noise,
  weather map, three cloud layers (750–1400 m, 1000–2200 m cumulus, 7500–8000 m
  high cloud), self-shadowing, multiple scattering, temporal reconstruction and
  atmospheric perspective. Assets: ~11.1 MiB of 128³/32³ noise, weather,
  turbulence, STBN and atmosphere LUTs.
- The main view uses temporal upsampling; a separate lower-quality cube capture
  feeds water reflections (one face every 0.25 simulated seconds, all six on
  parameter changes). Sun/moon directions use real ephemerides at Tokyo
  (139.8146°E, 35.7455°N); the atmosphere LUTs drive sun/sky/water colours.
- HDR sky and water are composed before a single tone-mapping step.

### Camera / extras

Orbit, walk and sail camera modes; underwater view with Snell's window,
single-scattering shafts, caustics, and post-processing; a nine-preset weather
UI. The video shows Sunset, daytime (Three.js Sky Pro), dusk, underwater, and
night-ish variants. Those are **reference observations**, not features of this
project.

## 3. Clean-room implementation

### 3.1 Rendering pipeline

```
sky dome (half-res RT, linear HDR)
        ↓ 5-tap blit + ACES + sRGB
default framebuffer
        ↓ depth clear
world: ocean + island + ship
        ↓
canvas (renderer.toneMapping = ACESFilmic)
```

- Renderer: WebGL2, `THREE.WebGLRenderer` (antialias, high-performance), r180,
  `pixelRatio = 1`, `outputColorSpace = SRGB`, ACES filmic, exposure 1.04–1.16.
- The sky is rendered into a linear `HalfFloatType` target at 0.60 (medium) of
  the canvas size and blitted with a 5-tap tent filter and ACES/sRGB conversion.
  This is the half-resolution decision for the expensive raymarch.
- The sky shader is used twice: the main half-res pass (30 steps) and a 128²
  `WebGLCubeRenderTarget` (18 steps, refreshed every 24 frames) sampled by the
  water. The cube is linear HDR; the water tone-maps once.
- Standard materials (island/ship) use the renderer's ACES tone mapping; the
  water includes three's `tonemapping_fragment`/`colorspace_fragment` so all
  objects share the same display transform.

### 3.2 Water

**Mesh.** Radial disc: 200 rings × 256 segments, radius 18,000 m, ring radius
`R·(i/N)^2.2` so density is highest near the orbit area. 51,200 vertices,
101,888 triangles, one draw, no index overflow.

**Waves.** Eight Gerstner waves (directions, amplitude, wavelength):

| # | direction (x,z) | amp (m) | λ (m) |
| ---: | --- | ---: | ---: |
| 1 | (0.940, 0.342) | 0.85 | 61.0 |
| 2 | (0.640, 0.768) | 0.55 | 37.0 |
| 3 | (-0.174, 0.985) | 0.38 | 24.0 |
| 4 | (0.985, -0.174) | 0.25 | 16.0 |
| 5 | (0.287, 0.958) | 0.16 | 10.5 |
| 6 | (-0.640, 0.768) | 0.10 | 7.2 |
| 7 | (0.848, 0.530) | 0.064 | 4.9 |
| 8 | (0.259, -0.966) | 0.040 | 3.3 |

`k = 2π/λ`, `ω = sqrt(9.81·k)·0.75`, steepness `Q = 0.42`. Vertex shader:

```
P.xz += Q·A·D·cos(φ)
P.y  += A·sin(φ)
```

Analytic partial derivatives give the tangent and binormal; the normal is
`normalize(cross(binormal, tangent))`. Short waves fade out with camera
distance (220→1500 m) to avoid vertex aliasing. `Σ Q·k·A ≈ 0.30`, so the
surface does not loop.

**Detail normals.** A 256² tileable fBm height field is differentiated into an
RG slope texture (plus a bubble channel). Two scrolling samples perturb the
Gerstner normal; strength 0.16.

**Reflection / sun.** Fresnel `0.02 + 0.98·(1−N·V)^5`; reflection direction
sampled from the sky cubemap and darkened/blue-tinted. The sun uses a broad and
a sharp `N·H` lobe plus a detail-thresholded sparkle and a reflection-path
term. This produces the sunset glitter column.

**Depth colour / foam.** Distance to the island drives a shallow→deep mix
(70→28 m) and a sand tint (38→24 m). Crest foam uses the accumulated Gerstner
compression plus a detail-noise threshold; a noisy band around the shore
radius (27 m) pulses with time. The water fades to the horizon colour from
2.2 km to 12 km.

**CPU waves.** `cpuWaveHeight(x,z,t)` repeats the same 8-wave sum; the ship is
positioned/tilted from finite differences. There is no buoyancy solver or
wake.

### 3.3 Volumetric clouds

**Textures (boot-time, deterministic).** A 96³ RGBA `Data3DTexture` with
domain-warped tileable value fBm:

- R: 4 octaves, base period 8 (low-frequency shape)
- G: 3 octaves, base 16 (erosion)
- B: 3 octaves, base 8, billowed (`1 − |2n−1|`)
- A: 3 octaves, base 32 (wisps)

Plus a 256² weather texture (R coverage masses, G offset noise) and a 256²
water-detail texture. Generation takes ~1.5–2 s on this machine and is covered
by the loading screen.

**Density.** Cloud slab 1450–2950 m. For a world point `p`:

```
weather  = texture(uWeather, p.xz / 19000 + drift).r
coverage = clamp(uCoverage * mix(0.48, 1.62, weather), 0, 1)
n        = texture(uNoise, p/11000 + drift)
d        = texture(uNoise, (p/11000)*3.2 + offset)
profile  = smoothstep(0, .07, h) * (1 - smoothstep(.50, 1, h))
shape    = n.r * profile
density  = smoothstep(1 - .94*coverage, 1 - .94*coverage + .10, shape)
           * erosion(n.g, d.g, n.b, d.b) * (0.72 + 0.28*n.a)
```

The second 3D fetch supplies high-frequency erosion and breaks the 96³
texel/lattice pattern. Coverage presets: 0.24 day, 0.28 sunset, 0.38 dusk.

**Raymarch.** Half-res sky pass, 30 steps (medium), 20 (low), 38 (high). Ray
slab entry/exit; max path 18 km; interleaved-gradient jitter (static, no
temporal accumulation). Per sample: two 3D + one 2D fetch; on hit, a 5-step
sun march (190 m steps) with the same density function. `exp(-optical·0.0085)`
gives sun transmittance. Integration:

```
T_step = exp(-density * 0.090 * dt)
scatter += T * cloudColor * (1 - T_step)
T *= T_step
```

`cloudColor = ambient(sky gradient by height) + sunColor·(0.05+1.65·HG(phase))·
sunTransmittance`, with a powder term and distance haze. The sun disc is
composited after the clouds and attenuated by `T`.

**Sky.** Analytic zenith→horizon gradient (pow 0.32), horizon warm band, sun
glow, sun disc, dithering. Palettes: day / sunset / dusk, interpolated in JS.

**Reflection cube.** The same shader, 128² faces, 18 steps, updated every 24
frames; the water samples it with a wave-perturbed reflection vector.

### 3.4 Island and ship

Both are generated at boot; no meshes/textures are loaded.

- **Island**: 84×84 m plane, 76×76 segments, heightfield from two fBm dunes +
  a dome + a hill bump. Vertex colours blend wet sand → sand → grass → rock by
  height/slope; flat shading. Nine dodecahedron rocks, four palms (bent trunk,
  nine tapered frond planes). The plane's outer edge is sunk 9 m below y=0 so
  wave troughs never expose underwater terrain.
- **Ship**: custom hull from nine cross-sections (keel/bilge/gunwale), deck,
  stern castle, bowsprit, three masts, yards, curved sails, a jib, line
  rigging, flag and a warm lantern + point light. It bobs and tilts with the
  CPU waves.

### 3.5 Camera / controls

Damped spherical orbit: default radius 96 m, polar 1.41 rad, target (0, 4, 0);
limits 34–165 m / 0.22–1.46 rad. Drag changes azimuth/polar, wheel dollies,
keyboard shortcuts for presets and quality. A slow automatic orbit begins
after 12 s idle; `Space` toggles it.

## 4. Performance

Measured with the verification harness on **Intel HD 6000**, ANGLE OpenGL
(Metal ANGLE unavailable, see README):

| Preset | Median FPS | Sky steps / RT | Notes |
| --- | ---: | --- | --- |
| Day | 50.7 | 30 / 768×432 | 1280×720 |
| Sunset | 45.3 | 30 / 768×432 | 1280×720 |
| Dusk | 52.0 | 30 / 768×432 | 1280×720 |

The performance levers, in order of impact:

1. sky raymarch resolution (0.42/0.60/0.72 of 1280×720);
2. sky step count (20/30/38) and the two 3D texture fetches per step;
3. cube refresh cadence (24 frames; 6 faces × 18 steps);
4. shadow-free standard materials and a single 51k-vertex ocean draw;
5. one-way adaptive quality fallback below 27 FPS.

The 96³ volume is ~1.5 s of boot time and 3.4 MiB; no additional texture assets
are loaded at runtime.

## 5. Verification

`./verify.sh` launches the static server and Playwright/Chrome, then:

- tries `--use-angle=metal`; if the renderer string contains SwiftShader,
  records it and retries with `--use-angle=gl` (real Intel GPU on this machine);
- screenshots day/sunset/dusk at 1280×720 and asserts the PNG header;
- samples FPS for 1.5 s per preset and asserts ≥30;
- captures 90 deterministic frames (12 FPS) of a sunset→day→dusk reel and
  encodes MP4 (1280×720) + GIF (960×540), validating duration 6–10 s;
- fails on console errors, page errors, external requests, software rendering,
  or a frozen/black video (mid-clip average colour check).

Latest report: `../docs/waterpro-clouds-verification.json` (PASS, console 0,
external 0). The `--use-angle=metal` deviation is recorded both in the report
and the README.

## 6. Divergences from the reference (known)

- Gerstner (8 waves) instead of 3-layer JONSWAP + GPU FFT.
- Sky-cubemap reflection only; no planar island/ship reflection, no screen-depth
  refraction/absorption; no wake.
- Single-slab raymarch with 5-step lighting; no temporal reprojection, no
  multi-layer cloud assets, no atmosphere LUTs.
- No shadows, bloom/SSAO, underwater mode, walk/sail modes, or WebGPU.
- Stylized low-poly island/ship rather than the commercial demo's assets.
- The sunset cloud field is puffy and mildly repetitive due to the 96³ tileable
  noise and a single weather scale; increasing the volume to 128³ or adding a
  second weather octave would improve it at extra boot/GPU cost.

The goal was a runnable, verifiable visual study with a clean license chain,
not a pixel-identical port.
