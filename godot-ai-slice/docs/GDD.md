# Sky Circuit — Slice GDD

## Pitch

A tiny yellow robot wakes up on broken sky islands. Collect three energy cores to restore the circuit and reach the portal.

## Core loop

1. Start on the home island.
2. Jump across floating islands; touch three glowing cores.
3. The portal activates when the third core is collected.
4. Enter the portal → win.
5. Press R to replay.

## Controls

- WASD: move
- Space: jump
- Enter / Space: start
- R: restart
- F1: debug overlay

## Acceptance

- Title → play → collect 3 → portal → win → restart works.
- `AI_SLICE_SMOKE_OK`.
- Title / play / win screenshots render without missing nodes.
- The slice remains playable without external assets.

## Non-goals (this slice)

- Combat, enemies, boss, inventory, save system.
- External 3D models, animation, audio, fonts.
- Mobile touch controls / export.
- Networking.

## Next candidates

- One enemy that patrols a platform.
- A head-throw / bowling mechanic (Cloudline-inspired, but original implementation).
- A proper scene-based level instead of code-built islands.
- gda live verification in the loop (input + screenshot).
