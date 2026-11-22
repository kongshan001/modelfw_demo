import type { Currency, Offer } from "./types";

export type SortDirection = "asc" | "desc";

const CURRENCY_ORDER: Record<Currency, number> = {
  CNY: 0,
  HKD: 1,
  USD: 2,
  EUR: 3,
  GBP: 4,
  JPY: 5,
  UNKNOWN: 6
};

/**
 * Sorts offers by price. Unpriced offers always sink to the bottom. When a
 * result set mixes currencies, we group by currency instead of inventing an
 * exchange rate. Within a currency the requested direction applies.
 */
export function sortOffersByPrice(
  offers: Offer[],
  direction: SortDirection = "asc"
): Offer[] {
  return [...offers].sort((a, b) => {
    if (a.price === null && b.price === null) return a.rank - b.rank;
    if (a.price === null) return 1;
    if (b.price === null) return -1;

    const aPrice = a.price;
    const bPrice = b.price;

    const currencyDelta =
      CURRENCY_ORDER[a.currency] - CURRENCY_ORDER[b.currency];
    if (currencyDelta !== 0) return currencyDelta;

    if (aPrice !== bPrice) {
      const delta = aPrice - bPrice;
      return direction === "asc" ? delta : -delta;
    }

    return a.rank - b.rank;
  });
}

export interface LowestCandidate {
  offerId: string;
  price: number;
  currency: Currency;
}

/**
 * A "lowest candidate" is only meaningful among priced offers in one currency.
 * Mixed currencies return null so the UI never implies an apples-to-apples
 * comparison that did not happen.
 */
export function pickLowestCandidate(offers: Offer[]): LowestCandidate | null {
  const priced = offers.filter(
    (offer): offer is Offer & { price: number } => offer.price !== null
  );
  if (priced.length === 0) return null;

  const currencies = new Set(priced.map((offer) => offer.currency));
  if (currencies.size !== 1) return null;
  if (currencies.has("UNKNOWN")) return null;

  const lowest = priced.reduce((best, offer) =>
    offer.price < best.price ? offer : best
  );

  return {
    offerId: lowest.id,
    price: lowest.price,
    currency: lowest.currency
  };
}

export function hasMixedCurrencies(offers: Offer[]): boolean {
  const currencies = new Set(
    offers
      .filter((offer) => offer.price !== null)
      .map((offer) => offer.currency)
  );
  return currencies.size > 1;
}
