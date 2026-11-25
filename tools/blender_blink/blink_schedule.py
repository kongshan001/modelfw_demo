"""Deterministic blink schedule generator (no bpy, pure stdlib).

Usage:
  python3 tools/blender_blink/blink_schedule.py --seed 20261125 --json out.json
  python3 tools/blender_blink/blink_schedule.py --stats --blinks 200

Model
-----
* 24 fps, 7.0 s loop (frames 1..168) by default.
* Per blink: close 2-3 frames, hold closed 1-2 frames, open 3-4 frames.
* Left/right can start 1 frame apart (stagger).
* Double-blink probability p=0.08 per blink (task asks ~5-10%).
* Inter-blink intervals random in [1.35, 2.55] s.
* All randomness comes from one `random.Random(seed)`, so a seed fully
  reproduces the schedule (frames, offsets, holds).

Demo policy: the shipped 7 s clip uses a seed whose window contains exactly
one double blink (the task requires the clip to demonstrate one).  The
generator probability stays 0.08; `--stats` reports the realised rate over
a long run so the clip is not mistaken for a 25% design target.
"""

import argparse
import json
import random

FPS = 24
DEFAULT_SEED = 20261125
DURATION_S = 7.0
FRAMES = int(FPS * DURATION_S)          # 168
MIN_START_S = 0.55
MAX_START_S = 1.55
INTERVAL_MIN_S = 1.35
INTERVAL_MAX_S = 2.55
P_DOUBLE = 0.08
TARGET_BLINKS = 4                       # doubles can push this to 5


def _blink(rng, start_s):
    close = rng.choice((2, 3))
    hold = rng.choice((1, 2))
    open_frames = rng.choice((3, 4))
    stagger = rng.choice((0, 1))
    if stagger:
        left_off, right_off = 0, 1
    else:
        left_off = right_off = 0
    return {
        'start_s': round(start_s, 4),
        'start': int(round(start_s * FPS)),
        'close': close,
        'hold': hold,
        'open': open_frames,
        'left_off': left_off,
        'right_off': right_off,
        'double': False,
    }


def blink_len(b):
    return b['close'] + b['hold'] + b['open']


def generate_schedule(seed=DEFAULT_SEED, frames=FRAMES, fps=FPS,
                      target_blinks=TARGET_BLINKS):
    rng = random.Random(seed)
    blinks = []
    t = rng.uniform(MIN_START_S, MAX_START_S)
    while len(blinks) < target_blinks:
        b = _blink(rng, t)
        if b['start'] + blink_len(b) > frames - 2:
            break
        blinks.append(b)
        last_end = b['start'] + blink_len(b)
        if rng.random() < P_DOUBLE and len(blinks) < target_blinks:
            gap = rng.randint(2, 5)
            start2 = last_end + gap
            b2 = _blink(rng, start2 / fps)
            if start2 + blink_len(b2) > frames - 2:
                break
            b['double'] = True
            b2['double'] = True
            blinks.append(b2)
            last_end = start2 + blink_len(b2)
        t = last_end / fps + rng.uniform(INTERVAL_MIN_S, INTERVAL_MAX_S)
    for i, b in enumerate(blinks):
        b['index'] = i
        b['end'] = b['start'] + blink_len(b)
    return {
        'seed': seed,
        'fps': fps,
        'duration_s': frames / fps,
        'frames': frames,
        'p_double': P_DOUBLE,
        'blinks': blinks,
        'double_pairs': sum(1 for b in blinks if b['double']) // 2,
        'intervals_s': [
            round((blinks[i + 1]['start'] - blinks[i]['start']) / fps, 3)
            for i in range(len(blinks) - 1)
        ],
    }


def eye_keys(b, channel='left'):
    """Return [(frame, value)] for one eye channel."""
    off = b['left_off'] if channel == 'left' else b['right_off']
    s = b['start'] + off
    c, h, o = b['close'], b['hold'], b['open']
    return [(s, 0.0), (s + c, 1.0), (s + c + h, 1.0), (s + c + h + o, 0.0)]


def is_valid(sch, frames=FRAMES):
    blinks = sch['blinks']
    if not (3 <= len(blinks) <= 5):
        return False, 'blink count %d' % len(blinks)
    if sch['double_pairs'] != 1:
        return False, 'double pairs %d' % sch['double_pairs']
    prev_end = 0
    for b in blinks:
        if b['double'] and b['start'] < prev_end + 1:
            return False, 'double overlap'
        if b['start'] - prev_end < 10 and not (b['double'] and prev_end and b['start'] - prev_end <= 6):
            return False, 'blink overlap'
        prev_end = b['end']
    if blinks[-1]['end'] > frames - 2:
        return False, 'past end'
    if not any(b['left_off'] or b['right_off'] for b in blinks):
        return False, 'no L/R stagger'
    return True, 'ok'


def find_seed(start=DEFAULT_SEED, limit=20000):
    for seed in range(start, start + limit):
        sch = generate_schedule(seed)
        ok, why = is_valid(sch)
        if ok:
            return seed, sch
    raise RuntimeError('no valid seed in %d..%d' % (start, start + limit))


def stats(windows=200, seed=DEFAULT_SEED):
    """Generate `windows` 7 s clips and report the realised double rate."""
    total = 0
    pairs = 0
    windows_with_double = 0
    for s in range(seed, seed + windows):
        sch = generate_schedule(s)
        total += len(sch['blinks'])
        pairs += sch['double_pairs']
        windows_with_double += 1 if sch['double_pairs'] else 0
    return {'windows': windows, 'blinks': total, 'double_pairs': pairs,
            'pairs_per_100_blinks': round(100.0 * pairs / max(1, total), 2),
            'windows_with_double': windows_with_double,
            'target_p': P_DOUBLE}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--seed', type=int, default=None,
                    help='seed; default: auto-pick the first seed matching the demo policy')
    ap.add_argument('--json', default=None)
    ap.add_argument('--stats', action='store_true')
    ap.add_argument('--blinks', type=int, default=200)
    args = ap.parse_args()

    if args.stats:
        print(json.dumps(stats(args.blinks), indent=2))
        return
    if args.seed is None:
        seed, sch = find_seed()
        print('# auto-picked seed', seed)
    else:
        seed = args.seed
        sch = generate_schedule(seed)
    ok, why = is_valid(sch)
    print(json.dumps(sch, indent=2))
    print('# valid:', ok, why)
    if args.json:
        with open(args.json, 'w') as f:
            json.dump(sch, f, indent=2)
        print('# wrote', args.json)
    if not ok:
        raise SystemExit(2)


if __name__ == '__main__':
    main()
