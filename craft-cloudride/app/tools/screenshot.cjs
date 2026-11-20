// Verification screenshot, exactly as specified: Playwright + Chrome headless
// with GPU enabled, 1280x720, ~4 s after load, saved to ../docs/screenshot.png.
// Usage: serve the app first (cd app && python3 -m http.server 8801), then
//   node tools/screenshot.cjs

const fs = require('fs');
const path = require('path');
const { chromium } = require('/Users/ks_128/node_modules/playwright');

(async () => {
  const browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
    args: ['--ignore-gpu-blocklist', '--enable-webgl', '--use-angle=metal'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (err) => errors.push(String(err)));
  await page.goto('http://localhost:8801/', { waitUntil: 'load' });
  await page.waitForTimeout(4000);
  // optional output path argument (used by the launcher); default stays
  // docs/screenshot.png as the request specifies
  const out = process.argv[2] || path.join(__dirname, '..', 'docs', 'screenshot.png');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  await page.screenshot({ path: out });
  if (errors.length) {
    console.error('CONSOLE ERRORS:\n' + errors.join('\n'));
    process.exitCode = 1;
  } else {
    console.log('OK — screenshot saved to ' + out + ', no console errors.');
  }
  await browser.close();
})();
