import type { SearchProviderId } from "./types";

export const MAX_UPLOAD_MB = 8;
export const MAX_UPLOAD_BYTES = MAX_UPLOAD_MB * 1024 * 1024;

const SEARCH_PROVIDER_IDS: SearchProviderId[] = [
  "mock",
  "serper",
  "tavily",
  "brave",
  "serpapi"
];

export function envValue(name: string): string | null {
  const value = process.env[name]?.trim();
  return value ? value : null;
}

export function getSearchProviderId(): SearchProviderId {
  const raw = envValue("SEARCH_PROVIDER")?.toLowerCase();
  if (!raw) return "mock";
  return SEARCH_PROVIDER_IDS.includes(raw as SearchProviderId)
    ? (raw as SearchProviderId)
    : "mock";
}

export function getSearchLimit(): number {
  const raw = Number.parseInt(envValue("SEARCH_RESULT_LIMIT") ?? "6", 10);
  if (!Number.isFinite(raw)) return 6;
  return Math.min(10, Math.max(3, raw));
}

export function getSearchLocale(): { country: string; language: string } {
  return {
    country: envValue("SEARCH_COUNTRY") ?? "cn",
    language: envValue("SEARCH_LANGUAGE") ?? "zh-cn"
  };
}

export function getVisionProviderId(): "demo" | "openai" {
  return envValue("VISION_PROVIDER")?.toLowerCase() === "openai"
    ? "openai"
    : "demo";
}

export function getVisionConfig(): {
  provider: "demo" | "openai";
  apiKey: string | null;
  baseUrl: string;
  model: string;
  missingEnv: string[];
} {
  const provider = getVisionProviderId();
  const apiKey = envValue("VISION_API_KEY");
  const baseUrl =
    envValue("VISION_BASE_URL") ?? "https://api.openai.com/v1";
  const model = envValue("VISION_MODEL") ?? "gpt-4o-mini";

  const missingEnv: string[] = [];
  if (provider === "openai" && !apiKey) {
    missingEnv.push("VISION_API_KEY");
  }

  return { provider, apiKey, baseUrl, model, missingEnv };
}
