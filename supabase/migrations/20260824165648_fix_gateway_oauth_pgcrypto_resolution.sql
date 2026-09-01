alter function public.gateway_authorize_oauth(uuid, text, text, text, text, text) set search_path = public, auth, extensions, pg_temp;
