// Golden-vector test for the JavaScript implementation.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { dirIndex, hash32, screenMotion } from '../impl/js/portable_core.mjs';

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const golden = JSON.parse(readFileSync(join(ROOT, 'spec', 'golden.json'), 'utf8'));
const EPS = 1e-9;
const fails = [];

for (const c of golden.iso) {
  const [mx, my] = screenMotion(c.in[0], c.in[1]);
  if (Math.abs(mx - c.motion[0]) > EPS || Math.abs(my - c.motion[1]) > EPS) {
    fails.push(`motion ${JSON.stringify(c.in)} -> ${mx},${my} != ${c.motion}`);
  }
  const got = dirIndex(c.in[0], c.in[1]);
  if (got !== c.dir) fails.push(`dir ${JSON.stringify(c.in)} -> ${got} != ${c.dir}`);
}

for (const c of golden.hash) {
  const got = hash32(c.x, c.y, c.seed);
  if (got !== c.out) fails.push(`hash (${c.x},${c.y},${c.seed}) -> ${got} != ${c.out}`);
}

if (fails.length) {
  for (const f of fails) console.error('PORTABLE_JS FAIL:', f);
  process.exit(1);
}
console.log(`PORTABLE_JS_OK iso=${golden.iso.length} hash=${golden.hash.length}`);
