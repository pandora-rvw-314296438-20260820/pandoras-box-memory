import "jsr:@supabase/functions-js@2.4.5/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2.57.2";
import { authorize } from "./workload-auth.ts";
import {
  CANONICAL_SUPABASE_URL,
  createSearchEndpoint,
  searchMemory,
} from "./handler.ts";

export { createSearchEndpoint, searchMemory };

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
if (supabaseUrl !== CANONICAL_SUPABASE_URL || !serviceRoleKey) {
  throw new Error("SEARCH_MEMORY_PROJECT_DENIED");
}

const boundedFetch: typeof fetch = (input, init = {}) =>
  fetch(input, {
    ...init,
    redirect: "error",
    signal: AbortSignal.any([
      ...(init.signal ? [init.signal] : []),
      AbortSignal.timeout(15_000),
    ]),
  });

const client = createClient(CANONICAL_SUPABASE_URL, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
  global: { fetch: boundedFetch },
});

Deno.serve(createSearchEndpoint({ authorize, client }));
