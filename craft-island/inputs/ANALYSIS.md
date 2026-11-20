# Target analysis — visible evidence only (clean room)

Reference: **Dan Greenheck — Three.js Water Pro expanded into a large-scale island
environment** (Top 2 in 《Three.js 案例合集 207期》, BV1x4nY6xEHo). The original is a
commercial Water Pro demo; the source project being used here is **Craft Anything**
(clean-room replication workflow). We only use what is visible in the reference
images. No original code, shaders, models, textures, names or logos are to be
copied.

## What the reference shows

- A small **fishing boat** in the foreground, moving toward a tropical island:
  weathered white hull, red cabin roof, dark windows, thin mast/antenna, red
  buoys, a small deck cargo. A soft white **wake** trails behind it.
- **Ocean**: turquoise/teal near the island, deeper blue-green toward the
  horizon; small wind waves, white foam around rocks and along the wake.
- **Island**: dark volcanic rock stacks, sandy beach, dense green vegetation,
  palm trees, layered ridges fading into atmospheric haze; two smaller islets
  and sea stacks around the main island.
- **Sky**: bright blue with large soft cumulus clouds, sun high and slightly to
  the left/front; strong warm sunlight; hazy horizon.
- **Camera**: low over the water, behind/above the boat, 3/4 view, boat centered;
  the island fills the background. Cinematic, not a UI demo.
- Mood: bright tropical daylight, calm but alive water, no rain/fog wall.

## Palette (approximate, for guidance)

- sky zenith `#3f7fbf`, horizon `#bcd7e8`, clouds `#f4f2ea` / `#8d99a6`
- open water `#0b3f4f` → shallow `#2aa6a0`, foam `#f2f6f5`
- sand `#d8c69a`, vegetation `#3f6b35` / `#2a4f2a`, volcanic rock `#4a4742`
- boat white `#e4e1d6`, cabin roof `#8e2f24`, wood `#6b4a2f`

## Composition

- 16:9, 1280×720.
- Boat occupies ~15–20% of width, lower-center; island ridge line around the
  upper third; horizon behind.
- Shallow-water foam and rocks frame the boat; palms break the skyline.

## Out of scope / must not copy

- Water Pro code or shaders, the original boat model, textures, logos,
  typography, or any proprietary assets.
- Rebuild the look and behavior from scratch with procedural geometry/materials.
