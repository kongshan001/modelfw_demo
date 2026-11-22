import { getSearchLimit } from "./config";
import { normalizeProviderOffers } from "./offers";
import { ProviderError } from "./providers/http";
import { getSearchProvider } from "./providers";
import { hasMixedCurrencies, pickLowestCandidate } from "./sort";
import type { ProductIdentity, SearchPayload } from "./types";
import { buildSearchQuery, productSchema } from "./validation";

const BASE_NOTES = [
  "仅为本次公开检索返回结果中的候选，不是“全网最低价”保证；价格、库存与版本请以商家页面为准。",
  "未绕过登录、付费墙或反爬机制；没有公开接口的数据不会出现在本结果中。"
];

export class SearchValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SearchValidationError";
  }
}

export async function runProductSearch(
  input: ProductIdentity
): Promise<SearchPayload> {
  const parsed = productSchema.safeParse(input);
  if (!parsed.success) {
    throw new SearchValidationError(
      parsed.error.issues.map((issue) => issue.message).join("；")
    );
  }

  const product = parsed.data;
  const query = buildSearchQuery(product);
  const provider = getSearchProvider();

  if (!provider.isConfigured()) {
    throw new ProviderError(
      `${provider.label} 尚未配置`,
      {
        code: "missing_key",
        hint: `${provider.hint} 当前缺少：${provider.missingEnv().join("、")}。可先切回 SEARCH_PROVIDER=mock 体验完整流程。`
      }
    );
  }

  const limit = getSearchLimit();
  const output = await provider.search({ product, query, limit });
  const fetchedAt = new Date().toISOString();
  const offers = normalizeProviderOffers(output, provider.id, fetchedAt, limit);
  const lowest = pickLowestCandidate(offers);

  const notes = [...BASE_NOTES, ...output.notes];

  if (offers.length === 0) {
    notes.push(
      "本次检索没有返回可展示的候选。可检查字段、搜索服务额度或网络后重试。"
    );
  }
  if (hasMixedCurrencies(offers)) {
    notes.push(
      "结果包含多个币种，未做汇率换算，也未给出跨币种的最低候选；价格排序按币种分组。"
    );
  }
  if (offers.some((offer) => offer.price === null)) {
    notes.push("有结果未标注价格，这些结果不参与最低候选判断。");
  }

  return {
    query,
    providerId: provider.id,
    providerLabel: provider.label,
    mode: provider.mode,
    fetchedAt,
    offers,
    notes,
    lowest: lowest
      ? {
          offerId: lowest.offerId,
          price: lowest.price,
          currency: lowest.currency
        }
      : null
  };
}
