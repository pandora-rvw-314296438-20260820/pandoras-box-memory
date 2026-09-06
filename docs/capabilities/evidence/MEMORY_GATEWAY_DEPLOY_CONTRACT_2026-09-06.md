# Memory gateway deploy contract — 2026-09-06

The merged indexed-search gateway uses npm dependencies and is deployed by Supabase in an isolated bundling environment.

The prior source setting `nodeModulesDir: manual` required a pre-populated local `node_modules` directory that the governed Supabase deploy boundary does not provide. The deployment attempt therefore failed before publishing and the live function remained on version 3.

This change sets `nodeModulesDir: auto` so Deno resolves the exact pinned npm imports during isolated bundling. It does not change authentication, authorization, search scope, canon authority, provider destination, or secret handling.

Verification requires the existing hardening, namespace-isolation, exact-head evidence, build, and no-literal-secrets gates to remain green before merge.
