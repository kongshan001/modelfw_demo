import { z } from "zod";

import { getVisionConfig, MAX_UPLOAD_BYTES } from "./config";
import type {
  AppStatus,
  ExtractionResult,
  FieldEvidence,
  ProductIdentity
} from "./types";
import { getAllSearchProviders, getSearchProvider } from "./providers";
import { imageDataUrlSchema, normalizeProduct } from "./validation";

export class VisionError extends Error {
  readonly code:
    | "not_configured"
    | "invalid_input"
    | "upstream_error"
    | "invalid_response";

  constructor(
    message: string,
    code: VisionError["code"]
  ) {
    super(message);
    this.name = "VisionError";
    this.code = code;
  }
}

export function getAppStatus(): AppStatus {
  const provider = getSearchProvider();
  const vision = getVisionConfig();

  const searchStatus = {
    id: provider.id,
    label: provider.label,
    mode: provider.mode,
    configured: provider.isConfigured(),
    missingEnv: provider.missingEnv(),
    hint: provider.hint
  };

  const visionConfigured =
    vision.provider === "demo" || Boolean(vision.apiKey);

  return {
    search: searchStatus,
    vision: {
      id: vision.provider,
      label:
        vision.provider === "demo"
          ? "Demo 演示识别"
          : "OpenAI 兼容视觉模型",
      mode: vision.provider === "demo" ? "demo" : "live",
      configured: visionConfigured,
      missingEnv:
        vision.provider === "demo" ? [] : vision.missingEnv,
      hint:
        vision.provider === "demo"
          ? "默认不调用视觉 API；识别结果来自内置样例并明确标注。"
          : "截图会以 base64 发送到你配置的视觉 API，只用于本次识别，不写入磁盘。"
    },
    demo: provider.mode === "demo" || vision.provider === "demo",
    maxUploadMb: 8,
    providerOptions: getAllSearchProviders().map((entry) => ({
      id: entry.id,
      label: entry.label,
      mode: entry.mode,
      configured: entry.isConfigured()
    }))
  };
}

const fieldSchema = z.union([z.string(), z.array(z.string())]).optional();

const visionOutputSchema = z
  .object({
    brand: fieldSchema,
    model: fieldSchema,
    category: fieldSchema,
    specs: fieldSchema,
    confidence: z
      .object({
        brand: z.number().optional(),
        model: z.number().optional(),
        category: z.number().optional(),
        specs: z.number().optional()
      })
      .partial()
      .optional()
  })
  .passthrough();

type VisionFields = z.infer<typeof visionOutputSchema>;

function toText(value: string | string[] | undefined): string {
  if (Array.isArray(value)) return value.join("、");
  return value?.trim() ?? "";
}

function clampConfidence(value: number | undefined, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(1, Math.max(0, value));
}

function parseModelJson(content: string): unknown {
  const trimmed = content.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced?.[1]?.trim() ?? trimmed;
  const start = candidate.indexOf("{");
  const end = candidate.lastIndexOf("}");
  if (start === -1 || end <= start) {
    throw new VisionError("视觉模型没有返回 JSON", "invalid_response");
  }
  try {
    return JSON.parse(candidate.slice(start, end + 1)) as unknown;
  } catch {
    throw new VisionError("视觉模型返回的 JSON 无法解析", "invalid_response");
  }
}

function buildExtraction(data: VisionFields): ExtractionResult {
  const product: ProductIdentity = normalizeProduct({
    brand: toText(data.brand),
    model: toText(data.model),
    category: toText(data.category),
    specs: toText(data.specs)
  });

  if (!product.brand && !product.model) {
    throw new VisionError(
      "视觉模型未能识别出品牌或型号，请手动填写",
      "invalid_response"
    );
  }

  const confidence = data.confidence ?? {};
  const fields: Record<keyof ProductIdentity, FieldEvidence> = {
    brand: { confidence: clampConfidence(confidence.brand, 0.6), source: "vision" },
    model: { confidence: clampConfidence(confidence.model, 0.6), source: "vision" },
    category: {
      confidence: clampConfidence(confidence.category, 0.5),
      source: "vision"
    },
    specs: { confidence: clampConfidence(confidence.specs, 0.5), source: "vision" }
  };

  return {
    product,
    fields,
    mode: "vision",
    notice:
      "已由视觉模型提取字段，请核对品牌与型号后再检索。图片仅用于本次请求，服务端不持久化。"
  };
}

const VISION_PROMPT = `你是商品信息提取器。请从这张商品截图里提取以下字段，只输出一个 JSON 对象，不要输出 Markdown 或解释：
{
  "brand": "品牌名，没有则为空字符串",
  "model": "型号或 SKU，没有则为空字符串",
  "category": "品类，例如 头戴式降噪耳机",
  "specs": "关键规格，用中文顿号连接，最多 60 字",
  "confidence": { "brand": 0到1的小数, "model": 0到1的小数, "category": 0到1的小数, "specs": 0到1的小数 }
}
不要猜测看不清的内容；价格、评分、评论不要提取。`;

interface ChatCompletionResponse {
  choices?: Array<{
    message?: {
      content?: unknown;
    };
  }>;
}

export async function extractProductFromImage(
  imageDataUrl: string
): Promise<ExtractionResult> {
  const input = imageDataUrlSchema.safeParse(imageDataUrl);
  if (!input.success) {
    throw new VisionError(
      input.error.issues[0]?.message ?? "图片格式不受支持",
      "invalid_input"
    );
  }

  const base64 = imageDataUrl.split(",", 2)[1] ?? "";
  const bytes = Buffer.from(base64, "base64").byteLength;
  if (bytes > MAX_UPLOAD_BYTES) {
    throw new VisionError("图片超过 8MB，请压缩后重试", "invalid_input");
  }

  const config = getVisionConfig();
  if (config.provider !== "openai") {
    throw new VisionError(
      "当前是 Demo 识别模式，不会调用视觉 API。请使用示例，或设置 VISION_PROVIDER=openai。",
      "not_configured"
    );
  }
  if (!config.apiKey) {
    throw new VisionError(
      "缺少 VISION_API_KEY。请在 .env.local 配置视觉 API，或手动填写商品字段。",
      "not_configured"
    );
  }

  let endpoint: URL;
  try {
    endpoint = new URL(
      `${config.baseUrl.replace(/\/+$/, "")}/chat/completions`
    );
  } catch {
    throw new VisionError("VISION_BASE_URL 不是有效 URL", "not_configured");
  }
  if (endpoint.protocol !== "https:" && endpoint.protocol !== "http:") {
    throw new VisionError("VISION_BASE_URL 必须使用 http(s)", "not_configured");
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      cache: "no-store",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${config.apiKey}`
      },
      body: JSON.stringify({
        model: config.model,
        temperature: 0.1,
        max_tokens: 700,
        messages: [
          {
            role: "user",
            content: [
              { type: "text", text: VISION_PROMPT },
              { type: "image_url", image_url: { url: imageDataUrl } }
            ]
          }
        ]
      })
    });

    if (!response.ok) {
      throw new VisionError(
        `视觉 API 请求失败（HTTP ${response.status}）`,
        "upstream_error"
      );
    }

    const payload = (await response.json()) as ChatCompletionResponse;
    const content = payload.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) {
      throw new VisionError("视觉 API 没有返回可用内容", "invalid_response");
    }

    const parsed = visionOutputSchema.safeParse(parseModelJson(content));
    if (!parsed.success) {
      throw new VisionError(
        "视觉 API 返回的字段不符合预期，请手动填写",
        "invalid_response"
      );
    }

    return buildExtraction(parsed.data);
  } catch (error) {
    if (error instanceof VisionError) throw error;
    if (error instanceof Error && error.name === "AbortError") {
      throw new VisionError("视觉 API 请求超时，请稍后重试", "upstream_error");
    }
    throw new VisionError("视觉 API 调用失败，请稍后重试", "upstream_error");
  } finally {
    clearTimeout(timeout);
  }
}
