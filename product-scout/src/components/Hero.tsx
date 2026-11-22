import { BadgeCheck, FileSearch, Quote, ScanLine } from "lucide-react";

const STEPS = [
  { icon: ScanLine, label: "截图识别", note: "品牌 · 型号 · 规格" },
  { icon: FileSearch, label: "公开检索", note: "渠道 · 标价 · 链接" },
  { icon: Quote, label: "口碑核对", note: "评分 · 片段 · 出处" }
];

export function Hero({
  compact,
  children
}: {
  compact: boolean;
  children: React.ReactNode;
}) {
  return (
    <section className="relative pb-10 pt-12 sm:pb-12 sm:pt-16 lg:pt-20">
      <div className="grid items-center gap-10 lg:grid-cols-[1.07fr_0.93fr] lg:gap-14">
        <div className="relative">
          <div className="mb-5 flex flex-wrap items-center gap-2">
            <span className="eyebrow">PRICE INTELLIGENCE / 公开信息侦察</span>
            <span className="hidden h-px w-10 bg-line sm:block" />
            <span className="pill border-teal/20 bg-teal-soft text-teal">
              <BadgeCheck className="h-3 w-3" />
              证据优先
            </span>
          </div>

          <h1
            className={`text-balance font-display font-semibold leading-[1.05] tracking-[-0.035em] ${
              compact
                ? "text-[42px] sm:text-[52px]"
                : "text-[46px] sm:text-[64px] lg:text-[76px]"
            }`}
          >
            截图在手，
            <br />
            <span className="relative whitespace-nowrap">
              <span className="relative z-10 text-vermilion">价格底细</span>
              <svg
                aria-hidden="true"
                viewBox="0 0 320 18"
                className="absolute -bottom-1 left-0 z-0 h-[13px] w-full text-vermilion/25"
                preserveAspectRatio="none"
              >
                <path
                  d="M3 12C65 4 143 3 201 7c43 3 81 6 116 2"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="9"
                  strokeLinecap="round"
                />
              </svg>
            </span>
            看透。
          </h1>

          <p className="mt-6 max-w-[560px] text-[15px] leading-8 text-muted sm:text-[16px]">
            上传一张商品截图，提取品牌、型号和关键规格；再去
            <span className="font-semibold text-ink">公开搜索与购物接口</span>
            里查同款候选，整理成一份能逐条核对的购买决策表。
          </p>

          <div className="mt-7 flex flex-wrap gap-x-5 gap-y-2 text-[12px] text-muted">
            <span className="inline-flex items-center gap-1.5">
              <span className="h-1 w-1 rounded-full bg-teal" />
              只调公开 API / 打开公开链接
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="h-1 w-1 rounded-full bg-vermilion" />
              口碑逐条附来源
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="h-1 w-1 rounded-full bg-gold" />
              截图不落盘
            </span>
          </div>

          {!compact && (
            <div className="mt-10 grid max-w-[610px] grid-cols-3 divide-x divide-line border-y border-line/80">
              {STEPS.map((step, index) => (
                <div
                  key={step.label}
                  className="flex flex-col gap-2 px-3 py-4 first:pl-0 sm:flex-row sm:items-center sm:gap-3 sm:px-5 sm:first:pl-0"
                >
                  <span className="font-mono text-[10px] text-muted/70">
                    0{index + 1}
                  </span>
                  <div>
                    <div className="flex items-center gap-1.5 text-[13px] font-semibold text-ink">
                      <step.icon className="h-3.5 w-3.5 text-vermilion" />
                      {step.label}
                    </div>
                    <p className="mt-1 text-[10px] tracking-wide text-muted">
                      {step.note}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="relative">{children}</div>
      </div>
    </section>
  );
}
