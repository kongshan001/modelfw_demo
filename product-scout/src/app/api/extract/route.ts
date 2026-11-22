import { NextResponse } from "next/server";
import { ZodError } from "zod";

import {
  extractProductFromImage,
  VisionError
} from "@/lib/vision";
import { extractRequestSchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_BODY_BYTES = 12 * 1024 * 1024;

function errorResponse(
  status: number,
  code: string,
  message: string
): NextResponse {
  return NextResponse.json(
    { error: { code, message } },
    { status, headers: { "Cache-Control": "no-store" } }
  );
}

export async function POST(request: Request) {
  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (contentLength > MAX_BODY_BYTES) {
    return errorResponse(413, "BODY_TOO_LARGE", "图片过大，最大 8MB");
  }

  let raw: unknown;
  try {
    raw = await request.json();
  } catch {
    return errorResponse(400, "INVALID_JSON", "请求格式不是有效 JSON");
  }

  try {
    const { imageDataUrl } = extractRequestSchema.parse(raw);
    const result = await extractProductFromImage(imageDataUrl);
    return NextResponse.json(result, {
      headers: { "Cache-Control": "no-store" }
    });
  } catch (error) {
    if (error instanceof ZodError) {
      return errorResponse(
        400,
        "VALIDATION_ERROR",
        error.issues[0]?.message ?? "图片格式不受支持"
      );
    }
    if (error instanceof VisionError) {
      const status =
        error.code === "not_configured" || error.code === "invalid_input"
          ? 400
          : 502;
      return errorResponse(status, error.code.toUpperCase(), error.message);
    }

    if (error instanceof Error) {
      console.warn("[product-scout] vision failed:", error.message);
    }
    return errorResponse(502, "VISION_FAILED", "视觉识别失败，请手动填写商品字段");
  }
}
