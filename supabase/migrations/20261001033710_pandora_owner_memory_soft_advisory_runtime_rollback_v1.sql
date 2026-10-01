begin;
do $bridge$
declare
  v_definition text;
  v_from constant text := 'array[''hard_canon'',''soft_canon''],coalesce((p_payload->>''maxBytes'')::integer,12288),clock_timestamp())';
  v_to constant text := 'array[''hard_canon''],coalesce((p_payload->>''maxBytes'')::integer,12288),clock_timestamp())';
begin
  select pg_get_functiondef(p.oid)
    into strict v_definition
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='memory_operations_bridge_v1';

  if strpos(v_definition,v_from)=0 then
    raise exception 'PANDORA_OWNER_MEMORY_SOFT_ADVISORY_ROLLBACK_BASELINE_MISMATCH';
  end if;

  execute replace(v_definition,v_from,v_to);
end
$bridge$;
commit;
