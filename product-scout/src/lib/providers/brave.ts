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

const braveResultSchema = z
  .object({
    title: z.string().optional(),
    url: z.string().optional(),
    description: z.string().optional(),
    extra_snippets: z.array(z.string()).optional()
  })
  .passthrough();

const braveResponseSchema = z
  .object({
    web: z
      .object({
        results: z.array(z.unknown()).optional()
      })
      .passthrough()
      .optional()
  })
  .passthrough();

export function parseBraveResponse(raw: unknown): ProviderSearchOutput {
  const parsed = braveResponseSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error("Brave 返回结构不符合预期");
  }

  const offers: ProviderOfferSeed[] = [];

  for (const item of parsed.data.web?.results ?? []) {
    const result = braveResultSchema.safeParse(item);
    if (!result.success) continue;

    const link = safeHttpUrl(result.data.url);
    const title = cleanText(result.data.title, 180);
    if (!link || !title) continue;

    const extra = result.data.extra_snippets?.join(" ");
    const snippet = cleanText(
      [result.data.description, extra].filter(Boolean).join(" "),
      450
    );

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
      "Brave 使用网页搜索接口（Shopping 专用接口以官方当前套餐为准）。结果仅包含公开网页摘要，价格提示需打开来源页核实。",
      "未使用网页抓取或反爬绕过。"
    ]
  };
}

export function createBraveProvider(): SearchProvider {
  const apiKey = envValue("BRAVE_API_KEY");

  return {
    id: "brave",
    label: "Brave · 公开网页搜索",
    mode: "live",
    requiredEnv: ["BRAVE_API_KEY"],
    hint: "在 .env.local 设置 BRAVE_API_KEY，并设 SEARCH_PROVIDER=brave。注意当前套餐与免费额度以 Brave 官方为准。",
    isConfigured: () => Boolean(apiKey),
    missingEnv: () => (apiKey ? [] : ["BRAVE_API_KEY"]),

    async search(input: SearchInput): Promise<ProviderSearchOutput> {
      if (!apiKey) {
        throw new Error("missing BRAVE_API_KEY");
      }

      const url = new URL("https://api.search.brave.com/res/v1/web/search");
      url.searchParams.set("q", input.query);
      url.searchParams.set("count", String(input.limit));
      url.searchParams.set("safesearch", "moderate");

      const raw = await fetchJson(url.toString(), {
        method: "GET",
        headers: {
          Accept: "application/json",
          "X-Subscription-Token": apiKey
        }
      });

      return parseBraveResponse(raw);
    }
  };
}
