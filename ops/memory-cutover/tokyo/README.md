# Archived Tokyo staging experiment — NOT CANONICAL

Do not deploy these functions or treat this schema as the Pandora Memory production backend.

- The target used by this experiment, xyefkykwuppbweabvvmk, is the shared PLP (Pueblo La Perla) / Pandora Connect Supabase project.
- The schemas pandora_memory_native and pandora_memory_migration, and the role pandora_memory_runtime, exist only as live objects in that project. They do not appear in the 143 committed migrations in this repository. There is no canonical SQL migration for them.
- The Tokyo function snapshots under this directory query those live-only objects. They are retained for forensic review, not for deployment.
- The 25-table import was a selective staging copy of durable memory/project records, not a full database migration. It did not copy 56 other public tables or the 12 private tables. The source database remains intact.
- The permanent Memory database is the dedicated Sydney project ivmvufhcsezyhczzondn, with the repository's existing public schema and committed migration history.
- Do not create a production dependency on pandora_memory_native, pandora_memory_migration, or pandora_memory_runtime. Do not change PLP or Pandora Connect grants to make this experiment work.

The direct Vercel gateway in app/api/pandora/** is the supported runtime path. It uses a server-only Supabase secret key to reach the dedicated Sydney project and verifies the caller's Vercel OIDC identity before any Memory operation.
