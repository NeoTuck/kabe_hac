-- Apply after the initial schema, including to already deployed databases.
-- Only body and soft-delete time are client-editable. RLS also requires current membership.
revoke update on public.messages from authenticated;
grant update (body, deleted_at) on public.messages to authenticated;
drop policy messages_delete_sender on public.messages;
create policy messages_update_sender on public.messages
for update to authenticated
using (sender_id = auth.uid() and public.is_group_member(group_id, auth.uid()))
with check (sender_id = auth.uid() and public.is_group_member(group_id, auth.uid()));

-- A consent record cannot be moved, extended, or reactivated through an UPDATE.
revoke update on public.location_shares from authenticated;
grant update (status, stopped_at) on public.location_shares to authenticated;

-- Owners retain access to their consent history. Managers only see an active,
-- unrevoked, unexpired consent belonging to a current member.
drop policy location_shares_select_owner_or_manager on public.location_shares;
create policy location_shares_select_owner_or_manager on public.location_shares
for select to authenticated using (
  user_id = auth.uid()
  or (
    public.can_manage_group(group_id, auth.uid())
    and public.is_group_member(group_id, user_id)
    and status = 'active' and stopped_at is null
    and starts_at <= now() and ends_at > now() and retention_until > now()
  )
);

drop policy location_updates_select_owner_or_manager on public.location_updates;
create policy location_updates_select_owner_or_manager on public.location_updates
for select to authenticated using (
  exists (
    select 1 from public.location_shares share
    where share.id = share_id and share.user_id = location_updates.user_id
      and share.retention_until > now()
      and (
        location_updates.user_id = auth.uid()
        or (
          public.can_manage_group(share.group_id, auth.uid())
          and public.is_group_member(share.group_id, share.user_id)
          and share.status = 'active' and share.stopped_at is null
          and share.starts_at <= now() and share.ends_at > now()
        )
      )
  )
);

drop policy location_updates_insert_active_share on public.location_updates;
create policy location_updates_insert_active_share on public.location_updates
for insert to authenticated with check (
  user_id = auth.uid() and exists (
    select 1 from public.location_shares share
    where share.id = share_id and share.user_id = auth.uid()
      and public.is_group_member(share.group_id, auth.uid())
      and share.status = 'active' and share.stopped_at is null
      and share.starts_at <= now() and share.ends_at > now()
      and share.retention_until > now()
      and measured_at >= share.starts_at and measured_at < share.ends_at
      and measured_at <= now()
  )
);
