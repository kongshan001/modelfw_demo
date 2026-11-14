---
name: godot-slice
description: Use when implementing or verifying gameplay, feel, UI, or game state in godot-ai-slice (Godot 4.6). Keeps the smoke test green, applies a small game-feel checklist, and verifies with screenshots and gda.
---

# Godot Slice

A tiny 3D vertical slice. Treat it as a production starter: small diffs, verified behavior, visible feedback.

## Before coding

1. Read `CLAUDE.md`, `AGENTS.md`, and `docs/GDD.md`.
2. Restate the acceptance criteria in one or two lines. If they are missing, add them to `docs/GDD.md` first.
3. Choose the smallest change that satisfies them; do not refactor unrelated code.

## Implementation rules

- Godot 4.6, GL Compatibility, typed GDScript. Match the existing style.
- Preserve public methods used by tools/tests: `start_game`, `restart_level`, `force_win`, `respawn`, `reset`, `collect`, `trigger`, `set_active`.
- Never edit `.godot/`. Let Godot import; use `godot --headless --import` if needed.
- No external assets/audio/fonts without an explicit license note. The slice is primitive geometry on purpose.
- UI copy is English; docs may be Chinese.
- Headless `-s` scripts must resolve the autoload by path: `root.get_node_or_null("Game")`.

## Verify (required)

```bash
godot --headless --path godot-ai-slice -s tools/smoke_slice.gd
# AI_SLICE_SMOKE_OK

godot --path godot-ai-slice --resolution 1280x720 -s tools/screenshot_slice.gd
# /tmp/ai_slice_shots/{title,play,win}.png
```

If `gda` is available (Windows uses the `*_console.exe` binary):

```bash
gda script validate --json
gda scene preflight res://scenes/main.tscn --json
# live: gda daemon start --windowed; gda game tree --json; gda screen capture --json
```

Do not claim done on smoke alone. Inspect all three screenshots for missing nodes, clipped UI, or invisible feedback.

## Game-feel checklist

For any interaction (collect, jump, portal, UI):

- Feedback starts within ~100 ms of the action.
- The player can tell what changed without reading a log.
- One strong cue is better than three competing ones.
- Existing juice: core pop + gold burst + small camera shake; portal activation burst/pulse + "PORTAL ONLINE" toast + HUD core flash.
- Do not over-shake or make the HUD unreadable. Keep the title/HUD/win overlays legible.
- If you add a new effect, make it deterministic enough for screenshots and reset it in `reset()`/`restart_level()`.

## Report

Return:

1. What changed and why (one paragraph).
2. Exact commands run and their key output (`AI_SLICE_SMOKE_OK`, screenshot paths).
3. Any remaining visual/design risk, or "none".
