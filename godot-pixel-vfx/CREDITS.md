# CREDITS · Pixel VFX Lab

## PixelFX (MIT)

- Repository: <https://github.com/patch-gg/pixelfx>
- Commit used: `5294518ce7c72e48b6100a744596e0acf57f2826` (2026-11-12, PixelFX 0.3.1)
- Effect ids: `melee/double-slash`, `fire/fireball`, `explosions/small-explosion`, `ice/freeze`, `pickups/coin-spin`, `pickups/collect-burst`
- Exported with the official `tools/render.mjs --sheet` renderer (Node v22.19.0).
- License text: [`assets/pixelfx/LICENSE`](assets/pixelfx/LICENSE)
- Upstream notices: [`assets/pixelfx/NOTICE.md`](assets/pixelfx/NOTICE.md)

```
MIT License

Copyright (c) 2026 Patch
Copyright (c) 2026 Hugo Duprez
```

The exported PNG/JSON sheets are derivative works of PixelFX and remain under the MIT license above. Only the exported sheets, LICENSE and NOTICE are included; no PixelFX core source code, gallery, or fonts are vendored.

### Upstream notices carried forward

- **Hugo Duprez / Sprite Fusion**: PixelFX's `src/core/sim.js` and several effects adapt the open-source pixel-art VFX at <https://www.spritefusion.com/pixel-art-vfx>, Copyright (c) 2026 Hugo Duprez, MIT. This project only uses exported sheets from PixelFX; the adaptation is credited upstream.
- **Hollow Crown**: PixelFX's `src/core/act.js` adapts skill staging from <https://github.com/rehan-remade/hollow-crown>, Copyright (c) 2026 rehan-remade, MIT. Not bundled here.
- **Patch Pixel font**: The font under PixelFX's `gallery/fonts` is Patch's own and is **not** covered by the MIT license. It is **not** included in this project.

## Original work

Everything below was authored for this project (T-20261121-023), not copied from another game:

- 640×360 dusk stage: sky bands, aurora, moon/moonbeam, mountains, watchtower, ruined arch, banners, fence, lanterns, hay bale, barrel, mushrooms, grass, rune ring, fireflies, birds.
- Original 40 px knight (idle bob, attack, cast), 44 px straw training dummy (recoil, hit flash, frost/burn tint, ice shards, status bars).
- Original 5×7 bitmap font (`scripts/pixel_font.gd`) for the English title, score, damage numbers and key badges.
- HUD layout, panels, buttons, icons and all interaction code (GDScript).
- Coin placement, effect choreography, hit-stop, camera shake, cleanup and test/capture tooling.

## Fonts

This project bundles **no font files**.

- Chinese HUD text is rasterized at runtime via Godot `SystemFont` with the following fallback list: PingFang SC, Hiragino Sans GB, Heiti SC, Microsoft YaHei, Noto Sans CJK SC, Arial Unicode MS, sans-serif. The fonts are provided by the host OS; their licenses remain with their owners.
- English title/score/damage glyphs are drawn from the original 5×7 bitmap font implemented in code.

For commercial distribution, verify that the target OS has a suitable CJK font or ship a properly licensed CJK font and update `scripts/hud.gd`.

## Reference / topic source

The task was inspired by the Toutiao video《做像素游戏，这些特效直接用 挥剑、火球、冰冻、捡金币，PixelFX》 (<https://m.toutiao.com/is/Mknvnb6nf9U/>). The video could not be downloaded (yt-dlp failed); no video frames or third-party game assets were copied. All visuals come from PixelFX's MIT sprite sheets plus the original work above.

## Engine / tools

- Godot 4.6 stable (GL Compatibility), original GDScript.
- Node.js v22.19.0 + PixelFX's renderer for sheet export.
- ffmpeg 8.0.1 for MP4/GIF encoding.
