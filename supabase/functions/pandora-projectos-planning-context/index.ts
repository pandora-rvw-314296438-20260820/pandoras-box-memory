import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.9";

const INTEGRATION_KEY = "projectos-learning-bridge";
const PRODUCT_KEY = "projectos";
const PRINCIPAL_KEY = "projectos-mcpmaster-production";
const NAMESPACE = "real_life";
const MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box";
const VISIBLE_ORG_ID = "00000000-0000-0000-0000-000000000001";
const PURPOSE = "projectos-planning-context-v2";
const MAX_BODY = 16 * 1024;
const MAX_QUERY = 2000;
const MAX_ITEMS = 6;
const MAX_SKEW = 5 * 60_000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HASH = /^[0-9a-f]{64}$/i;
const DECISIONS = new Set(["project_spec","build","repair"]);
const CANON = ["hard_canon","soft_canon"];
const STOP = new Set(["and","are","for","from","has","have","its","not","our","that","the","their","them","there","these","this","was","were","what","when","which","with","you","your"]);

type R = Record<string, unknown>;
type Admin = ReturnType<typeof createClient<any>>;
const reply = (status:number, body:R) => new Response(JSON.stringify(body), {status,headers:{"content-type":"application/json; charset=utf-8","cache-control":"no-store","x-content-type-options":"nosniff"}});
const rec = (v:unknown):R => v && typeof v === "object" && !Array.isArray(v) ? v as R : {};
const txt = (v:unknown,n=256):string|null => typeof v === "string" && v.trim() && v.trim().length <= n ? v.trim() : null;
const uid = (v:unknown):string|null => { const x=txt(v,64); return x && UUID.test(x) ? x.toLowerCase() : null; };
const hex = (v:unknown):string|null => { const x=txt(v,64); return x && HASH.test(x) ? x.toLowerCase() : null; };
const compact = (v:unknown,n:number) => (typeof v === "string" ? v.replace(/\s+/g," ").trim() : "").slice(0,n);
const equal = (a:string,b:string) => { if(a.length!==b.length)return false; let d=0; for(let i=0;i<a.length;i++)d|=a.charCodeAt(i)^b.charCodeAt(i); return d===0; };
const sha = async (v:string) => [...new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(v)))].map(x=>x.toString(16).padStart(2,"0")).join("");
const hmac = async (secret:string,v:string) => {
  const e=new TextEncoder(), k=await crypto.subtle.importKey("raw",e.encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
  return [...new Uint8Array(await crypto.subtle.sign("HMAC",k,e.encode(v)))].map(x=>x.toString(16).padStart(2,"0")).join("");
};
const terms = (q:string) => {
  const out=new Set<string>();
  for(const x of q.toLowerCase().replace(/[\\%_,().:'"]/g," ").split(/\s+/)){ if(x.length<3||STOP.has(x))continue; out.add(x.slice(0,64)); if(out.size>=12)break; }
  return [...out];
};
const responseBasis = (x:{requestId:string;organizationId:string;visibleProjectId:string;memoryProjectId:string;projectKey:string;decisionType:string;queryHash:string;retrievalLogId:string;contextStatus:string;packHash:string;highlights:Array<{id:string;memory_type:string;summary:string;updated_at:string}>}) =>
  ["projectos-planning-context-response-v2",x.requestId,x.organizationId,x.visibleProjectId,x.memoryProjectId,x.projectKey,x.decisionType,x.queryHash,x.retrievalLogId,x.contextStatus,x.packHash,x.highlights.map(i=>i.id).join(","),...x.highlights.map(i=>[i.id,i.memory_type,i.summary,i.updated_at].join("|"))].join("\n");

Deno.serve(async (request:Request) => {
  if(request.method!=="POST") return reply(405,{ok:false,error:"method_not_allowed"});
  const len=Number(request.headers.get("content-length")||0);
  if(Number.isFinite(len)&&len>MAX_BODY)return reply(413,{ok:false,error:"payload_too_large"});
  const raw=await request.text();
  if(raw.length>MAX_BODY)return reply(413,{ok:false,error:"payload_too_large"});
  let body:R; try{body=rec(JSON.parse(raw));}catch{return reply(400,{ok:false,error:"invalid_json"});}
  const expected=["schema_version","purpose","request_id","organization_id","visible_project_id","project_key","decision_type","query","query_hash"].sort().join(",");
  if(Object.keys(body).sort().join(",")!==expected || body.schema_version!==2 || body.purpose!==PURPOSE) return reply(400,{ok:false,error:"unsupported_schema"});

  const requestId=uid(body.request_id), organizationId=uid(body.organization_id), visibleProjectId=uid(body.visible_project_id);
  const projectKey=txt(body.project_key,96), decisionType=txt(body.decision_type,32), query=compact(body.query,MAX_QUERY), queryHash=hex(body.query_hash);
  if(!requestId||organizationId!==VISIBLE_ORG_ID||!visibleProjectId||projectKey!==MEMORY_PROJECT_KEY||!decisionType||!DECISIONS.has(decisionType)||!query||!queryHash)
    return reply(400,{ok:false,error:"planning_request_invalid"});
  const expectedQueryHash=await sha(["projectos-planning-query-v2",organizationId,visibleProjectId,projectKey,decisionType,query].join("\n"));
  if(!equal(expectedQueryHash,queryHash))return reply(400,{ok:false,error:"query_hash_mismatch"});

  const timestamp=request.headers.get("x-pandora-timestamp")||"", supplied=request.headers.get("x-pandora-signature")||"", ms=Number(timestamp);
  if(!Number.isFinite(ms)||Math.abs(Date.now()-ms)>MAX_SKEW||!HASH.test(supplied))return reply(401,{ok:false,error:"stale_or_invalid_signature"});

  const url=Deno.env.get("SUPABASE_URL"), role=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!url||!role)return reply(503,{ok:false,error:"service_not_configured"});
  const admin:Admin=createClient(url,role,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:credential,error:credentialError}=await admin.rpc("pandora_integration_credential",{p_integration_key:INTEGRATION_KEY});
  const cr=rec(credential), secret=txt(cr.secret_value,512), memoryUserId=uid(cr.memory_user_id);
  const products=Array.isArray(cr.allowed_product_keys)?cr.allowed_product_keys.filter((v):v is string=>typeof v==="string"):[];
  if(credentialError||!secret||!memoryUserId||cr.is_active!==true||!products.includes(PRODUCT_KEY))return reply(503,{ok:false,error:"bridge_not_configured"});
  const basis=[PURPOSE,requestId,organizationId,visibleProjectId,projectKey,decisionType,queryHash,query].join("\n");
  if(!equal(await hmac(secret,timestamp+"."+basis),supplied.toLowerCase()))return reply(401,{ok:false,error:"invalid_signature"});

  const {data:project,error:projectError}=await admin.from("pandora_projects").select("id,project_key").eq("project_key",projectKey).eq("memory_namespace",NAMESPACE).eq("lifecycle_status","active").maybeSingle();
  const memoryProjectId=uid(project?.id);
  if(projectError||!memoryProjectId||project?.project_key!==projectKey)return reply(403,{ok:false,error:"project_not_allowed"});
  const {data:grant,error:grantError}=await admin.from("pandora_project_grants").select("project_id,allowed_record_types").eq("principal_key",PRINCIPAL_KEY).eq("project_id",memoryProjectId).eq("environment","production").eq("is_active",true).eq("can_read",true).is("revoked_at",null).maybeSingle();
  const allowed=Array.isArray(grant?.allowed_record_types)?grant.allowed_record_types.filter((v):v is string=>typeof v==="string"&&/^[a-z0-9][a-z0-9._-]{0,95}$/.test(v)):[];
  if(grantError||grant?.project_id!==memoryProjectId||allowed.length<1)return reply(403,{ok:false,error:"project_not_allowed"});

  const {data:packRaw,error:packError}=await admin.rpc("memory_context_pack_v2",{p_project_id:memoryProjectId,p_principal_key:PRINCIPAL_KEY,p_namespace:NAMESPACE,p_as_of:new Date().toISOString(),p_max_bytes:12*1024});
  const pack=rec(packRaw), pp=rec(pack.project), pa=rec(pack.authorization), pd=rec(pack.degradation), packHash=hex(pack.contextSha256);
  if(packError||pack.schemaVersion!=="2.0"||pack.status!=="available"||pack.namespace!==NAMESPACE||pp.id!==memoryProjectId||pp.projectKey!==projectKey||pa.principalKey!==PRINCIPAL_KEY||pa.environment!=="production"||pa.canRead!==true||pd.legacyUnscopedPackUsed!==false||!packHash||typeof pack.byteSize!=="number"||pack.byteSize>12*1024)
    return reply(503,{ok:false,error:"context_pack_invalid"});

  let iq=admin.from("memory_items").select("id,title,body,memory_type,updated_at,canon_status,record_type").eq("user_id",memoryUserId).eq("namespace",NAMESPACE).eq("project_id",memoryProjectId).eq("is_active",true).is("superseded_at",null).is("revoked_at",null).in("canon_status",CANON).in("record_type",allowed).order("updated_at",{ascending:false}).limit(MAX_ITEMS);
  const ts=terms(query); if(ts.length)iq=iq.or(ts.flatMap(t=>["title.ilike.%"+t+"%","body.ilike.%"+t+"%"]).join(","));
  const {data:items,error:itemError}=await iq; if(itemError)return reply(503,{ok:false,error:"memory_query_failed"});
  const highlights=(Array.isArray(items)?items:[]).map(rawItem=>{
    const item=rec(rawItem), id=uid(item.id), summary=compact((typeof item.title==="string"?item.title+": ":"")+(typeof item.body==="string"?item.body:""),700);
    return id&&summary&&CANON.includes(String(item.canon_status))?{id,memory_type:compact(item.memory_type,80),summary,updated_at:compact(item.updated_at,64)}:null;
  }).filter((v):v is {id:string;memory_type:string;summary:string;updated_at:string}=>v!==null);
  const itemIds=highlights.map(x=>x.id), contextStatus=highlights.length?"available":"empty";
  const {data:log,error:logError}=await admin.from("memory_retrieval_logs").insert({user_id:memoryUserId,namespace:NAMESPACE,query_hash:queryHash,project_id:memoryProjectId,memory_item_ids:itemIds,metadata:{source:"projectos_planning_hmac_v2",purpose:PURPOSE,visible_project_id:visibleProjectId,project_key:projectKey,decision_type:decisionType,context_pack_sha256:packHash,returned_items:highlights.length,query_persisted:false}}).select("id").maybeSingle();
  const retrievalLogId=uid(log?.id); if(logError||!retrievalLogId)return reply(503,{ok:false,error:"retrieval_log_failed"});
  const contextHash=await sha(responseBasis({requestId,organizationId,visibleProjectId,memoryProjectId,projectKey,decisionType,queryHash,retrievalLogId,contextStatus,packHash,highlights}));
  return reply(200,{ok:true,schema_version:2,purpose:PURPOSE,request_id:requestId,organization_id:organizationId,visible_project_id:visibleProjectId,memory_project_id:memoryProjectId,project_key:projectKey,decision_type:decisionType,query_hash:queryHash,retrieval_log_id:retrievalLogId,context_status:contextStatus,context_pack_sha256:packHash,context_hash:contextHash,approved_memory_item_ids:itemIds,highlights,canonical_memory_written:false});
});
