-- Pandora Memory Engine RLS policy foundation
-- Real-life tables.

ALTER TABLE public.people ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.people FORCE ROW LEVEL SECURITY;
CREATE POLICY people_select_own ON public.people FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY people_insert_own ON public.people FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.relationships FORCE ROW LEVEL SECURITY;
CREATE POLICY relationships_select_own ON public.relationships FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY relationships_insert_own ON public.relationships FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.relationship_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.relationship_events FORCE ROW LEVEL SECURITY;
CREATE POLICY relationship_events_select_own ON public.relationship_events FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY relationship_events_insert_own ON public.relationship_events FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.business_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_entities FORCE ROW LEVEL SECURITY;
CREATE POLICY business_entities_select_own ON public.business_entities FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY business_entities_insert_own ON public.business_entities FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.business_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_deals FORCE ROW LEVEL SECURITY;
CREATE POLICY business_deals_select_own ON public.business_deals FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY business_deals_insert_own ON public.business_deals FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.promises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promises FORCE ROW LEVEL SECURITY;
CREATE POLICY promises_select_own ON public.promises FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY promises_insert_own ON public.promises FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decisions FORCE ROW LEVEL SECURITY;
CREATE POLICY decisions_select_own ON public.decisions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY decisions_insert_own ON public.decisions FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.risks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risks FORCE ROW LEVEL SECURITY;
CREATE POLICY risks_select_own ON public.risks FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY risks_insert_own ON public.risks FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.evidence_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_items FORCE ROW LEVEL SECURITY;
CREATE POLICY evidence_items_select_own ON public.evidence_items FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY evidence_items_insert_own ON public.evidence_items FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
