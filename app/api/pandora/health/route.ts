import { NextRequest } from "next/server";
import { proxyPandoraMemoryRequest } from "@/lib/services/pandora-memory-bridge-client";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  return proxyPandoraMemoryRequest(request, { action: "health" });
}
