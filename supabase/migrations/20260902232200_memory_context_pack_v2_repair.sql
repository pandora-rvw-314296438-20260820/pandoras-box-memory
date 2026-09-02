-- Task14/16 production repair: pandora_projects uses canonical_name, not name.
do $repair$
declare
  v_definition text;
begin
  select pg_get_functiondef('public.memory_context_pack_v2(uuid,text,text,timestamp with time zone,integer)'::regprocedure)
    into v_definition;
  if position('v_project.name' in v_definition) = 0 then
    raise exception 'memory_context_pack_v2 expected source defect not found';
  end if;
  v_definition := replace(v_definition, 'v_project.name', 'v_project.canonical_name');
  execute v_definition;
end
$repair$;

comment on function public.memory_context_pack_v2(uuid,text,text,timestamptz,integer) is
  'Tasks14/16 service-only exact-project MemoryContextPack v2. Requires active production can_read grant, uses hard-canon scoped Memory plus exact-project governed negative knowledge/decisions/open loops/conflicts, never uses legacy unscoped packs, redacts credential-shaped text, and enforces <=12KiB output.';
revoke all on function public.memory_context_pack_v2(uuid,text,text,timestamptz,integer) from public, anon, authenticated;
grant execute on function public.memory_context_pack_v2(uuid,text,text,timestamptz,integer) to service_role;
