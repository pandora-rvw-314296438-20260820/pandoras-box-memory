create policy product_intelligence_products_client_deny
on public.product_intelligence_products
for all to anon, authenticated
using (false)
with check (false);

create policy product_intelligence_event_contracts_client_deny
on public.product_intelligence_event_contracts
for all to anon, authenticated
using (false)
with check (false);

create policy product_intelligence_signals_client_deny
on public.product_intelligence_signals
for all to anon, authenticated
using (false)
with check (false);

create policy product_intelligence_metric_snapshots_client_deny
on public.product_intelligence_metric_snapshots
for all to anon, authenticated
using (false)
with check (false);

create policy product_intelligence_observations_client_deny
on public.product_intelligence_observations
for all to anon, authenticated
using (false)
with check (false);

create policy product_intelligence_recommendations_client_deny
on public.product_intelligence_recommendations
for all to anon, authenticated
using (false)
with check (false);

create policy product_intelligence_sync_runs_client_deny
on public.product_intelligence_sync_runs
for all to anon, authenticated
using (false)
with check (false);
