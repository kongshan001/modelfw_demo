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

const serpApiItemSchema = z
  .object({
    title: z.string().optional(),
    source: z.string().optional(),
    link: z.string().optional(),
    price: z.union([z.string(), z.number()]).optional(),
    extracted_price: z.number().optional(),
    rating: z.union([z.number(), z.string()]).optional(),
    reviews: z.union([z.number(), z.string()]).optional(),
    snippet: z.string().optional(),
    delivery: z.string().optional()
  })
  .passthrough();

const serpApiResponseSchema = z
  .object({
    shopping_results: z.array(z.unknown()).optional(),
    error: z.string().optional()
  })
  .passthrough();

export function parseSerpApiResponse(raw: unknown): ProviderSearchOutput {
  const parsed = serpApiResponseSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error("SerpAPI 返回结构不符合预期");
  }
  if (parsed.data.error) {
    throw new Error("SerpAPI 返回了错误状态");
  }

  const offers: ProviderOfferSeed[] = [];
  const notes = [
    "SerpAPI 返回 Google Shopping 的公开聚合结果；价格为检索时页面标价，可能随时变化。"
  ];

  for (const item of parsed.data.shopping_results ?? []) {
    const result = serpApiItemSchema.safeParse(item);
    if (!result.success) continue;

    const link = safeHttpUrl(result.data.link);
    const title = cleanText(result.data.title, 180);
    if (!link || !title) continue;

    const priceText = normalizePriceText(result.data.price);

    offers.push({
      channel: channelFromSource(result.data.source, link),
      title,
      link,
      priceText,
      rating: normalizeRating(result.data.rating),
      reviewCount: normalizeReviewCount(result.data.reviews),
      snippet:
        cleanText(result.data.snippet, 400) ??
        cleanText(result.data.delivery, 300),
      reviewExcerpt: null
    });
  }

  if (offers.some((offer) => offer.priceText === null)) {
    notes.push("部分结果未返回价格；未标价结果不参与最低候选判断。");
  }

  return { offers, notes };
}

export function createSerpApiProvider(): SearchProvider {
  const apiKey = envValue("SERPAPI_API_KEY");
  const locale = getSearchLocale();

  return {
    id: "serpapi",
    label: "SerpAPI · Google Shopping",
    mode: "live",
    requiredEnv: ["SERPAPI_API_KEY"],
    hint: "在 .env.local 设置 SERPAPI_API_KEY，并设 SEARCH_PROVIDER=serpapi。免费层每月 250 次成功搜索，超出后按套餐计费。",
    isConfigured: () => Boolean(apiKey),
    missingEnv: () => (apiKey ? [] : ["SERPAPI_API_KEY"]),

    async search(input: SearchInput): Promise<ProviderSearchOutput> {
      if (!apiKey) {
        throw new Error("missing SERPAPI_API_KEY");
      }

      const url = new URL("https://serpapi.com/search.json");
      url.searchParams.set("engine", "google_shopping");
      url.searchParams.set("q", input.query);
      url.searchParams.set("gl", locale.country);
      url.searchParams.set("hl", locale.language);
      url.searchParams.set("num", String(input.limit));
      url.searchParams.set("api_key", apiKey);

      const raw = await fetchJson(url.toString(), {
        method: "GET",
        headers: { Accept: "application/json" }
      });

      return parseSerpApiResponse(raw);
    }
  };
}
