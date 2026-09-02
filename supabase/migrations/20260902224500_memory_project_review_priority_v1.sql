-- Task 10: exact-project review prioritization without a second review authority.
-- Read-only projection over memory_capture_candidates + memory_review_queue_items.
create or replace function public.memory_project_review_priority_v1(
  p_project_id uuid,
  p_limit integer default 100,
  p_now timestamptz default now()
)
returns table (
  project_id uuid,
  family_key text,
  fingerprint text,
  representative_candidate_id uuid,
  representative_review_item_id uuid,
  representative_source_ref text,
  review_status text,
  candidate_created_at timestamptz,
  age_hours numeric,
  derived_stale_status text,
  duplicate_count bigint,
  candidate_ids uuid[],
  review_item_ids uuid[],
  priority_rank bigint
)
language sql
security definer
set search_path = pg_catalog, public
as $$
  with eligible as (
    select
      c.project_id,
      coalesce(
        nullif(r.source_metadata->>'evidenceKind',''),
        nullif(r.candidate_type,''),
        nullif(c.record_type,''),
        'memory_candidate'
      ) as family_key,
      coalesce(
        nullif(r.fingerprint,''),
        nullif(c.metadata->>'fingerprint',''),
        encode(extensions.digest(convert_to(coalesce(c.source_ref,c.id::text),'utf8'),'sha256'),'hex')
      ) as fingerprint,
      c.id as candidate_id,
      r.id as review_item_id,
      c.source_ref,
      r.status as review_status,
      c.created_at,
      row_number() over (
        partition by
          c.project_id,
          coalesce(nullif(r.source_metadata->>'evidenceKind',''),nullif(r.candidate_type,''),nullif(c.record_type,''),'memory_candidate'),
          coalesce(nullif(r.fingerprint,''),nullif(c.metadata->>'fingerprint',''),encode(extensions.digest(convert_to(coalesce(c.source_ref,c.id::text),'utf8'),'sha256'),'hex'))
        order by c.created_at desc, c.id desc
      ) as representative_order
    from public.memory_capture_candidates c
    join public.memory_review_queue_items r on r.source_ref = c.source_ref
    join public.pandora_projects p on p.id = c.project_id and p.lifecycle_status = 'active'
    where c.project_id = p_project_id
      and c.project_id is not null
      and c.status = 'pending'
      and c.requires_review is true
      and r.status = 'pending_review'
      and r.requires_review is true
      and r.archived_at is null
      and coalesce(r.source_metadata->>'projectId','') = c.project_id::text
  ), grouped as (
    select e.project_id,e.family_key,e.fingerprint,
      (array_agg(e.candidate_id order by e.created_at desc,e.candidate_id desc) filter (where e.representative_order=1))[1] as representative_candidate_id,
      (array_agg(e.review_item_id order by e.created_at desc,e.review_item_id desc) filter (where e.representative_order=1))[1] as representative_review_item_id,
      (array_agg(e.source_ref order by e.created_at desc,e.candidate_id desc) filter (where e.representative_order=1))[1] as representative_source_ref,
      (array_agg(e.review_status order by e.created_at desc,e.candidate_id desc) filter (where e.representative_order=1))[1] as review_status,
      max(e.created_at) as candidate_created_at,
      count(*)::bigint as duplicate_count,
      array_agg(e.candidate_id order by e.created_at desc,e.candidate_id desc) as candidate_ids,
      array_agg(e.review_item_id order by e.created_at desc,e.review_item_id desc) as review_item_ids
    from eligible e group by e.project_id,e.family_key,e.fingerprint
  ), scored as (
    select g.*,
      greatest(0, extract(epoch from (p_now-g.candidate_created_at))/3600.0)::numeric as age_hours,
      case when p_now-g.candidate_created_at >= interval '7 days' then 'stale' when p_now-g.candidate_created_at >= interval '24 hours' then 'aging' else 'fresh' end as derived_stale_status,
      row_number() over (order by case when g.family_key='repeated_failure' then 0 else 1 end,g.duplicate_count desc,g.candidate_created_at asc,g.fingerprint asc) as priority_rank
    from grouped g
  )
  select s.project_id,s.family_key,s.fingerprint,s.representative_candidate_id,s.representative_review_item_id,s.representative_source_ref,s.review_status,s.candidate_created_at,s.age_hours,s.derived_stale_status,s.duplicate_count,s.candidate_ids,s.review_item_ids,s.priority_rank
  from scored s order by s.priority_rank limit greatest(1,least(coalesce(p_limit,100),500));
$$;
comment on function public.memory_project_review_priority_v1(uuid,integer,timestamptz) is 'Task10 read-only exact-project review projection. Groups only identical family+fingerprint items, preserves outcome-transition families separately, derives staleness from timestamps, and exposes member IDs for drill-through.';
revoke all on function public.memory_project_review_priority_v1(uuid,integer,timestamptz) from public, anon, authenticated;
grant execute on function public.memory_project_review_priority_v1(uuid,integer,timestamptz) to service_role;

create or replace function public.memory_project_review_group_members_v1(p_project_id uuid,p_family_key text,p_fingerprint text)
returns table (candidate_id uuid,review_item_id uuid,source_ref text,candidate_created_at timestamptz,review_status text)
language sql security definer set search_path = pg_catalog, public as $$
  select c.id,r.id,c.source_ref,c.created_at,r.status
  from public.memory_capture_candidates c
  join public.memory_review_queue_items r on r.source_ref=c.source_ref
  join public.pandora_projects p on p.id=c.project_id and p.lifecycle_status='active'
  where c.project_id=p_project_id and c.project_id is not null and c.status='pending' and c.requires_review is true and r.status='pending_review' and r.requires_review is true and r.archived_at is null
    and coalesce(r.source_metadata->>'projectId','')=c.project_id::text
    and coalesce(nullif(r.source_metadata->>'evidenceKind',''),nullif(r.candidate_type,''),nullif(c.record_type,''),'memory_candidate')=p_family_key
    and coalesce(nullif(r.fingerprint,''),nullif(c.metadata->>'fingerprint',''),encode(extensions.digest(convert_to(coalesce(c.source_ref,c.id::text),'utf8'),'sha256'),'hex'))=p_fingerprint
  order by c.created_at desc,c.id desc;
$$;
comment on function public.memory_project_review_group_members_v1(uuid,text,text) is 'Task10 exact-project drill-through for one family+fingerprint group. No cross-project or legacy-unscoped fallback.';
revoke all on function public.memory_project_review_group_members_v1(uuid,text,text) from public, anon, authenticated;
grant execute on function public.memory_project_review_group_members_v1(uuid,text,text) to service_role;
