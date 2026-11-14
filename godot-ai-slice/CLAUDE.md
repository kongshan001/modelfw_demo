# AI Slice — Sky Circuit

Godot 4.6 / GL Compatibility / GDScript. A small 3D vertical slice for AI-assisted iteration.

## Commands

```bash
godot --path godot-ai-slice
godot --headless --path godot-ai-slice -s tools/smoke_slice.gd   # AI_SLICE_SMOKE_OK
godot --path godot-ai-slice --resolution 1280x720 -s tools/screenshot_slice.gd
```

## Rules

- **Keep `tools/smoke_slice.gd` green.** Any gameplay/state change must update or preserve it.
- **Do not edit `.godot/`.** Let Godot import; use `godot --headless --import` if needed.
- One feature per change. For visual changes, run the screenshot tool and inspect all three shots.
- Typed GDScript; keep functions small. `Game` is the only autoload and its public API is:
  `TITLE / PLAYING / WON`, `TOTAL_CORES`, `state`, `collected`, `start()`, `collect_core()`, `win()`, `is_playing()`, `is_title()`, `is_won()`, `total_cores()`, `state_name()`.
- Headless `-s` scripts cannot rely on the `Game` global identifier; resolve it with `root.get_node_or_null("Game")` (see `tools/smoke_slice.gd`).
- No external assets, fonts, or audio without an explicit license note. The starter uses primitives on purpose.
- UI copy is English; docs may be Chinese.
- Do not rewrite the project structure for a small request. Preserve public methods used by the tools (`start_game`, `restart_level`, `force_win`, `respawn`, `reset`, `collect`, `trigger`, `set_active`).

## Map

- `src/game.gd` — state machine + core count.
- `src/main.gd` — level builder, input, game flow.
- `src/player.gd` — CharacterBody3D + fixed follow camera.
- `src/coin.gd` / `src/portal.gd` — interactables.
- `src/hud.gd` — title / HUD / win / F1 debug.
- `tools/` — acceptance and screenshots.

## Acceptance

1. `AI_SLICE_SMOKE_OK`.
2. title/play/win screenshots render, no missing nodes or script errors.
3. The change is visible/playable in the run command, not only in tests.
