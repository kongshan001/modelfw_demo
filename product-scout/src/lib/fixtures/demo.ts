import type { ExtractionResult, ProductIdentity } from "../types";

export interface DemoOfferSeed {
  channel: string;
  title: string;
  priceText: string;
  link: string;
  rating: number;
  reviewCount: number;
  snippet: string;
  reviewExcerpt: string;
}

export interface DemoProduct {
  id: string;
  label: string;
  shortLabel: string;
  imagePath: string;
  accent: string;
  product: ProductIdentity;
  confidence: {
    brand: number;
    model: number;
    category: number;
    specs: number;
  };
  offers: DemoOfferSeed[];
}

const searchUrls = {
  jd: (q: string) => `https://search.jd.com/Search?keyword=${encodeURIComponent(q)}`,
  tmall: (q: string) => `https://s.taobao.com/search?q=${encodeURIComponent(q)}`,
  suning: (q: string) =>
    `https://search.suning.com/${encodeURIComponent(q).replace(/%20/g, "-")}/`,
  pdd: (q: string) =>
    `https://mobile.yangkeduo.com/search_result.html?search_key=${encodeURIComponent(q)}`,
  amazon: (q: string) =>
    `https://www.amazon.com/s?k=${encodeURIComponent(q)}`,
  douyin: (q: string) =>
    `https://www.douyin.com/search/${encodeURIComponent(q)}`
};

export const DEMO_PRODUCTS: DemoProduct[] = [
  {
    id: "sony-xm5",
    label: "Sony WH-1000XM5 降噪耳机",
    shortLabel: "降噪耳机",
    imagePath: "/demo/sony-wh1000xm5.svg",
    accent: "#1F3A4D",
    product: {
      brand: "Sony",
      model: "WH-1000XM5",
      category: "头戴式降噪耳机",
      specs: "蓝牙 5.2 · 约 30 小时续航 · 约 250g"
    },
    confidence: { brand: 0.97, model: 0.93, category: 0.9, specs: 0.76 },
    offers: [
      {
        channel: "京东 · 自营",
        title: "Sony WH-1000XM5 头戴式无线降噪耳机",
        priceText: "¥2,299.00",
        link: searchUrls.jd("Sony WH-1000XM5"),
        rating: 4.9,
        reviewCount: 23_000,
        snippet: "自营配送，次日达；支持 7 天无理由退货（以商家页面为准）。",
        reviewExcerpt:
          "降噪效果很强，佩戴舒适，长时间使用也不压耳。折叠结构取消了，收纳盒偏大。"
      },
      {
        channel: "天猫 · 官方旗舰店",
        title: "Sony WH-1000XM5 无线降噪头戴耳机 官方正品",
        priceText: "¥2,399.00",
        link: searchUrls.tmall("Sony WH-1000XM5"),
        rating: 4.8,
        reviewCount: 18_500,
        snippet: "官方旗舰店；大促期间价格与赠品可能变化，以商品页为准。",
        reviewExcerpt:
          "通话清晰，地铁通勤很稳定。价格波动大，大促前后差三四百。"
      },
      {
        channel: "苏宁易购",
        title: "索尼 WH-1000XM5 头戴式蓝牙降噪耳机",
        priceText: "¥2,199.00",
        link: searchUrls.suning("Sony WH-1000XM5"),
        rating: 4.7,
        reviewCount: 6_320,
        snippet: "公开检索结果；库存、发票与售后以商家页面为准。",
        reviewExcerpt:
          "机身很轻，做工扎实。夏天佩戴略微闷热，App 调音功能一般。"
      },
      {
        channel: "拼多多 · 百亿补贴",
        title: "Sony 索尼 WH-1000XM5 降噪耳机 国行",
        priceText: "¥1,999.00",
        link: searchUrls.pdd("Sony WH-1000XM5"),
        rating: 4.6,
        reviewCount: 12_000,
        snippet: "第三方店铺；补贴资格、发票与版本需在商品页核实。",
        reviewExcerpt: "性价比高，包装完好。发货速度一般。"
      },
      {
        channel: "亚马逊 · 海外购",
        title: "Sony WH-1000XM5 Wireless Noise Canceling Headphones",
        priceText: "¥2,499.00",
        link: searchUrls.amazon("Sony WH-1000XM5"),
        rating: 4.7,
        reviewCount: 9_800,
        snippet: "海外版商品；税费、保修与版本差异请以下单页为准。",
        reviewExcerpt: "国际版音质好，支持 LDAC。保修流程比较麻烦。"
      }
    ]
  },
  {
    id: "anker-nano2",
    label: "Anker Nano II 65W 充电器",
    shortLabel: "氮化镓充电器",
    imagePath: "/demo/anker-nano2.svg",
    accent: "#2C574C",
    product: {
      brand: "Anker 安克",
      model: "Nano II 65W",
      category: "氮化镓充电器",
      specs: "USB-C 单口 65W · 可折叠插脚"
    },
    confidence: { brand: 0.95, model: 0.89, category: 0.92, specs: 0.81 },
    offers: [
      {
        channel: "京东 · 自营",
        title: "Anker 安克 Nano II 65W 氮化镓充电器",
        priceText: "¥149.00",
        link: searchUrls.jd("Anker Nano II 65W"),
        rating: 4.9,
        reviewCount: 53_000,
        snippet: "自营仓发货；适配机型请对照商品详情页。",
        reviewExcerpt:
          "体积小，充电快，出差带着很方便。单口 65W 给笔记本供电也够用。"
      },
      {
        channel: "天猫 · 官方旗舰店",
        title: "Anker 安克 65W 氮化镓充电器 单口折叠",
        priceText: "¥139.00",
        link: searchUrls.tmall("Anker Nano II 65W"),
        rating: 4.8,
        reviewCount: 21_000,
        snippet: "官方旗舰店；活动价与券后价以下单页为准。",
        reviewExcerpt: "做工不错，插脚可折叠。价格比首发略贵，但还能接受。"
      },
      {
        channel: "苏宁易购",
        title: "安克 Anker Nano II 65W PD 充电器",
        priceText: "¥159.00",
        link: searchUrls.suning("Anker Nano II 65W"),
        rating: 4.7,
        reviewCount: 4_200,
        snippet: "公开检索结果，第三方配送信息以页面为准。",
        reviewExcerpt:
          "给手机充电会发热，夏天有点烫手。兼容性好，Switch 也能用。"
      },
      {
        channel: "抖音商城",
        title: "Anker 安克 65W 快充头 直播同款",
        priceText: "¥129.00",
        link: searchUrls.douyin("Anker Nano II 65W"),
        rating: 4.5,
        reviewCount: 8_600,
        snippet: "直播/店铺商品；规格、保修与发票需向商家确认。",
        reviewExcerpt: "一次买两个，性价比高。包装有点简陋。"
      }
    ]
  },
  {
    id: "dyson-v12",
    label: "Dyson V12 Detect Slim 吸尘器",
    shortLabel: "无线吸尘器",
    imagePath: "/demo/dyson-v12.svg",
    accent: "#5B3E57",
    product: {
      brand: "Dyson 戴森",
      model: "V12 Detect Slim",
      category: "无线吸尘器",
      specs: "激光探测 · 约 2.2kg · 最长 60 分钟续航"
    },
    confidence: { brand: 0.96, model: 0.9, category: 0.88, specs: 0.72 },
    offers: [
      {
        channel: "京东 · 自营",
        title: "戴森 V12 Detect Slim 轻量无线吸尘器",
        priceText: "¥3,499.00",
        link: searchUrls.jd("Dyson V12 Detect Slim"),
        rating: 4.8,
        reviewCount: 31_000,
        snippet: "自营配送；配件清单与保修政策以商品页为准。",
        reviewExcerpt:
          "吸力强，地毯清洁很干净。机身偏重，长时间举着手腕累。"
      },
      {
        channel: "天猫 · 官方旗舰店",
        title: "Dyson 戴森 V12 Detect Slim 无线吸尘器",
        priceText: "¥3,690.00",
        link: searchUrls.tmall("Dyson V12 Detect Slim"),
        rating: 4.8,
        reviewCount: 14_200,
        snippet: "官方旗舰店；赠品与安装服务随时间变化。",
        reviewExcerpt:
          "激光探测很好用，灰尘一目了然。续航一般，大户型要分两次。"
      },
      {
        channel: "苏宁易购",
        title: "戴森 V12 Detect Slim 手持无线吸尘器",
        priceText: "¥3,399.00",
        link: searchUrls.suning("Dyson V12 Detect Slim"),
        rating: 4.7,
        reviewCount: 5_100,
        snippet: "公开检索结果；实际库存与配送范围以页面为准。",
        reviewExcerpt: "做工扎实，配件齐全。价格贵，售后网点少。"
      },
      {
        channel: "山姆会员商店",
        title: "Dyson V12 Detect Slim 无线吸尘器套装",
        priceText: "¥3,599.00",
        link: "https://www.samsclub.cn/search?keyword=Dyson%20V12",
        rating: 4.6,
        reviewCount: 2_400,
        snippet: "会员店商品；需会员资格，库存以门店/页面为准。",
        reviewExcerpt: "开箱体验不错，安装方便。尘盒清理略麻烦。"
      }
    ]
  }
];

export const DEMO_DEFAULT_PRODUCT_ID = "sony-xm5";

export function getDemoProduct(id: string | null | undefined): DemoProduct {
  const fallback = DEMO_PRODUCTS[0];
  if (!fallback) throw new Error("Demo 商品目录为空");
  return DEMO_PRODUCTS.find((product) => product.id === id) ?? fallback;
}

export function buildDemoExtraction(demo: DemoProduct): ExtractionResult {
  return {
    product: { ...demo.product },
    fields: {
      brand: { confidence: demo.confidence.brand, source: "demo" },
      model: { confidence: demo.confidence.model, source: "demo" },
      category: { confidence: demo.confidence.category, source: "demo" },
      specs: { confidence: demo.confidence.specs, source: "demo" }
    },
    mode: "demo",
    notice:
      "Demo 模式：以上字段来自内置样例，并非对这张图片的真实 OCR/视觉识别。图片只在浏览器内预览，不会上传。"
  };
}

export const DEMO_DISCLAIMER =
  "Demo 演示数据：价格、评分与评论片段均为内置样例，仅用于展示流程，不是实时市场数据。";
