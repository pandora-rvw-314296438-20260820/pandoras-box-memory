-- Column-level UPDATE (id) lets pandora_memory_runtime run SELECT ... FOR SHARE on these tables; RLS still denies any row modification.
GRANT UPDATE (id) ON TABLE pandora_memory_native.pandora_service_principals TO pandora_memory_runtime;
GRANT UPDATE (id) ON TABLE pandora_memory_native.pandora_projects TO pandora_memory_runtime;
GRANT UPDATE (id) ON TABLE pandora_memory_native.pandora_project_grants TO pandora_memory_runtime;
GRANT UPDATE (id) ON TABLE pandora_memory_native.memory_items TO pandora_memory_runtime;
