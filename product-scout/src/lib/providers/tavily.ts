import { z } from "zod";

import { envValue } from "../config";
import { fetchJson } from "./http";
import {
  cleanText,
  hostnameChannel,
  priceFromSnippet,
  ratingFromSnippet,
  reviewCountFromSnippet,
  safeHttpUrl
} from "./parse-helpers";
import type {
  ProviderOfferSeed,
  ProviderSearchOutput,
  SearchInput,
  SearchProvider
} from "./types";

const tavilyResultSchema = z
  .object({
    title: z.string().optional(),
    url: z.string().optional(),
    content: z.string().optional(),
    score: z.number().optional()
  })
  .passthrough();

const tavilyResponseSchema = z
  .object({
    results: z.array(z.unknown()).optional(),
    answer: z.string().optional()
  })
  .passthrough();

export function parseTavilyResponse(raw: unknown): ProviderSearchOutput {
  const parsed = tavilyResponseSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error("Tavily 返回结构不符合预期");
  }

  const offers: ProviderOfferSeed[] = [];

  for (const item of parsed.data.results ?? []) {
    const result = tavilyResultSchema.safeParse(item);
    if (!result.success) continue;

    const link = safeHttpUrl(result.data.url);
    const title = cleanText(result.data.title, 180);
    if (!link || !title) continue;

    const snippet = cleanText(result.data.content, 450);

    offers.push({
      channel: hostnameChannel(link),
      title,
      link,
      priceText: priceFromSnippet(snippet),
      rating: ratingFromSnippet(snippet),
      reviewCount: reviewCountFromSnippet(snippet),
      snippet,
      reviewExcerpt: null
    });
  }

  return {
    offers,
    notes: [
      "Tavily 返回的是网页检索摘要，不是购物比价接口。价格与评分是从公开摘要中识别的文本提示，可能不是当前成交价；请打开来源页核对。",
      "本工具不会抓取需要登录或付费的页面，也不绕过任何站点的反爬机制。"
    ]
  };
}

export function createTavilyProvider(): SearchProvider {
  const apiKey = envValue("TAVILY_API_KEY");

  return {
    id: "tavily",
    label: "Tavily · 公开网页搜索",
    mode: "live",
    requiredEnv: ["TAVILY_API_KEY"],
    hint: "在 .env.local 设置 TAVILY_API_KEY，并设 SEARCH_PROVIDER=tavily。基础搜索每次约 1 credit。",
    isConfigured: () => Boolean(apiKey),
    missingEnv: () => (apiKey ? [] : ["TAVILY_API_KEY"]),

    async search(input: SearchInput): Promise<ProviderSearchOutput> {
      if (!apiKey) {
        throw new Error("missing TAVILY_API_KEY");
      }

      const raw = await fetchJson("https://api.tavily.com/search", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`
        },
        body: JSON.stringify({
          query: input.query,
          search_depth: "basic",
          topic: "general",
          max_results: input.limit,
          include_answer: false,
          include_raw_content: false
        })
      });

      return parseTavilyResponse(raw);
    }
  };
}
