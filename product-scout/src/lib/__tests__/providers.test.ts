import { describe, expect, it } from "@jest/globals";

import { normalizeProviderOffers } from "../offers";
import { parseBraveResponse } from "../providers/brave";
import { parseSerpApiResponse } from "../providers/serpapi";
import { parseSerperResponse } from "../providers/serper";
import { parseTavilyResponse } from "../providers/tavily";
import type { ProviderOfferSeed } from "../providers/types";

describe("Serper parser", () => {
  it("normalizes Google Shopping rows", () => {
    const output = parseSerperResponse({
      shopping: [
        {
          title: "Sony WH-1000XM5 无线降噪耳机",
          source: "京东",
          link: "https://search.jd.com/Search?keyword=Sony",
          price: "¥2,299.00",
          rating: 4.9,
          ratingCount: 23_000,
          delivery: "次日达"
        },
        {
          title: "Invalid link row",
          link: "javascript:alert(1)",
          price: "¥1"
        }
      ]
    });

    expect(output.offers).toHaveLength(1);
    expect(output.offers[0]).toMatchObject({
      channel: "京东",
      priceText: "¥2,299.00",
      rating: 4.9,
      reviewCount: 23_000,
      reviewExcerpt: null
    });
    expect(output.notes.join(" ")).toContain("Google Shopping");
  });

  it("throws on an unexpected envelope", () => {
    expect(() => parseSerperResponse([])).toThrow("Serper");
  });
});

describe("SerpAPI parser", () => {
  it("normalizes shopping_results and keeps source links", () => {
    const output = parseSerpApiResponse({
      shopping_results: [
        {
          title: "Sony WH-1000XM5 Headphones",
          source: "Amazon",
          link: "https://www.amazon.com/s?k=Sony+WH-1000XM5",
          price: "US$399.99",
          rating: 4.7,
          reviews: 9800,
          snippet: "Public listing snippet"
        }
      ]
    });

    expect(output.offers[0]).toMatchObject({
      channel: "Amazon",
      priceText: "US$399.99",
      rating: 4.7,
      reviewCount: 9800,
      reviewExcerpt: null
    });
    expect(output.offers[0]?.snippet).toContain("Public listing");
  });

  it("treats a provider error field as a failed parse", () => {
    expect(() =>
      parseSerpApiResponse({ error: "Invalid API key" })
    ).toThrow("错误状态");
  });
});

describe("Tavily parser", () => {
  it("extracts snippet-derived price, rating and review count", () => {
    const output = parseTavilyResponse({
      results: [
        {
          title: "索尼 WH-1000XM5 价格与测评",
          url: "https://post.smzdm.com/p/abc123/",
          content: "近期售价 ¥1,299，公开评分 4.8 分，已有 1.2万条评价。",
          score: 0.91
        }
      ]
    });

    expect(output.offers[0]).toMatchObject({
      channel: "什么值得买",
      priceText: "¥1,299",
      rating: 4.8,
      reviewCount: 12_000,
      reviewExcerpt: null
    });
    expect(output.notes.join(" ")).toContain("网页检索摘要");
  });

  it("returns an empty list for a valid empty response", () => {
    expect(parseTavilyResponse({ results: [] }).offers).toEqual([]);
  });
});

describe("Brave parser", () => {
  it("normalizes web results and merges extra snippets", () => {
    const output = parseBraveResponse({
      web: {
        results: [
          {
            title: "Sony WH-1000XM5 review",
            url: "https://www.amazon.com/dp/B09Y2MYL5C",
            description: "现价 $329.99，评分 4.7/5。",
            extra_snippets: ["公开页面片段"]
          }
        ]
      }
    });

    expect(output.offers[0]).toMatchObject({
      channel: "亚马逊",
      priceText: "$329.99",
      rating: 4.7
    });
    expect(output.offers[0]?.snippet).toContain("公开页面片段");
  });

  it("accepts a response without web results", () => {
    expect(parseBraveResponse({}).offers).toEqual([]);
  });
});

describe("normalizeProviderOffers", () => {
  const seeds: ProviderOfferSeed[] = [
    {
      channel: "渠道 A",
      title: "商品 A",
      link: "https://example.com/a",
      priceText: "¥100",
      rating: 4.5,
      reviewCount: 10,
      snippet: "摘要 A",
      reviewExcerpt: "这条不是 live 评论正文"
    },
    {
      channel: "渠道 B",
      title: "商品 B",
      link: "https://example.com/a#reviews",
      priceText: "¥90",
      rating: 4.6,
      reviewCount: 20,
      snippet: "重复链接",
      reviewExcerpt: null
    },
    {
      channel: "渠道 C",
      title: "商品 C",
      link: "https://example.com/c",
      priceText: null,
      rating: null,
      reviewCount: null,
      snippet: null,
      reviewExcerpt: null
    }
  ];

  it("drops review excerpts from live providers and dedupes links", () => {
    const offers = normalizeProviderOffers(
      { offers: seeds, notes: [] },
      "tavily",
      "2026-11-22T00:00:00.000Z",
      5
    );

    expect(offers).toHaveLength(2);
    expect(offers[0]?.reviewExcerpt).toBeNull();
    expect(offers[0]?.price).toBe(100);
    expect(offers[1]?.price).toBeNull();
    expect(offers[1]?.currency).toBe("UNKNOWN");
  });

  it("keeps demo review excerpts because they are explicitly labelled", () => {
    const offers = normalizeProviderOffers(
      { offers: seeds.slice(0, 1), notes: [] },
      "mock",
      "2026-11-22T00:00:00.000Z",
      5
    );
    expect(offers[0]?.reviewExcerpt).toContain("live 评论");
  });

  it("honours the result limit and drops invalid URLs", () => {
    const offers = normalizeProviderOffers(
      {
        offers: [
          ...seeds,
          {
            channel: "bad",
            title: "bad",
            link: "ftp://example.com/file",
            priceText: "¥1",
            rating: null,
            reviewCount: null,
            snippet: null,
            reviewExcerpt: null
          }
        ],
        notes: []
      },
      "mock",
      "2026-11-22T00:00:00.000Z",
      1
    );
    expect(offers).toHaveLength(1);
    expect(offers[0]?.link).toBe("https://example.com/a");
  });
});
