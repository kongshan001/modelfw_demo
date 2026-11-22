import { NextResponse } from "next/server";
import { ZodError } from "zod";

import { ProviderError } from "@/lib/providers/http";
import {
  runProductSearch,
  SearchValidationError
} from "@/lib/search-service";
import { searchRequestSchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_SEARCH_BODY_BYTES = 32 * 1024;

interface ErrorBody {
  error: {
    code: string;
    message: string;
    hint?: string;
  };
}

function errorResponse(
  status: number,
  code: string,
  message: string,
  hint?: string
): NextResponse<ErrorBody> {
  return NextResponse.json(
    { error: hint ? { code, message, hint } : { code, message } },
    { status, headers: { "Cache-Control": "no-store" } }
  );
}

export async function POST(request: Request) {
  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (contentLength > MAX_SEARCH_BODY_BYTES) {
    return errorResponse(413, "BODY_TOO_LARGE", "请求体过大");
  }

  let raw: unknown;
  try {
    raw = await request.json();
  } catch {
    return errorResponse(400, "INVALID_JSON", "请求格式不是有效 JSON");
  }

  try {
    const { product } = searchRequestSchema.parse(raw);
    const payload = await runProductSearch(product);

    return NextResponse.json(payload, {
      headers: { "Cache-Control": "no-store" }
    });
  } catch (error) {
    if (error instanceof ZodError) {
      return errorResponse(
        400,
        "VALIDATION_ERROR",
        error.issues[0]?.message ?? "商品字段不完整"
      );
    }
    if (error instanceof SearchValidationError) {
      return errorResponse(400, "VALIDATION_ERROR", error.message);
    }
    if (error instanceof ProviderError) {
      const status =
        error.code === "missing_key"
          ? 400
          : error.code === "rate_limited"
            ? 429
            : 502;
      return errorResponse(
        status,
        error.code.toUpperCase(),
        error.message,
        error.hint ?? undefined
      );
    }

    // Deliberately no request/response dump here: it could contain user data
    // or provider credentials. The message is already user-safe.
    if (error instanceof Error) {
      console.warn("[product-scout] search failed:", error.message);
    }
    return errorResponse(
      502,
      "SEARCH_FAILED",
      "检索暂时失败，请稍后重试或在 .env.local 切回 mock"
    );
  }
}
