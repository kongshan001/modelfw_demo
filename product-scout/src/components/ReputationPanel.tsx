"use client";

import {
  ExternalLink,
  Info,
  Quote,
  ThumbsDown,
  ThumbsUp
} from "lucide-react";
import { useMemo } from "react";

import { buildReputationSummary } from "@/lib/reputation";
import type { ReputationPoint, SearchPayload } from "@/lib/types";

function PointCard({
  point,
  kind
}: {
  point: ReputationPoint;
  kind: "positive" | "negative";
}) {
  const Icon = kind === "positive" ? ThumbsUp : ThumbsDown;
  return (
    <li className="rounded-xl border border-line/80 bg-white/40 px-3.5 py-3">
      <p className="flex items-start gap-2 text-[12px] leading-relaxed text-ink">
        <Icon
          className={`mt-0.5 h-3.5 w-3.5 shrink-0 ${
            kind === "positive" ? "text-teal" : "text-vermilion"
          }`}
        />
        <span>{point.text}</span>
      </p>
      <a
        href={point.sourceUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="mt-2 inline-flex items-center gap-1 pl-5 text-[9px] font-medium text-muted transition-colors hover:text-teal"
      >
        来源：{point.sourceChannel}
        <ExternalLink className="h-2.5 w-2.5" />
      </a>
    </li>
  );
}

function Column({
  title,
  kind,
  points
}: {
  title: string;
  kind: "positive" | "negative";
  points: ReputationPoint[];
}) {
  const Icon = kind === "positive" ? ThumbsUp : ThumbsDown;
  return (
    <div className="rounded-2xl border border-line bg-paper/35 p-4">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="flex items-center gap-1.5 text-[12px] font-semibold">
          <span
            className={`grid h-6 w-6 place-items-center rounded-md ${
              kind === "positive"
                ? "bg-teal-soft text-teal"
                : "bg-blush text-vermilion"
            }`}
          >
            <Icon className="h-3 w-3" />
          </span>
          {title}
        </h3>
        <span className="font-mono text-[9px] text-muted">{points.length} 条</span>
      </div>

      {points.length > 0 ? (
        <ul className="space-y-2">
          {points.map((point) => (
            <PointCard key={`${kind}-${point.text}`} point={point} kind={kind} />
          ))}
        </ul>
      ) : (
        <div className="grid min-h-[92px] place-items-center rounded-xl border border-dashed border-line text-center">
          <p className="text-[11px] text-muted">未获取</p>
        </div>
      )}
    </div>
  );
}

export function ReputationPanel({ payload }: { payload: SearchPayload | null }) {
  const summary = useMemo(
    () =>
      payload
        ? buildReputationSummary(payload.offers)
        : {
            ratedOfferCount: 0,
            weightedRating: null,
            reviewCountSum: null,
            pros: [],
            cons: [],
            conclusion: "",
            unavailableNote: null
          },
    [payload]
  );

  if (!payload) return null;

  return (
    <section
      className="surface mt-5 overflow-hidden"
      data-testid="reputation-panel"
      id="reputation"
    >
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-5 py-4 sm:px-6">
        <div>
          <p className="font-mono text-[9px] tracking-[0.24em] text-muted">
            SENTIMENT CHECK / 04
          </p>
          <h2 className="mt-0.5 font-display text-[22px] font-semibold">
            口碑摘要 · 只写检索得到的事
          </h2>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {payload.mode === "demo" && (
            <span className="pill border-gold/35 bg-gold-soft text-gold">
              DEMO 评论片段
            </span>
          )}
          <span className="pill border-line bg-paper/70 text-muted">
            覆盖 {summary.ratedOfferCount} 个有评分渠道
          </span>
        </div>
      </div>

      <div className="p-5 sm:p-6">
        <div className="grid gap-3 lg:grid-cols-[300px_1fr]">
          <div className="relative min-h-[272px] overflow-hidden rounded-2xl bg-ink px-5 py-5 text-cream">
            <div className="pointer-events-none absolute -right-8 -top-8 h-28 w-28 rounded-full border border-cream/10" />
            <div className="pointer-events-none absolute -bottom-10 -left-8 h-28 w-28 rounded-full border border-cream/10" />
            <p className="font-mono text-[9px] uppercase tracking-[0.2em] text-cream/55">
              WEIGHTED SAMPLE SCORE
            </p>
            <div className="mt-3 flex items-end gap-2">
              <span className="font-display text-[54px] font-semibold leading-none">
                {summary.weightedRating === null
                  ? "—"
                  : summary.weightedRating.toFixed(1)}
              </span>
              <span className="pb-1 text-[12px] text-cream/55">/ 5</span>
            </div>
            <p className="mt-2 text-[11px] text-cream/70">
              {summary.weightedRating === null
                ? "未获取可用公开评分"
                : "检索样本按评论数加权的公开评分"}
            </p>
            <div className="mt-5 space-y-2 border-t border-cream/15 pt-4 text-[10px] text-cream/60">
              <div className="flex items-center justify-between gap-3">
                <span>有评分渠道</span>
                <span className="font-mono text-cream/90">
                  {summary.ratedOfferCount} / {payload.offers.length}
                </span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>评论样本</span>
                <span className="font-mono text-cream/90">
                  {summary.reviewCountSum === null
                    ? "未获取"
                    : `${summary.reviewCountSum.toLocaleString("zh-CN")} 条`}
                </span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>可归纳片段</span>
                <span className="font-mono text-cream/90">
                  {summary.pros.length + summary.cons.length} 条
                </span>
              </div>
            </div>
          </div>

          <div className="relative flex flex-col justify-between rounded-2xl border border-line bg-paper/40 px-5 py-5">
            <Quote className="h-5 w-5 text-vermilion/45" />
            <p className="mt-1 font-display text-[22px] font-medium leading-[1.55] tracking-wide text-ink sm:text-[24px]">
              {summary.conclusion}
            </p>
            <div className="mt-4 flex flex-wrap items-center justify-between gap-2 border-t border-dashed border-line pt-3">
              <p className="text-[9px] leading-relaxed text-muted">
                结论只描述本次检索返回的公开样本，不代表全部消费者。
              </p>
              <span className="inline-flex items-center gap-1 rounded-full border border-line bg-cream px-2 py-1 font-mono text-[8px] tracking-[0.14em] text-muted">
                <Info className="h-2.5 w-2.5" />
                NO EXTRAPOLATION
              </span>
            </div>
          </div>
        </div>

        <div className="mt-3 grid gap-3 md:grid-cols-2">
          <Column title="公开片段里的优点" kind="positive" points={summary.pros} />
          <Column title="公开片段里的顾虑" kind="negative" points={summary.cons} />
        </div>

        {summary.unavailableNote && (
          <p className="mt-3 flex items-start gap-2 rounded-xl border border-line bg-paper/50 px-3.5 py-2.5 text-[10px] leading-relaxed text-muted">
            <Info className="mt-0.5 h-3 w-3 shrink-0 text-gold" />
            {summary.unavailableNote}
          </p>
        )}

        <div className="mt-4 flex flex-col gap-1 border-t border-dashed border-line pt-3 text-[9px] leading-relaxed text-muted/85 sm:flex-row sm:items-center sm:justify-between">
          <p>
            口碑归纳：只使用检索结果中的评分与评论片段；没有数据时写“未获取”，不做推断。
          </p>
          <p className="shrink-0">
            {payload.mode === "demo"
              ? "Demo 片段为样例，非真实用户评论。"
              : "搜索 API 通常不返回评论正文，此时不会生成优缺点。"}
          </p>
        </div>
      </div>
    </section>
  );
}
