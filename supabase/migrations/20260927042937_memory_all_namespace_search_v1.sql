-- Gemini/Pandora Memory all-namespace read search v1.
-- Preserves the existing real_life-only default path and adds a separate,
-- grant-gated RPC for explicitly authorized AU or all-namespace reads.

begin;

create index if not exists memory_items_all_namespace_search_fts_idx
on public.memory_items
using gin (
  to_tsvector(
    'simple',
    coalesce(title,'') || ' ' || coalesce(body,'')
  )
)
where is_active = true
  and canon_status in (
    'hard_canon'::public.canon_status,
    'soft_canon'::public.canon_status
  );

create or replace function public.memory_search_namespaced_v1(
  p_user_id uuid,
  p_query text,
  p_namespace text default null,
  p_limit integer default 10
)
returns table (
  id uuid,
  title text,
  body text,
  namespace text,
  canon_status text,
  confidence numeric,
  source_summary text,
  updated_at timestamptz,
  project_id uuid,
  record_type text,
  rank real
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_query text := btrim(coalesce(p_query,''));
  v_namespace text := nullif(btrim(coalesce(p_namespace,'')), '');
  v_limit integer := least(greatest(coalesce(p_limit,10),1),20);
  v_tsquery tsquery;
begin
  if p_user_id is null or v_query = '' or length(v_query) > 2000 then
    raise exception 'memory_search_invalid_request' using errcode='22023';
  end if;

  if v_namespace is not null and v_namespace not in ('real_life','au') then
    raise exception 'memory_search_namespace_invalid' using errcode='22023';
  end if;

  v_tsquery := plainto_tsquery('simple', v_query);
  if numnode(v_tsquery) = 0 then
    return;
  end if;

  return query
  select
    m.id,
    m.title,
    m.body,
    m.namespace::text,
    m.canon_status::text,
    m.confidence,
    m.source_summary,
    m.updated_at,
    m.project_id,
    m.record_type::text,
    ts_rank_cd(
      to_tsvector('simple', coalesce(m.title,'') || ' ' || coalesce(m.body,'')),
      v_tsquery
    )::real as rank
  from public.memory_items m
  where m.user_id = p_user_id
    and (v_namespace is null or m.namespace::text = v_namespace)
    and m.is_active = true
    and m.canon_status in (
      'hard_canon'::public.canon_status,
      'soft_canon'::public.canon_status
    )
    and to_tsvector(
      'simple',
      coalesce(m.title,'') || ' ' || coalesce(m.body,'')
    ) @@ v_tsquery
  order by rank desc, m.updated_at desc, m.id
  limit v_limit;
end
$function$;

comment on function public.memory_search_namespaced_v1(uuid,text,text,integer) is
  'Service-only bounded canonical Memory discovery across one namespace or all namespaces for an already authorized principal. Results remain search-only and are not decision-authoritative.';

revoke all on function public.memory_search_namespaced_v1(uuid,text,text,integer)
  from public, anon, authenticated;
grant execute on function public.memory_search_namespaced_v1(uuid,text,text,integer)
  to service_role;

commit;
