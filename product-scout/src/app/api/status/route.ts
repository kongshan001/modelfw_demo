import { NextResponse } from "next/server";

import { getAppStatus } from "@/lib/vision";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json(getAppStatus(), {
    headers: { "Cache-Control": "no-store" }
  });
}
