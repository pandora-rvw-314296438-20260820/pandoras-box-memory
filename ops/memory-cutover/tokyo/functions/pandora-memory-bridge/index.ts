import "jsr:@supabase/functions-js@2.4.5/edge-runtime.d.ts";
import {authorize} from "./workload-auth.ts";
import {client} from "./native-client.ts";
import {createOperationsEndpoint} from "./operations-http.mjs";
Deno.serve(createOperationsEndpoint({authorize,client}));