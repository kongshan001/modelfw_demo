# Codex / Agent Instructions — AI Slice

Read `CLAUDE.md` first; the rules are identical:

- Godot 4.6, GL Compatibility, typed GDScript.
- Keep `tools/smoke_slice.gd` green.
- Never edit `.godot/`.
- One feature per change; run the smoke and screenshots for visual work.
- No external assets without a license; this starter is original primitive geometry.
- Preserve the public methods used by tools and scripts.
- In `-s` scripts, resolve the `Game` autoload via `root.get_node_or_null("Game")`.

## Task split

1. **Design / GDD** (Codex): write `docs/GDD.md` with core loop, controls, acceptance, and explicit non-goals. Do not edit code in this step.
2. **Implementation** (Claude Code or Codex): smallest vertical change, then:
   ```bash
   godot --headless --path godot-ai-slice -s tools/smoke_slice.gd
   godot --path godot-ai-slice --resolution 1280x720 -s tools/screenshot_slice.gd
   ```
3. **Verification** (gda on Windows): see `docs/AI_WORKFLOW.md`.

## Definition of done

- `AI_SLICE_SMOKE_OK`.
- Screenshots show the intended change.
- The diff is small and explainable; no unrelated refactors.
