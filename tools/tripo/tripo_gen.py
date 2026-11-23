"""Tripo image-to-3D CLI for the original-short-anime character pipeline.

  # preflight + cost/plan only (no network charge; works without a key)
  HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 \
    python3 tools/tripo/tripo_gen.py --image refs/front.png \
    --out out/tripo --model P2-20260801 --dry-run

  # actual generation (key is read from env; never printed)
  teamai env exec -- env HTTPS_PROXY=http://127.0.0.1:7897 \
    HTTP_PROXY=http://127.0.0.1:7897 \
    python3 tools/tripo/tripo_gen.py --image refs/front.png \
    --out out/tripo --model P2-20260801 --face-limit 20000

  # resume after a timeout/network failure (do not resubmit)
  python3 tools/tripo/tripo_gen.py --resume <task_id> --out out/tripo

Without TRIPO_API_KEY this exits 3 with TRIPO_SKIPPED and does not fabricate
any model.  Use tools/blender_anime/build_character.py as the Blender-only
fallback and record tripo=skipped in the manifest.
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from tripo_api import TripoClient, TripoError, file_sha256  # noqa: E402

DEFAULT_MODEL = os.environ.get('TRIPO_MODEL', 'P2-20260801')


def now():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def write_json(path, data):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def sanitize(obj, key=''):
    if isinstance(obj, str):
        return obj.replace(key, '[REDACTED]') if key else obj
    if isinstance(obj, dict):
        return {k: sanitize(v, key) for k, v in obj.items()}
    if isinstance(obj, list):
        return [sanitize(v, key) for v in obj]
    return obj


def image_info(path):
    size = os.path.getsize(path)
    info = {'path': os.path.abspath(path), 'bytes': size,
            'sha256': file_sha256(path)}
    try:
        from PIL import Image
        with Image.open(path) as im:
            info['width'], info['height'] = im.size
            info['mode'] = im.mode
            info['format'] = im.format
    except Exception as e:
        info['pil_error'] = str(e)
    return info


def main():
    ap = argparse.ArgumentParser(prog='tripo_gen.py')
    ap.add_argument('--image', default=None, help='original reference image')
    ap.add_argument('--out', required=True)
    ap.add_argument('--model', default=DEFAULT_MODEL)
    ap.add_argument('--face-limit', type=int, default=None)
    ap.add_argument('--texture', dest='texture', action='store_true',
                    default=True)
    ap.add_argument('--no-texture', dest='texture', action='store_false')
    ap.add_argument('--pbr', dest='pbr', action='store_true', default=True)
    ap.add_argument('--no-pbr', dest='pbr', action='store_false')
    ap.add_argument('--quad', action='store_true',
                    help='P2 quad; Tripo returns FBX for quad output')
    ap.add_argument('--texture-quality', default=None)
    ap.add_argument('--geometry-quality', default=None)
    ap.add_argument('--model-seed', type=int, default=None)
    ap.add_argument('--texture-seed', type=int, default=None)
    ap.add_argument('--timeout', type=int, default=600)
    ap.add_argument('--interval', type=float, default=2.0)
    ap.add_argument('--proxy', default='auto',
                    help='proxy URL, "auto" (env or 127.0.0.1:7897), or off')
    ap.add_argument('--no-proxy', action='store_true')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--resume', default=None, metavar='TASK_ID')
    ap.add_argument('--json', action='store_true')
    args = ap.parse_args()
    key = os.environ.get('TRIPO_API_KEY', '')
    proxy = None if args.no_proxy else args.proxy
    client = TripoClient(key, proxy=proxy)
    out_dir = os.path.abspath(args.out)
    os.makedirs(out_dir, exist_ok=True)
    task_file = os.path.join(out_dir, 'tripo_task.json')
    plan = {
        'api_base': client.base_url,
        'proxy': client.proxy,
        'model': args.model,
        'texture': args.texture, 'pbr': args.pbr, 'quad': args.quad,
        'face_limit': args.face_limit,
        'key_present': bool(key),
        'note': 'key value is never printed or written',
    }
    if args.dry_run:
        if args.image:
            plan['image'] = image_info(args.image)
        plan['estimated_credits'] = '20-30 (image-to-3D standard; verify in console)'
        plan['will_submit'] = False
        plan['status'] = 'dry-run'
        write_json(os.path.join(out_dir, 'tripo_plan.json'), plan)
        print('TRIPO_DRY_RUN_OK model=%s proxy=%s key=%s' % (
            args.model, client.proxy, 'set' if key else 'unset'))
        print('  key is not needed for a dry-run; actual generation requires '
              'TRIPO_API_KEY in the environment/teamai secret.')
        print('  plan:', json.dumps(plan, ensure_ascii=False))
        return 0
    if not key:
        msg = ('TRIPO_SKIPPED: TRIPO_API_KEY is not set. No task was '
               'submitted and no model was fabricated. Configure the key in '
               'your terminal or teamai secret, then rerun. Blender-only '
               'fallback: tools/blender_anime/build_character.py')
        print(msg)
        write_json(task_file, {
            'status': 'skipped', 'reason': 'TRIPO_API_KEY unset',
            'created': now(), 'model': args.model,
            'api_base': client.base_url, 'proxy': client.proxy,
            'fallback': 'tools/blender_anime/build_character.py',
        })
        return 3
    started = time.time()
    task_meta = {
        'status': 'running', 'created': now(), 'model': args.model,
        'api_base': client.base_url, 'proxy': client.proxy,
        'texture': args.texture, 'pbr': args.pbr, 'quad': args.quad,
        'face_limit': args.face_limit, 'task_id': args.resume,
    }
    if args.image:
        task_meta['input'] = image_info(args.image)
    try:
        if args.resume:
            task_id = args.resume
            print('TRIPO_RESUME task_id=%s' % task_id)
        else:
            if not args.image:
                ap.error('--image is required unless --resume is used')
            print('TRIPO_UPLOAD image=%s' % os.path.basename(args.image))
            token = client.upload_file(args.image)
            print('TRIPO_UPLOAD_OK file_token=%s...' % str(token)[:8])
            task_id, resp = client.create_image_to_model(
                token, model=args.model, face_limit=args.face_limit,
                texture=args.texture, pbr=args.pbr, quad=args.quad,
                model_seed=args.model_seed, texture_seed=args.texture_seed,
                texture_quality=args.texture_quality,
                geometry_quality=args.geometry_quality)
            task_meta['task_id'] = task_id
            print('TRIPO_SUBMITTED task_id=%s' % task_id)
        write_json(task_file, task_meta)

        def tick(data):
            status = data.get('status') if isinstance(data, dict) else None
            if status and status != task_meta.get('last_status'):
                task_meta['last_status'] = status
                task_meta['polled'] = now()
                write_json(task_file, task_meta)

        data, raw = client.poll(task_id, timeout=args.timeout,
                                interval=args.interval, on_tick=tick)
        outputs = client.extract_outputs(data)
        credits = client.extract_credits(data)
        if not outputs:
            raise TripoError('task succeeded but no .glb/.fbx/.obj URL was '
                             'found in the response')
        # prefer GLB, then FBX; download all model URLs
        outputs.sort(key=lambda o: (0 if '.glb' in o['url'].lower()
                                    else 1 if '.fbx' in o['url'].lower()
                                    else 2))
        models_dir = os.path.join(out_dir, 'models')
        os.makedirs(models_dir, exist_ok=True)
        downloaded = []
        for i, item in enumerate(outputs):
            ext = os.path.splitext(item['url'].split('?')[0])[1] or '.bin'
            dst = os.path.join(models_dir, 'model_%02d%s' % (i, ext))
            print('TRIPO_DOWNLOAD %s -> %s' % (item['key'] or 'model',
                                               os.path.basename(dst)))
            got = client.download(item['url'], dst)
            got['key'] = item['key']
            downloaded.append(got)
        elapsed = round(time.time() - started, 2)
        result = sanitize({
            'status': 'success', 'task_id': task_id, 'model': args.model,
            'created': task_meta.get('created'), 'finished': now(),
            'elapsed_s': elapsed, 'input': task_meta.get('input'),
            'outputs': downloaded, 'credits_consumed': credits,
            'credit_note': 'null/unknown means the API response did not '
                           'include a credit field; check the Tripo console',
            'api_base': client.base_url, 'proxy': client.proxy,
            'raw_status': data.get('status') if isinstance(data, dict)
            else None,
        }, key)
        write_json(task_file, result)
        with open(os.path.join(out_dir, 'credits.jsonl'), 'a',
                  encoding='utf-8') as f:
            f.write(json.dumps({
                'at': now(), 'task_id': task_id, 'model': args.model,
                'credits_consumed': credits, 'elapsed_s': elapsed,
            }, ensure_ascii=False) + '\n')
        glb = next((d['path'] for d in downloaded
                    if d['path'].lower().endswith('.glb')), None)
        print('TRIPO_TASK_OK task_id=%s glb=%s credits=%s elapsed=%.1fs' % (
            task_id, glb, credits, elapsed))
        if args.json:
            print(json.dumps(result, ensure_ascii=False))
        return 0
    except TripoError as e:
        msg = client.redact(str(e))
        failed = dict(task_meta)
        failed.update({'status': 'failed', 'finished': now(),
                       'error': msg,
                       'error_status': getattr(e, 'status', None),
                       'error_code': getattr(e, 'code', None)})
        write_json(task_file, sanitize(failed, key))
        print('TRIPO_FAIL status=%s code=%s message=%s' % (
            getattr(e, 'status', None), getattr(e, 'code', None), msg))
        print('  Do not resubmit blindly: if the task may exist, use '
              '--resume <task_id> after checking the console/balance.')
        return 1


if __name__ == '__main__':
    sys.exit(main())
