import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 45_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [["list"]],
  outputDir: "test-results",
  use: {
    baseURL: "http://127.0.0.1:3311",
    viewport: { width: 1920, height: 1080 },
    trace: "retain-on-failure",
    video: "off"
  },
  webServer: {
    command: "npm run build && npm run start -- --port 3311",
    url: "http://127.0.0.1:3311/api/status",
    reuseExistingServer: false,
    timeout: 300_000,
    env: {
      NEXT_TELEMETRY_DISABLED: "1",
      SEARCH_PROVIDER: "mock",
      VISION_PROVIDER: "demo"
    }
  }
});
