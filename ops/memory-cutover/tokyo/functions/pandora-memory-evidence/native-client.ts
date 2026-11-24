
import postgres from "npm:postgres@3.4.7";
const target="https://xyefkykwuppbweabvvmk.supabase.co";
if(Deno.env.get("SUPABASE_URL")!==target) throw new Error("MEMORY_TARGET_DENIED");
const url=Deno.env.get("SUPABASE_DB_URL");
if(!url) throw new Error("MEMORY_DATABASE_UNAVAILABLE");
const sql=postgres(url,{prepare:false,max:2,connect_timeout:5,idle_timeout:10});
export async function run(fn:any) {
 try { const data=await sql.begin(async tx=>{
  await tx`set local role pandora_memory_runtime`;
  await tx`set local statement_timeout='8s'`;
  await tx`set local lock_timeout='3s'`;
  return await fn(tx);
 }); return {data,error:null}; }
 catch(e:any){return {data:null,error:{code:String(e?.code??"DB_UNAVAILABLE"),message:/^OPS_MEMORY_[A-Z0-9_]{1,100}$/.test(e?.message??"")?e.message:"MEMORY_DATABASE_REJECTED"}};}
}
function from(table:string) {
 const filters:Record<string,any>={};
 const query={
 select(_fields:string){return query;},
 eq(key:string,value:any){filters[key]=value;return query;},
 is(key:string,value:any){filters[key]=value;return query;},
 async maybeSingle(){return run(async(tx:any)=>{
 let rows;
 if(table==="pandora_service_principals"&&filters.principal_key==="pandora-mcpmaster-production"&&filters.is_active===true){
 rows=await tx`select issuer,audience,subject,owner_id,project_id,project_name,environment,memory_user_id,allowed_namespaces,scopes,is_active from pandora_memory_native.pandora_service_principals where principal_key='pandora-mcpmaster-production' and is_active limit 2`;
 }else if(table==="pandora_projects"&&filters.lifecycle_status==="active"&&(filters.project_id||filters.id||filters.project_key)){
 rows=await tx`select id,project_key,memory_namespace,lifecycle_status from pandora_memory_native.pandora_projects where memory_namespace=${filters.memory_namespace} and lifecycle_status='active' and (${filters.id??null}::uuid is null or id=${filters.id??null}::uuid) and (${filters.project_key??null}::text is null or project_key=${filters.project_key??null}) limit 2`;
 }else if(table==="pandora_project_grants"&&filters.principal_key==="pandora-mcpmaster-production"&&filters.can_read===true&&filters.is_active===true&&filters.revoked_at===null){
 rows=await tx`select project_id,allowed_record_types from pandora_memory_native.pandora_project_grants where principal_key='pandora-mcpmaster-production' and project_id=${filters.project_id}::uuid and environment=${filters.environment} and is_active and can_read and revoked_at is null limit 2`;
 }else throw new Error("MEMORY_TABLE_DENIED");
 if(rows.length>1)throw new Error("MEMORY_NON_UNIQUE");
 return rows[0]??null;
 });}
 };return query;
}
function rpc(name:string,a:any){return run(async(tx:any)=>{
 if(a.p_principal_key!=="pandora-mcpmaster-production")throw new Error("MEMORY_PRINCIPAL_DENIED");
 if(name==="memory_operations_bridge_v1"){const r=await tx`select pandora_memory_native.memory_operations_bridge_v1(${a.p_operation},${a.p_memory_user_id}::uuid,${a.p_namespace},${a.p_project_id}::uuid,${a.p_principal_key},${a.p_environment},${tx.json(a.p_payload)}::jsonb) as value`;return r[0].value;}
 if(name==="memory_operations_performance_v1"){const r=await tx`select pandora_memory_native.memory_operations_performance_v1(${a.p_memory_user_id}::uuid,${a.p_namespace},${a.p_project_id}::uuid,${a.p_principal_key},${a.p_environment},${tx.json(a.p_request)}::jsonb) as value`;return r[0].value;}
 if(name==="memory_context_pack_v2"){const r=await tx`select pandora_memory_native.memory_context_pack_v2(${a.p_project_id}::uuid,${a.p_principal_key},${a.p_namespace},${a.p_as_of}::timestamptz,${a.p_max_bytes}::int) as value`;return r[0].value;}
 if(name==="memory_task_context_v1"){const r=await tx`select pandora_memory_native.memory_task_context_v1(${a.p_user_id}::uuid,${a.p_namespace},${a.p_project_id}::uuid,${a.p_principal_key},${a.p_environment},${a.p_intent},${a.p_action_mode},${a.p_consequential}::boolean,${tx.array(a.p_terms)}::text[],${tx.array(a.p_required_capabilities)}::text[],${tx.array(a.p_canon_statuses)}::text[],${a.p_max_bytes}::int,${a.p_as_of}::timestamptz) as value`;return r[0].value;}
 if(name==="memory_pandora_search_scoped_v1"){return await tx`select * from pandora_memory_native.memory_pandora_search_scoped_v1(${a.p_user_id}::uuid,${a.p_namespace},${a.p_project_id}::uuid,${a.p_principal_key},${a.p_environment},${tx.array(a.p_terms)}::text[],${tx.array(a.p_canon_statuses)}::text[],${a.p_limit}::int)`;}
 throw new Error("MEMORY_RPC_DENIED");
 });}
export const client={supabaseUrl:target,from,rpc};
