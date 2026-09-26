
import {readBridgeBody,handleOperationsMemory} from './operations-bridge.mjs';
const reply=(body,status)=>new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'}});
/** A deliberately narrow new deployment. The historical native route catalogue is NOT activated. */
export function createOperationsEndpoint({authorize,client}) {
 if(typeof authorize!=='function'||client?.supabaseUrl!=='https://ivmvufhcsezyhczzondn.supabase.co')throw new Error('OPS_MEMORY_CONFIGURATION_DENIED');
 return async request=>{
  if(request.method!=='POST')return reply({ok:false,error:'OPS_MEMORY_METHOD_DENIED'},405);
  if(request.headers.has('origin'))return reply({ok:false,error:'OPS_MEMORY_BROWSER_DENIED'},403);
  const token=request.headers.get('x-pandora-vercel-oidc')||request.headers.get('authorization')||'';
  if(token.length<32||token.length>8200)return reply({ok:false,error:'OPS_MEMORY_IDENTITY_REQUIRED',outcomeUnknown:false},401);
  try {
   // No query can choose a provider, target, project identity or alternate gateway action.
   const url=new URL(request.url);
   if(url.search||url.hash)return reply({ok:false,error:'OPS_MEMORY_ROUTE_DENIED',outcomeUnknown:false},404);
   const authorization=await authorize(request,client);
   if(!authorization.ok)return authorization.error;
   const body=await readBridgeBody(request,{maxBytes:40000});
   if(body.action!=='operations')return reply({ok:false,error:'OPS_MEMORY_OPERATION_DENIED',outcomeUnknown:false},403);
   const result=await handleOperationsMemory(body,authorization.principal,client,{signal:request.signal});
   return reply(result.body,result.status);
  }catch{return reply({ok:false,error:'OPS_MEMORY_REQUEST_UNAVAILABLE',outcomeUnknown:false},503);}
 };
}
