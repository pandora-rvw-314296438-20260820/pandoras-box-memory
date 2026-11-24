
import "jsr:@supabase/functions-js@2.4.5/edge-runtime.d.ts";
import {authorize} from "./workload-auth.ts";
import {client,run} from "./native-client.ts";
import {readBoundedBody} from "./handler.ts";
import {submitEvidenceCandidate} from "./evidence-intake.ts";
import {submitEvidenceCandidate as submitCompatibilityCandidate} from "./compat-evidence-intake.ts";
const reply=(body:unknown,status:number)=>new Response(JSON.stringify(body),{status,headers:{"content-type":"application/json; charset=utf-8","cache-control":"no-store","x-content-type-options":"nosniff"}});
const candidateCols="user_id namespace source source_ref raw_excerpt redacted_excerpt memory_type title summary importance sensitivity confidence should_capture requires_review status reason people projects risks tags metadata usefulness_score confidence_score freshness_score retrieval_weight stale_status scoring_version scored_at".split(" ");
const reviewCols="user_id namespace status candidate_type normalized_text evidence_snapshot sensitivity_snapshot namespace_snapshot source_metadata audit_metadata append_only proposed_operation requires_review source_ref request_hash fingerprint persistence_execution_metadata".split(" ");
function scopedClient(tx:any,p:any,compat:boolean){
 const candidateSource=compat?'projectos-post-task':'pandora-post-task'; const reviewType=compat?'projectos_outcome':'pandora_outcome';
 return {from(table:string){
  const f:Record<string,any>={};let insert:Record<string,any>|null=null;
  const q={select(_s:string){return q;},eq(k:string,v:any){f[k]=v;return q;},is(k:string,v:any){f[k]=v;return q;},insert(v:Record<string,any>){insert=v;return q;},
  async maybeSingle(){let rows:any[];
    if(insert){
      const columns=table==="memory_capture_candidates"?candidateCols:table==="memory_review_queue_items"?reviewCols:null;
      if(!columns||Object.keys(insert).length!==columns.length||!columns.every(k=>Object.hasOwn(insert!,k))||insert.user_id!==p.memory_user_id||!p.allowed_namespaces.includes(insert.namespace)||(table==="memory_capture_candidates"&&insert.source!==candidateSource)||(table==="memory_review_queue_items"&&insert.candidate_type!==reviewType))throw new Error("EVIDENCE_INSERT_DENIED");
      const col=columns.join(",");
      const safeTable=table==="memory_capture_candidates"?"pandora_memory_native.memory_capture_candidates":"pandora_memory_native.memory_review_queue_items";
      rows=await tx.unsafe("insert into "+safeTable+" ("+col+") select "+col+" from jsonb_populate_record(null::"+safeTable+",$1::jsonb) on conflict do nothing returning id",[JSON.stringify(insert)]);
    }else if(table==="pandora_projects"&&f.lifecycle_status==="active"&&(f.id||f.project_key)&&p.allowed_namespaces.includes(f.memory_namespace)){
      rows=await tx`select id,project_key,memory_namespace,lifecycle_status from pandora_memory_native.pandora_projects where memory_namespace=${f.memory_namespace} and lifecycle_status='active' and (${f.id??null}::uuid is null or id=${f.id??null}::uuid) and (${f.project_key??null}::text is null or project_key=${f.project_key??null}) limit 2 for share`;
    }else if(table==="pandora_project_grants"&&f.principal_key==="pandora-mcpmaster-production"&&f.environment===p.environment&&f.can_propose===true&&f.is_active===true&&f.revoked_at===null){
      rows=await tx`select project_id,allowed_record_types from pandora_memory_native.pandora_project_grants where principal_key='pandora-mcpmaster-production' and project_id=${f.project_id}::uuid and environment=${p.environment} and is_active and can_propose and revoked_at is null limit 2 for share`;
    }else if(table==="memory_capture_candidates"&&f.user_id===p.memory_user_id&&p.allowed_namespaces.includes(f.namespace)&&f.source===candidateSource&&typeof f.source_ref==="string"){
      rows=await tx`select id,summary,metadata from pandora_memory_native.memory_capture_candidates where user_id=${p.memory_user_id}::uuid and namespace=${f.namespace} and source=${candidateSource} and source_ref=${f.source_ref} limit 2`;
    }else if(table==="memory_review_queue_items"&&f.user_id===p.memory_user_id&&p.allowed_namespaces.includes(f.namespace)&&f.candidate_type===reviewType&&typeof f.source_ref==="string"){
      rows=await tx`select id from pandora_memory_native.memory_review_queue_items where user_id=${p.memory_user_id}::uuid and namespace=${f.namespace} and candidate_type=${reviewType} and source_ref=${f.source_ref} limit 2`;
    }else throw new Error("EVIDENCE_TABLE_DENIED");
    if(rows.length>1)throw new Error("EVIDENCE_NON_UNIQUE");return {data:rows[0]??null,error:null};
  }};return q;
 }};
}
Deno.serve(async req=>{
 if(req.method!=="POST")return reply({ok:false,error:"method_not_allowed"},405);
 if(req.headers.has("origin")||new URL(req.url).search)return reply({ok:false,error:"origin_not_allowed"},403);
 const token=req.headers.get("x-pandora-vercel-oidc")||req.headers.get("authorization")||"";
 if(token.length<32||token.length>8200)return reply({ok:false,error:"unauthorized"},401);
 try {
  const auth=await authorize(req,client);
  if(!auth.ok)return auth.error;
  const body=await readBoundedBody(req,{maxBytes:16384});
  if(!body.ok)return body.response;
  const compat=body.body.action==="submit_legacy_evidence_candidate";
  if(!compat&&body.body.action!=="submit_evidence_candidate")return reply({ok:false,error:"action_not_allowed"},403);
  const result=await run(async(tx:any)=>{
    const p=auth.principal;
    const current=await tx`select 1 from pandora_memory_native.pandora_service_principals where principal_key='pandora-mcpmaster-production' and is_active and memory_user_id=${p.memory_user_id}::uuid and environment=${p.environment} and issuer=${p.issuer} and audience=${p.audience} and subject=${p.subject} and owner_id=${p.owner_id} and project_id=${p.project_id} and project_name=${p.project_name} and scopes=${tx.array(p.scopes)}::text[] and allowed_namespaces=${tx.array(p.allowed_namespaces)}::text[] and 'memory:write'=any(scopes) for share`;
    if(current.length!==1)return reply({ok:false,error:"scope_not_allowed"},403);
    return await (compat?submitCompatibilityCandidate:submitEvidenceCandidate)({...body.body,action:"submit_evidence_candidate"},p,scopedClient(tx,p,compat));
  });
  return result.error?reply({ok:false,error:"candidate_storage_unavailable"},503):result.data;
 }catch{return reply({ok:false,error:"candidate_storage_unavailable"},503);}
});
