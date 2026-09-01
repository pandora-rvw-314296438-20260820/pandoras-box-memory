-- Pandora Memory Engine RLS policy foundation
-- Core tables.

ALTER TABLE public.memory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_items FORCE ROW LEVEL SECURITY;
CREATE POLICY memory_items_select_own ON public.memory_items FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY memory_items_insert_own ON public.memory_items FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.memory_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_sources FORCE ROW LEVEL SECURITY;
CREATE POLICY memory_sources_select_own ON public.memory_sources FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY memory_sources_insert_own ON public.memory_sources FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.memory_patches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_patches FORCE ROW LEVEL SECURITY;
CREATE POLICY memory_patches_select_own ON public.memory_patches FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY memory_patches_insert_own ON public.memory_patches FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.retrieval_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retrieval_logs FORCE ROW LEVEL SECURITY;
CREATE POLICY retrieval_logs_select_own ON public.retrieval_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY retrieval_logs_insert_own ON public.retrieval_logs FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.prompt_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prompt_logs FORCE ROW LEVEL SECURITY;
CREATE POLICY prompt_logs_select_own ON public.prompt_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY prompt_logs_insert_own ON public.prompt_logs FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;
CREATE POLICY audit_logs_select_own ON public.audit_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY audit_logs_insert_own ON public.audit_logs FOR
INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
