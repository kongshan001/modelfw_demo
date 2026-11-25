"""Build an original cute-anime character with the blender_anime toolkit.

  /Applications/Blender.app/Contents/MacOS/Blender -b \
    -P tools/blender_anime/build_character.py -- \
    --preset tools/blender_anime/presets/cute_l2.json \
    --design tools/blender_anime/designs/taoyao.json \
    --out agent-probes/blender-anime-v01

No external assets. Tripo is optional: this builder is the Blender-only
fallback and the post-Tripo rebuild stage (see import_tripo.py).
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import anime_kit as kit  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))


def resolve(path):
    if os.path.isabs(path):
        return path
    cand = os.path.abspath(path)
    if os.path.exists(cand):
        return cand
    cand = os.path.join(REPO, path)
    if os.path.exists(cand):
        return cand
    cand = os.path.join(HERE, path)
    if os.path.exists(cand):
        return cand
    return os.path.abspath(path)


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    ap = argparse.ArgumentParser(prog='build_character.py')
    ap.add_argument('--preset', default=os.path.join(HERE, 'presets',
                                                     'cute_l2.json'))
    ap.add_argument('--design', default=os.path.join(HERE, 'designs',
                                                     'taoyao.json'))
    ap.add_argument('--out', required=True)
    ap.add_argument('--name', default=None,
                    help='output file stem (default: design.name)')
    ap.add_argument('--no-outline', action='store_true')
    ap.add_argument('--tripo-task-json', default=None,
                    help='optional tools/tripo task.json to record provenance')
    args = ap.parse_args(argv)
    preset = kit.load_json(resolve(args.preset))
    design = kit.load_json(resolve(args.design))
    tripo_status = {
        'status': 'skipped',
        'reason': 'TRIPO_API_KEY unset; Blender-only fallback'
        if not os.environ.get('TRIPO_API_KEY')
        else 'key present but this run used Blender-only fallback',
    }
    if args.tripo_task_json:
        try:
            task = kit.load_json(resolve(args.tripo_task_json))
            tripo_status = {
                'status': 'success' if task.get('status') == 'success'
                else task.get('status', 'unknown'),
                'task_id': task.get('task_id'),
                'model': task.get('model'),
                'credits': task.get('credits_consumed'),
                'input_sha256': task.get('input_sha256'),
                'output': task.get('output'),
            }
        except Exception as e:
            tripo_status['task_json_error'] = str(e)
    manifest = kit.build_character(
        preset, design, os.path.abspath(resolve(args.out)),
        char_name=args.name, outline=not args.no_outline,
        tripo_status=tripo_status)
    print('BLENDER_ANIME_BUILD_DONE', manifest['id'],
          manifest['mesh']['tris'], 'tris',
          manifest['armature']['bones'], 'bones',
          manifest['files']['glb_bytes'], 'GLB bytes')


if __name__ == '__main__':
    main()
