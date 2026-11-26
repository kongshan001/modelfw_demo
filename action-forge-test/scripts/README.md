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
| `glb_inspect.py` | Standalone GLB parser: skeleton, meshes, animations, root motion, duration |

The app's UI text/IDs may change as it is a Beta; update selectors from the live DOM if a run fails. The browser profile state (uploaded character/animation) is not shipped.
