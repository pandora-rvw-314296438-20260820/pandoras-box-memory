
import {generateKeyPair,exportJWK,SignJWT} from 'npm:jose@5.10.0';
import {authorize} from '../supabase/functions/pandora-memory-bridge/workload-auth.ts';
const pair=await generateKeyPair('RS256');
const key={...await exportJWK(pair.publicKey),kid:'operations-unit-fixture',alg:'RS256',use:'sig'};
const originalFetch=globalThis.fetch;
// Mocked provider JWKS only; JWT signatures are actually generated and verified.
globalThis.fetch=async(input)=>{
 const url=typeof input==='string'?input:input instanceof URL?input.href:input.url;
 if(!['https://oidc.vercel.com/mbanatao/.well-known/jwks','https://oidc.vercel.com/.well-known/jwks'].includes(url))throw new Error('Unexpected test network');
 return Response.json({keys:[key]});
};
const principal={issuer:'https://oidc.vercel.com/mbanatao',audience:'https://vercel.com/mbanatao',
 subject:'owner:mbanatao:project:mcpmaster:environment:production',owner_id:'team_fixture',project_id:'prj_fixture',project_name:'mcpmaster',environment:'production',
 memory_user_id:'0a436417-517f-461f-819f-08f66899cdda',allowed_namespaces:['real_life'],scopes:['memory:read','memory:write'],is_active:true};
const claims=()=>({iss:principal.issuer,aud:principal.audience,sub:principal.subject,owner_id:principal.owner_id,project_id:principal.project_id,
 project:principal.project_name,environment:principal.environment,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+300});
function client(active=true){
 const query={select:(_value:string)=>query,eq:(_k:string,_v:unknown)=>query,maybeSingle:async()=>({data:active?principal:null,error:null})};
 return {from:(table:string)=>{if(table!=='pandora_service_principals')throw new Error('Wrong auth table');return query;}};
}
async function signed(payload:Record<string,unknown>,privateKey=pair.privateKey){return new SignJWT(payload).setProtectedHeader({alg:'RS256',kid:key.kid}).sign(privateKey);}
async function verify(payload:Record<string,unknown>){const token=await signed(payload);return authorize(new Request('https://memory.invalid',{headers:{'x-pandora-vercel-oidc':token}}),client());}
Deno.test('actual RS256 verification accepts exact registered workload',async()=>{const r=await verify(claims());if(!r.ok||r.principal.project_id!==principal.project_id)throw new Error('Valid fixture rejected');});
for(const field of ['iss','aud','sub','owner_id','project_id','project','environment'])Deno.test(`actual verifier rejects changed ${field}`,async()=>{
 const r=await verify({...claims(),[field]:'wrong'});if(r.ok)throw new Error('Wrong claim accepted');
});
Deno.test('expired signed token fails actual cryptographic JWT validation',async()=>{const r=await verify({...claims(),exp:Math.floor(Date.now()/1000)-120});if(r.ok)throw new Error('Expired token accepted');});
Deno.test('signed token without expiry is denied',async()=>{const p:Record<string,unknown>=claims();delete p.exp;const r=await verify(p);if(r.ok)throw new Error('Unbounded identity accepted');});
Deno.test('wrong signing key is denied even with exact registered claims',async()=>{
 const other=await generateKeyPair('RS256');const token=await signed(claims(),other.privateKey);
 const r=await authorize(new Request('https://memory.invalid',{headers:{'x-pandora-vercel-oidc':token}}),client());if(r.ok)throw new Error('Wrong signature accepted');
});
Deno.test('unsigned claims are not a valid identity',async()=>{const token=btoa(JSON.stringify({alg:'none'}))+'.'+btoa(JSON.stringify(claims()))+'.';const r=await authorize(new Request('https://memory.invalid',{headers:{'x-pandora-vercel-oidc':token}}),client());if(r.ok)throw new Error('Unsigned identity accepted');});
Deno.test('revoked principal denied before identity acceptance',async()=>{const token=await signed(claims());const r=await authorize(new Request('https://memory.invalid',{headers:{'x-pandora-vercel-oidc':token}}),client(false));if(r.ok||r.error.status!==503)throw new Error('Missing active principal accepted');});
Deno.test('missing identity denied before any principal query',async()=>{const r=await authorize(new Request('https://memory.invalid'),{from:()=>{throw new Error('Unexpected database read');}});if(r.ok||r.error.status!==401)throw new Error('Missing identity accepted');});
Deno.test('restore mocked JWKS transport',()=>{globalThis.fetch=originalFetch;});
