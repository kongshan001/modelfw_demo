import fs from "node:fs";
import path from "node:path";

import { chromium } from "playwright";

const baseUrl = process.env.BASE_URL ?? "http://127.0.0.1:3111";
const outDir = path.resolve(process.cwd(), "docs/media");
const rawDir = path.join(outDir, "raw");

fs.mkdirSync(outDir, { recursive: true });
fs.mkdirSync(rawDir, { recursive: true });

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 1,
  recordVideo: {
    dir: rawDir,
    size: { width: 1920, height: 1080 }
  }
});
const page = await context.newPage();

const consoleErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", (error) => consoleErrors.push(`PAGEERROR: ${error.message}`));

await page.goto(baseUrl, { waitUntil: "networkidle" });
await page.waitForTimeout(900);
await page.screenshot({ path: path.join(outDir, "01-upload.png") });

await page.getByTestId("sample-sony-xm5").click();
await page.waitForFunction(
  () => document.querySelector("#field-brand")?.value === "Sony",
  null,
  { timeout: 10_000 }
);
await page.waitForTimeout(1300);

await page.getByTestId("search-submit").click();
await page.getByTestId("results-content").waitFor({ timeout: 15_000 });
await page.waitForTimeout(1600);
await page.screenshot({ path: path.join(outDir, "02-results.png") });

await page.locator("#reputation").scrollIntoViewIfNeeded();
await page.waitForTimeout(2100);
await page.screenshot({ path: path.join(outDir, "03-reputation.png") });

await page.waitForTimeout(500);
await context.close();

const mobile = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 1
});
const mobilePage = await mobile.newPage();
mobilePage.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
mobilePage.on("pageerror", (error) =>
  consoleErrors.push(`PAGEERROR: ${error.message}`)
);
await mobilePage.goto(baseUrl, { waitUntil: "networkidle" });
await mobilePage.getByTestId("sample-sony-xm5").click();
await mobilePage.waitForFunction(
  () => document.querySelector("#field-brand")?.value === "Sony",
  null,
  { timeout: 10_000 }
);
await mobilePage.getByTestId("search-submit").click();
await mobilePage.getByTestId("results-content").waitFor({ timeout: 15_000 });
await mobilePage.waitForTimeout(600);
await mobilePage.screenshot({ path: path.join(outDir, "04-mobile.png") });
await mobile.close();
await browser.close();

if (consoleErrors.length > 0) {
  console.error("CONSOLE ERRORS:", consoleErrors);
  process.exit(1);
}

const videos = fs
  .readdirSync(rawDir)
  .filter((file) => file.endsWith(".webm"))
  .map((file) => path.join(rawDir, file));

if (videos.length === 0) {
  console.error("No recorded video found");
  process.exit(1);
}

console.log("CAPTURED", {
  screenshots: [
    path.join(outDir, "01-upload.png"),
    path.join(outDir, "02-results.png"),
    path.join(outDir, "03-reputation.png"),
    path.join(outDir, "04-mobile.png")
  ],
  video: videos[0]
});
