import { parsePriceText, parseRating, parseReviewCount } from "../money";

const DOMAIN_CHANNELS: Array<[RegExp, string]> = [
  [/(^|\.)jd\.com$/i, "京东"],
  [/(^|\.)tmall\.com$/i, "天猫"],
  [/(^|\.)taobao\.com$/i, "淘宝"],
  [/(^|\.)suning\.com$/i, "苏宁易购"],
  [/(^|\.)yangkeduo\.com$/i, "拼多多"],
  [/(^|\.)pinduoduo\.com$/i, "拼多多"],
  [/(^|\.)amazon\.[a-z.]+$/i, "亚马逊"],
  [/(^|\.)douyin\.com$/i, "抖音"],
  [/(^|\.)samsclub\.cn$/i, "山姆会员商店"],
  [/(^|\.)xiaohongshu\.com$/i, "小红书"],
  [/(^|\.)zhihu\.com$/i, "知乎"],
  [/(^|\.)smzdm\.com$/i, "什么值得买"]
];

const ENTITIES: Record<string, string> = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&quot;": '"',
  "&#39;": "'",
  "&nbsp;": " "
};

export function decodeEntities(value: string): string {
  return value
    .replace(/&(amp|lt|gt|quot|#39|nbsp);/g, (entity) => ENTITIES[entity] ?? entity)
    .replace(/\s+/g, " ")
    .trim();
}

export function cleanText(value: unknown, maxLength = 500): string | null {
  if (typeof value !== "string") return null;
  const text = decodeEntities(value.replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return null;
  return text.slice(0, maxLength);
}

export function safeHttpUrl(value: unknown): string | null {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "http:" && url.protocol !== "https:") return null;
    return url.toString();
  } catch {
    return null;
  }
}

export function hostnameChannel(value: string | null | undefined): string {
  if (!value) return "公开网页";
  try {
    const hostname = new URL(value).hostname.replace(/^www\./i, "");
    for (const [pattern, label] of DOMAIN_CHANNELS) {
      if (pattern.test(hostname)) return label;
    }
    return hostname;
  } catch {
    return "公开网页";
  }
}

export function channelFromSource(
  source: unknown,
  link: string | null
): string {
  const cleaned = cleanText(source, 60);
  return cleaned ?? hostnameChannel(link);
}

export function normalizeRating(raw: unknown): number | null {
  if (typeof raw === "number") return parseRating(raw);
  if (typeof raw === "string") return parseRating(raw);
  return null;
}

export function normalizeReviewCount(raw: unknown): number | null {
  if (typeof raw === "number") return parseReviewCount(raw);
  if (typeof raw === "string") return parseReviewCount(raw);
  return null;
}

export function normalizePriceText(raw: unknown): string | null {
  if (typeof raw === "string") return cleanText(raw, 80);
  if (typeof raw === "number" && Number.isFinite(raw)) return String(raw);
  return null;
}

/**
 * Extracts the first credible price mention from a public snippet. This is a
 * display hint, not a purchase price, and the UI labels it as snippet-derived.
 */
export function priceFromSnippet(text: string | null): string | null {
  if (!text) return null;

  const currencyFirst = text.match(
    /(?:HK\$|US\$|CN[¥￥]|JP[¥￥]|[¥￥$€£])\s*\d[\d,.]*(?:\s*-\s*(?:HK\$|US\$|CN[¥￥]|[¥￥$€£])?\s*\d[\d,.]*)?/i
  );
  if (currencyFirst?.[0]) return currencyFirst[0].trim();

  const unitAfter = text.match(
    /\d[\d,.]*(?:\.\d+)?\s*(?:元|美元|欧元|英镑|日元|港币)/i
  );
  if (unitAfter?.[0]) return unitAfter[0].trim();

  return null;
}

export function ratingFromSnippet(text: string | null): number | null {
  if (!text) return null;
  const match = text.match(
    /(\d(?:\.\d)?)\s*(?:\/\s*5|分|星|out of 5)/i
  );
  if (!match?.[1]) return null;
  return parseRating(Number.parseFloat(match[1]));
}

export function reviewCountFromSnippet(text: string | null): number | null {
  if (!text) return null;
  const match = text.match(
    /([\d,.]+\s*[万萬亿億kK]?)\s*(?:条|个|則|则)?\s*(?:评价|评论|reviews?)/i
  );
  if (!match?.[1]) return null;
  return parseReviewCount(match[1]);
}

export function needsLiveCurrencyNote(rawPrice: string | null): boolean {
  if (!rawPrice) return false;
  const parsed = parsePriceText(rawPrice);
  return parsed?.currency === "UNKNOWN";
}
