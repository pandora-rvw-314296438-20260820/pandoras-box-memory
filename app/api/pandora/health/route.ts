import { NextRequest, NextResponse } from "next/server";
import { proxyProjectOSMemoryRequest } from "@/lib/services/projectos-memory-bridge-client";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const response = await proxyProjectOSMemoryRequest(request, { action: "health" });
  if (!response.ok) return response;
  const contentType = response.headers.get("content-type") || "";
  if (!contentType.includes("application/json")) return response;
  const payload = await response.json().catch(() => null);
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return response;
  return NextResponse.json({ ...payload, status: "pandora-connected" }, { status: response.status });
}
