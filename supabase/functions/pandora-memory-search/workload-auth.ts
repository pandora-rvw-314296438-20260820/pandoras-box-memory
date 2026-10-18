// Single shared authenticator: native Vercel signature and exact registered workload claims.
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from "npm:jose@5.10.0";
const PRINCIPAL_KEY = "pandora-mcpmaster-production";
type JsonRecord = Record<string, unknown>;
type AdminClient = { from: (table: string) => any };
const GLOBAL_JWKS = createRemoteJWKSet(
  new URL("https://oidc.vercel.com/.well-known/jwks"),
);
const issuerJwks = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

type Principal = {
  issuer: string;
  audience: string;
  subject: string;
  owner_id: string;
  project_id: string;
  project_name: string;
  environment: string;
  memory_user_id: string;
  allowed_namespaces: string[];
  scopes: string[];
  is_active: boolean;
};
type AuthorizationResult =
  | { ok: true; principal: Principal }
  | { ok: false; error: Response };

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
};

const respond = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });

const isRecord = (value: unknown): value is JsonRecord =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const errorCode = (error: unknown): string =>
  typeof error === "object" && error !== null && "code" in error
    ? String((error as { code?: unknown }).code ?? "")
    : "";

const workloadToken = (request: Request): string | null => {
  const internal = request.headers.get("x-pandora-vercel-oidc")?.trim();
  if (internal) return internal;
  const authorization = request.headers.get("authorization") ?? "";
  const [scheme, token] = authorization.split(" ");
  return scheme?.toLowerCase() === "bearer" && token ? token : null;
};

const exactAudience = (payload: JWTPayload): string | undefined =>
  Array.isArray(payload.aud) ? payload.aud[0] : payload.aud;

const jwksForIssuer = (issuer: string) => {
  const url = new URL(issuer);
  if (
    url.protocol !== "https:" ||
    url.hostname !== "oidc.vercel.com" ||
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    !/^\/[A-Za-z0-9_-]+$/.test(url.pathname)
  ) {
    throw new Error("principal_issuer_invalid");
  }
  const normalized = url.toString().replace(/\/$/, "");
  let jwks = issuerJwks.get(normalized);
  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(`${normalized}/.well-known/jwks`));
    issuerJwks.set(normalized, jwks);
  }
  return jwks;
};

const mayRetryGlobal = (error: unknown): boolean => {
  const code = errorCode(error);
  return code === "ERR_JWS_SIGNATURE_VERIFICATION_FAILED" ||
    code === "ERR_JWKS_NO_MATCHING_KEY" ||
    code.startsWith("ERR_JWKS");
};

const verificationFailure = (error: unknown): Response => {
  const code = errorCode(error);
  if (code.startsWith("ERR_JWKS")) {
    return respond({ ok: false, error: "identity_key_unavailable" }, 502);
  }
  if (code === "ERR_JWT_CLAIM_VALIDATION_FAILED") {
    return respond({ ok: false, error: "identity_claim_invalid" }, 403);
  }
  if (code === "ERR_JWT_EXPIRED") {
    return respond({ ok: false, error: "identity_expired" }, 401);
  }
  if (code === "ERR_JWS_SIGNATURE_VERIFICATION_FAILED") {
    return respond({ ok: false, error: "identity_signature_invalid" }, 498);
  }
  if (code === "ERR_JOSE_NOT_SUPPORTED") {
    return respond({ ok: false, error: "identity_algorithm_unsupported" }, 501);
  }
  return respond({ ok: false, error: "invalid_identity" }, 499);
};

const verifyVercelToken = async (token: string, principal: Principal) => {
  const options = {
    issuer: principal.issuer,
    audience: principal.audience,
    subject: principal.subject,
    clockTolerance: 30,
    algorithms: ["RS256"],
    requiredClaims: ["exp", "iat", "iss", "aud", "sub"],
  };
  try {
    return await jwtVerify(token, jwksForIssuer(principal.issuer), options);
  } catch (error) {
    if (!mayRetryGlobal(error)) throw error;
    return await jwtVerify(token, GLOBAL_JWKS, options);
  }
};

export const authorize = async (
  request: Request,
  supabase: AdminClient,
): Promise<AuthorizationResult> => {
  const token = workloadToken(request);
  if (!token) {
    return { ok: false, error: respond({ ok: false, error: "unauthorized" }, 401) };
  }

  const { data, error } = await supabase
    .from("pandora_service_principals")
    .select(
      "issuer,audience,subject,owner_id,project_id,project_name,environment,memory_user_id,allowed_namespaces,scopes,is_active",
    )
    .eq("principal_key", PRINCIPAL_KEY)
    .eq("is_active", true)
    .maybeSingle();

  if (error || !data) {
    return {
      ok: false,
      error: respond({ ok: false, error: "principal_unavailable" }, 503),
    };
  }
  const principal = data as Principal;

  try {
    const { payload } = await verifyVercelToken(token, principal);
    const matches =
      payload.owner_id === principal.owner_id &&
      payload.project_id === principal.project_id &&
      payload.project === principal.project_name &&
      payload.environment === principal.environment &&
      payload.iss === principal.issuer &&
      exactAudience(payload) === principal.audience &&
      payload.sub === principal.subject;
    if (!matches) {
      return {
        ok: false,
        error: respond({ ok: false, error: "identity_not_allowed" }, 403),
      };
    }
  } catch (error) {
    return { ok: false, error: verificationFailure(error) };
  }
  return { ok: true, principal };
};

