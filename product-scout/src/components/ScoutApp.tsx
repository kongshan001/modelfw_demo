"use client";

import {
  ArrowUpRight,
  BadgeCheck,
  FileSearch,
  LockKeyhole,
  Quote,
  ScanLine,
  ShieldCheck
} from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";

import {
  buildDemoExtraction,
  DEMO_DEFAULT_PRODUCT_ID,
  DEMO_DISCLAIMER,
  getDemoProduct,
  type DemoProduct
} from "@/lib/fixtures/demo";
import { ApiError, requestExtraction, requestSearch } from "@/lib/client-api";
import type {
  AppStatus,
  ExtractionResult,
  FieldEvidence,
  ProductFieldKey,
  ProductIdentity,
  SearchPayload
} from "@/lib/types";
import type { FieldValidationErrors } from "@/lib/validation";
import { validateProductFields } from "@/lib/validation";
import type { SortDirection } from "@/lib/sort";

import { Header } from "./Header";
import { Hero } from "./Hero";
import {
  ProductEditor,
  type EditorSearchError
} from "./ProductEditor";
import { ReputationPanel } from "./ReputationPanel";
import { ResultsPanel } from "./ResultsPanel";
import { UploadDropzone, type PreviewState } from "./UploadDropzone";

const EMPTY_PRODUCT: ProductIdentity = {
  brand: "",
  model: "",
  category: "",
  specs: ""
};

function fileSizeLabel(bytes: number): string {
  if (bytes >= 1024 * 1024) {
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
}

function fileTypeLabel(type: string): string {
  if (type === "image/png") return "PNG";
  if (type === "image/jpeg") return "JPG";
  if (type === "image/webp") return "WebP";
  if (type === "image/svg+xml") return "SVG";
  return type.split("/")[1]?.toUpperCase() ?? "图片";
}

function readFileAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === "string") resolve(reader.result);
      else reject(new Error("无法读取文件"));
    };
    reader.onerror = () => reject(new Error("无法读取文件"));
    reader.readAsDataURL(file);
  });
}

function HowItWorks() {
  const cards = [
    {
      icon: ScanLine,
      index: "01",
      title: "字段先摊开",
      body: "Demo 用内置样例并明确标注；配置视觉 API 后才会把截图发给模型。每个字段都可改，识别置信度与来源都摆在旁边。"
    },
    {
      icon: FileSearch,
      index: "02",
      title: "只查公开接口",
      body: "默认 mock 不联网；Live 模式调用 Serper / Tavily / Brave / SerpAPI 等官方搜索 API。不爬站、不绕过登录或付费墙。"
    },
    {
      icon: Quote,
      index: "03",
      title: "口碑有出处",
      body: "优点、顾虑和结论只读检索返回的评分与评论片段，每条附来源链接；没有数据就显示“未获取”，绝不补写。"
    }
  ];

  return (
    <section id="how" className="py-12 sm:py-16">
      <div className="mb-7 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="eyebrow">HOW IT WORKS / 使用方式</p>
          <h2 className="mt-2 font-display text-[30px] font-semibold tracking-tight sm:text-[36px]">
            不装“全网最低”，只交付可核对。
          </h2>
        </div>
        <p className="max-w-[360px] text-[12px] leading-relaxed text-muted">
          这更像一张调查工作台，而不是一个比价承诺。每个价格都能点回来源，每条口碑都能找到出处。
        </p>
      </div>

      <div className="grid gap-3 md:grid-cols-3">
        {cards.map((card) => (
          <article
            key={card.index}
            className="group surface relative overflow-hidden p-5 transition-transform duration-200 hover:-translate-y-1 sm:p-6"
          >
            <span className="absolute right-4 top-3 font-display text-[54px] font-semibold leading-none text-line/55">
              {card.index}
            </span>
            <span className="grid h-9 w-9 place-items-center rounded-xl border border-line bg-paper/65 text-vermilion">
              <card.icon className="h-4 w-4" />
            </span>
            <h3 className="mt-5 font-display text-[21px] font-semibold">{card.title}</h3>
            <p className="mt-2 text-[12px] leading-[1.85] text-muted">{card.body}</p>
            <span className="mt-5 inline-flex items-center gap-1 font-mono text-[9px] tracking-[0.18em] text-muted/60">
              READ THE EVIDENCE
              <ArrowUpRight className="h-3 w-3" />
            </span>
          </article>
        ))}
      </div>
    </section>
  );
}

function LegalSection() {
  return (
    <section id="legal" className="pb-14 pt-2 sm:pb-20">
      <div className="relative overflow-hidden rounded-[26px] bg-ink px-5 py-7 text-cream sm:px-8 sm:py-9">
        <div className="pointer-events-none absolute -right-20 -top-24 h-64 w-64 rounded-full border border-cream/10" />
        <div className="pointer-events-none absolute -bottom-32 left-1/3 h-64 w-64 rounded-full border border-cream/10" />
        <div className="relative grid gap-8 lg:grid-cols-[1.05fr_0.95fr]">
          <div>
            <p className="font-mono text-[9px] uppercase tracking-[0.24em] text-cream/45">
              LEGAL & PRIVACY / 边界说明
            </p>
            <h2 className="mt-3 font-display text-[30px] font-semibold tracking-tight sm:text-[38px]">
              不爬站，不伪造，
              <br />
              不替你下单。
            </h2>
            <p className="mt-4 max-w-[470px] text-[12px] leading-[1.9] text-cream/60">
              Product Scout 是本地单用户工具。它不提供登录、支付或代购服务，也不对你看到的第三方价格、库存与售后作担保。所有商标归各自权利人。
            </p>
            <div className="mt-6 flex flex-wrap gap-2">
              <span className="inline-flex items-center gap-1.5 rounded-full border border-cream/15 px-3 py-1.5 text-[10px] text-cream/65">
                <LockKeyhole className="h-3 w-3" />
                图片不落盘
              </span>
              <span className="inline-flex items-center gap-1.5 rounded-full border border-cream/15 px-3 py-1.5 text-[10px] text-cream/65">
                <ShieldCheck className="h-3 w-3" />
                不绕过反爬 / ToS
              </span>
              <span className="inline-flex items-center gap-1.5 rounded-full border border-cream/15 px-3 py-1.5 text-[10px] text-cream/65">
                <BadgeCheck className="h-3 w-3" />
                无数据写“未获取”
              </span>
            </div>
          </div>

          <div className="grid gap-5 sm:grid-cols-2">
            <div>
              <p className="font-mono text-[9px] tracking-[0.2em] text-cream/40">PRIVACY</p>
              <ul className="mt-2 space-y-2 text-[11px] leading-relaxed text-cream/65">
                <li>截图只在浏览器内预览，默认不离开本机。</li>
                <li>仅当配置 Live 视觉 API 时，图片才以 base64 发给该服务，服务端不写入磁盘或数据库。</li>
                <li>不记录原始截图、API key 或完整请求体到日志。</li>
              </ul>
            </div>
            <div>
              <p className="font-mono text-[9px] tracking-[0.2em] text-cream/40">DATA BOUNDARY</p>
              <ul className="mt-2 space-y-2 text-[11px] leading-relaxed text-cream/65">
                <li>Live 结果来自第三方搜索 API，受其额度、套餐与 ToS 约束。</li>
                <li>只打开公开链接；不抓取需登录或付费的数据。</li>
                <li>“最低候选”仅指本次返回结果中的最低，不是“全网最低价”。</li>
                <li>Demo 数据均为样例并已标注，请勿据此购买。</li>
              </ul>
            </div>
          </div>
        </div>
        <div className="relative mt-7 flex flex-wrap items-center justify-between gap-2 border-t border-cream/10 pt-4 font-mono text-[8px] tracking-[0.16em] text-cream/35">
          <span>PRODUCT SCOUT · LOCAL SINGLE USER TOOL</span>
          <span>PUBLIC APIs ONLY · NO SCRAPING · NO FAKE REVIEWS</span>
        </div>
      </div>
    </section>
  );
}

function Footer({ demoData }: { demoData: boolean }) {
  return (
    <footer className="border-t border-line/80 py-7">
      <div className="mx-auto flex max-w-[1240px] flex-wrap items-center justify-between gap-3 px-5 text-[10px] text-muted sm:px-8">
        <div className="flex items-center gap-2">
          <span className="grid h-6 w-6 place-items-center rounded-md bg-vermilion font-display text-[11px] font-bold text-cream">
            侦
          </span>
          <span>Product Scout · 商品侦察台</span>
        </div>
        <p>
          {demoData
            ? DEMO_DISCLAIMER
            : "Live 结果来自第三方公开搜索 API，价格与库存请以来源页面为准。"}
        </p>
        <p className="font-mono tracking-wide">v1.0 · 本地单用户</p>
      </div>
    </footer>
  );
}

export function ScoutApp({ initialStatus }: { initialStatus: AppStatus }) {
  const status = initialStatus;

  const [preview, setPreview] = useState<PreviewState | null>(null);
  const [workspaceOpen, setWorkspaceOpen] = useState(false);
  const [product, setProduct] = useState<ProductIdentity>(EMPTY_PRODUCT);
  const [fieldMeta, setFieldMeta] = useState<
    Partial<Record<ProductFieldKey, FieldEvidence>> | null
  >(null);
  const [extraction, setExtraction] = useState<ExtractionResult | null>(null);
  const [fieldErrors, setFieldErrors] = useState<FieldValidationErrors>({});
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [extracting, setExtracting] = useState(false);
  const [searching, setSearching] = useState(false);
  const [payload, setPayload] = useState<SearchPayload | null>(null);
  const [searchError, setSearchError] = useState<EditorSearchError | null>(null);
  const [resultError, setResultError] = useState<EditorSearchError | null>(null);
  const [sortDir, setSortDir] = useState<SortDirection>("asc");

  const opSeq = useRef(0);
  const previewUrlRef = useRef<string | null>(null);
  const hasWorkspace = workspaceOpen || preview !== null;

  const releasePreviewUrl = useCallback(() => {
    if (previewUrlRef.current?.startsWith("blob:")) {
      URL.revokeObjectURL(previewUrlRef.current);
    }
    previewUrlRef.current = null;
  }, []);

  useEffect(() => releasePreviewUrl, [releasePreviewUrl]);

  useEffect(() => {
    function preventFileDrop(event: DragEvent) {
      if (event.dataTransfer?.types.includes("Files")) {
        event.preventDefault();
      }
    }
    window.addEventListener("dragover", preventFileDrop);
    window.addEventListener("drop", preventFileDrop);
    return () => {
      window.removeEventListener("dragover", preventFileDrop);
      window.removeEventListener("drop", preventFileDrop);
    };
  }, []);

  const applyExtraction = useCallback((result: ExtractionResult) => {
    setProduct(result.product);
    setFieldMeta(result.fields);
    setExtraction(result);
    setFieldErrors({});
    window.setTimeout(() => {
      document.getElementById("workspace")?.scrollIntoView({
        behavior: "smooth",
        block: "start"
      });
    }, 120);
  }, []);

  const applyDemoProduct = useCallback(
    (demo: DemoProduct, seq: number, delay: number, customNotice?: string) => {
      setExtracting(true);
      window.setTimeout(() => {
        if (opSeq.current !== seq) return;
        const result = buildDemoExtraction(demo);
        if (customNotice) result.notice = customNotice;
        applyExtraction(result);
        setExtracting(false);
      }, delay);
    },
    [applyExtraction]
  );

  const handleSample = useCallback(
    (sample: DemoProduct) => {
      const seq = opSeq.current + 1;
      opSeq.current = seq;
      releasePreviewUrl();
      setPreview({
        url: sample.imagePath,
        name: `示例截图 · ${sample.label}`,
        meta: "内置样例 · Demo 数据",
        isSample: true,
        sampleId: sample.id
      });
      setWorkspaceOpen(true);
      setExtraction(null);
      setFieldErrors({});
      setUploadError(null);
      setSearchError(null);
      setResultError(null);
      setPayload(null);
      setSearching(false);
      setExtracting(false);
      setProduct(EMPTY_PRODUCT);
      setFieldMeta(null);

      applyDemoProduct(
        sample,
        seq,
        620,
        "Demo 模式：以上字段来自内置示例商品，并非对这张图片的真实识别；示例截图也不会发送到任何视觉 API。"
      );
    },
    [applyDemoProduct, releasePreviewUrl]
  );

  const handleFile = useCallback(
    (file: File) => {
      const seq = opSeq.current + 1;
      opSeq.current = seq;

      setUploadError(null);
      setSearchError(null);
      setResultError(null);
      setPayload(null);
      setSearching(false);
      setExtracting(false);

      if (!file.type.startsWith("image/")) {
        setUploadError("请选择图片文件（PNG / JPG / WebP / SVG）。");
        return;
      }
      if (file.size > status.maxUploadMb * 1024 * 1024) {
        setUploadError(`图片超过 ${status.maxUploadMb}MB，请压缩后再试。`);
        return;
      }
      if (status.vision.mode === "live" && file.type === "image/svg+xml") {
        setUploadError(
          "视觉 API 不支持 SVG。请上传 PNG / JPG / WebP，或直接手动填写商品字段。"
        );
        return;
      }

      releasePreviewUrl();
      const objectUrl = URL.createObjectURL(file);
      previewUrlRef.current = objectUrl;
      setPreview({
        url: objectUrl,
        name: file.name || "粘贴的截图",
        meta: `${fileTypeLabel(file.type)} · ${fileSizeLabel(file.size)} · 本地预览`,
        isSample: false,
        sampleId: null
      });
      setWorkspaceOpen(true);
      setExtraction(null);
      setProduct(EMPTY_PRODUCT);
      setFieldMeta(null);
      setFieldErrors({});
      setPayload(null);

      if (status.vision.mode === "demo") {
        const demo = getDemoProduct(DEMO_DEFAULT_PRODUCT_ID);
        applyDemoProduct(
          demo,
          seq,
          760,
          "Demo 模式：以下字段来自内置样例，并非对这张图片的真实 OCR/视觉识别。图片只在浏览器内预览，没有上传；可以逐项手动修改。"
        );
        return;
      }

      if (!status.vision.configured) {
        setUploadError(
          "已加入本地预览，但视觉 API 尚未配置。请手动填写下方字段，或配置 VISION_API_KEY 后重启。"
        );
        return;
      }

      setExtracting(true);
      void (async () => {
        try {
          const dataUrl = await readFileAsDataUrl(file);
          const result = await requestExtraction(dataUrl);
          if (opSeq.current !== seq) return;
          applyExtraction(result);
        } catch (error) {
          if (opSeq.current !== seq) return;
          setExtraction(null);
          setProduct(EMPTY_PRODUCT);
          setFieldMeta(null);
          setUploadError(
            error instanceof ApiError
              ? `${error.message}${error.hint ? ` ${error.hint}` : ""}`
              : "视觉识别失败，请手动填写商品字段。"
          );
        } finally {
          if (opSeq.current === seq) setExtracting(false);
        }
      })();
    },
    [applyDemoProduct, applyExtraction, releasePreviewUrl, status]
  );

  useEffect(() => {
    function handlePaste(event: ClipboardEvent) {
      const items = event.clipboardData?.items;
      if (!items) return;
      for (const item of items) {
        if (item.type.startsWith("image/")) {
          const file = item.getAsFile();
          if (file) {
            event.preventDefault();
            handleFile(file);
            return;
          }
        }
      }
    }
    document.addEventListener("paste", handlePaste);
    return () => document.removeEventListener("paste", handlePaste);
  }, [handleFile]);

  function handleClear() {
    opSeq.current += 1;
    releasePreviewUrl();
    setPreview(null);
    setWorkspaceOpen(false);
    setProduct(EMPTY_PRODUCT);
    setFieldMeta(null);
    setExtraction(null);
    setFieldErrors({});
    setUploadError(null);
    setSearchError(null);
    setResultError(null);
    setPayload(null);
    setExtracting(false);
    setSearching(false);
  }

  function handleManual() {
    if (!preview) {
      opSeq.current += 1;
      setWorkspaceOpen(true);
      setProduct(EMPTY_PRODUCT);
      setFieldMeta(null);
      setExtraction(null);
      setUploadError(null);
      setFieldErrors({});
    }
    window.setTimeout(() => {
      document.getElementById("workspace")?.scrollIntoView({
        behavior: "smooth",
        block: "start"
      });
    }, 30);
  }

  const updateField = useCallback(
    (key: ProductFieldKey, value: string) => {
      setProduct((current) => ({ ...current, [key]: value }));
      setFieldMeta((current) => ({
        ...(current ?? {}),
        [key]: { confidence: 1, source: "manual" }
      }));
      setFieldErrors((current) => ({ ...current, [key]: undefined }));
      if (searching) {
        opSeq.current += 1;
        setSearching(false);
      }
      if (payload) setPayload(null);
      if (searchError) setSearchError(null);
      if (resultError) setResultError(null);
    },
    [payload, resultError, searchError, searching]
  );

  function handleSearch() {
    const errors = validateProductFields(product);
    if (Object.keys(errors).length > 0) {
      setFieldErrors(errors);
      setResultError(null);
      setSearchError({
        message: errors.brand ?? errors.model ?? "请先补全商品字段",
        hint: "至少填写品牌或型号；品类与规格越完整，检索越准确。"
      });
      return;
    }

    if (!status.search.configured) {
      setResultError(null);
      setSearchError({
        message: `${status.search.label} 尚未配置`,
        hint: `${status.search.hint} 缺少：${status.search.missingEnv.join("、")}。`
      });
      return;
    }

    const seq = opSeq.current + 1;
    opSeq.current = seq;
    setSearching(true);
    setSearchError(null);
    setResultError(null);
    setPayload(null);
    setFieldErrors({});

    void (async () => {
      try {
        const result = await requestSearch(product);
        if (opSeq.current !== seq) return;
        setPayload(result);
        setSortDir("asc");
        window.setTimeout(() => {
          document.getElementById("results")?.scrollIntoView({
            behavior: "smooth",
            block: "start"
          });
        }, 80);
      } catch (error) {
        if (opSeq.current !== seq) return;
        const failure =
          error instanceof ApiError
            ? { message: error.message, hint: error.hint }
            : { message: "检索失败，请稍后重试。", hint: null };
        setSearchError(failure);
        setResultError(failure);
      } finally {
        if (opSeq.current === seq) setSearching(false);
      }
    })();
  }

  return (
    <div className="min-h-screen">
      <a className="skip-link" href="#workspace">
        跳到工作台
      </a>
      <Header status={status} />

      <main id="top" className="mx-auto max-w-[1240px] px-5 sm:px-8">
        <Hero compact={hasWorkspace}>
          <UploadDropzone
            preview={preview}
            busy={extracting}
            busyLabel={
              status.vision.mode === "demo" ? "Demo 演示识别中…" : "视觉模型解析中…"
            }
            error={uploadError}
            activeSampleId={preview?.sampleId ?? null}
            visionMode={status.vision.mode}
            maxUploadMb={status.maxUploadMb}
            onFile={handleFile}
            onSample={handleSample}
            onClear={handleClear}
            onManual={handleManual}
          />
        </Hero>

        {hasWorkspace ? (
          <>
            <section id="workspace" className="scroll-mt-[92px] pb-4">
              <div className="mb-4 flex flex-wrap items-end justify-between gap-3 border-b border-line/80 pb-3">
                <div>
                  <p className="eyebrow">SCOUT WORKSPACE / 侦察工作台</p>
                  <h2 className="mt-1 font-display text-[26px] font-semibold tracking-tight sm:text-[30px]">
                    把字段核对好，再去查价格。
                  </h2>
                </div>
                <p className="max-w-[410px] text-[11px] leading-relaxed text-muted">
                  默认 Demo 数据可完整体验；Live 模式需要你自行配置搜索 API key。
                  结果只是公开候选，不替代商家页面与售后确认。
                </p>
              </div>

              <div className="grid items-start gap-4 lg:grid-cols-[390px_minmax(0,1fr)]">
                <ProductEditor
                  product={product}
                  fieldMeta={fieldMeta}
                  extraction={extraction}
                  errors={fieldErrors}
                  busy={extracting}
                  searchBusy={searching}
                  searchError={searchError}
                  searchStatus={status.search}
                  onUpdate={updateField}
                  onSearch={handleSearch}
                />
                <div id="results" className="min-w-0 scroll-mt-[92px]">
                  <ResultsPanel
                    payload={payload}
                    status={status}
                    sortDir={sortDir}
                    onSortChange={setSortDir}
                    searching={searching}
                    error={resultError}
                    onRetry={handleSearch}
                  />
                  {payload && !searching && (
                    <div className="mt-4 flex flex-wrap items-center justify-between gap-2 rounded-xl border border-line bg-cream/60 px-4 py-3 text-[10px] text-muted">
                      <span>
                        想重新核对？修改任一字段会清空当前结果，避免旧结果和新字段混用。
                      </span>
                      <button
                        type="button"
                        onClick={handleSearch}
                        disabled={searching}
                        className="btn-secondary px-2.5 py-1.5 text-[10px]"
                      >
                        重新检索
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </section>

            <ReputationPanel payload={payload} />
          </>
        ) : (
          <HowItWorks />
        )}

        <div className={hasWorkspace ? "mt-8" : ""}>
          <LegalSection />
        </div>
      </main>

      <Footer demoData={status.search.mode === "demo"} />
    </div>
  );
}
