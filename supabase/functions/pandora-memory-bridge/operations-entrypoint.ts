
import "jsr:@supabase/functions-js@2.4.5/edge-runtime.d.ts";
import {createClient} from "jsr:@supabase/supabase-js@2.57.2";
import {authorize} from "./workload-auth.ts";
import {createOperationsEndpoint} from "./operations-http.mjs";
const canonical="https://ivmvufhcsezyhczzondn.supabase.co";
if(Deno.env.get("SUPABASE_URL")!==canonical)throw new Error("OPS_MEMORY_PROJECT_DENIED");
const boundedFetch:typeof fetch=(input,init={})=>fetch(input,{...init,redirect:"error",signal:AbortSignal.any([
 ...(init.signal?[init.signal]:[]),AbortSignal.timeout(15000),
])});
const client=createClient(canonical,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"",{
 auth:{persistSession:false,autoRefreshToken:false},global:{fetch:boundedFetch},
});
Deno.serve(createOperationsEndpoint({authorize,client}));
