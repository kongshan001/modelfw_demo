export const PRODUCT_FIELDS = ["brand", "model", "category", "specs"] as const;

export type ProductFieldKey = (typeof PRODUCT_FIELDS)[number];

export interface ProductIdentity {
  brand: string;
  model: string;
  category: string;
  specs: string;
}

export type FieldSource = "demo" | "vision" | "manual";

export interface FieldEvidence {
  confidence: number;
  source: FieldSource;
}

export interface ExtractionResult {
  product: ProductIdentity;
  fields: Record<ProductFieldKey, FieldEvidence>;
  mode: "demo" | "vision";
  notice: string;
}

export type Currency = "CNY" | "USD" | "EUR" | "GBP" | "JPY" | "HKD" | "UNKNOWN";

export interface Offer {
  id: string;
  channel: string;
  title: string;
  price: number | null;
  currency: Currency;
  priceText: string | null;
  link: string;
  rating: number | null;
  reviewCount: number | null;
  snippet: string | null;
  reviewExcerpt: string | null;
  source: string;
  fetchedAt: string;
  rank: number;
}

export interface SearchPayload {
  query: string;
  providerId: string;
  providerLabel: string;
  mode: "demo" | "live";
  fetchedAt: string;
  offers: Offer[];
  notes: string[];
  lowest: {
    offerId: string;
    price: number;
    currency: Currency;
  } | null;
}

export type SearchProviderId = "mock" | "serper" | "tavily" | "brave" | "serpapi";

export interface SearchStatus {
  id: SearchProviderId;
  label: string;
  mode: "demo" | "live";
  configured: boolean;
  missingEnv: string[];
  hint: string;
}

export interface VisionStatus {
  id: "demo" | "openai";
  label: string;
  mode: "demo" | "live";
  configured: boolean;
  missingEnv: string[];
  hint: string;
}

export interface AppStatus {
  search: SearchStatus;
  vision: VisionStatus;
  demo: boolean;
  maxUploadMb: number;
  providerOptions: Array<{
    id: SearchProviderId;
    label: string;
    mode: "demo" | "live";
    configured: boolean;
  }>;
}

export interface ReputationPoint {
  text: string;
  sentiment: "positive" | "negative";
  sourceChannel: string;
  sourceUrl: string;
}

export interface ReputationSummary {
  ratedOfferCount: number;
  weightedRating: number | null;
  reviewCountSum: number | null;
  pros: ReputationPoint[];
  cons: ReputationPoint[];
  conclusion: string;
  unavailableNote: string | null;
}
