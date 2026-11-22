import { z } from "zod";

import { envValue, getSearchLocale } from "../config";
import { fetchJson } from "./http";
import {
  channelFromSource,
  cleanText,
  normalizePriceText,
  normalizeRating,
  normalizeReviewCount,
  safeHttpUrl
} from "./parse-helpers";
import type {
  ProviderOfferSeed,
  ProviderSearchOutput,
  SearchInput,
  SearchProvider
} from "./types";

const serperItemSchema = z
  .object({
    title: z.string().optional(),
    source: z.string().optional(),
    link: z.string().optional(),
    price: z.union([z.string(), z.number()]).optional(),
    rating: z.union([z.number(), z.string()]).optional(),
    ratingCount: z.union([z.number(), z.string()]).optional(),
    reviews: z.union([z.number(), z.string()]).optional(),
    delivery: z.string().optional()
  })
  .passthrough();

const serperResponseSchema = z
  .object({
    shopping: z.array(z.unknown()).optional(),
    shopping_results: z.array(z.unknown()).optional()
  })
  .passthrough();

export function parseSerperResponse(raw: unknown): ProviderSearchOutput {
  const parsed = serperResponseSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error("Serper 返回结构不符合预期");
  }

  const items = parsed.data.shopping ?? parsed.data.shopping_results ?? [];
  const offers: ProviderOfferSeed[] = [];
  const notes = [
    "Serper 返回 Google Shopping 的公开聚合结果；价格与币种以来源页面为准。"
  ];

  for (const item of items) {
    const result = serperItemSchema.safeParse(item);
    if (!result.success) continue;

    const link = safeHttpUrl(result.data.link);
    const title = cleanText(result.data.title, 180);
    if (!link || !title) continue;

    offers.push({
      channel: channelFromSource(result.data.source, link),
      title,
      link,
      priceText: normalizePriceText(result.data.price),
      rating: normalizeRating(result.data.rating),
      reviewCount: normalizeReviewCount(
        result.data.ratingCount ?? result.data.reviews
      ),
      snippet: cleanText(result.data.delivery, 300),
      reviewExcerpt: null
    });
  }

  if (offers.some((offer) => offer.priceText === null)) {
    notes.push("部分结果未返回价格；未标注价格的结果不会参与最低候选判断。");
  }

  return { offers, notes };
}

export function createSerperProvider(): SearchProvider {
  const apiKey = envValue("SERPER_API_KEY");
  const locale = getSearchLocale();

  return {
    id: "serper",
    label: "Serper · Google Shopping",
    mode: "live",
    requiredEnv: ["SERPER_API_KEY"],
    hint: "在 .env.local 设置 SERPER_API_KEY，并设 SEARCH_PROVIDER=serper。购物搜索每次约消耗 2 credits。",
    isConfigured: () => Boolean(apiKey),
    missingEnv: () => (apiKey ? [] : ["SERPER_API_KEY"]),

    async search(input: SearchInput): Promise<ProviderSearchOutput> {
      if (!apiKey) {
        throw new Error("missing SERPER_API_KEY");
      }

      const raw = await fetchJson("https://google.serper.dev/shopping", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": apiKey
        },
        body: JSON.stringify({
          q: input.query,
          gl: locale.country,
          hl: locale.language,
          num: input.limit
        })
      });

      return parseSerperResponse(raw);
    }
  };
}
