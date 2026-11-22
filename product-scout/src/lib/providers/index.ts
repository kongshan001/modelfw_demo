import { getSearchProviderId } from "../config";
import type { SearchProviderId } from "../types";
import { createBraveProvider } from "./brave";
import { mockProvider } from "./mock";
import { createSerpApiProvider } from "./serpapi";
import { createSerperProvider } from "./serper";
import { createTavilyProvider } from "./tavily";
import type { SearchProvider } from "./types";

export function createSearchProvider(id: SearchProviderId): SearchProvider {
  switch (id) {
    case "serper":
      return createSerperProvider();
    case "tavily":
      return createTavilyProvider();
    case "brave":
      return createBraveProvider();
    case "serpapi":
      return createSerpApiProvider();
    case "mock":
    default:
      return mockProvider;
  }
}

export function getSearchProvider(): SearchProvider {
  return createSearchProvider(getSearchProviderId());
}

export function getAllSearchProviders(): SearchProvider[] {
  return [
    mockProvider,
    createSerperProvider(),
    createTavilyProvider(),
    createBraveProvider(),
    createSerpApiProvider()
  ];
}
