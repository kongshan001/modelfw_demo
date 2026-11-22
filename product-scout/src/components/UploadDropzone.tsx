"use client";

import {
  AlertTriangle,
  ArrowRight,
  ClipboardPaste,
  Image as ImageIcon,
  Loader2,
  ScanLine,
  Trash2,
  UploadCloud
} from "lucide-react";
import { useRef, useState } from "react";

import type { DemoProduct } from "@/lib/fixtures/demo";
import { DEMO_PRODUCTS } from "@/lib/fixtures/demo";

export interface PreviewState {
  url: string;
  name: string;
  meta: string;
  isSample: boolean;
  sampleId: string | null;
}

interface UploadDropzoneProps {
  preview: PreviewState | null;
  busy: boolean;
  busyLabel: string;
  error: string | null;
  activeSampleId: string | null;
  visionMode: "demo" | "live";
  maxUploadMb: number;
  onFile: (file: File) => void;
  onSample: (sample: DemoProduct) => void;
  onClear: () => void;
  onManual: () => void;
}

export function UploadDropzone({
  preview,
  busy,
  busyLabel,
  error,
  activeSampleId,
  visionMode,
  maxUploadMb,
  onFile,
  onSample,
  onClear,
  onManual
}: UploadDropzoneProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);

  function pickFile(file: File | undefined) {
    if (!file) return;
    onFile(file);
    if (inputRef.current) inputRef.current.value = "";
  }

  return (
    <div
      className={`surface relative overflow-hidden transition-colors ${
        dragging ? "border-teal/60 bg-teal-soft/30" : ""
      }`}
      onDragOver={(event) => {
        event.preventDefault();
        setDragging(true);
      }}
      onDragLeave={(event) => {
        if (event.currentTarget.contains(event.relatedTarget as Node)) return;
        setDragging(false);
      }}
      onDrop={(event) => {
        event.preventDefault();
        setDragging(false);
        pickFile(event.dataTransfer.files[0]);
      }}
      data-testid="upload-dropzone"
    >
      <div className="pointer-events-none absolute -right-8 -top-8 h-28 w-28 rounded-full border border-dashed border-line/85" />
      <div className="relative p-4 sm:p-5">
        <div className="mb-3 flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <span className="grid h-7 w-7 place-items-center rounded-md bg-ink text-cream">
              <ScanLine className="h-3.5 w-3.5" />
            </span>
            <div>
              <p className="font-mono text-[9px] tracking-[0.24em] text-muted">
                SCAN / 01
              </p>
              <p className="text-[13px] font-semibold leading-tight">上传商品截图</p>
            </div>
          </div>
          <span className="pill border-line bg-paper/70 text-muted">
            {visionMode === "demo" ? "Demo 识别" : "视觉 API 识别"}
          </span>
        </div>

        <input
          ref={inputRef}
          type="file"
          accept="image/png,image/jpeg,image/webp,image/svg+xml"
          className="sr-only"
          aria-label="选择商品截图"
          onChange={(event) => pickFile(event.target.files?.[0])}
          data-testid="file-input"
        />

        {preview ? (
          <div className="animate-rise overflow-hidden rounded-2xl border border-line bg-[#EAE3D5]">
            <div className="relative flex h-[210px] items-center justify-center overflow-hidden sm:h-[250px]">
              <div
                aria-hidden="true"
                className="absolute inset-0 opacity-60"
                style={{
                  backgroundImage:
                    "linear-gradient(rgba(28,25,20,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(28,25,20,0.05) 1px, transparent 1px)",
                  backgroundSize: "22px 22px"
                }}
              />
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={preview.url}
                alt={`已选择截图预览：${preview.name}`}
                className="relative max-h-[88%] max-w-[92%] rounded-md object-contain shadow-[0_14px_35px_-18px_rgba(28,25,20,0.55)]"
                data-testid="preview-image"
              />

              <span className="absolute left-2.5 top-2.5 inline-flex items-center gap-1 rounded-full bg-ink/85 px-2 py-1 text-[10px] font-medium text-cream backdrop-blur">
                <ImageIcon className="h-3 w-3" />
                本地预览 · 未上传
              </span>

              <button
                type="button"
                onClick={onClear}
                className="absolute right-2.5 top-2.5 grid h-7 w-7 place-items-center rounded-full bg-cream/90 text-muted shadow-sm transition-colors hover:bg-white hover:text-ink"
                aria-label="移除截图"
              >
                <Trash2 className="h-3.5 w-3.5" />
              </button>

              {busy && (
                <div
                  className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-ink/55 text-cream backdrop-blur-[2px]"
                  role="status"
                  aria-live="polite"
                >
                  <div className="relative h-0.5 w-32 overflow-hidden bg-cream/20">
                    <span className="absolute inset-y-0 left-0 w-1/3 animate-sweep bg-cream" />
                  </div>
                  <div className="flex items-center gap-2 text-[12px] font-medium">
                    <Loader2 className="h-3.5 w-3.5 animate-spin" />
                    {busyLabel}
                  </div>
                </div>
              )}
            </div>

            <div className="flex items-center justify-between gap-3 border-t border-line/80 bg-cream/90 px-3 py-2.5">
              <div className="min-w-0">
                <p className="truncate text-[11px] font-medium text-ink" title={preview.name}>
                  {preview.name}
                </p>
                <p className="mt-0.5 text-[10px] text-muted">{preview.meta}</p>
              </div>
              <button
                type="button"
                className="btn-secondary shrink-0 px-2.5 py-1.5 text-[11px]"
                onClick={() => inputRef.current?.click()}
                disabled={busy}
              >
                更换
              </button>
            </div>
          </div>
        ) : (
          <button
            type="button"
            className="group relative flex h-[230px] w-full flex-col items-center justify-center gap-3 overflow-hidden rounded-2xl border border-dashed border-ink/25 bg-white/45 px-5 text-center transition-colors hover:border-teal/50 hover:bg-white/70 sm:h-[270px]"
            onClick={() => inputRef.current?.click()}
            data-testid="upload-open"
          >
            <span
              aria-hidden="true"
              className="absolute left-3 top-3 h-4 w-4 border-l border-t border-ink/25"
            />
            <span
              aria-hidden="true"
              className="absolute right-3 top-3 h-4 w-4 border-r border-t border-ink/25"
            />
            <span
              aria-hidden="true"
              className="absolute bottom-3 left-3 h-4 w-4 border-b border-l border-ink/25"
            />
            <span
              aria-hidden="true"
              className="absolute bottom-3 right-3 h-4 w-4 border-b border-r border-ink/25"
            />

            <span className="grid h-12 w-12 place-items-center rounded-2xl border border-line bg-cream text-vermilion shadow-sm transition-transform duration-200 group-hover:-translate-y-1">
              <UploadCloud className="h-5 w-5" />
            </span>
            <span>
              <span className="block font-display text-[20px] font-semibold text-ink">
                把商品截图放到这里
              </span>
              <span className="mt-1.5 block text-[12px] text-muted">
                拖拽、点击选择，或直接 <kbd className="rounded border border-line bg-paper px-1 py-0.5 font-mono text-[10px]">⌘/Ctrl + V</kbd> 粘贴
              </span>
            </span>
            <span className="inline-flex items-center gap-1.5 text-[10px] tracking-wide text-muted/75">
              <ClipboardPaste className="h-3 w-3" />
              PNG / JPG / WebP / SVG · 最大 {maxUploadMb}MB
            </span>
          </button>
        )}

        {error && (
          <div
            role="alert"
            className="mt-3 flex items-start gap-2 rounded-xl border border-vermilion/25 bg-blush/55 px-3 py-2 text-[12px] leading-relaxed text-vermilion-dark"
          >
            <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <div className="mt-4">
          <div className="mb-2 flex items-center justify-between">
            <p className="eyebrow">DEMO EXAMPLES / 示例截图</p>
            <span className="text-[9px] text-muted">点击即可体验</span>
          </div>
          <div className="grid grid-cols-3 gap-2">
            {DEMO_PRODUCTS.map((sample) => {
              const active = activeSampleId === sample.id;
              return (
                <button
                  key={sample.id}
                  type="button"
                  onClick={() => onSample(sample)}
                  className={`group flex flex-col overflow-hidden rounded-lg border text-left transition-all ${
                    active
                      ? "border-vermilion/55 bg-white shadow-sm"
                      : "border-line bg-cream/60 hover:-translate-y-0.5 hover:border-ink/25 hover:bg-white"
                  }`}
                  aria-pressed={active}
                  data-testid={`sample-${sample.id}`}
                >
                  <span className="relative block h-[54px] w-full overflow-hidden bg-[#E7E0D3]">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={sample.imagePath}
                      alt=""
                      className="h-full w-full object-cover object-center transition-transform duration-300 group-hover:scale-[1.03]"
                    />
                  </span>
                  <span className="block px-2 py-1.5">
                    <span className="block truncate text-[10px] font-semibold text-ink">
                      {sample.product.brand}
                    </span>
                    <span className="block truncate text-[9px] text-muted">
                      {sample.shortLabel}
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        <div className="mt-3 flex items-center justify-between gap-3 border-t border-dashed border-line pt-3">
          <p className="prose-note max-w-[72%]">
            {visionMode === "demo"
              ? "识别结果来自内置样例，仅本地预览图片，不调用外部视觉 API。"
              : "截图会发送到你配置的视觉 API，仅用于本次识别，服务端不存储。"}
          </p>
          <button
            type="button"
            onClick={onManual}
            className="inline-flex shrink-0 items-center gap-1 text-[11px] font-semibold text-teal transition-colors hover:text-ink"
          >
            手动填写
            <ArrowRight className="h-3 w-3" />
          </button>
        </div>
      </div>
    </div>
  );
}
