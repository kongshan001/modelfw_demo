import type { ProductIdentity, SearchProviderId } from "../types";

export interface ProviderOfferSeed {
  channel: string;
  title: string;
  link: string;
  priceText: string | null;
  rating: number | null;
  reviewCount: number | null;
  snippet: string | null;
  reviewExcerpt: string | null;
}

export interface ProviderSearchOutput {
  offers: ProviderOfferSeed[];
  notes: string[];
}

export interface SearchInput {
  product: ProductIdentity;
  query: string;
  limit: number;
}

export interface SearchProvider {
  id: SearchProviderId;
  label: string;
  mode: "demo" | "live";
  requiredEnv: string[];
  hint: string;
  isConfigured(): boolean;
  missingEnv(): string[];
  search(input: SearchInput): Promise<ProviderSearchOutput>;
}
