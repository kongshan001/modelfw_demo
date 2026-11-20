# Brief

**Question:** Rebuild the Three.js tropical-island boat demo (clean room) in app/ from REQUEST.md + inputs/ANALYSIS.md evidence: island, ocean with wake sim, boat, sky, controls, screenshot verification.

**Purpose:** Clean-room rebuild of a reference demo; visible evidence only, no original code/assets copied.

**Targets:**
- /Users/ks_128/Documents/modelfw_demo/craft-island/inputs/cover.jpg
- /Users/ks_128/Documents/modelfw_demo/craft-island/inputs/frames/

**Constraints:**
- Clean room: never open/run original code; inputs images + ANALYSIS.md are the only evidence
- Change files only inside app/
- No external textures, no CDN; vendored three.js only
- Verify with Playwright + Chrome GPU; never --disable-gpu

**Done when:** app/ serves the demo with island, water+sim wake, boat, sky, controls; app/docs/screenshot.png matches reference composition; app/README.md present; rebuild_check passes or remaining diffs are documented as unverifiable.
