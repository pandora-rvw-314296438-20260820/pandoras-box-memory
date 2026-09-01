alter table public.pandora_operator_actions
  drop constraint if exists pandora_operator_actions_status_check;
alter table public.pandora_operator_actions
  add constraint pandora_operator_actions_status_check
  check (status in ('proposed','dry_ran','approved','executing','completed','blocked','failed','cancelled'));
