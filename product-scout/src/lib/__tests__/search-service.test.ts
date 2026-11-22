import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";

import { runProductSearch, SearchValidationError } from "../search-service";

const SONY = {
  brand: "Sony",
  model: "WH-1000XM5",
  category: "头戴式降噪耳机",
  specs: "蓝牙 5.2"
};

describe("runProductSearch (mock provider)", () => {
  const original = process.env.SEARCH_PROVIDER;

  beforeEach(() => {
    process.env.SEARCH_PROVIDER = "mock";
  });

  afterEach(() => {
    if (original === undefined) delete process.env.SEARCH_PROVIDER;
    else process.env.SEARCH_PROVIDER = original;
  });

  it("aggregates five demo channels with a lowest candidate", async () => {
    const payload = await runProductSearch(SONY);

    expect(payload.mode).toBe("demo");
    expect(payload.providerId).toBe("mock");
    expect(payload.query).toBe("Sony WH-1000XM5 头戴式降噪耳机 价格");
    expect(payload.offers).toHaveLength(5);
    expect(new Set(payload.offers.map((offer) => offer.channel)).size).toBe(5);
    expect(payload.lowest).toEqual({
      offerId: expect.any(String),
      price: 1999,
      currency: "CNY"
    });
    expect(Number.isNaN(Date.parse(payload.fetchedAt))).toBe(false);
    expect(payload.notes.join(" ")).toContain("Demo 演示数据");
    expect(payload.notes.join(" ")).toContain("不是“全网最低价”保证");
    expect(payload.offers.every((offer) => offer.source === "mock")).toBe(true);
  });

  it("returns a transparent empty result for unknown demo products", async () => {
    const payload = await runProductSearch({
      brand: "Nintendo",
      model: "Switch OLED",
      category: "游戏机",
      specs: ""
    });

    expect(payload.offers).toEqual([]);
    expect(payload.lowest).toBeNull();
    expect(payload.notes.join(" ")).toContain("未匹配到内置样例");
  });

  it("rejects empty product identity", async () => {
    await expect(
      runProductSearch({ brand: " ", model: "", category: "", specs: "" })
    ).rejects.toBeInstanceOf(SearchValidationError);
  });
});
