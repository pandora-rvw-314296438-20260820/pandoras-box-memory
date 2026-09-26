
# Operations Memory Router grant activation evidence

Live migration version: 20260926032651, name: operations_memory_router_grant_v1.

The canonical production grant row is 11759bb1-2b9d-4b02-8c7a-6027df7999b2 for principal pandora-mcpmaster-production and Memory project 7c686cbd-d968-49d5-86cc-918f5e777bd2.

Before mutation, the live row was locked and required:
- active and not revoked;
- can_read true;
- can_propose true;
- can_approve false;
- production environment;
- existing baseline project/governance record types.

The only effective permission delta is adding model_outcome and provider_performance to allowed_record_types. The post-change provider readback shows both values and still shows can_approve false.

This lets the already-deployed service-only Operations RPCs:
- propose model-outcome candidates that still require normal Memory review before canon;
- read approved, current, hard-canon provider-performance evidence.

It does not approve candidates, promote canonical Memory, create a principal, widen namespace/project access, or change Vercel workload identity.

The first source mirror head ed82f3f46259cb602fa197dae3de56e96385e712 correctly failed Validate exact-head evidence registry because the migration changed tracked source without a required evidence co-change. This file is the correction. The gate itself is unchanged and the failure remains historical evidence.

Rollback requires pausing Operations consumers first, reconciling in-flight outcome deliveries, and removing only these two record types while preserving receipt/review history.
