// Verification helper: serve app/ on :8801, open it in Chrome with GPU
// (WebGL via Metal), wait until ~4 s of in-page simulation time (on a GPU
// that is ~4.5 s wall clock; on software WebGL it takes longer), save a
// 1280x720 screenshot and report page errors, fps and sim time.
// Usage: node docs/shot.mjs [out.png] [waitMsCap]
import { chromium } from '/Users/ks_128/node_modules/playwright/index.mjs';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const appDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = process.argv[2] ? path.resolve(process.argv[2]) : path.join(appDir, 'docs', 'screenshot.png');
const waitCapMs = Number(process.argv[3] || 60000);

const server = spawn('python3', ['-m', 'http.server', '8801', '--bind', '127.0.0.1'], {
  cwd: appDir,
  stdio: 'ignore',
});
const stop = () => { try { server.kill(); } catch {} };

let up = false;
for (let i = 0; i < 50; i++) {
  try {
    const r = await fetch('http://127.0.0.1:8801/index.html');
    if (r.ok) { up = true; break; }
  } catch {}
  await new Promise((r) => setTimeout(r, 200));
}
if (!up) {
  console.error('server did not start');
  stop();
  process.exit(1);
}

const browser = await chromium.launch({
  channel: 'chrome',
  headless: true,
  args: ['--ignore-gpu-blocklist', '--enable-webgl', '--use-angle=metal'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', (e) => errors.push('pageerror: ' + e));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push('console: ' + m.text());
});
await page.goto('http://127.0.0.1:8801/?shot=1', { waitUntil: 'load' });
// wait until the page's simulation time reaches ~4 s (up to the cap)
const deadline = Date.now() + waitCapMs;
let simT = 0;
while (Date.now() < deadline && simT < 4) {
  await page.waitForTimeout(500);
  simT = await page.evaluate(() => window.__simT ?? 0);
}
fs.mkdirSync(path.dirname(out), { recursive: true });
await page.screenshot({ path: out });
const stats = await page.evaluate(() => ({
  fps: window.__fps ?? null,
  frames: window.__frames ?? null,
  simT: window.__simT ?? null,
}));
console.log(JSON.stringify({ screenshot: out, errors, ...stats }));
await browser.close();
stop();
process.exit(errors.length ? 1 : 0);
