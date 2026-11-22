import { parsePriceText, parseRating, parseReviewCount } from "./money";
import type { ProviderOfferSeed, ProviderSearchOutput } from "./providers/types";
import type { Offer, SearchProviderId } from "./types";

function clean(value: string | null, maxLength: number): string | null {
  if (!value) return null;
  const cleaned = value.replace(/\s+/g, " ").trim();
  return cleaned ? cleaned.slice(0, maxLength) : null;
}

function validHttpLink(link: string): boolean {
  try {
    const parsed = new URL(link);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    return false;
  }
}

export function normalizeOffer(
  seed: ProviderOfferSeed,
  index: number,
  providerId: SearchProviderId,
  fetchedAt: string
): Offer | null {
  const title = clean(seed.title, 180);
  if (!title || !validHttpLink(seed.link)) return null;

  const channel = clean(seed.channel, 60) ?? "公开网页";
  const price = parsePriceText(seed.priceText);
  const rating = parseRating(seed.rating);
  const reviewCount = parseReviewCount(seed.reviewCount);

  return {
    id: `${providerId}-${index + 1}`,
    channel,
    title,
    price: price?.amount ?? null,
    currency: price?.currency ?? "UNKNOWN",
    priceText: price?.priceText ?? null,
    link: seed.link,
    rating,
    reviewCount,
    snippet: clean(seed.snippet, 450),
    // Review text is only accepted from the explicitly labelled demo fixture.
    // Live provider snippets are page summaries, never review quotes.
    reviewExcerpt:
      providerId === "mock" ? clean(seed.reviewExcerpt, 500) : null,
    source: providerId,
    fetchedAt,
    rank: index
  };
}

export function normalizeProviderOffers(
  output: ProviderSearchOutput,
  providerId: SearchProviderId,
  fetchedAt: string,
  limit: number
): Offer[] {
  const seenLinks = new Set<string>();
  const offers: Offer[] = [];

  for (const [index, seed] of output.offers.entries()) {
    const offer = normalizeOffer(seed, index, providerId, fetchedAt);
    if (!offer) continue;

    const dedupeKey = offer.link.replace(/#.*$/, "");
    if (seenLinks.has(dedupeKey)) continue;
    seenLinks.add(dedupeKey);

    offers.push(offer);
    if (offers.length >= limit) break;
  }

  return offers;
}
