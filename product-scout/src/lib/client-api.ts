import type {
  AppStatus,
  ExtractionResult,
  ProductIdentity,
  SearchPayload
} from "./types";

export interface ApiErrorShape {
  code: string;
  message: string;
  hint?: string;
}

export class ApiError extends Error {
  readonly code: string;
  readonly hint: string | null;

  constructor(error: ApiErrorShape) {
    super(error.message);
    this.name = "ApiError";
    this.code = error.code;
    this.hint = error.hint ?? null;
  }
}

async function readJson(response: Response): Promise<unknown> {
  try {
    return (await response.json()) as unknown;
  } catch {
    return null;
  }
}

function extractError(raw: unknown): ApiErrorShape | null {
  if (!raw || typeof raw !== "object") return null;
  const record = raw as { error?: unknown };
  if (!record.error || typeof record.error !== "object") return null;

  const error = record.error as {
    code?: unknown;
    message?: unknown;
    hint?: unknown;
  };
  if (typeof error.message !== "string") return null;

  return {
    code: typeof error.code === "string" ? error.code : "UNKNOWN",
    message: error.message,
    hint: typeof error.hint === "string" ? error.hint : undefined
  };
}

export async function fetchStatus(): Promise<AppStatus> {
  const response = await fetch("/api/status", { cache: "no-store" });
  const raw = await readJson(response);
  if (!response.ok) {
    throw new ApiError({
      code: "STATUS_FAILED",
      message: "无法读取服务配置状态"
    });
  }
  return raw as AppStatus;
}

export async function requestSearch(
  product: ProductIdentity
): Promise<SearchPayload> {
  const response = await fetch("/api/search", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ product })
  });
  const raw = await readJson(response);
  if (!response.ok) {
    const parsed = extractError(raw);
    throw new ApiError(
      parsed ?? { code: "SEARCH_FAILED", message: "检索失败，请稍后重试" }
    );
  }
  return raw as SearchPayload;
}

export async function requestExtraction(
  imageDataUrl: string
): Promise<ExtractionResult> {
  const response = await fetch("/api/extract", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ imageDataUrl })
  });
  const raw = await readJson(response);
  if (!response.ok) {
    const parsed = extractError(raw);
    throw new ApiError(
      parsed ?? { code: "VISION_FAILED", message: "视觉识别失败，请手动填写" }
    );
  }
  return raw as ExtractionResult;
}
