
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {handleOperationsMemory,readBridgeBody} from '../supabase/functions/pandora-memory-bridge/operations-bridge.mjs';
const requestId='33e5b2de-048b-4814-b601-7d7daac7a649';
const projectId='7c686cbd-d968-49d5-86cc-918f5e777bd2';
const userId='0a436417-517f-461f-819f-08f66899cdda';
const principal=()=>({is_active:true,project_name:'mcpmaster',environment:'production',memory_user_id:userId,allowed_namespaces:['real_life'],scopes:['memory:read','memory:write']});
const body=(operation='context')=>({action:'operations',operation,requestId,projectId,namespace:'real_life',payload:{}});
function client(run=async()=>({data:{kind:'fixture'},error:null})) {
 const calls=[];return {calls,supabaseUrl:'https://ivmvufhcsezyhczzondn.supabase.co',rpc(name,args){calls.push({name,args});return run(name,args);}};
}
for(const operation of ['context','performance','propose_outcome','readback']) test(`authenticated ${operation} uses one fixed native RPC and server identity`,async()=>{
 const c=client();const output=await handleOperationsMemory(body(operation),principal(),c);
 assert.equal(output.status,200);assert.equal(output.body.requestId,requestId);assert.equal(output.body.operation,operation);
 assert.equal(c.calls.length,1);const call=c.calls[0];
 assert.equal(call.name,operation==='performance'?'memory_operations_performance_v1':'memory_operations_bridge_v1');
 assert.equal(call.args.p_principal_key,'pandora-mcpmaster-production');assert.equal(call.args.p_memory_user_id,userId);
 assert.equal(call.args.p_namespace,'real_life');assert.equal(call.args.p_environment,'production');assert.equal(call.args.p_project_id,projectId);
 assert.equal(Object.hasOwn(call.args,'p_operation'),operation!=='performance');
});
for(const [name,patch] of [ ['inactive',{is_active:false}],['wrong workload',{project_name:'enterprise'}],['preview',{environment:'preview'}],['wrong namespace',{allowed_namespaces:['au']}],['missing user',{memory_user_id:null}],['missing scopes',{scopes:[]}]] ) test(`denies ${name} before RPC`,async()=>{
 const c=client(),result=await handleOperationsMemory(body(),{...principal(),...patch},c);
 assert.equal(result.status,403);assert.equal(c.calls.length,0);
});
for(const operation of ['propose_outcome','readback']) test(`${operation} cannot use read-only service scope`,async()=>{
 const c=client(),p=principal();p.scopes=['memory:read'];const r=await handleOperationsMemory(body(operation),p,c);
 assert.equal(r.status,403);assert.equal(c.calls.length,0);
});
for(const [name,patch] of [['principal injection',{principalKey:'another-principal'}],['user injection',{memoryUserId:userId}],['SQL injection',{sql:'select 1'}],['cross namespace',{namespace:'au'}],['bad project',{projectId:'invalid'}],['unknown action',{action:'promote'}],['unknown operation',{operation:'approve'}],['non-object payload',{payload:[]}],['missing nonce',{requestId:null}]] ) test(`rejects ${name}`,async()=>{
 const c=client(),r=await handleOperationsMemory({...body(),...patch},principal(),c);assert.equal(r.status,400);assert.equal(c.calls.length,0);
});
test('native grant denial is retained rather than converted to success or synthetic data',async()=>{
 const c=client(async()=>({error:{code:'42501',message:'OPS_MEMORY_GRANT_DENIED'}}));const r=await handleOperationsMemory(body('performance'),principal(),c);
 assert.equal(r.status,403);assert.equal(r.body.error,'OPS_MEMORY_GRANT_DENIED');assert.equal(r.body.outcomeUnknown,false);assert.equal(c.calls.length,1);
});
test('definite native mutation rejection is not an uncertain mutation',async()=>{
 const c=client(async()=>({error:{code:'22023',message:'OPS_MEMORY_REPLAY_CONFLICT'}}));const r=await handleOperationsMemory(body('propose_outcome'),principal(),c);
 assert.equal(r.status,400);assert.equal(r.body.outcomeUnknown,false);assert.equal(c.calls.length,1);
});
test('unknown transport mutation is retained with no retry and sanitized error',async()=>{
 const c=client(async()=>{throw new Error('private provider detail');});const r=await handleOperationsMemory(body('propose_outcome'),principal(),c);
 assert.equal(r.status,503);assert.equal(r.body.outcomeUnknown,true);assert.equal(c.calls.length,1);assert.doesNotMatch(JSON.stringify(r),/private provider detail/);
});
test('read failure never claims a mutation happened',async()=>{
 const c=client(async()=>{throw new Error('down');});const r=await handleOperationsMemory(body(),principal(),c);assert.equal(r.body.outcomeUnknown,false);
});
test('unknown native database error is not retried or leaked',async()=>{
 const c=client(async()=>({error:{code:'08006',message:'internal connection secret'}}));const r=await handleOperationsMemory(body('propose_outcome'),principal(),c);
 assert.equal(r.status,502);assert.equal(r.body.outcomeUnknown,true);assert.equal(c.calls.length,1);assert.doesNotMatch(JSON.stringify(r),/connection secret/);
});
test('timeout terminates wait and leaves mutation outcome unknown',async()=>{
 const c=client(()=>new Promise(()=>{}));const r=await handleOperationsMemory(body('propose_outcome'),principal(),c,{timeoutMs:10});
 assert.equal(r.status,503);assert.equal(r.body.outcomeUnknown,true);assert.equal(c.calls.length,1);
});
test('already cancelled request cannot issue an RPC',async()=>{
 const c=client();const r=await handleOperationsMemory(body('propose_outcome'),principal(),c,{signal:AbortSignal.abort()});assert.equal(r.status,409);assert.equal(r.body.outcomeUnknown,false);assert.equal(c.calls.length,0);
});
test('cancellation is propagated to native RPC abort signal',async()=>{
 let aborted=false;const c=client(()=>({abortSignal(signal){signal.addEventListener('abort',()=>{aborted=true;});return new Promise(()=>{});}}));
 const controller=new AbortController();const pending=handleOperationsMemory(body('propose_outcome'),principal(),c,{signal:controller.signal});controller.abort();const r=await pending;
 assert.equal(aborted,true);assert.equal(r.body.outcomeUnknown,true);assert.equal(c.calls.length,1);
});
for(const data of [null,[],{unsafe:'x'.repeat(41000)}]) test(`unreadable or oversized reply is not mutation acceptance: ${Array.isArray(data)?'array':data===null?'null':'oversize'}`,async()=>{
 const r=await handleOperationsMemory(body('propose_outcome'),principal(),client(async()=>({data})));assert.equal(r.status,503);assert.equal(r.body.outcomeUnknown,true);
});
test('rejects noncanonical database client before request',async()=>{
 const c=client();c.supabaseUrl='https://example.invalid';const r=await handleOperationsMemory(body(),principal(),c);assert.equal(r.status,400);assert.equal(c.calls.length,0);
});
test('body size is bounded before RPC',async()=>{
 const c=client(),b=body();b.payload={x:'x'.repeat(40000)};const r=await handleOperationsMemory(b,principal(),c);assert.equal(r.status,400);assert.equal(c.calls.length,0);
});
test('bounded body reader decodes literal JSON with multibyte content',async()=>{
 const b={action:'search',query:'Verified café'};const r=new Request('https://example.invalid',{method:'POST',body:JSON.stringify(b)});assert.deepEqual(await readBridgeBody(r),b);
});
for(const value of ['null','[]','{bad json']) test(`body reader rejects ${value}`,async()=>{
 await assert.rejects(readBridgeBody(new Request('https://example.invalid',{method:'POST',body:value})));
});
test('body reader rejects oversized content-length without reading',async()=>{
 const r=new Request('https://example.invalid',{method:'POST',headers:{'content-length':'99999'},body:'{}'});await assert.rejects(readBridgeBody(r),/BODY_LIMIT/);
});
test('chunked response without declared length remains bounded',async()=>{
 const r=new Request('https://example.invalid',{method:'POST',body:'{"text":"'+ 'x'.repeat(100)+'"}'});await assert.rejects(readBridgeBody(r,{maxBytes:64}),/BODY_LIMIT/);
});
test('a stalled body does not hold the invocation indefinitely',async()=>{
 const stream=new ReadableStream({start(){}});const r=new Request('https://example.invalid',{method:'POST',body:stream,duplex:'half'});
 await assert.rejects(readBridgeBody(r,{timeoutMs:10}),/READ_TIMEOUT/);
});
test('native entrypoint authenticates before operations delegation and keeps existing routes',async()=>{
 const text=await readFile(new URL('../supabase/functions/pandora-memory-bridge/index.ts',import.meta.url),'utf8');
 const boundary=text.indexOf('Deno.serve('),auth=text.indexOf('if (!authorization.ok) return authorization.error;',boundary),delegate=text.indexOf('await handleOperationsMemory(',boundary);
 assert.ok(boundary>=0&&auth>boundary&&delegate>auth);assert.ok(text.includes('authorization.principal, supabase, { signal: request.signal }'));
 for(const action of ['health','search','submit_evidence_candidate','record_decision_influence','record_decision_outcome']) assert.ok(text.includes(`body.action === "${action}"`));
 assert.ok(text.includes('await readBridgeBody(request)'));const shared=await readFile(new URL('../supabase/functions/pandora-memory-bridge/workload-auth.ts',import.meta.url),'utf8');assert.ok(shared.includes('payload.owner_id === principal.owner_id'));assert.ok(shared.includes('payload.project_id === principal.project_id'));
});

for(const method of ['GET','PUT','DELETE','OPTIONS'])test(`narrow deployed handler refuses ${method}`,async()=>{
 const {createOperationsEndpoint}=await import('../supabase/functions/pandora-memory-bridge/operations-http.mjs');
 const h=createOperationsEndpoint({authorize:()=>assert.fail('auth should not run'),client:client()});
 assert.equal((await h(new Request('https://memory.invalid',{method}))).status,405);
});
test('narrow endpoint refuses browser origin and missing workload identity before native calls',async()=>{
 const {createOperationsEndpoint}=await import('../supabase/functions/pandora-memory-bridge/operations-http.mjs');const h=createOperationsEndpoint({authorize:()=>assert.fail(),client:client()});
 assert.equal((await h(new Request('https://memory.invalid',{method:'POST',headers:{origin:'https://mcpmaster.vercel.app'}}))).status,403);
 assert.equal((await h(new Request('https://memory.invalid',{method:'POST'}))).status,401);
});
for(const action of ['search','health','submit_evidence_candidate','approve','record_decision_outcome'])test(`new deployment does not activate historical ${action} route`,async()=>{
 const {createOperationsEndpoint}=await import('../supabase/functions/pandora-memory-bridge/operations-http.mjs');const c=client(()=>assert.fail());
 const h=createOperationsEndpoint({authorize:async()=>({ok:true,principal:principal()}),client:c});
 const r=await h(new Request('https://memory.invalid',{method:'POST',headers:{'x-pandora-vercel-oidc':'fixture'.repeat(10)},body:JSON.stringify({action})}));assert.equal(r.status,403);assert.equal(c.calls.length,0);
});
test('new entrypoint is bound to narrow handler and shared authentication, not historical main',async()=>{
 const text=await readFile(new URL('../supabase/functions/pandora-memory-bridge/operations-entrypoint.ts',import.meta.url),'utf8');
 const cfg=await readFile(new URL('../supabase/config.toml',import.meta.url),'utf8');
 assert.ok(text.includes('createOperationsEndpoint({authorize,client})'));assert.ok(text.includes('./workload-auth.ts'));assert.ok(!text.includes('./index.ts'));
 assert.ok(cfg.includes('operations-entrypoint.ts'));assert.ok(text.includes('supabase-js@2.57.2'));
});
test('narrow authenticated handler preserves native write uncertainty',async()=>{
 const {createOperationsEndpoint}=await import('../supabase/functions/pandora-memory-bridge/operations-http.mjs');const c=client(async()=>{throw new Error('lost response');});
 const h=createOperationsEndpoint({authorize:async()=>({ok:true,principal:principal()}),client:c});
 const r=await h(new Request('https://memory.invalid',{method:'POST',headers:{'x-pandora-vercel-oidc':'fixture'.repeat(10)},body:JSON.stringify(body('propose_outcome'))}));
 assert.equal(r.status,503);assert.equal((await r.json()).outcomeUnknown,true);assert.equal(c.calls.length,1);
});
