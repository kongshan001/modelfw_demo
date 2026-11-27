#!/usr/bin/env node
/**
 * 3渲2 拖尾 GIF 证据：确定性截帧 + ffmpeg 编码
 *
 * 用法:
 *   node tools/giflab_capture.js                 # 全部 6 个模式
 *   node tools/giflab_capture.js rt map          # 只重建指定模式
 *
 * 依赖: playwright（本机 node 全局或 npx）、ffmpeg。
 * 输入: docs/2d-map-3d-trail-gif-lab.html 的 window.GIFLAB.seek(mode, t)
 * 输出: docs/shots/2d-map-3d-trail-<mode>.gif (960x540, 24fps, 96 帧, 4s, loop)
 *
 * 说明: 用 canvas.toDataURL 直接读 960x540 后备缓冲，避免 CSS 缩放和合成时序；
 *       所有帧由解析时间函数求出，录制过程确定性、可复现。
 */
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

let chromium;
try { ({ chromium } = require('playwright')); }
catch (e) { ({ chromium } = require(path.join(os.homedir(), 'node_modules', 'playwright'))); }

const ROOT = path.resolve(__dirname, '..');
const LAB = path.join(ROOT, 'docs', '2d-map-3d-trail-gif-lab.html');
const OUT_DIR = path.join(ROOT, 'docs', 'shots');
const FPS = 24, SECONDS = 4, FRAMES = FPS * SECONDS;
const ALL = ['rt', 'map', 'hybrid', 'true3d', 'gpu', 'afterimage'];
const modes = process.argv.slice(2).filter(m => ALL.includes(m));
const picked = modes.length ? modes : ALL;
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'giflab-'));

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 900 }, deviceScaleFactor: 1 });
  const errors = [], external = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('PAGEERROR ' + e.message));
  page.on('request', r => { if (!r.url().startsWith('file://')) external.push(r.url()); });

  await page.goto('file://' + LAB);
  await page.waitForFunction(() => window.GIFLAB && window.GIFLAB.ready);
  await page.waitForTimeout(400);

  // 首个 canvas 读回可能是空的后备缓冲（Chromium 首次呈现前的竞态）。
  // 统一走 grab()：PNG 体积过小视为空帧，重渲染重试。
  async function grab(mode, t) {
    for (let attempt = 0; attempt < 6; attempt++) {
      const b64 = await page.evaluate(([m, t]) => {
        window.GIFLAB.seek(m, t);
        return document.getElementById('stage').toDataURL('image/png').slice(22);
      }, [mode, t]);
      const buf = Buffer.from(b64, 'base64');
      if (buf.length > 20000) return buf;   // 空/透明 960x540 PNG 只有几 KB
      await page.waitForTimeout(120);
    }
    throw new Error('blank canvas after retries: ' + mode + ' @ ' + t);
  }
  await grab(picked[0], 0);   // 预热读回

  const summary = { lab: path.relative(ROOT, LAB), fps: FPS, seconds: SECONDS, frames: FRAMES, errors, external, gifs: {} };

  for (const mode of picked) {
    const dir = path.join(tmp, mode);
    fs.mkdirSync(dir, { recursive: true });
    for (let i = 0; i < FRAMES; i++) {
      const buf = await grab(mode, i / FPS);
      fs.writeFileSync(path.join(dir, String(i).padStart(3, '0') + '.png'), buf);
    }
    const out = path.join(OUT_DIR, `2d-map-3d-trail-${mode}.gif`);
    const vf = 'split[s0][s1];[s0]palettegen=max_colors=128:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle';
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-framerate', String(FPS),
      '-i', path.join(dir, '%03d.png'), '-vf', vf, '-loop', '0', out], { stdio: 'inherit' });
    summary.gifs[mode] = { file: path.relative(ROOT, out), bytes: fs.statSync(out).size };
    console.log(mode, fs.statSync(out).size, 'bytes');
  }

  const heroes = await page.evaluate(() => window.GIFLAB.heroes);
  summary.heroes = heroes;
  summary.heroStats = {};
  for (const mode of picked) {
    await page.evaluate(([m, t]) => window.GIFLAB.seek(m, t), [mode, heroes[mode]]);
    summary.heroStats[mode] = await page.evaluate(() => window.GIFLAB.stats());
  }
  await browser.close();
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log(JSON.stringify(summary, null, 2));
  if (errors.length || external.length) process.exitCode = 1;
})().catch(e => { console.error(e); process.exit(1); });
