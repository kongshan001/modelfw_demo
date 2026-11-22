import path from "node:path";

import { expect, test } from "@playwright/test";

const SAMPLE_PATH = path.resolve(
  process.cwd(),
  "public/demo/sony-wh1000xm5.svg"
);

test("upload → demo recognition → public results → sourced sentiment", async ({
  page
}) => {
  const consoleErrors: string[] = [];
  const apiCalls: string[] = [];

  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleErrors.push(message.text());
    }
  });
  page.on("pageerror", (error) => {
    consoleErrors.push(`PAGEERROR: ${error.message}`);
  });
  page.on("request", (request) => {
    const url = new URL(request.url());
    if (url.pathname.startsWith("/api/")) {
      apiCalls.push(url.pathname);
    }
  });

  await page.goto("/", { waitUntil: "networkidle" });

  await expect(
    page.getByRole("heading", { name: /截图在手/ })
  ).toBeVisible();
  await expect(page.getByText("DEMO 数据").first()).toBeVisible();
  await expect(page.getByTestId("upload-open")).toBeVisible();

  await page.getByTestId("file-input").setInputFiles(SAMPLE_PATH);

  await expect(page.getByTestId("preview-image")).toBeVisible();
  await expect(page.locator("#field-brand")).toHaveValue("Sony", {
    timeout: 10_000
  });
  await expect(page.locator("#field-model")).toHaveValue("WH-1000XM5");
  await expect(page.getByTestId("query-preview")).toContainText(
    "Sony WH-1000XM5 头戴式降噪耳机 价格"
  );
  await expect(page.getByText("Demo 模式：以下字段来自内置样例")).toBeVisible();

  await page.getByTestId("search-submit").click();

  await expect(page.getByTestId("results-content")).toBeVisible({
    timeout: 15_000
  });
  await expect(page.getByTestId("lowest-candidate")).toContainText("¥1,999");
  await expect(page.getByTestId("lowest-candidate")).toContainText(
    "不是“全网最低价”保证"
  );
  await expect(page.getByTestId("offer-row")).toHaveCount(5);
  await expect(page.getByTestId("results-panel")).toContainText("5 个渠道");
  await expect(
    page.getByTestId("results-panel").getByText("DEMO 演示数据").first()
  ).toBeVisible();

  const sortGroup = page.getByRole("group", { name: "价格排序" });
  await sortGroup.getByRole("button").nth(1).click();
  await expect(page.getByTestId("offer-row").first()).toContainText("¥2,499");
  await sortGroup.getByRole("button").nth(0).click();
  await expect(page.getByTestId("offer-row").first()).toContainText("¥1,999");

  await expect(page.getByTestId("reputation-panel")).toBeVisible();
  await expect(page.getByTestId("reputation-panel")).toContainText(
    "加权均分 4.8/5"
  );
  await expect(page.getByTestId("reputation-panel")).toContainText("来源：");
  await expect(page.getByTestId("reputation-panel")).toContainText(
    "DEMO 评论片段"
  );
  await expect(page.getByText("来源：京东 · 自营").first()).toBeVisible();

  // Demo image processing must stay local: only the keyword search API is hit.
  expect(apiCalls).toContain("/api/search");
  expect(apiCalls).not.toContain("/api/extract");

  const firstSource = page.getByTestId("offer-row").first().getByRole("link").first();
  await expect(firstSource).toHaveAttribute("target", "_blank");
  await expect(firstSource).toHaveAttribute("rel", /noopener/);

  expect(consoleErrors).toEqual([]);
});

test("manual entry validates before searching", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => {
    consoleErrors.push(`PAGEERROR: ${error.message}`);
  });

  await page.goto("/", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: /手动填写/ }).first().click();
  await expect(page.getByRole("heading", { name: "核对商品信息" })).toBeVisible();

  await page.getByTestId("search-submit").click();
  await expect(
    page.getByText("请至少填写品牌或型号，才能构造检索词").first()
  ).toBeVisible();
  await expect(
    page.getByText("至少填写品牌或型号；品类与规格越完整，检索越准确。")
  ).toBeVisible();

  expect(consoleErrors).toEqual([]);
});
