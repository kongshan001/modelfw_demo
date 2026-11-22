"use client";

import {
  AlertTriangle,
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Clock,
  ExternalLink,
  Info,
  Loader2,
  Search,
  Star,
  Store,
  Telescope
} from "lucide-react";
import { useMemo } from "react";

import {
  currencyCodeLabel,
  formatDateTime,
  formatReviewCount
} from "@/lib/format";
import { currencyLabel, formatPrice } from "@/lib/money";
import { hasMixedCurrencies, pickLowestCandidate, sortOffersByPrice } from "@/lib/sort";
import type { AppStatus, Offer, SearchPayload } from "@/lib/types";
import type { SortDirection } from "@/lib/sort";

import type { EditorSearchError } from "./ProductEditor";

interface ResultsPanelProps {
  payload: SearchPayload | null;
  status: AppStatus;
  sortDir: SortDirection;
  onSortChange: (direction: SortDirection) => void;
  searching: boolean;
  error: EditorSearchError | null;
  onRetry: () => void;
}

function ChannelAvatar({ channel, index }: { channel: string; index: number }) {
  const palette = [
    "bg-[#E8DDD2] text-[#7A4A32]",
    "bg-[#DFE9E4] text-[#285A4D]",
    "bg-[#E8E1EF] text-[#5B3E57]",
    "bg-[#EEE5CF] text-[#7A6027]",
    "bg-[#E3E7EC] text-[#324A5E]"
  ];
  const style = palette[index % palette.length] ?? palette[0];
  return (
    <span
      className={`grid h-8 w-8 shrink-0 place-items-center rounded-lg text-[12px] font-bold ${style}`}
      aria-hidden="true"
    >
      {channel.slice(0, 1)}
    </span>
  );
}

function RatingCell({ offer }: { offer: Offer }) {
  if (offer.rating === null) {
    return <span className="text-[11px] text-muted">未获取评分</span>;
  }
  return (
    <div>
      <div className="flex items-center gap-1 text-[13px] font-semibold text-ink">
        <Star className="h-3.5 w-3.5 fill-gold text-gold" />
        {offer.rating.toFixed(1)}
        <span className="text-[10px] font-normal text-muted">/ 5</span>
      </div>
      <p className="mt-0.5 text-[10px] text-muted">
        {offer.reviewCount === null
          ? "评论数未获取"
          : `${formatReviewCount(offer.reviewCount)} 条`}
      </p>
    </div>
  );
}

function OfferSummary({ offer }: { offer: Offer }) {
  const summary = offer.reviewExcerpt ?? offer.snippet;
  return (
    <div className="min-w-0">
      <a
        href={offer.link}
        target="_blank"
        rel="noopener noreferrer"
        className="group inline-flex items-start gap-1 text-[13px] font-semibold leading-snug text-ink transition-colors hover:text-vermilion"
      >
        <span className="line-clamp-2">{offer.title}</span>
        <ExternalLink className="mt-0.5 h-3 w-3 shrink-0 opacity-0 transition-opacity group-hover:opacity-100" />
      </a>
      {summary ? (
        <p className="mt-1.5 line-clamp-2 text-[11px] leading-relaxed text-muted">
          <span className="mr-1 font-mono text-[9px] uppercase tracking-wider text-muted/70">
            {offer.reviewExcerpt ? "评论片段" : "页面摘要"}
          </span>
          {summary}
        </p>
      ) : (
        <p className="mt-1.5 text-[11px] text-muted/80">未获取公开摘要</p>
      )}
    </div>
  );
}

function SkeletonResults() {
  return (
    <div className="space-y-2.5 p-5" aria-hidden="true">
      {[0, 1, 2, 3].map((index) => (
        <div
          key={index}
          className="flex animate-pulseSoft items-center gap-4 rounded-xl border border-line/70 bg-white/40 px-4 py-4"
          style={{ animationDelay: `${index * 120}ms` }}
        >
          <div className="h-8 w-8 rounded-lg bg-line/60" />
          <div className="flex-1 space-y-2">
            <div className="h-3 w-2/3 rounded bg-line/60" />
            <div className="h-2.5 w-1/2 rounded bg-line/40" />
          </div>
          <div className="h-4 w-16 rounded bg-line/50" />
        </div>
      ))}
    </div>
  );
}

function EmptyState({
  status,
  payloadMissing
}: {
  status: AppStatus;
  payloadMissing: boolean;
}) {
  return (
    <div className="flex min-h-[390px] flex-col items-center justify-center px-6 py-12 text-center">
      <div className="relative mb-5">
        <div className="absolute inset-0 -m-3 rounded-full border border-dashed border-line" />
        <span className="grid h-14 w-14 place-items-center rounded-2xl border border-line bg-white/70 text-teal shadow-sm">
          <Telescope className="h-6 w-6" />
        </span>
      </div>
      <p className="font-display text-[20px] font-semibold">
        {payloadMissing ? "等待你发起公开检索" : "还没有检索结果"}
      </p>
      <p className="mt-2 max-w-[360px] text-[12px] leading-relaxed text-muted">
        核对左侧识别字段，点击「公开检索」，这里会出现公开渠道的价格候选、链接与口碑证据。
      </p>
      <div className="mt-5 inline-flex items-center gap-2 rounded-full border border-line bg-paper/60 px-3 py-1.5 text-[10px] text-muted">
        <span
          className={`h-1.5 w-1.5 rounded-full ${
            status.search.mode === "demo" ? "bg-gold" : "bg-teal"
          }`}
        />
        当前通道：{status.search.label}
      </div>
    </div>
  );
}

export function ResultsPanel({
  payload,
  status,
  sortDir,
  onSortChange,
  searching,
  error,
  onRetry
}: ResultsPanelProps) {
  const sortedOffers = useMemo(
    () => (payload ? sortOffersByPrice(payload.offers, sortDir) : []),
    [payload, sortDir]
  );
  const lowest = useMemo(
    () => (payload ? pickLowestCandidate(payload.offers) : null),
    [payload]
  );
  const lowestOffer = lowest
    ? payload?.offers.find((offer) => offer.id === lowest.offerId) ?? null
    : null;
  const channelCount = payload
    ? new Set(payload.offers.map((offer) => offer.channel)).size
    : 0;
  const mixed = payload ? hasMixedCurrencies(payload.offers) : false;

  return (
    <div className="surface min-w-0 overflow-hidden" data-testid="results-panel">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-5 py-4">
        <div>
          <p className="font-mono text-[9px] tracking-[0.24em] text-muted">
            PUBLIC RESULTS / 03
          </p>
          <h2 className="mt-0.5 font-display text-[20px] font-semibold">
            公开渠道候选
          </h2>
        </div>
        <div className="flex items-center gap-2">
          {payload?.mode === "demo" && (
            <span className="pill border-gold/35 bg-gold-soft text-gold">
              DEMO 演示数据
            </span>
          )}
          <span className="pill border-line bg-paper/70 text-muted">
            <Store className="h-3 w-3" />
            {payload ? payload.providerLabel : status.search.label}
          </span>
        </div>
      </div>

      {searching ? (
        <div aria-busy="true" data-testid="results-loading">
          <div className="flex items-center gap-2 border-b border-dashed border-line px-5 py-3 text-[11px] text-muted">
            <Loader2 className="h-3.5 w-3.5 animate-spin text-vermilion" />
            正在联系 {status.search.label}，检索公开结果…
          </div>
          <SkeletonResults />
        </div>
      ) : error ? (
        <div className="flex min-h-[390px] flex-col items-center justify-center px-7 py-12 text-center">
          <span className="grid h-12 w-12 place-items-center rounded-2xl border border-vermilion/20 bg-blush/60 text-vermilion">
            <AlertTriangle className="h-5 w-5" />
          </span>
          <p className="mt-4 font-display text-[20px] font-semibold">这次检索没有完成</p>
          <p className="mt-2 max-w-[420px] text-[12px] leading-relaxed text-muted">
            {error.message}
          </p>
          {error.hint && (
            <p className="mt-2 max-w-[460px] rounded-lg border border-line bg-paper/70 px-3 py-2 text-[10px] leading-relaxed text-muted">
              {error.hint}
            </p>
          )}
          <button type="button" className="btn-secondary mt-5" onClick={onRetry}>
            重试检索
          </button>
        </div>
      ) : !payload ? (
        <EmptyState status={status} payloadMissing />
      ) : (
        <div data-testid="results-content">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-dashed border-line px-5 py-3">
            <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-[10px] text-muted">
              <span className="inline-flex items-center gap-1">
                <Clock className="h-3 w-3" />
                {formatDateTime(payload.fetchedAt)}
              </span>
              <span className="h-3 w-px bg-line" />
              <span>
                {payload.offers.length} 条结果 · {channelCount} 个渠道
              </span>
            </div>

            <div
              className="inline-flex items-center rounded-lg border border-line bg-paper/60 p-0.5"
              role="group"
              aria-label="价格排序"
            >
              <span className="px-1.5 text-muted">
                <ArrowUpDown className="h-3 w-3" />
              </span>
              <button
                type="button"
                onClick={() => onSortChange("asc")}
                aria-pressed={sortDir === "asc"}
                aria-label="价格从低到高"
                className={`inline-flex items-center gap-0.5 rounded-md px-2 py-1 text-[10px] font-medium transition-colors ${
                  sortDir === "asc"
                    ? "bg-ink text-cream"
                    : "text-muted hover:text-ink"
                }`}
              >
                <ArrowUp className="h-3 w-3" />
                价格
              </button>
              <button
                type="button"
                onClick={() => onSortChange("desc")}
                aria-pressed={sortDir === "desc"}
                aria-label="价格从高到低"
                className={`inline-flex items-center gap-0.5 rounded-md px-2 py-1 text-[10px] font-medium transition-colors ${
                  sortDir === "desc"
                    ? "bg-ink text-cream"
                    : "text-muted hover:text-ink"
                }`}
              >
                <ArrowDown className="h-3 w-3" />
                价格
              </button>
            </div>
          </div>

          <div className="px-5 pt-4">
            <p className="mb-3 rounded-lg border border-line/80 bg-paper/55 px-3 py-2 text-[10px] leading-relaxed text-muted">
              <span className="font-semibold text-ink">检索词：</span>
              <span className="font-mono">{payload.query}</span>
              {" · "}
              公开检索结果中的候选，不等于全网最低价。
            </p>

            {lowestOffer && lowest ? (
              <div
                className="relative mb-4 overflow-hidden rounded-xl border border-gold/35 bg-gold-soft/55 px-4 py-3"
                data-testid="lowest-candidate"
              >
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p className="font-mono text-[9px] uppercase tracking-[0.2em] text-[#7A5B21]">
                      LOWEST CANDIDATE · 本次检索最低候选
                    </p>
                    <div className="mt-1 flex flex-wrap items-baseline gap-2">
                      <span className="font-display text-[26px] font-semibold leading-none text-[#5C4418]">
                        {formatPrice(lowest.price, lowest.currency)}
                      </span>
                      <span className="text-[10px] text-[#7A5B21]">
                        {currencyLabel(lowest.currency)} · {lowestOffer.channel}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="hidden rounded-full border border-[#7A5B21]/25 px-2 py-1 text-[9px] text-[#7A5B21] sm:inline">
                      仅限本次返回结果
                    </span>
                    <a
                      href={lowestOffer.link}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 rounded-lg bg-[#5C4418] px-3 py-2 text-[11px] font-semibold text-cream transition-colors hover:bg-ink"
                    >
                      打开来源
                      <ExternalLink className="h-3 w-3" />
                    </a>
                  </div>
                </div>
                <p className="mt-2 text-[10px] leading-relaxed text-[#7A5B21]/90">
                  这是本次检索返回的有价结果中最低的一个，不是“全网最低价”保证；未覆盖的渠道、会员价、券后价均可能更低。
                </p>
              </div>
            ) : payload.offers.length > 0 ? (
              <p className="mb-4 flex items-start gap-1.5 rounded-lg border border-line bg-paper/55 px-3 py-2 text-[10px] leading-relaxed text-muted">
                <Info className="mt-0.5 h-3 w-3 shrink-0" />
                {mixed
                  ? "结果包含多个币种，本工具不做汇率换算，因此不计算跨币种最低候选。"
                  : "没有可比较的同一币种标价，因此不计算最低候选。"}
              </p>
            ) : null}
          </div>

          {payload.offers.length === 0 ? (
            <div className="px-5 pb-6">
              <div className="rounded-xl border border-dashed border-line bg-white/35 px-5 py-10 text-center">
                <Search className="mx-auto h-6 w-6 text-muted/60" />
                <p className="mt-3 font-display text-[18px] font-semibold">
                  没有可展示的候选
                </p>
                <p className="mx-auto mt-1 max-w-[420px] text-[11px] leading-relaxed text-muted">
                  可能是检索词未匹配到样例，或服务商没有返回结果。可更换字段后重试。
                </p>
              </div>
            </div>
          ) : (
            <>
              <div className="hidden md:block">
                <table className="w-full table-fixed border-collapse text-left" data-testid="results-table">
                  <thead>
                    <tr className="border-y border-line bg-paper/45 text-[9px] uppercase tracking-[0.14em] text-muted">
                      <th scope="col" className="w-[136px] px-4 py-2 font-semibold">
                        渠道
                      </th>
                      <th scope="col" className="px-2 py-2 font-semibold">
                        商品 / 公开摘要
                      </th>
                      <th scope="col" className="w-[112px] px-2 py-2 text-right font-semibold">
                        价格
                      </th>
                      <th scope="col" className="w-[108px] px-2 py-2 font-semibold">
                        评分
                      </th>
                      <th scope="col" className="w-[72px] px-4 py-2 text-right font-semibold">
                        来源
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-line/80">
                    {sortedOffers.map((offer, index) => {
                      const isLowest = lowest?.offerId === offer.id;
                      return (
                        <tr
                          key={offer.id}
                          className={isLowest ? "bg-gold-soft/35" : "transition-colors hover:bg-paper/45"}
                          data-testid="offer-row"
                        >
                          <td className="px-4 py-3.5 align-top">
                            <div className="flex items-center gap-2">
                              <ChannelAvatar channel={offer.channel} index={index} />
                              <div className="min-w-0">
                                <p className="line-clamp-2 text-[11px] font-semibold leading-snug">
                                  {offer.channel}
                                </p>
                                {isLowest && (
                                  <span className="mt-1 inline-block rounded bg-gold/20 px-1 py-0.5 text-[8px] font-semibold text-[#6E5220]">
                                    最低候选
                                  </span>
                                )}
                              </div>
                            </div>
                          </td>
                          <td className="px-2 py-3.5 align-top">
                            <OfferSummary offer={offer} />
                          </td>
                          <td className="px-2 py-3.5 text-right align-top">
                            <p className="font-display text-[16px] font-semibold leading-none text-ink" data-testid="offer-price">
                              {formatPrice(offer.price, offer.currency)}
                            </p>
                            <p className="mt-1 text-[9px] text-muted">
                              {offer.price === null
                                ? "公开摘要未标价"
                                : currencyCodeLabel(offer.currency)}
                            </p>
                          </td>
                          <td className="px-2 py-3.5 align-top">
                            <RatingCell offer={offer} />
                          </td>
                          <td className="px-4 py-3.5 text-right align-top">
                            <a
                              href={offer.link}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="inline-flex items-center gap-1 text-[10px] font-semibold text-teal transition-colors hover:text-vermilion"
                              aria-label={`打开 ${offer.channel} 的来源页面`}
                            >
                              查看
                              <ExternalLink className="h-3 w-3" />
                            </a>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>

              <div className="space-y-2.5 px-4 pb-2 md:hidden">
                {sortedOffers.map((offer, index) => {
                  const isLowest = lowest?.offerId === offer.id;
                  return (
                    <article
                      key={offer.id}
                      className={`rounded-xl border p-3.5 ${
                        isLowest
                          ? "border-gold/35 bg-gold-soft/30"
                          : "border-line bg-white/40"
                      }`}
                      data-testid="offer-card"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-2">
                          <ChannelAvatar channel={offer.channel} index={index} />
                          <span className="text-[11px] font-semibold">{offer.channel}</span>
                        </div>
                        {isLowest && (
                          <span className="rounded bg-gold/20 px-1.5 py-0.5 text-[8px] font-semibold text-[#6E5220]">
                            最低候选
                          </span>
                        )}
                      </div>
                      <div className="mt-3">
                        <OfferSummary offer={offer} />
                      </div>
                      <div className="mt-3 flex items-end justify-between gap-3 border-t border-dashed border-line pt-3">
                        <div>
                          <p className="font-display text-[19px] font-semibold">
                            {formatPrice(offer.price, offer.currency)}
                          </p>
                          <p className="mt-0.5 text-[9px] text-muted">
                            {offer.price === null ? "未标价" : currencyCodeLabel(offer.currency)}
                            {" · "}
                            {offer.rating === null
                              ? "评分未获取"
                              : `${offer.rating.toFixed(1)} / 5${
                                  offer.reviewCount === null
                                    ? ""
                                    : ` · ${formatReviewCount(offer.reviewCount)} 条`
                                }`}
                          </p>
                        </div>
                        <a
                          href={offer.link}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="btn-secondary px-2.5 py-1.5 text-[10px]"
                        >
                          查看来源
                          <ExternalLink className="h-3 w-3" />
                        </a>
                      </div>
                    </article>
                  );
                })}
              </div>
            </>
          )}

          <details className="mt-3 border-t border-dashed border-line px-5 py-3">
            <summary className="cursor-pointer select-none text-[10px] font-semibold text-muted transition-colors hover:text-ink">
              检索说明与边界（{payload.notes.length}）
            </summary>
            <ul className="mt-2 space-y-1.5">
              {payload.notes.map((note, index) => (
                <li
                  key={`${index}-${note.slice(0, 8)}`}
                  className="flex items-start gap-1.5 text-[10px] leading-relaxed text-muted"
                >
                  <span className="mt-[5px] h-1 w-1 shrink-0 rounded-full bg-line" />
                  {note}
                </li>
              ))}
            </ul>
          </details>
        </div>
      )}
    </div>
  );
}
