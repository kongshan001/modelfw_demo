import type { Currency } from "./types";

export function formatReviewCount(count: number | null): string {
  if (count === null) return "评论数未获取";
  if (count >= 100_000_000) return `${trim(count / 100_000_000)} 亿`;
  if (count >= 10_000) return `${trim(count / 10_000)} 万`;
  return count.toLocaleString("zh-CN");
}

function trim(value: number): string {
  return value.toFixed(1).replace(/\.0$/, "");
}

export function formatDateTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  }).format(date);
}

export function formatConfidence(value: number): string {
  return `${Math.round(value * 100)}%`;
}

export function currencyCodeLabel(currency: Currency): string {
  return currency === "UNKNOWN" ? "币种未注明" : currency;
}

export function providerModeLabel(mode: "demo" | "live"): string {
  return mode === "demo" ? "Demo" : "Live";
}
