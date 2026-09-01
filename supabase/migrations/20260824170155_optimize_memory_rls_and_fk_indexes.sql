alter policy "memory_capture_candidates_user_scoped" on public.memory_capture_candidates to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "memory_embeddings_user_scoped" on public.memory_embeddings to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "memory_feedback_events_user_scoped" on public.memory_feedback_events to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "memory_open_loops_user_scoped" on public.memory_open_loops to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "memory_profiles_user_scoped" on public.memory_profiles to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "memory_pruning_candidates_user_scoped" on public.memory_pruning_candidates to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "memory_session_digests_user_scoped" on public.memory_session_digests to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "memory_context_packs_authenticated_insert_own_namespace" on public.memory_context_packs to authenticated with check (((select auth.uid()) = user_id) and (namespace = any (array['real_life'::public.pandora_namespace, 'au'::public.pandora_namespace])));
alter policy "memory_context_packs_authenticated_select_own_namespace" on public.memory_context_packs to authenticated using (((select auth.uid()) = user_id) and (namespace = any (array['real_life'::public.pandora_namespace, 'au'::public.pandora_namespace])));
alter policy "memory_context_packs_authenticated_update_own_namespace" on public.memory_context_packs to authenticated using ((select auth.uid()) = user_id) with check (((select auth.uid()) = user_id) and (namespace = any (array['real_life'::public.pandora_namespace, 'au'::public.pandora_namespace])));

alter policy "memory_events_authenticated_insert_own_namespace" on public.memory_events to authenticated with check (((select auth.uid()) = user_id) and ((select auth.uid()) = created_by) and (namespace = any (array['real_life'::public.pandora_namespace, 'au'::public.pandora_namespace])));
alter policy "memory_events_authenticated_select_own_namespace" on public.memory_events to authenticated using (((select auth.uid()) = user_id) and (namespace = any (array['real_life'::public.pandora_namespace, 'au'::public.pandora_namespace])));
alter policy "memory_events_authenticated_update_own_namespace" on public.memory_events to authenticated using ((select auth.uid()) = user_id) with check (((select auth.uid()) = user_id) and (namespace = any (array['real_life'::public.pandora_namespace, 'au'::public.pandora_namespace])));

alter policy "memory_items_insert_own" on public.memory_items to authenticated with check ((select auth.uid()) = user_id);
alter policy "memory_items_select_own" on public.memory_items to authenticated using ((select auth.uid()) = user_id);
alter policy "memory_patches_insert_own" on public.memory_patches to authenticated with check ((select auth.uid()) = user_id);
alter policy "memory_patches_select_own" on public.memory_patches to authenticated using ((select auth.uid()) = user_id);

alter policy "memory_proposals_authenticated_insert_own_namespace" on public.memory_proposals to authenticated with check (((select auth.uid()) = user_id) and ((select auth.uid()) = proposed_by) and (status = 'pending'::text) and (reviewed_by is null) and (persisted_memory_id is null));
alter policy "memory_proposals_authenticated_select_own_namespace" on public.memory_proposals to authenticated using (((select auth.uid()) = user_id) and (namespace = any (array['real_life'::public.pandora_namespace, 'au'::public.pandora_namespace])));
alter policy "memory_proposals_authenticated_update_own_namespace" on public.memory_proposals to authenticated using ((select auth.uid()) = user_id) with check (((select auth.uid()) = user_id) and (namespace = any (array['real_life'::public.pandora_namespace, 'au'::public.pandora_namespace])));

alter policy "memory_review_queue_decisions_insert_own_item" on public.memory_review_queue_decisions to authenticated with check ((user_id = (select auth.uid())) and exists (select 1 from public.memory_review_queue_items item where item.id = memory_review_queue_decisions.review_item_id and item.user_id = (select auth.uid()) and item.namespace = memory_review_queue_decisions.namespace));
alter policy "memory_review_queue_decisions_select_own" on public.memory_review_queue_decisions to authenticated using (user_id = (select auth.uid()));
alter policy "memory_review_queue_items_insert_own" on public.memory_review_queue_items to authenticated with check (user_id = (select auth.uid()));
alter policy "memory_review_queue_items_select_own" on public.memory_review_queue_items to authenticated using (user_id = (select auth.uid()));
alter policy "memory_sources_insert_own" on public.memory_sources to authenticated with check ((select auth.uid()) = user_id);
alter policy "memory_sources_select_own" on public.memory_sources to authenticated using ((select auth.uid()) = user_id);

create index if not exists pandora_integration_credentials_memory_user_id_idx on private.pandora_integration_credentials(memory_user_id);
create index if not exists memory_events_created_by_idx on public.memory_events(created_by);
create index if not exists memory_items_superseded_by_idx on public.memory_items(superseded_by);
create index if not exists memory_patches_memory_item_id_idx on public.memory_patches(memory_item_id);
create index if not exists memory_proposals_persisted_memory_id_idx on public.memory_proposals(persisted_memory_id);
create index if not exists memory_proposals_proposed_by_idx on public.memory_proposals(proposed_by);
create index if not exists memory_proposals_reviewed_by_idx on public.memory_proposals(reviewed_by);
create index if not exists memory_sources_memory_item_id_idx on public.memory_sources(memory_item_id);
