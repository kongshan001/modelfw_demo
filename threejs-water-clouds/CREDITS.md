# Credits and license chain

## Runtime code

| Component | Version | License | Use |
| --- | --- | --- | --- |
| Three.js | r180 (`vendor/three.module.js`, `three.core.js`) | MIT, Copyright 2010–2025 Three.js Authors | The only third-party runtime code. License: `vendor/LICENSE-three.txt`. Copied from the repository's `craft-island/app/vendor/` so the demo has no CDN/build dependency. |

Everything else in `src/` (water, sky, cloud raymarch, noise generators, island,
ship, camera, UI) is original code written for this study. The noise algorithms
are standard published techniques (tileable value fBm, domain warping,
Beer–Lambert integration, Henyey–Greenstein phase); the shaders and geometry
are not copied from any of the referenced projects.

## References (not bundled)

| Source | License status | What we used |
| --- | --- | --- |
| Bilibili **BV1BRHw6fEfW**, 《waterpro+threejs体积云复刻，开源！！！》, 可爱的管哥哥 | Video is copyrighted; no redistribution | Visual/technical analysis only. No video frames, audio or text are shipped. The uploaded video's description points to the Gitee repo below. |
| Gitee **`tube-brother/vue3-threejs`** | **No license file; Gitee API `license: null`.** Public availability is not a reuse grant. | Read-only study of `docs/water-scene.md`, `package.json` and the water module to identify techniques. **No code, assets, UI text or branding copied.** |
| **THREE.JS WATER PRO / Sky Pro** (`threejswaterpro.com`, `docs.threejswaterpro.com`) | Commercial product, no public license obtained | Visual target only. No code, assets, models, textures or branding used. The Gitee project itself states it did not include the paid product's code. |
| **Takram three-geospatial** — `@takram/three-clouds` 0.7.6, `@takram/three-atmosphere` 0.19.1, `@takram/three-geospatial` 0.9.1 | **MIT** (npm package metadata + GitHub API; Copyright (c) 2024 Shota Matsuda) | Technique reference: weather-map driven 3D-noise raymarching, self-shadowing, multiple-scattering/temporal ideas, atmosphere. The libraries and their 11 MiB of noise/atmosphere assets are **not bundled**. Our 96³ noise and raymarch are independent. |
| Gitee project's `public/water/ATTRIBUTION.md` | States that the ship/island/foam GLBs came from the commercial demo and that their redistribution status is **unverified** | Confirms why we did not reuse them. Our island/ship are procedural originals. |

## Generated assets

All in-app assets are generated at boot or authored here:

- 96³ cloud noise volume, 256² weather map, 256² water detail map — `src/noise.js`;
- island heightfield, vertex colours, rocks, palms — `src/props.js`;
- ship hull/masts/sails/rigging/lantern — `src/props.js`;
- sky gradients and cloud field — `src/sky.js`;
- ocean mesh and water shader — `src/ocean.js`;
- UI/CSS — original; no fonts or images fetched at runtime.

## Tooling (development only, not shipped)

- Playwright + Google Chrome (verification).
- Python `http.server` (local static server).
- ffmpeg/ffprobe (MP4/GIF encoding and artifact checks).
- yt-dlp and ffmpeg were used only to inspect the reference video during
  identification; the downloaded media is not part of the project.

## Screenshots / video

`docs/shots/waterpro-clouds-*.png`, `docs/waterpro-clouds-demo.mp4` and
`docs/waterpro-clouds-demo.gif` are renders of **this** project. The contact
sheet is made from those renders. No reference video frames are included.

## Branding

“WATER PRO”, “Sky Pro”, “Three.js Sky Pro” and the Gitee author's UI/branding
are used only as factual references in documentation. This project's title
(“Volumetric Shore”), palette, HUD text and geometry are original.
