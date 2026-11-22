import { round1 } from "./money";
import type {
  Offer,
  ReputationPoint,
  ReputationSummary
} from "./types";

const POSITIVE_TERMS = [
  "降噪",
  "舒适",
  "安静",
  "很轻",
  "轻便",
  "扎实",
  "音质好",
  "清晰",
  "稳定",
  "很快",
  "值得",
  "满意",
  "性价比",
  "好评",
  "不错",
  "好用",
  "续航长",
  "方便",
  "省心",
  "推荐",
  "干净",
  "吸力强"
];

const NEGATIVE_TERMS = [
  "夹头",
  "压耳",
  "偏重",
  "很重",
  "太贵",
  "价格波动",
  "断连",
  "漏音",
  "延迟",
  "发热",
  "闷热",
  "不舒服",
  "失望",
  "一般",
  "麻烦",
  "鸡肋",
  "虚高",
  "不推荐",
  "发货慢",
  "瑕疵",
  "偏大",
  "收纳",
  "售后",
  "简陋",
  "烫手",
  "累",
  "续航一般"
];

const MAX_POINTS = 3;

function splitSentences(text: string): string[] {
  return text
    .split(/(?<=[。！？!?])|\n+/u)
    .map((sentence) => sentence.trim().replace(/^[-•·]\s*/, ""))
    .filter((sentence) => sentence.length >= 4 && sentence.length <= 120);
}

function classifySentence(sentence: string): "positive" | "negative" | null {
  let positive = 0;
  let negative = 0;

  for (const term of POSITIVE_TERMS) {
    if (sentence.includes(term)) positive += 1;
  }
  for (const term of NEGATIVE_TERMS) {
    if (sentence.includes(term)) negative += 1;
  }

  if (positive === negative) return null;
  return positive > negative ? "positive" : "negative";
}

function weightedAverage(offers: Offer[]): number | null {
  const rated = offers.filter(
    (offer) =>
      offer.rating !== null &&
      offer.reviewCount !== null &&
      offer.reviewCount > 0
  );

  if (rated.length > 0) {
    const totalWeight = rated.reduce(
      (sum, offer) => sum + (offer.reviewCount ?? 0),
      0
    );
    if (totalWeight > 0) {
      const weighted = rated.reduce(
        (sum, offer) => sum + (offer.rating ?? 0) * (offer.reviewCount ?? 0),
        0
      );
      return round1(weighted / totalWeight);
    }
  }

  const simple = offers
    .map((offer) => offer.rating)
    .filter((rating): rating is number => rating !== null);
  if (simple.length === 0) return null;

  return round1(simple.reduce((sum, rating) => sum + rating, 0) / simple.length);
}

function buildConclusion(
  summary: Pick<
    ReputationSummary,
    "weightedRating" | "ratedOfferCount" | "pros" | "cons"
  >
): string {
  const { weightedRating, ratedOfferCount, pros, cons } = summary;

  if (weightedRating === null && pros.length === 0 && cons.length === 0) {
    return "本次公开检索未返回可用评分或评论片段，无法判断整体口碑。";
  }

  const parts: string[] = [];
  if (weightedRating !== null) {
    const tone =
      weightedRating >= 4.5
        ? "整体口碑很好"
        : weightedRating >= 4
          ? "整体口碑偏正面"
          : weightedRating >= 3
            ? "口碑褒贬不一"
            : "口碑偏负面";
    parts.push(
      `基于 ${ratedOfferCount} 个有评分的渠道，加权均分 ${weightedRating.toFixed(1)}/5，${tone}`
    );
  } else {
    parts.push("本次检索缺少可用的公开评分");
  }

  if (pros.length > 0 && cons.length > 0) {
    parts.push(`评论片段同时提到 ${pros.length} 条优点和 ${cons.length} 条顾虑`);
  } else if (pros.length > 0) {
    parts.push(`评论片段以正面反馈为主（${pros.length} 条）`);
  } else if (cons.length > 0) {
    parts.push(`评论片段以负面反馈为主（${cons.length} 条）`);
  } else {
    parts.push("未获取可归纳的公开评论正文");
  }

  return `${parts.join("；")}。`;
}

/**
 * Builds a reputation summary ONLY from fields returned by the search
 * provider. It never infers a pro/con from a rating alone, and it never treats
 * a product description snippet as a review quote. Demo fixtures opt in by
 * providing reviewExcerpt (labelled as demo in the UI).
 */
export function buildReputationSummary(offers: Offer[]): ReputationSummary {
  const ratedOffers = offers.filter((offer) => offer.rating !== null);
  const reviewCounts = offers
    .map((offer) => offer.reviewCount)
    .filter((count): count is number => count !== null);

  const pros: ReputationPoint[] = [];
  const cons: ReputationPoint[] = [];
  const seen = new Set<string>();

  for (const offer of offers) {
    if (!offer.reviewExcerpt) continue;

    for (const sentence of splitSentences(offer.reviewExcerpt)) {
      if (seen.has(sentence)) continue;
      const sentiment = classifySentence(sentence);
      if (!sentiment) continue;

      const target = sentiment === "positive" ? pros : cons;
      if (target.length >= MAX_POINTS) continue;

      seen.add(sentence);
      target.push({
        text: sentence,
        sentiment,
        sourceChannel: offer.channel,
        sourceUrl: offer.link
      });
    }
  }

  const weightedRating = weightedAverage(offers);
  const reviewCountSum =
    reviewCounts.length > 0
      ? reviewCounts.reduce((sum, count) => sum + count, 0)
      : null;

  const hasExcerpts = offers.some((offer) => Boolean(offer.reviewExcerpt));
  let unavailableNote: string | null = null;

  if (ratedOffers.length === 0 && !hasExcerpts) {
    unavailableNote =
      "本次检索没有返回公开评分或评论正文。搜索 API 通常只提供商品摘要，本工具不会凭空补写口碑。";
  } else if (pros.length === 0 && cons.length === 0) {
    unavailableNote = hasExcerpts
      ? "虽返回了部分公开片段，但没有可稳定归类的评论正文，因此不生成优缺点。"
      : "本次检索返回了评分，但没有评论正文；优缺点显示为“未获取”，未做推断。";
  }

  return {
    ratedOfferCount: ratedOffers.length,
    weightedRating,
    reviewCountSum,
    pros,
    cons,
    conclusion: buildConclusion({
      weightedRating,
      ratedOfferCount: ratedOffers.length,
      pros,
      cons
    }),
    unavailableNote
  };
}
