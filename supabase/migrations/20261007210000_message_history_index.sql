-- Match the stable timestamp/ID cursor used by the mobile history reader.
-- Authorization remains enforced by existing messages RLS policies.
create index if not exists messages_group_created_id_idx
  on public.messages (group_id, created_at desc, id desc);
