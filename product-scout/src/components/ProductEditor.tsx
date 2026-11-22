"use client";

import {
  AlertTriangle,
  Info,
  Loader2,
  Search,
  Sparkles
} from "lucide-react";

import { formatConfidence } from "@/lib/format";
import type {
  ExtractionResult,
  FieldEvidence,
  ProductFieldKey,
  ProductIdentity,
  SearchStatus
} from "@/lib/types";
import type { FieldValidationErrors } from "@/lib/validation";
import { buildSearchQuery } from "@/lib/validation";

const FIELDS: Array<{
  key: ProductFieldKey;
  label: string;
  placeholder: string;
  hint: string;
  wide: boolean;
  multiline?: boolean;
}> = [
  {
    key: "brand",
    label: "品牌",
    placeholder: "例如 Sony / 安克",
    hint: "品牌名或常见中文名",
    wide: false
  },
  {
    key: "model",
    label: "型号 / SKU",
    placeholder: "例如 WH-1000XM5",
    hint: "尽量保留完整型号",
    wide: false
  },
  {
    key: "category",
    label: "品类",
    placeholder: "例如 头戴式降噪耳机",
    hint: "帮助搜索引擎理解商品",
    wide: true
  },
  {
    key: "specs",
    label: "关键规格",
    placeholder: "例如 蓝牙 5.2 · 约 30 小时续航 · 约 250g",
    hint: "可选，用顿号或空格分隔",
    wide: true,
    multiline: true
  }
];

function EvidencePill({ meta }: { meta: FieldEvidence | undefined }) {
  if (!meta) {
    return (
      <span className="pill border-line bg-paper/70 text-muted">待填写</span>
    );
  }

  if (meta.source === "manual") {
    return (
      <span className="pill border-line bg-paper/80 text-muted">手动 · 已校正</span>
    );
  }

  if (meta.source === "vision") {
    return (
      <span className="pill border-teal/25 bg-teal-soft text-teal">
        视觉 · {formatConfidence(meta.confidence)}
      </span>
    );
  }

  return (
    <span className="pill border-gold/30 bg-gold-soft text-gold">
      Demo · {formatConfidence(meta.confidence)}
    </span>
  );
}

export interface EditorSearchError {
  message: string;
  hint?: string | null;
}

interface ProductEditorProps {
  product: ProductIdentity;
  fieldMeta: Partial<Record<ProductFieldKey, FieldEvidence>> | null;
  extraction: ExtractionResult | null;
  errors: FieldValidationErrors;
  busy: boolean;
  searchBusy: boolean;
  searchError: EditorSearchError | null;
  searchStatus: SearchStatus;
  onUpdate: (key: ProductFieldKey, value: string) => void;
  onSearch: () => void;
}

export function ProductEditor({
  product,
  fieldMeta,
  extraction,
  errors,
  busy,
  searchBusy,
  searchError,
  searchStatus,
  onUpdate,
  onSearch
}: ProductEditorProps) {
  const query = buildSearchQuery(product);
  const searchDisabled = !searchStatus.configured || busy || searchBusy;

  return (
    <div className="surface overflow-hidden lg:sticky lg:top-[88px]">
      <div className="flex items-center justify-between gap-3 border-b border-line px-5 py-4">
        <div>
          <p className="font-mono text-[9px] tracking-[0.24em] text-muted">
            VERIFY / 02
          </p>
          <h2 className="mt-0.5 font-display text-[20px] font-semibold">核对商品信息</h2>
        </div>
        <span className="pill border-line bg-paper/80 text-muted">
          {extraction?.mode === "vision"
            ? "视觉提取"
            : extraction?.mode === "demo"
              ? "Demo 识别"
              : "手动填写"}
        </span>
      </div>

      <form
        className="space-y-4 p-5"
        onSubmit={(event) => {
          event.preventDefault();
          onSearch();
        }}
        noValidate
      >
        {extraction?.notice ? (
          <div className="flex items-start gap-2 rounded-xl border border-gold/25 bg-gold-soft/55 px-3 py-2.5 text-[11px] leading-relaxed text-[#6E5220]">
            <Sparkles className="mt-0.5 h-3.5 w-3.5 shrink-0 text-gold" />
            <span>{extraction.notice}</span>
          </div>
        ) : (
          <div className="flex items-start gap-2 rounded-xl border border-line bg-paper/55 px-3 py-2.5 text-[11px] leading-relaxed text-muted">
            <Info className="mt-0.5 h-3.5 w-3.5 shrink-0 text-teal" />
            <span>
              可以手动填写或修改任意字段。至少提供品牌或型号后才能构造检索词。
            </span>
          </div>
        )}

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {FIELDS.map((field) => (
            <div key={field.key} className={field.wide ? "sm:col-span-2" : ""}>
              <div className="field-label">
                <label htmlFor={`field-${field.key}`}>{field.label}</label>
                <EvidencePill meta={fieldMeta?.[field.key]} />
              </div>
              {field.multiline ? (
                <textarea
                  id={`field-${field.key}`}
                  className="field-input min-h-[72px] resize-y"
                  value={product[field.key]}
                  placeholder={field.placeholder}
                  onChange={(event) => onUpdate(field.key, event.target.value)}
                  aria-invalid={Boolean(errors[field.key])}
                  aria-describedby={`hint-${field.key}`}
                  rows={2}
                />
              ) : (
                <input
                  id={`field-${field.key}`}
                  type="text"
                  className="field-input"
                  value={product[field.key]}
                  placeholder={field.placeholder}
                  onChange={(event) => onUpdate(field.key, event.target.value)}
                  aria-invalid={Boolean(errors[field.key])}
                  aria-describedby={`hint-${field.key}`}
                  autoComplete="off"
                />
              )}
              <p
                id={`hint-${field.key}`}
                className={`mt-1.5 text-[10px] ${
                  errors[field.key] ? "text-vermilion" : "text-muted/70"
                }`}
              >
                {errors[field.key] ?? field.hint}
              </p>
            </div>
          ))}
        </div>

        <div className="rounded-xl border border-line bg-paper/50 px-3 py-3">
          <div className="flex items-center justify-between gap-3">
            <span className="eyebrow">QUERY PREVIEW / 检索词</span>
            <span className="font-mono text-[9px] text-muted/70">PUBLIC</span>
          </div>
          <p
            className="mt-1.5 break-words font-mono text-[12px] leading-relaxed text-ink"
            data-testid="query-preview"
          >
            {query || "填写品牌或型号后生成检索词"}
          </p>
        </div>

        <div className="rounded-xl border border-line/90 bg-white/45 px-3 py-3">
          <div className="flex items-center justify-between gap-2">
            <span className="text-[11px] font-semibold text-ink">检索通道</span>
            <span
              className={`pill ${
                searchStatus.mode === "demo"
                  ? "border-gold/30 bg-gold-soft text-gold"
                  : searchStatus.configured
                    ? "border-teal/25 bg-teal-soft text-teal"
                    : "border-vermilion/25 bg-blush text-vermilion-dark"
              }`}
            >
              <span
                className={`h-1.5 w-1.5 rounded-full ${
                  searchStatus.mode === "demo"
                    ? "bg-gold"
                    : searchStatus.configured
                      ? "bg-teal"
                      : "bg-vermilion"
                }`}
              />
              {searchStatus.mode === "demo" ? "DEMO" : "LIVE"}
            </span>
          </div>
          <p className="mt-1.5 text-[12px] font-medium">{searchStatus.label}</p>
          <p className="mt-1 text-[10px] leading-relaxed text-muted">
            {searchStatus.mode === "demo"
              ? "内置样例数据，用于演示流程；不会联网检索。"
              : "通过搜索服务商的官方 API 查询公开结果。"}
          </p>

          {!searchStatus.configured && (
            <div className="mt-2.5 rounded-lg border border-vermilion/20 bg-blush/50 px-2.5 py-2 text-[10px] leading-relaxed text-vermilion-dark">
              <span className="inline-flex items-center gap-1 font-semibold">
                <AlertTriangle className="h-3 w-3" />
                缺少 API key，无法检索
              </span>
              <p className="mt-1">
                {searchStatus.hint} 缺少：
                <code className="font-mono">{searchStatus.missingEnv.join("、")}</code>。
                或在 <code className="font-mono">.env.local</code> 设{" "}
                <code className="font-mono">SEARCH_PROVIDER=mock</code> 体验 Demo。
              </p>
            </div>
          )}
        </div>

        {searchError && (
          <div
            role="alert"
            className="rounded-xl border border-vermilion/25 bg-blush/45 px-3 py-2.5 text-[11px] leading-relaxed text-vermilion-dark"
          >
            <p className="flex items-start gap-1.5 font-semibold">
              <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
              {searchError.message}
            </p>
            {searchError.hint && (
              <p className="mt-1 pl-5 text-[10px] text-vermilion-dark/85">
                {searchError.hint}
              </p>
            )}
          </div>
        )}

        <button
          type="submit"
          className="btn-primary w-full"
          disabled={searchDisabled}
          data-testid="search-submit"
        >
          {searchBusy ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" />
              正在公开检索…
            </>
          ) : (
            <>
              <Search className="h-4 w-4" />
              公开检索价格与口碑
            </>
          )}
        </button>

        <p className="text-center text-[10px] leading-relaxed text-muted/80">
          检索只发送商品关键词，不发送截图。
          <br />
          结果不是“全网最低价”，请以来源页面为准。
        </p>
      </form>
    </div>
  );
}
