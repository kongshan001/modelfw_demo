import { describe, expect, it } from "@jest/globals";

import {
  hasMixedCurrencies,
  pickLowestCandidate,
  sortOffersByPrice
} from "../sort";
import type { Currency, Offer } from "../types";

function offer(
  id: string,
  price: number | null,
  rank: number,
  currency: Currency = "CNY"
): Offer {
  return {
    id,
    channel: `渠道 ${id}`,
    title: `商品 ${id}`,
    price,
    currency,
    priceText: price === null ? null : `${price}`,
    link: `https://example.com/${id}`,
    rating: null,
    reviewCount: null,
    snippet: null,
    reviewExcerpt: null,
    source: "mock",
    fetchedAt: "2026-11-22T00:00:00.000Z",
    rank
  };
}

describe("sortOffersByPrice", () => {
  const offers = [
    offer("b", 200, 0),
    offer("none", null, 1),
    offer("a", 100, 2),
    offer("c", 200, 3)
  ];

  it("sorts ascending and keeps unpriced offers last", () => {
    expect(sortOffersByPrice(offers, "asc").map((entry) => entry.id)).toEqual([
      "a",
      "b",
      "c",
      "none"
    ]);
  });

  it("sorts descending but still keeps unpriced offers last", () => {
    expect(sortOffersByPrice(offers, "desc").map((entry) => entry.id)).toEqual([
      "b",
      "c",
      "a",
      "none"
    ]);
  });

  it("does not mutate the input", () => {
    sortOffersByPrice(offers, "desc");
    expect(offers.map((entry) => entry.id)).toEqual(["b", "none", "a", "c"]);
  });

  it("groups currencies instead of comparing amounts across them", () => {
    const mixed = [
      offer("usd", 10, 0, "USD"),
      offer("cny", 5000, 1, "CNY"),
      offer("usd2", 5, 2, "USD")
    ];
    expect(sortOffersByPrice(mixed, "asc").map((entry) => entry.id)).toEqual([
      "cny",
      "usd2",
      "usd"
    ]);
  });
});

describe("pickLowestCandidate", () => {
  it("returns the lowest priced offer within one currency", () => {
    expect(
      pickLowestCandidate([offer("a", 299, 0), offer("b", 199, 1)])
    ).toEqual({ offerId: "b", price: 199, currency: "CNY" });
  });

  it("ignores unpriced offers", () => {
    const lowest = pickLowestCandidate([
      offer("none", null, 0),
      offer("a", 500, 1)
    ]);
    expect(lowest?.offerId).toBe("a");
    expect(lowest?.price).toBe(500);
  });

  it("refuses a cross-currency comparison", () => {
    expect(
      pickLowestCandidate([offer("usd", 10, 0, "USD"), offer("cny", 20, 1, "CNY")])
    ).toBeNull();
    expect(hasMixedCurrencies([offer("usd", 10, 0, "USD"), offer("cny", 20, 1, "CNY")]))
      .toBe(true);
  });

  it("refuses an unknown-currency comparison", () => {
    expect(pickLowestCandidate([offer("a", 10, 0, "UNKNOWN")])).toBeNull();
  });

  it("returns null when nothing is priced", () => {
    expect(pickLowestCandidate([offer("a", null, 0)])).toBeNull();
  });
});
