# Swarmforge art provenance · T-20261126-026

Date: 2026-11-26 · Author: game-artist worker · License: original project assets (unless noted)

## Principle

All game art in this repository is **original**: it is generated from primitives,
gradients, noise and procedural geometry by the scripts in `tools/art_gen/`.
No reference-game screenshot, character, card, UI or logo was traced, copied or
fed into an image model. No AI image generation API was used for this task
(no image-model credits/keys were available); the result is a deliberate
"stylized micro-foundry" vector/painterly lane, not a copied art style.

## Generated assets

| Asset | Generator | Source / parameters | Size | Notes |
| --- | --- | --- | --- | --- |
| `assets/art/units/unit_atlas_10x12_768x640.png` | `tools/art_gen/gen_units.py` + `artlib.py` | 10 cards × 12 frames, 64 px cells, seed 20261126; right-facing, dark 2–3 px outline, ceramic/brass palette, baked contact shadow | 768×640 RGBA | 0–1 idle, 2–3 move, 4–6 attack, 7–9 death, 10 spawn, 11 elite; team tint is applied per instance in the shader, not baked |
| `assets/art/cards/card_atlas_1024x768.png` + `cards/src/00..09_*_512.png` | `tools/art_gen/gen_cards.py` | 10 original constructs, 512 px source, 4×3 / 256 px atlas cells, seeds 1000–3009 | 1024×768 + 10×512 | full-bleed illustration, no text/logo/UI baked |
| `assets/art/env/arena_1800x570.png` | `tools/art_gen/gen_env.py` | 1800×570 (1.5× of 1200×380), seed 20261126; hex deck, 96 px tide lane, 4 gates, tide well, pipes, light pools, vignette | 1800×570 | static stage; flags/fog are separate animated layers |
| `assets/art/env/flag_ally_96x192.png`, `flag_enemy_96x192.png` | `tools/art_gen/gen_env.py` | 96×192, team crest, transparent outside | 96×192 each | waving done by `assets/shaders/flag.gdshader` |
| `assets/art/env/fog_0.png`, `fog_1.png` | `tools/art_gen/gen_env.py` | 512×256 fBm noise, seeds 11/23 | 512×256 each | scrolling tint shader; alpha-only texture |
| `assets/art/vfx/vfx_atlas_96x192.png` | `tools/art_gen/gen_vfx.py` | 3 frames × 6 effects (spark, shot, splash ring, death, spawn, victory), 32 px cells | 96×192 | additive; tinted per instance |
| `assets/art/ui/icons_20.png` | `tools/art_gen/gen_ui.py` | 17 line icons (coin, furnace, star, hp, atk, aspd, range, refresh, level, greed, flood, code, melee, ranged, support, tank, splash), 20 px | 340×20 | white, tinted per use |
| `assets/art/keyart/victory_1920x1080.png` | `tools/art_gen/gen_keyart.py` | 1920×1080, tideheart core + two converging swarms assembled from the unit atlas, seed 20261126 | 1920×1080 | no text/logo; UI title is drawn separately |

Preview sheets for review: `docs/shots/art-impl/unit_atlas_preview.png`,
`unit_silhouette_8px_after.png`, `card_art_preview.png`, `env_preview.png`,
`vfx_atlas_preview.png`, `icons_preview.png`, `keyart_preview.png`.

## Fonts

| Font | Source / license | Bundled file |
| --- | --- | --- |
| Noto Sans SC | Google Fonts, SIL Open Font License 1.1, © The Noto Project Authors | `assets/fonts/NotoSansSC-Regular-subset.otf` / `-Bold-subset.otf` (instanced wght 400/700, subset to the 740 glyphs in `tools/art_gen/glyphs.txt`, ~244 KB each) |
| Oxanium | Google Fonts, SIL Open Font License 1.1, © The Oxanium Project Authors | `assets/fonts/Oxanium-SemiBold.ttf` (variable @ wght 600, 28 KB) |

License texts: `assets/fonts/OFL-NotoSansSC.txt`, `assets/fonts/OFL-Oxanium.txt`.
CJK glyphs missing from the subset fall back through the OS font (FontFile
`allow_system_fallback`). Adding new Chinese copy means re-running the subset
step (documented in `tools/art_gen/README.md`).

## Reproduce

```bash
cd godot-swarm-autobattler/tools/art_gen
python3 gen_units.py
python3 gen_cards.py
python3 gen_env.py
python3 gen_vfx.py
python3 gen_ui.py
python3 gen_keyart.py
# fonts: fontTools instancer + pyftsubset (see this file / tools/art_gen/README.md)
```

The generated PNGs are checked into `assets/art/` so the game is reproducible
without running Python. Re-running the generators is deterministic for the
recorded seeds (PIL/font versions may shift a few pixels).

## Deviations / notes

- Unit source cells are 64 px; no mipmaps are used for the unit atlas to avoid
  cross-cell bleed with custom per-instance UVs. The unit filter is linear.
- The brief's "1 px gold outer stroke" is replaced by a **gold crown marker +
  gold base ring + warmer tint + 4% size** for gold cards: at 8–16 px display a
  1 px stroke aliases into a gold box around the quad/contact shadow. The shader
  still exposes the outline path in history, but the shipped build uses the
  crown marker.
- The contact shadow is baked into each unit frame instead of a separate shadow
  MultiMesh (saves one draw call and 3000 instance uploads; still grounds units).
- Card illustrations are procedural/vector; they are original and consistent but
  flatter than a hand-painted AI pass. A later painterly pass can replace the
  512 px sources without changing the atlas layout.

## Texture budget (uncompressed RGBA estimate)

| Texture | MB |
| --- | ---: |
| unit atlas 768×640 | 1.97 |
| card atlas 1024×768 | 3.15 |
| arena 1800×570 | 4.10 |
| key art 1920×1080 | 8.29 |
| fog ×2 512×256 | 1.05 |
| flags, VFX, icons | 0.25 |
| **total** | **≈18.8 MB** (< 24 MB brief budget) |

## Third-party assets

None. No purchased, CC0 or scraped image assets are included. Fonts are the only
third-party binaries and are OFL-licensed with license texts included.
