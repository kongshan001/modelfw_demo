import { ScanLine, ShieldCheck } from "lucide-react";

import type { AppStatus } from "@/lib/types";

function ProviderChip({ status }: { status: AppStatus }) {
  if (status.search.mode === "demo") {
    return (
      <span className="pill border-gold/35 bg-gold-soft text-gold">
        <span className="h-1.5 w-1.5 rounded-full bg-gold" />
        DEMO 数据
      </span>
    );
  }

  if (!status.search.configured) {
    return (
      <span className="pill border-vermilion/25 bg-blush text-vermilion-dark">
        <span className="h-1.5 w-1.5 rounded-full bg-vermilion" />
        LIVE 未配置
      </span>
    );
  }

  return (
    <span className="pill border-teal/25 bg-teal-soft text-teal">
      <span className="h-1.5 w-1.5 rounded-full bg-teal" />
      LIVE · {status.search.label}
    </span>
  );
}

export function Header({ status }: { status: AppStatus }) {
  return (
    <header className="sticky top-0 z-40 border-b border-line/75 bg-paper/85 backdrop-blur-xl">
      <div className="mx-auto flex h-[68px] max-w-[1240px] items-center justify-between gap-4 px-5 sm:px-8">
        <a href="#top" className="group flex items-center gap-3">
          <span className="relative grid h-10 w-10 place-items-center overflow-hidden rounded-[11px] bg-vermilion text-cream shadow-[inset_0_0_0_1px_rgba(255,255,255,0.22)]">
            <ScanLine className="h-[19px] w-[19px]" strokeWidth={1.9} />
            <span className="absolute -bottom-2 -right-2 h-4 w-4 rotate-45 border border-cream/35" />
          </span>
          <span className="leading-none">
            <span className="block font-display text-[20px] font-semibold tracking-tight">
              Product Scout
            </span>
            <span className="mt-1 block font-mono text-[9px] tracking-[0.24em] text-muted">
              商品侦察台 / 公开信息比价
            </span>
          </span>
        </a>

        <div className="flex items-center gap-2 sm:gap-3">
          <div className="hidden items-center gap-1.5 text-[11px] text-muted md:flex">
            <ShieldCheck className="h-3.5 w-3.5 text-teal" />
            不爬站 · 不存图
          </div>
          <div className="hidden h-5 w-px bg-line md:block" />
          <a
            href="#how"
            className="hidden text-[12px] font-medium text-muted transition-colors hover:text-ink sm:block"
          >
            如何使用
          </a>
          <a
            href="#legal"
            className="hidden text-[12px] font-medium text-muted transition-colors hover:text-ink sm:block"
          >
            合法边界
          </a>
          <ProviderChip status={status} />
        </div>
      </div>
    </header>
  );
}
