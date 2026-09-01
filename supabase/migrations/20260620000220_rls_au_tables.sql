-- Pandora Memory Engine RLS policy foundation
-- AU/story tables.

ALTER TABLE public.au_worlds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_worlds FORCE ROW LEVEL SECURITY;
CREATE POLICY au_worlds_select_own ON public.au_worlds FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_worlds_insert_own ON public.au_worlds FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_characters FORCE ROW LEVEL SECURITY;
CREATE POLICY au_characters_select_own ON public.au_characters FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_characters_insert_own ON public.au_characters FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_relationships FORCE ROW LEVEL SECURITY;
CREATE POLICY au_relationships_select_own ON public.au_relationships FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_relationships_insert_own ON public.au_relationships FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_scenes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_scenes FORCE ROW LEVEL SECURITY;
CREATE POLICY au_scenes_select_own ON public.au_scenes FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_scenes_insert_own ON public.au_scenes FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_consequences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_consequences FORCE ROW LEVEL SECURITY;
CREATE POLICY au_consequences_select_own ON public.au_consequences FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_consequences_insert_own ON public.au_consequences FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_open_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_open_threads FORCE ROW LEVEL SECURITY;
CREATE POLICY au_open_threads_select_own ON public.au_open_threads FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_open_threads_insert_own ON public.au_open_threads FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_rules FORCE ROW LEVEL SECURITY;
CREATE POLICY au_rules_select_own ON public.au_rules FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_rules_insert_own ON public.au_rules FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_character_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_character_states FORCE ROW LEVEL SECURITY;
CREATE POLICY au_character_states_select_own ON public.au_character_states FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_character_states_insert_own ON public.au_character_states FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_relationship_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_relationship_states FORCE ROW LEVEL SECURITY;
CREATE POLICY au_relationship_states_select_own ON public.au_relationship_states FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_relationship_states_insert_own ON public.au_relationship_states FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_retcons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_retcons FORCE ROW LEVEL SECURITY;
CREATE POLICY au_retcons_select_own ON public.au_retcons FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_retcons_insert_own ON public.au_retcons FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.au_quality_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.au_quality_reviews FORCE ROW LEVEL SECURITY;
CREATE POLICY au_quality_reviews_select_own ON public.au_quality_reviews FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY au_quality_reviews_insert_own ON public.au_quality_reviews FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
