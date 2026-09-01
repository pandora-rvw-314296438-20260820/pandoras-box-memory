# Memory Migration Lineage Recovery — 2026-09-01

## Exact checkpoint
- Live applied migrations: **85**
- Exact applied source in recovery branch: **65 / 85**
- Missing applied source: **20 / 85**
- Conservative-safe legacy restored: **32 / 40**
- Conservative-safe legacy remaining: **8**
- Quarantined legacy versions: **12**, unchanged and not materialized

## Exact source
- Base main: `9da819876037aa6427e745189f7b3949747b3bef`
- Source commit: `27f82bee6acc371bd65b129a28d1f3a927fa6952`
- Source tree: `94d405dffa5c41ef4f93e99701a515c9046bd69a`
- Migration subtree: `6e1bc3a191f95c8970fce2f0a16e37a382f8b820`
- Recovered-safe manifest: `3841` bytes / `88632ac6c00b5a092abc0e3d7262a87d6281ae71cc244790d043bc028dc4e36e`
- Remaining-safe manifest: `936` bytes / `cf3e3f7a2b8e1799c0c486ca8457b1901547c35cf4916bbfc256f49bc3ef2c95`

## Safety
- No production migration execution or schema replay.
- No migration-ledger repair marking.
- No Vercel or Edge mutation.
- GitHub writes used the existing primary Supabase Vault-backed server-side path.
- Quarantined SQL bodies remain outside Git source and evidence.
