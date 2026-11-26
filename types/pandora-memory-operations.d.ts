declare module "@/supabase/functions/pandora-memory-bridge/operations-http.mjs" {
  export function createOperationsEndpoint(input: {
    authorize: (request: Request, client: any) => Promise<any>;
    client: any;
  }): (request: Request) => Promise<Response>;
}
