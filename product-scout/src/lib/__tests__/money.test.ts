import { describe, expect, it } from "@jest/globals";

import {
  formatPrice,
  parsePriceText,
  parseRating,
  parseReviewCount
} from "../money";

describe("parsePriceText", () => {
  it("parses CNY with thousands separators", () => {
    expect(parsePriceText("¥2,299.00")).toEqual({
      amount: 2299,
      currency: "CNY",
      priceText: "¥2,299.00"
    });
  });

  it("recognises major currency symbols and units", () => {
    expect(parsePriceText("US$1,299.99")?.currency).toBe("USD");
    expect(parsePriceText("HK$4,999")?.currency).toBe("HKD");
    expect(parsePriceText("€79.90")?.currency).toBe("EUR");
    expect(parsePriceText("£89")?.currency).toBe("GBP");
    expect(parsePriceText("1,999元")?.currency).toBe("CNY");
    expect(parsePriceText("1,299 美元")?.currency).toBe("USD");
    expect(parsePriceText("JP¥19,800")?.currency).toBe("JPY");
  });

  it("takes the first amount from a range but preserves the label", () => {
    const parsed = parsePriceText("¥1,999 - ¥2,299");
    expect(parsed?.amount).toBe(1999);
    expect(parsed?.priceText).toBe("¥1,999 - ¥2,299");
  });

  it("returns unknown currency rather than inventing one", () => {
    expect(parsePriceText("1999")?.currency).toBe("UNKNOWN");
    expect(parsePriceText("待定")).toBeNull();
    expect(parsePriceText(null)).toBeNull();
  });
});

describe("parseRating", () => {
  it("accepts 0–5 numeric and text forms", () => {
    expect(parseRating(4.8)).toBe(4.8);
    expect(parseRating("4.7 / 5")).toBe(4.7);
    expect(parseRating("评分 4.6 分")).toBe(4.6);
    expect(parseRating("4.9 out of 5")).toBe(4.9);
  });

  it("rejects impossible scores instead of clamping them", () => {
    expect(parseRating(8)).toBeNull();
    expect(parseRating("暂无评分")).toBeNull();
    expect(parseRating(null)).toBeNull();
  });
});

describe("parseReviewCount", () => {
  it("understands Chinese units and separators", () => {
    expect(parseReviewCount("1.2万条评价")).toBe(12_000);
    expect(parseReviewCount("23,000")).toBe(23_000);
    expect(parseReviewCount("1.5k reviews")).toBe(1_500);
    expect(parseReviewCount(6320)).toBe(6320);
    expect(parseReviewCount(null)).toBeNull();
  });
});

describe("formatPrice", () => {
  it("renders a currency-marked price or a transparent fallback", () => {
    expect(formatPrice(2299, "CNY")).toBe("¥2,299");
    expect(formatPrice(1299.5, "USD")).toBe("$1,299.50");
    expect(formatPrice(null, "CNY")).toBe("未标注");
  });
});
