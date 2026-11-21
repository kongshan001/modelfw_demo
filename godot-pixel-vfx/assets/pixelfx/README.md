# PixelFX assets

These sprite sheets were exported with the official PixelFX renderer.

- Source: <https://github.com/patch-gg/pixelfx>
- Commit: `5294518ce7c72e48b6100a744596e0acf57f2826` (PixelFX 0.3.1)
- License: MIT — see `LICENSE` and `NOTICE.md` in this folder.
- Renderer: `tools/render.mjs` (Node 18+; exported with Node v22.19.0).
- Reproduction: `../../tools/export_pixelfx.sh /path/to/pixelfx`.

Only the six exported PNG/JSON pairs, the MIT license and the NOTICE file are
vendored here. The rest of the PixelFX repository (core code, gallery, fonts,
videos) is not part of this project.

| key | PixelFX id | frames | duration | loop | frame | sheet | palette |
|---|---|---|---|---|---|---|---|
| slash | `melee/double-slash` | 25 | 0.833 s | no | 164×108 | 820×540 | default magenta |
| fireball | `fire/fireball` | 36 | 1.200 s | yes | 136×56 | 544×504 | default fire |
| explosion | `explosions/small-explosion` | 163 | 5.433 s | no | 300×240 | 3600×3360 | default fire |
| freeze | `ice/freeze` | 121 | 4.033 s | no | 176×128 | 1760×1664 | default ice |
| coin | `pickups/coin-spin` | 48 | 1.600 s | yes | 56×56 | 392×392 | default gold |
| burst | `pickups/collect-burst` | 42 | 1.400 s | no | 112×108 | 784×648 | **gold** (re-exported) |

`small-explosion` is exported in full but the runtime stops it at 2.2 s so the
long smoke tail does not linger.

The Patch Pixel font in the PixelFX gallery is **not** included and is not
covered by PixelFX's MIT license. This project bundles no font files at all.

See `MANIFEST.json` for exact pivots, columns and SHA-256 checksums, and
`../../CREDITS.md` for attribution.
