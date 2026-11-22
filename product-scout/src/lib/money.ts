import type { Currency } from "./types";

export interface ParsedPrice {
  amount: number;
  currency: Currency;
  priceText: string;
}

const CURRENCY_SYMBOLS: Array<{
  pattern: RegExp;
  currency: Currency;
  strip: RegExp;
}> = [
  { pattern: /HK\$/i, currency: "HKD", strip: /HK\$/i },
  { pattern: /US\$/i, currency: "USD", strip: /US\$/i },
  { pattern: /CN[¥￥]/i, currency: "CNY", strip: /CN[¥￥]/i },
  { pattern: /JP[¥￥]/i, currency: "JPY", strip: /JP[¥￥]/i },
  { pattern: /NT\$/i, currency: "UNKNOWN", strip: /NT\$/i },
  { pattern: /€/, currency: "EUR", strip: /€/ },
  { pattern: /£/, currency: "GBP", strip: /£/ },
  { pattern: /\$/, currency: "USD", strip: /\$/ },
  { pattern: /[¥￥]/, currency: "CNY", strip: /[¥￥]/ },
  { pattern: /円/, currency: "JPY", strip: /円/ }
];

const CURRENCY_CODES: Array<{ pattern: RegExp; currency: Currency }> = [
  { pattern: /日元|\bJPY\b/i, currency: "JPY" },
  { pattern: /美元|\bUSD\b/i, currency: "USD" },
  { pattern: /欧元|\bEUR\b/i, currency: "EUR" },
  { pattern: /英镑|\bGBP\b/i, currency: "GBP" },
  { pattern: /港币|港元|\bHKD\b/i, currency: "HKD" },
  { pattern: /人民币|\bCNY\b|\bRMB\b|元/, currency: "CNY" }
];

export function parseAmount(raw: string): number | null {
  const normalized = raw
    .replace(/[，,](?=\d{3}(\D|$))/g, "")
    .replace(/\s+/g, "")
    .replace(/[–—~～至]/g, "-");

  const match = normalized.match(/(\d+(?:\.\d+)?)/);
  if (!match?.[1]) return null;

  const amount = Number.parseFloat(match[1]);
  return Number.isFinite(amount) && amount >= 0 ? amount : null;
}

export function parseReviewCount(raw: string | number | null | undefined): number | null {
  if (typeof raw === "number") {
    return Number.isFinite(raw) && raw >= 0 ? Math.round(raw) : null;
  }
  if (!raw) return null;

  const cleaned = raw.replace(/,/g, "").trim();
  const match = cleaned.match(/(\d+(?:\.\d+)?)\s*([万萬亿億kK])?/);
  if (!match?.[1]) return null;

  const base = Number.parseFloat(match[1]);
  if (!Number.isFinite(base)) return null;

  const unit = match[2];
  const multiplier =
    unit === "万" || unit === "萬"
      ? 10_000
      : unit === "亿" || unit === "億"
        ? 100_000_000
        : unit === "k" || unit === "K"
          ? 1_000
          : 1;

  return Math.round(base * multiplier);
}

export function parseRating(raw: string | number | null | undefined): number | null {
  if (typeof raw === "number") {
    return Number.isFinite(raw) && raw >= 0 && raw <= 5 ? round1(raw) : null;
  }
  if (!raw) return null;

  const match = raw.match(/(\d+(?:\.\d+)?)/);
  if (!match?.[1]) return null;

  const value = Number.parseFloat(match[1]);
  if (!Number.isFinite(value) || value < 0 || value > 5) return null;
  return round1(value);
}

export function parsePriceText(raw: string | null | undefined): ParsedPrice | null {
  if (!raw) return null;

  const priceText = raw.trim().replace(/\s+/g, " ").slice(0, 80);
  if (!priceText) return null;

  let currency: Currency = "UNKNOWN";
  let stripped = priceText;

  for (const entry of CURRENCY_CODES) {
    if (entry.pattern.test(priceText)) {
      currency = entry.currency;
      break;
    }
  }

  if (currency === "UNKNOWN") {
    for (const entry of CURRENCY_SYMBOLS) {
      if (entry.pattern.test(priceText)) {
        currency = entry.currency;
        stripped = priceText.replace(entry.strip, "");
        break;
      }
    }
  }

  if (currency === "UNKNOWN") {
    // Provider context is usually Chinese shopping results; an unsuffixed
    // number is still useful, but we do not pretend to know its currency.
    currency = "UNKNOWN";
  }

  const amount = parseAmount(stripped);
  if (amount === null) return null;

  return { amount, currency, priceText };
}

export function currencyLabel(currency: Currency): string {
  switch (currency) {
    case "CNY":
      return "人民币";
    case "USD":
      return "美元";
    case "EUR":
      return "欧元";
    case "GBP":
      return "英镑";
    case "JPY":
      return "日元";
    case "HKD":
      return "港币";
    default:
      return "币种未知";
  }
}

export function currencySymbol(currency: Currency): string {
  switch (currency) {
    case "CNY":
      return "¥";
    case "USD":
      return "$";
    case "EUR":
      return "€";
    case "GBP":
      return "£";
    case "JPY":
      return "¥";
    case "HKD":
      return "HK$";
    default:
      return "";
  }
}

export function formatPrice(
  amount: number | null,
  currency: Currency
): string {
  if (amount === null) return "未标注";
  const rendered = amount.toLocaleString("zh-CN", {
    minimumFractionDigits: Number.isInteger(amount) ? 0 : 2,
    maximumFractionDigits: 2
  });
  const symbol = currencySymbol(currency);
  return symbol ? `${symbol}${rendered}` : rendered;
}

export function round1(value: number): number {
  return Math.round(value * 10) / 10;
}
