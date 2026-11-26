# Scripts

Playwright scripts operate the live Action Forge web app; they do **not** upload to any service and use no account.

Prerequisites:
- `/opt/anaconda3/bin/python` with Playwright + Chromium (`playwright install chromium`).
- A persistent Chromium profile (`AF_PROFILE`, default `/tmp/af_profile`) where KayKit Rogue has been uploaded/kept and Michelle Walk imported once; see `docs/action-forge-test.md` §6.2.

| Script | Purpose |
|---|---|
| `af_import_animation.py` | Setup › Import: upload `Michelle_Walk.glb`, Motion = Root travels |
| `af_export_variants.py` | Download in-place / root-motion / motion-only GLBs into `../exports/` |
| `af_record_operation.py` | Playwright-recorded adjust/download session (long; trim afterwards) |
| `af_library_audit.py` | T-013: fetch the public library manifest (or `--manifest` offline), print 85/89 counts, categories, root-motion clips, zero-duration poses; optional preview downloads |
| `af_layer_export.py` | T-013: rebuild base Walk Loop + upper-body Idle Talking layer, set weight 100%, download layered GLB/FBX. Do not drag the strip; see docstring |
| `af_character_retarget.py` | T-013: upload `/tmp/Michelle_scaled.glb`, let Action Forge map Mixamo (52/62), export Walk Loop GLB/FBX. Raw export has the 1.618× scale bug; docs §4 |
| `glb_inspect.py` | Standalone GLB parser: skeleton, meshes, animations, root motion, duration |

The app's UI text/IDs may change as it is a Beta; update selectors from the live DOM if a run fails. The browser profile state (uploaded character/animation) is not shipped.

T-013 critical gotchas (also in `docs/action-forge-test.md` §2):
- The character file input is index 1 (`accept=".glb,.fbx,.afcharacter,..."`); index 0 is animation import. Use the filechooser event, not a click on the hidden tile.
- A new layer must be selected in Animate > Adjust > LAYERS **before** `+ ADD SELECTED`; otherwise the clip goes to Base.
- Do not drag the strip after adding: that resets the auto upper-body mask to Full body.
- Clicking the layer head at x≈60 can hit the mini weight slider and set the layer to 0.
- Composite root-motion is not baked; layered exports stay in-place.
