import { describe, expect, it } from "@jest/globals";

import { buildReputationSummary } from "../reputation";
import type { Offer } from "../types";

function offer(partial: Partial<Offer> & Pick<Offer, "id">): Offer {
  return {
    channel: "京东",
    title: "测试商品",
    price: 100,
    currency: "CNY",
    priceText: "¥100",
    link: "https://search.jd.com/Search?keyword=test",
    rating: 4.8,
    reviewCount: 100,
    snippet: "商品摘要",
    reviewExcerpt: null,
    source: "mock",
    fetchedAt: "2026-11-22T00:00:00.000Z",
    rank: 0,
    ...partial
  };
}

describe("buildReputationSummary", () => {
  it("derives sourced pros and cons only from review excerpts", () => {
    const summary = buildReputationSummary([
      offer({
        id: "a",
        reviewExcerpt: "降噪效果很强，佩戴舒适。收纳盒偏大。",
        rating: 5,
        reviewCount: 300
      }),
      offer({
        id: "b",
        channel: "天猫",
        reviewExcerpt: "通话清晰。价格波动大。",
        rating: 4,
        reviewCount: 100,
        link: "https://s.taobao.com/search?q=test"
      })
    ]);

    expect(summary.ratedOfferCount).toBe(2);
    expect(summary.weightedRating).toBe(4.8);
    expect(summary.reviewCountSum).toBe(400);
    expect(summary.pros.length).toBeGreaterThanOrEqual(2);
    expect(summary.cons.length).toBeGreaterThanOrEqual(2);
    for (const point of [...summary.pros, ...summary.cons]) {
      expect(point.sourceUrl).toMatch(/^https:\/\//);
      expect(point.sourceChannel.length).toBeGreaterThan(0);
    }
    expect(summary.conclusion).toContain("加权均分 4.8/5");
  });

  it("does not treat product snippets as review quotes", () => {
    const summary = buildReputationSummary([
      offer({
        id: "a",
        snippet: "降噪效果很好，值得推荐。",
        reviewExcerpt: null
      })
    ]);

    expect(summary.pros).toEqual([]);
    expect(summary.cons).toEqual([]);
    expect(summary.unavailableNote).toContain("没有评论正文");
  });

  it("says 未获取 instead of inventing when no data exists", () => {
    const summary = buildReputationSummary([
      offer({
        id: "a",
        rating: null,
        reviewCount: null,
        snippet: null,
        reviewExcerpt: null
      })
    ]);

    expect(summary.weightedRating).toBeNull();
    expect(summary.reviewCountSum).toBeNull();
    expect(summary.conclusion).toContain("无法判断");
    expect(summary.unavailableNote).toContain("没有返回公开评分或评论正文");
  });

  it("falls back to a simple average when counts are missing", () => {
    const summary = buildReputationSummary([
      offer({ id: "a", rating: 5, reviewCount: null }),
      offer({ id: "b", rating: 4, reviewCount: null })
    ]);
    expect(summary.weightedRating).toBe(4.5);
  });

  it("caps the number of pros and cons", () => {
    const summary = buildReputationSummary([
      offer({
        id: "a",
        reviewExcerpt:
          "降噪很好。佩戴舒适。通话清晰。做工扎实。价格波动大。售后麻烦。散热一般。太贵。"
      })
    ]);
    expect(summary.pros).toHaveLength(3);
    expect(summary.cons).toHaveLength(3);
  });
});
