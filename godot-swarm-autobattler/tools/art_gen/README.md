# Swarmforge procedural art pipeline

All art is generated from primitives; no external image assets. See
`assets/art/PROVENANCE.md` for the full table and licenses.

```bash
cd godot-swarm-autobattler
python3 tools/art_gen/gen_units.py     # unit_atlas_10x12_768x640.png
python3 tools/art_gen/gen_cards.py     # card_atlas_1024x768.png + cards/src/*.png
python3 tools/art_gen/gen_env.py       # arena, flags, fog
python3 tools/art_gen/gen_vfx.py       # vfx_atlas_96x192.png
python3 tools/art_gen/gen_ui.py        # icons_20.png
python3 tools/art_gen/gen_keyart.py    # victory_1920x1080.png
```

## Font subset (optional, already checked in)

The bundled Noto Sans SC files are a static instance/subset of the upstream
variable font (Google Fonts, OFL). To refresh after copy changes:

```bash
python3 - <<'PY'
from pathlib import Path
# collect all non-ASCII glyphs used by runtime scripts
chars=set()
for p in list(Path('scripts').glob('*.gd'))+list(Path('tools').glob('*.gd')):
    for ch in p.read_text():
        if ord(ch)>127: chars.add(ch)
chars.update("◆◇★☆×·—–…%‰°±≤≥≈∞✓▲▼◀▶，。！？、；：（）【】「」《》〈〉“”‘’")
chars.update("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz .,:;!?()[]{}<>+-=*/%#@&|~^_\"'`\\\n")
Path('tools/art_gen/glyphs.txt').write_text(''.join(sorted(chars)),encoding='utf-8')
PY
# then instancer + pyftsubset (fontTools) for wght 400 and 700
```

The runtime uses a CJK fallback through the OS font for any glyph outside the
subset; keep the subset in sync with new UI copy.
