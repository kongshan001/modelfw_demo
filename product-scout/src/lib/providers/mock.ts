import {
  DEMO_DISCLAIMER,
  DEMO_PRODUCTS
} from "../fixtures/demo";
import type { SearchProvider, SearchInput, ProviderSearchOutput } from "./types";

const ALIASES: Record<string, { brands: string[]; models: string[] }> = {
  "sony-xm5": {
    brands: ["sony", "索尼"],
    models: ["wh-1000xm5", "wh1000xm5", "xm5"]
  },
  "anker-nano2": {
    brands: ["anker", "安克"],
    models: ["nano ii", "nano2", "65w", "氮化镓"]
  },
  "dyson-v12": {
    brands: ["dyson", "戴森"],
    models: ["v12", "detect slim"]
  }
};

function normalize(value: string): string {
  return value.toLocaleLowerCase().replace(/\s+/g, " ").trim();
}

function matchDemoProduct(input: SearchInput): string | null {
  const brand = normalize(input.product.brand);
  const model = normalize(input.product.model);
  const haystack = `${brand} ${model} ${normalize(input.product.category)}`;

  for (const demo of DEMO_PRODUCTS) {
    const aliases = ALIASES[demo.id];
    if (!aliases) continue;

    const brandHit = aliases.brands.some(
      (alias) => brand.includes(alias) || haystack.includes(alias)
    );
    const modelHit = aliases.models.some(
      (alias) => model.includes(alias) || haystack.includes(alias)
    );

    if (brandHit && modelHit) return demo.id;
  }

  return null;
}

const sleep = (ms: number) =>
  new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });

export const mockProvider: SearchProvider = {
  id: "mock",
  label: "内置演示数据",
  mode: "demo",
  requiredEnv: [],
  hint: "默认模式，不需要 API key；所有价格、评分与评论均为明确标注的样例数据。",
  isConfigured: () => true,
  missingEnv: () => [],

  async search(input: SearchInput): Promise<ProviderSearchOutput> {
    // Small deterministic delay keeps loading states observable in the demo
    // without wasting test time.
    await sleep(520);

    const demoId = matchDemoProduct(input);
    if (!demoId) {
      return {
        offers: [],
        notes: [
          "Demo 模式未匹配到内置样例商品。可点击页面上的示例，或配置真实搜索 provider 查询自定义商品。",
          DEMO_DISCLAIMER
        ]
      };
    }

    const demo = DEMO_PRODUCTS.find((entry) => entry.id === demoId);
    if (!demo) {
      return {
        offers: [],
        notes: ["Demo 数据读取失败。", DEMO_DISCLAIMER]
      };
    }

    return {
      offers: demo.offers.slice(0, input.limit).map((offer) => ({
        channel: offer.channel,
        title: offer.title,
        link: offer.link,
        priceText: offer.priceText,
        rating: offer.rating,
        reviewCount: offer.reviewCount,
        snippet: offer.snippet,
        reviewExcerpt: offer.reviewExcerpt
      })),
      notes: [
        DEMO_DISCLAIMER,
        "所用链接指向对应平台的公开搜索页，不是具体成交页；价格与库存请以平台页面为准。"
      ]
    };
  }
};
