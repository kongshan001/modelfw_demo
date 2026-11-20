#!/usr/bin/env node
'use strict';

// Verification + capture harness.
// - Real Chrome (channel: chrome), WebGL on the actual GPU.
// - Tries the requested ANGLE Metal backend first; on machines where Metal is
//   unavailable (e.g. Intel HD 6000) Chrome silently falls back to SwiftShader,
//   so we retry with ANGLE GL and record the deviation in the report.
// - Writes 1280x720 screenshots, a 6-10 s MP4/GIF, and a JSON report.
// - Fails on console errors, page errors, non-local requests, missing files,
//   software rendering, or a measured FPS below the target.

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function loadPlaywright() {
  const candidates = [
    process.env.PLAYWRIGHT_MODULE,
    'playwright',
    path.join(process.env.HOME || '', 'node_modules', 'playwright')
  ].filter(Boolean);
  for (const candidate of candidates) {
    try {
      return require(candidate);
    } catch (error) {
      // Try the next location.
    }
  }
  console.error(
    'Playwright not found. Install it (npm i playwright) or set PLAYWRIGHT_MODULE to the package path.'
  );
  process.exit(2);
}

const { chromium } = loadPlaywright();

const ROOT = path.resolve(__dirname, '..');
const REPO = path.resolve(ROOT, '..');
const SHOTS = path.join(REPO, 'docs', 'shots');
const DOCS = path.join(REPO, 'docs');
const DEMO_URL = process.env.DEMO_URL || 'http://127.0.0.1:8145/';
const VIDEO_DIR = fs.mkdtempSync('/tmp/waterpro-video-');
const WIDTH = 1280;
const HEIGHT = 720;
const TARGET_FPS = Number(process.env.TARGET_FPS || 30);
const HEADLESS = process.env.HEADLESS === '1';
const BASE_ARGS = ['--ignore-gpu-blocklist', '--enable-webgl', '--use-angle=metal'];
const FALLBACK_ARGS = ['--ignore-gpu-blocklist', '--enable-webgl', '--use-angle=gl'];

const report = {
  startedAt: new Date().toISOString(),
  url: DEMO_URL,
  viewport: { width: WIDTH, height: HEIGHT },
  targetFps: TARGET_FPS,
  headless: HEADLESS,
  gpuProbe: null,
  gpuFallback: null,
  consoleErrors: [],
  pageErrors: [],
  externalRequests: [],
  presets: {},
  screenshots: [],
  video: {},
  failures: []
};

function fail(message) {
  report.failures.push(message);
  console.error('FAIL:', message);
}

function run(bin, args, label) {
  const result = spawnSync(bin, args, { encoding: 'utf8' });
  if (result.status !== 0) {
    console.error(result.stdout || '');
    console.error(result.stderr || '');
    fail(`${label} exited with ${result.status}`);
    return false;
  }
  return true;
}

function probeImage(file) {
  const buffer = fs.readFileSync(file);
  if (buffer.toString('ascii', 1, 4) !== 'PNG') throw new Error(`${file} is not a PNG`);
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

function mediaInfo(file) {
  const result = spawnSync('ffprobe', [
    '-v', 'error',
    '-show_entries', 'format=duration,size',
    '-of', 'default=noprint_wrappers=1',
    file
  ], { encoding: 'utf8' });
  if (result.status !== 0) return null;
  const out = {};
  for (const line of result.stdout.trim().split('\n')) {
    const [key, value] = line.split('=');
    if (key) out[key] = Number(value);
  }
  return out;
}

async function launchBrowser(args) {
  return chromium.launch({ channel: 'chrome', headless: HEADLESS, args });
}

async function probeGpu(browser) {
  const page = await browser.newPage({ viewport: { width: 400, height: 300 } });
  await page.goto('about:blank');
  const result = await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    if (!gl) return { webgl: false, renderer: 'no webgl' };
    const ext = gl.getExtension('WEBGL_debug_renderer_info');
    return {
      webgl: true,
      renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER)
    };
  });
  await page.close();
  return result;
}

function wirePage(page, bucket) {
  page.on('console', (message) => {
    if (message.type() === 'error') {
      bucket.consoleErrors.push(message.text());
      report.consoleErrors.push(message.text());
    }
  });
  page.on('pageerror', (error) => {
    bucket.pageErrors.push(error.message);
    report.pageErrors.push(error.message);
  });
  page.on('request', (request) => {
    const url = request.url();
    if (url.startsWith('data:') || url.startsWith('blob:')) return;
    try {
      const host = new URL(url).hostname;
      if (host !== '127.0.0.1' && host !== 'localhost') {
        bucket.externalRequests.push(url);
        report.externalRequests.push(url);
      }
    } catch (error) {
      // Ignore malformed URLs.
    }
  });
}

async function waitReady(page) {
  await page.goto(DEMO_URL, { waitUntil: 'load', timeout: 60000 });
  await page.waitForFunction(() => window.__ready === true, { timeout: 60000 });
  await page.waitForTimeout(1800);
}

async function sampleFps(page) {
  return page.evaluate(async () => {
    const samples = [];
    for (let i = 0; i < 6; i++) {
      await new Promise((resolve) => setTimeout(resolve, 250));
      samples.push(window.__stats.fps);
    }
    const valid = samples.filter((value) => value > 0).sort((a, b) => a - b);
    return {
      samples,
      median: valid.length ? valid[Math.floor(valid.length / 2)] : 0,
      stats: window.__stats,
      bootMs: window.__bootMs
    };
  });
}

async function main() {
  fs.mkdirSync(SHOTS, { recursive: true });
  fs.mkdirSync(DOCS, { recursive: true });

  let browser = await launchBrowser(BASE_ARGS);
  report.metalProbe = await probeGpu(browser);
  let gpuProbe = report.metalProbe;
  if (!gpuProbe.webgl) {
    fail('WebGL is unavailable in Chrome.');
  } else if (/swiftshader|software/i.test(gpuProbe.renderer)) {
    report.gpuFallback = 'ANGLE Metal selected SwiftShader; retried with ANGLE GL.';
    await browser.close();
    browser = await launchBrowser(FALLBACK_ARGS);
    gpuProbe = await probeGpu(browser);
  }
  report.gpuProbe = gpuProbe;

  if (!gpuProbe.webgl) {
    fail('WebGL is unavailable after the fallback launch.');
  }
  if (/swiftshader|software/i.test(gpuProbe.renderer)) {
    fail(`No hardware WebGL renderer: ${gpuProbe.renderer}`);
  }

  const context = await browser.newContext({
    viewport: { width: WIDTH, height: HEIGHT },
    deviceScaleFactor: 1
  });
  const page = await context.newPage();
  const bucket = { consoleErrors: [], pageErrors: [], externalRequests: [] };
  wirePage(page, bucket);

  await waitReady(page);

  for (const preset of ['day', 'sunset', 'dusk']) {
    await page.evaluate((name) => window.__demo.setPreset(name), preset);
    await page.waitForTimeout(1900);
    const fps = await sampleFps(page);
    const file = path.join(SHOTS, `waterpro-clouds-${preset}.png`);
    await page.screenshot({ path: file });
    const size = probeImage(file);
    report.screenshots.push({ preset, file: path.relative(REPO, file), ...size });
    report.presets[preset] = {
      fps: Number(fps.median.toFixed(1)),
      fpsSamples: fps.samples.map((value) => Number(value.toFixed(1))),
      quality: fps.stats.quality,
      skyTarget: fps.stats.skyTarget,
      gpu: fps.stats.gpu,
      bootMs: fps.bootMs
    };
    if (size.width !== WIDTH || size.height !== HEIGHT) {
      fail(`${preset} screenshot is ${size.width}x${size.height}, expected ${WIDTH}x${HEIGHT}`);
    }
    if (fps.median < TARGET_FPS) {
      fail(`${preset} median FPS ${fps.median.toFixed(1)} is below ${TARGET_FPS}`);
    }
  }

  // Make a contact sheet for quick review.
  run('ffmpeg', [
    '-y',
    '-i', path.join(SHOTS, 'waterpro-clouds-day.png'),
    '-i', path.join(SHOTS, 'waterpro-clouds-sunset.png'),
    '-i', path.join(SHOTS, 'waterpro-clouds-dusk.png'),
    '-filter_complex',
    '[0:v]scale=640:-1[a];[1:v]scale=640:-1[b];[2:v]scale=640:-1[c];[a][b][c]hstack=inputs=3',
    path.join(SHOTS, 'waterpro-clouds-contact.png')
  ], 'contact sheet');

  // Deterministic frame-by-frame video pass on the visible page. Playwright's
  // built-in screencast can freeze when a headed window is occluded on macOS,
  // so we step the simulation and take screenshots instead.
  await page.evaluate(() => {
    window.__demo.pause(true);
    window.__demo.snapPalette('sunset');
  });
  report.videoVisibility = await page.evaluate(() => document.visibilityState);
  if (report.videoVisibility !== 'visible') {
    fail(`video page visibility is ${report.videoVisibility}`);
  }

  const framesDir = path.join(VIDEO_DIR, 'frames');
  fs.mkdirSync(framesDir, { recursive: true });
  const FRAME_COUNT = 90;
  const FRAME_RATE = 12;
  const presetCues = new Map([[24, 'day'], [54, 'sunset'], [74, 'dusk']]);

  for (let i = 0; i < FRAME_COUNT; i++) {
    if (presetCues.has(i)) {
      await page.evaluate((name) => window.__demo.setPreset(name), presetCues.get(i));
    }
    await page.evaluate((frame) => {
      window.__demo.step(1 / 12);
      window.__demo.setCamera({ theta: 0.55 + frame * 0.0022, phi: 1.41, radius: 96 });
    }, i);
    await page.waitForTimeout(45);
    await page.screenshot({
      path: path.join(framesDir, `frame-${String(i).padStart(4, '0')}.png`)
    });
  }

  await context.close();

  const mp4 = path.join(DOCS, 'waterpro-clouds-demo.mp4');
  const gif = path.join(DOCS, 'waterpro-clouds-demo.gif');
  const frameInput = ['-framerate', String(FRAME_RATE), '-start_number', '0', '-i', path.join(framesDir, 'frame-%04d.png')];
  const mp4Ok = run('ffmpeg', [
    '-y', ...frameInput,
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '21',
    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', mp4
  ], 'mp4 encode');
  const gifOk = run('ffmpeg', [
    '-y', ...frameInput,
    '-filter_complex',
    'scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=192[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4',
    '-loop', '0', gif
  ], 'gif encode');

  // Guard against a frozen recording (e.g. a background window): sample the
  // average color of a mid-video frame. The loading screen is nearly black.
  if (fs.existsSync(mp4)) {
    const frame = spawnSync('ffmpeg', [
      '-v', 'error', '-ss', '2', '-i', mp4, '-frames:v', '1',
      '-vf', 'scale=1:1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'
    ]);
    const px = frame.stdout && frame.stdout.length >= 3
      ? [frame.stdout[0], frame.stdout[1], frame.stdout[2]]
      : null;
    report.videoAverageColor = px;
    if (!px || px[0] + px[1] + px[2] < 80) {
      fail(`video looks like a frozen/loading frame (avg rgb ${px})`);
    }
  }

  const mp4Info = mediaInfo(mp4);
  const gifInfo = mediaInfo(gif);
  report.video = {
    mp4: fs.existsSync(mp4) ? { file: path.relative(REPO, mp4), ...mp4Info } : null,
    gif: fs.existsSync(gif) ? { file: path.relative(REPO, gif), ...gifInfo } : null,
    mp4Ok,
    gifOk,
    frames: FRAME_COUNT,
    frameRate: FRAME_RATE,
    seconds: FRAME_COUNT / FRAME_RATE,
    capture: 'deterministic stepped screenshots (occlusion-safe)'
  };
  for (const [name, info] of [['mp4', mp4Info], ['gif', gifInfo]]) {
    if (!info || !info.duration) {
      fail(`${name} output is missing or has no duration.`);
    } else if (info.duration < 6 || info.duration > 10.5) {
      fail(`${name} duration ${info.duration.toFixed(2)}s is outside 6-10 s.`);
    }
  }

  if (report.consoleErrors.length || report.pageErrors.length) {
    fail(`console/page errors: ${report.consoleErrors.length}/${report.pageErrors.length}`);
  }
  if (report.externalRequests.length) {
    fail(`external requests: ${report.externalRequests.join(', ')}`);
  }
  report.externalRequests = [...new Set(report.externalRequests)];
  report.consoleErrors = [...new Set(report.consoleErrors)];
  report.pageErrors = [...new Set(report.pageErrors)];
  report.finishedAt = new Date().toISOString();
  report.passed = report.failures.length === 0;

  const reportFile = path.join(DOCS, 'waterpro-clouds-verification.json');
  fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');

  console.log('— waterpro / three.js verification —');
  console.log(`GPU (Metal probe): ${report.metalProbe?.renderer || 'n/a'}`);
  console.log(`GPU (final): ${report.gpuProbe?.renderer || 'n/a'}`);
  if (report.gpuFallback) console.log(`GPU fallback: ${report.gpuFallback}`);
  for (const [name, info] of Object.entries(report.presets)) {
    console.log(
      `${name.padEnd(6)} fps=${String(info.fps).padStart(5)}  quality=${info.quality}  skyRT=${info.skyTarget?.join('x')}`
    );
  }
  console.log(`console errors: ${report.consoleErrors.length}`);
  console.log(`external requests: ${report.externalRequests.length}`);
  console.log(`report: ${path.relative(REPO, reportFile)}`);
  console.log(`video: ${report.video.mp4?.file || 'missing'} / ${report.video.gif?.file || 'missing'}`);
  console.log(report.passed ? 'PASS' : `FAIL (${report.failures.length} issues)`);

  await browser.close();
  process.exit(report.passed ? 0 : 1);
}

main().catch(async (error) => {
  console.error(error);
  report.failures.push(error.message);
  report.passed = false;
  fs.mkdirSync(DOCS, { recursive: true });
  fs.writeFileSync(
    path.join(DOCS, 'waterpro-clouds-verification.json'),
    JSON.stringify(report, null, 2) + '\n'
  );
  process.exit(1);
});
