-- A block is personal. It hides the blocked sender's messages from its owner
-- and prevents private messages in either direction. Group chat remains visible
-- to other members. Reports are stored for service-role moderation handling.
create table public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default clock_timestamp(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index user_blocks_blocked_idx on public.user_blocks (blocked_id, blocker_id);
alter table public.user_blocks enable row level security;
revoke all on public.user_blocks from public, anon;
grant select, insert, delete on public.user_blocks to authenticated;
create policy user_blocks_own_select on public.user_blocks
  for select to authenticated using (blocker_id = auth.uid());
create policy user_blocks_own_insert on public.user_blocks
  for insert to authenticated with check (
    blocker_id = auth.uid() and exists (
      select 1 from public.group_members mine
      join public.group_members theirs on theirs.group_id = mine.group_id
      where mine.user_id = auth.uid() and mine.status = 'active'
        and theirs.user_id = blocked_id and theirs.status = 'active'
    )
  );
create policy user_blocks_own_delete on public.user_blocks
  for delete to authenticated using (blocker_id = auth.uid());

-- SECURITY DEFINER avoids making the other user's block list readable.
create function public.users_block_each_other(first_user uuid, second_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select first_user = auth.uid() and exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = first_user and b.blocked_id = second_user)
       or (b.blocker_id = second_user and b.blocked_id = first_user)
  );
$$;
revoke all on function public.users_block_each_other(uuid, uuid) from public, anon;
grant execute on function public.users_block_each_other(uuid, uuid) to authenticated;

drop policy messages_select_group on public.messages;
create policy messages_select_group on public.messages
for select to authenticated using (
  public.is_group_member(group_id, auth.uid())
  and (recipient_id is null or auth.uid() in (sender_id, recipient_id))
  and not exists (
    select 1 from public.user_blocks b
    where b.blocker_id = auth.uid() and b.blocked_id = sender_id
  )
);
drop policy messages_insert_member on public.messages;
create policy messages_insert_member on public.messages
for insert to authenticated with check (
  sender_id = auth.uid() and public.is_group_member(group_id, auth.uid())
  and (
    recipient_id is null or (
      public.is_group_member(group_id, recipient_id)
      and (public.is_group_guide(group_id, auth.uid())
           or public.is_group_guide(group_id, recipient_id))
      and not public.users_block_each_other(auth.uid(), recipient_id)
    )
  )
);

create table public.message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in ('harassment', 'spam', 'misinformation', 'other')),
  detail text check (detail is null or char_length(detail) between 1 and 1000),
  status text not null default 'pending' check (status in ('pending', 'reviewing', 'resolved')),
  created_at timestamptz not null default clock_timestamp(),
  unique (message_id, reporter_id)
);
create index message_reports_status_idx on public.message_reports(status, created_at);
alter table public.message_reports enable row level security;
revoke all on public.message_reports from public, anon;
grant select, insert on public.message_reports to authenticated;
create policy message_reports_own_select on public.message_reports
for select to authenticated using (reporter_id = auth.uid());
create policy message_reports_visible_insert on public.message_reports
for insert to authenticated with check (
  reporter_id = auth.uid() and status = 'pending'
  and public.is_group_member(group_id, auth.uid())
  and exists (
    select 1 from public.messages m
    where m.id = message_id and m.group_id = message_reports.group_id
      and m.sender_id <> auth.uid() and m.deleted_at is null
  )
);

-- An authenticated user can file one deletion request and see its status.
-- Processing and the final account/data removal require a service operator.
create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'rejected')),
  requested_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);
alter table public.account_deletion_requests enable row level security;
revoke all on public.account_deletion_requests from public, anon;
grant select on public.account_deletion_requests to authenticated;
grant insert (user_id) on public.account_deletion_requests to authenticated;
create policy account_deletion_requests_own_select
on public.account_deletion_requests for select to authenticated
using (user_id = auth.uid());
create policy account_deletion_requests_own_insert
on public.account_deletion_requests for insert to authenticated
with check (user_id = auth.uid() and status = 'pending');

create function public.revoke_sharing_for_deletion_request()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.location_shares
     set status = 'stopped', stopped_at = clock_timestamp()
   where user_id = new.user_id and status = 'active';
  delete from public.device_push_tokens where user_id = new.user_id;
  return new;
end;
$$;
create trigger account_deletion_request_revoke
after insert on public.account_deletion_requests
for each row execute function public.revoke_sharing_for_deletion_request();
revoke all on function public.revoke_sharing_for_deletion_request() from public, anon, authenticated;

create policy location_shares_no_pending_deletion
on public.location_shares as restrictive for insert to authenticated
with check (not exists (
  select 1 from public.account_deletion_requests r
  where r.user_id = auth.uid()
));
create policy push_tokens_no_pending_deletion
on public.device_push_tokens as restrictive for insert to authenticated
with check (not exists (
  select 1 from public.account_deletion_requests r
  where r.user_id = auth.uid()
));

-- The worker calls this again immediately before sending a queued push.
-- Replacing the existing function keeps its identity for callers and adds
-- the new personal block check to the message branch.
create or replace function public.push_delivery_allowed(d public.push_deliveries)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.device_push_tokens t join public.groups g on g.id = d.group_id
    join public.group_members gm on gm.group_id = g.id and gm.user_id = t.user_id
    where t.id = d.token_id and t.enabled and t.updated_at = d.token_version
      and char_length(t.token) between 1 and 4096 and gm.status = 'active'
      and gm.joined_at <= d.created_at and g.archived_at is null
      and not exists (select 1 from public.device_push_tokens other
        where other.token = t.token and other.user_id <> t.user_id and other.enabled)
      and (
        (d.kind = 'message' and exists (
          select 1 from public.messages m where m.id = d.source_id
            and m.group_id = d.group_id and m.deleted_at is null
            and m.sender_id <> t.user_id and public.is_group_member(m.group_id, m.sender_id)
            and not exists (select 1 from public.user_blocks b
              where b.blocker_id = t.user_id and b.blocked_id = m.sender_id)
            and (m.recipient_id is null or
              (m.recipient_id = t.user_id and
               (public.is_group_guide(m.group_id, m.sender_id) or
                public.is_group_guide(m.group_id, m.recipient_id))))
        )) or (d.kind = 'announcement' and exists (
          select 1 from public.announcements a where a.id = d.source_id
            and a.group_id = d.group_id and a.author_id <> t.user_id
            and (a.expires_at is null or a.expires_at > now())
            and public.is_group_member(a.group_id, a.author_id)
            and public.can_manage_group(a.group_id, a.author_id)
        )) or (d.kind = 'program' and exists (
          select 1 from public.group_programs p where p.id = d.source_id
            and p.group_id = d.group_id and p.created_by <> t.user_id
            and public.is_group_member(p.group_id, p.created_by)
            and public.can_manage_group(p.group_id, p.created_by)
        ))
      )
  );
$$;
