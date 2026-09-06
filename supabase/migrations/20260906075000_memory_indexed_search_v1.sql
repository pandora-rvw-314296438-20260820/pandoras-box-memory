-- Indexed, bounded generic Memory search v1.
-- Generic search may return hard/soft canon for discovery, but it is explicitly
-- search-only. ProjectOS decision authority remains the approved hard-canon
-- exact-project ContextPack path.

begin;

create index if not exists memory_items_real_life_search_fts_idx
on public.memory_items
using gin (
  to_tsvector(
    'simple',
    coalesce(title,'') || ' ' || coalesce(body,'')
  )
)
where namespace = 'real_life'
  and is_active = true
  and canon_status in ('hard_canon'::public.canon_status,'soft_canon'::public.canon_status);

create or replace function public.memory_search_scoped_v1(
  p_user_id uuid,
  p_query text,
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
  v_limit integer := least(greatest(coalesce(p_limit,10),1),20);
  v_tsquery tsquery;
begin
  if p_user_id is null or v_query = '' or length(v_query) > 2000 then
    raise exception 'memory_search_invalid_request' using errcode='22023';
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
    and m.namespace = 'real_life'
    and m.is_active = true
    and m.canon_status in ('hard_canon'::public.canon_status,'soft_canon'::public.canon_status)
    and to_tsvector(
      'simple',
      coalesce(m.title,'') || ' ' || coalesce(m.body,'')
    ) @@ v_tsquery
  order by rank desc, m.updated_at desc, m.id
  limit v_limit;
end
$function$;

comment on function public.memory_search_scoped_v1(uuid,text,integer) is
  'Service-only indexed generic Memory discovery. Hard/soft canon may be searched, but results are not decision-authoritative; ProjectOS planning uses approved hard-canon exact-project ContextPack retrieval.';

revoke all on function public.memory_search_scoped_v1(uuid,text,integer)
  from public, anon, authenticated;
grant execute on function public.memory_search_scoped_v1(uuid,text,integer)
  to service_role;

commit;
