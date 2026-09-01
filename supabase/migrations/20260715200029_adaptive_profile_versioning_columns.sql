-- Adaptive profile versioning columns.
-- Fully additive: no table dropped, no column removed, no row deleted.
--
-- upsertVersionedMemoryProfile records a supersession chain when it refreshes an
-- adaptive profile (mark the previous active version superseded, insert the new active
-- version pointing back at it). The phase_4c memory_profiles table shipped without the
-- two chain columns, so a non-dry profile refresh failed with a PostgREST 400
-- ("column does not exist") on re-runs. These columns close that gap.

alter table public.memory_profiles add column if not exists supersedes_profile_id uuid;
alter table public.memory_profiles add column if not exists superseded_at timestamptz;
create index if not exists memory_profiles_supersedes_idx
  on public.memory_profiles(supersedes_profile_id)
  where supersedes_profile_id is not null;
