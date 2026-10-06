create extension if not exists pgcrypto with schema extensions;

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.company_members (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('company_admin', 'staff')),
  status text not null default 'active' check (status in ('active', 'left', 'removed')),
  joined_at timestamptz not null default now(),
  primary key (company_id, user_id)
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete set null,
  name text not null check (char_length(name) between 2 and 120),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  archived_at timestamptz
);

create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('group_admin', 'guide', 'member')),
  status text not null default 'active' check (status in ('active', 'left', 'removed')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table public.group_invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  token_digest text not null unique check (char_length(token_digest) = 64),
  invited_role text not null default 'member' check (invited_role in ('guide', 'member')),
  created_by uuid not null references auth.users(id),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  max_uses integer not null default 1 check (max_uses between 1 and 1000),
  uses integer not null default 0 check (uses >= 0 and uses <= max_uses),
  created_at timestamptz not null default now()
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid references auth.users(id) on delete cascade,
  client_id uuid not null,
  message_type text not null default 'chat' check (message_type in ('chat', 'guide_private')),
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (sender_id, client_id),
  check ((message_type = 'guide_private') = (recipient_id is not null))
);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  author_id uuid not null references auth.users(id),
  title text not null check (char_length(title) between 1 and 160),
  body text not null check (char_length(body) between 1 and 8000),
  pinned boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

create table public.group_programs (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  version integer not null check (version > 0),
  title text not null check (char_length(title) between 1 and 160),
  program_date date not null,
  document jsonb not null check (jsonb_typeof(document) = 'object'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  supersedes_id uuid references public.group_programs(id),
  unique (group_id, id, version)
);

create table public.group_routes (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  version integer not null check (version > 0),
  title text not null check (char_length(title) between 1 and 160),
  route_document jsonb not null check (jsonb_typeof(route_document) = 'object'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  supersedes_id uuid references public.group_routes(id),
  unique (group_id, id, version)
);

create table public.location_shares (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  mode text not null check (mode in ('one_time', 'trip')),
  status text not null default 'active' check (status in ('active', 'stopped', 'expired')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  stopped_at timestamptz,
  retention_until timestamptz not null,
  check (ends_at is null or ends_at > starts_at),
  check (retention_until > starts_at)
);

create table public.location_updates (
  id bigint generated always as identity primary key,
  share_id uuid not null references public.location_shares(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_meters double precision not null check (accuracy_meters >= 0),
  measured_at timestamptz not null,
  sent_at timestamptz not null default now(),
  unique (share_id, measured_at)
);

create table public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  token text not null,
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create index group_members_active_user_idx
  on public.group_members (user_id, group_id) where status = 'active';
create index company_members_active_user_idx
  on public.company_members (user_id, company_id) where status = 'active';
create index messages_group_created_idx on public.messages (group_id, created_at desc);
create index announcements_group_created_idx on public.announcements (group_id, created_at desc);
create index location_updates_share_measured_idx
  on public.location_updates (share_id, measured_at desc);
create index location_shares_retention_idx on public.location_shares (retention_until);

create or replace function public.is_group_member(
  target_group_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members member
    where member.group_id = target_group_id
      and member.user_id = target_user_id
      and member.status = 'active'
  );
$$;

create or replace function public.is_company_member(
  target_company_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.company_members member
    where member.company_id = target_company_id
      and member.user_id = target_user_id
      and member.status = 'active'
  );
$$;

create or replace function public.can_manage_company(
  target_company_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.companies company
    where company.id = target_company_id
      and (
        company.created_by = target_user_id
        or exists (
          select 1 from public.company_members member
          where member.company_id = target_company_id
            and member.user_id = target_user_id
            and member.status = 'active'
            and member.role = 'company_admin'
        )
      )
  );
$$;

create or replace function public.can_manage_group(
  target_group_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.groups g
    where g.id = target_group_id
      and (
        g.created_by = target_user_id
        or exists (
          select 1 from public.group_members gm
          where gm.group_id = g.id
            and gm.user_id = target_user_id
            and gm.status = 'active'
            and gm.role in ('group_admin', 'guide')
        )
        or exists (
          select 1 from public.company_members cm
          where cm.company_id = g.company_id
            and cm.user_id = target_user_id
            and cm.status = 'active'
            and cm.role = 'company_admin'
        )
      )
  );
$$;

create or replace function public.is_group_guide(
  target_group_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members member
    where member.group_id = target_group_id
      and member.user_id = target_user_id
      and member.status = 'active'
      and member.role in ('group_admin', 'guide')
  );
$$;

create or replace function public.group_id_from_realtime_topic(topic text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
begin
  if topic !~ '^group:[0-9a-fA-F-]{36}$' then
    return null;
  end if;
  return split_part(topic, ':', 2)::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

create or replace function public.accept_group_invitation(raw_token text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  invitation public.group_invitations%rowtype;
begin
  if auth.uid() is null or raw_token is null or char_length(raw_token) < 24 then
    raise exception 'invalid invitation' using errcode = '22023';
  end if;
  select * into invitation
  from public.group_invitations
  where token_digest = encode(digest(raw_token, 'sha256'), 'hex')
    and revoked_at is null
    and expires_at > now()
    and uses < max_uses
  for update;
  if not found then
    raise exception 'invitation unavailable' using errcode = 'P0002';
  end if;
  insert into public.group_members (group_id, user_id, role, status)
  values (invitation.group_id, auth.uid(), invitation.invited_role, 'active')
  on conflict (group_id, user_id) do update
    set role = excluded.role, status = 'active';
  update public.group_invitations
  set uses = uses + 1
  where id = invitation.id;
  return invitation.group_id;
end;
$$;

revoke all on function public.is_group_member(uuid, uuid) from public;
revoke all on function public.is_company_member(uuid, uuid) from public;
revoke all on function public.can_manage_company(uuid, uuid) from public;
revoke all on function public.can_manage_group(uuid, uuid) from public;
revoke all on function public.is_group_guide(uuid, uuid) from public;
revoke all on function public.accept_group_invitation(text) from public;
grant execute on function public.is_group_member(uuid, uuid) to authenticated;
grant execute on function public.is_company_member(uuid, uuid) to authenticated;
grant execute on function public.can_manage_company(uuid, uuid) to authenticated;
grant execute on function public.can_manage_group(uuid, uuid) to authenticated;
grant execute on function public.is_group_guide(uuid, uuid) to authenticated;
grant execute on function public.accept_group_invitation(text) to authenticated;

alter table public.companies enable row level security;
alter table public.company_members enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invitations enable row level security;
alter table public.messages enable row level security;
alter table public.announcements enable row level security;
alter table public.group_programs enable row level security;
alter table public.group_routes enable row level security;
alter table public.location_shares enable row level security;
alter table public.location_updates enable row level security;
alter table public.device_push_tokens enable row level security;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

create policy companies_select_member on public.companies
for select to authenticated using (
  created_by = auth.uid() or public.is_company_member(id, auth.uid())
);
create policy companies_insert_owner on public.companies
for insert to authenticated with check (created_by = auth.uid());
create policy companies_update_admin on public.companies
for update to authenticated using (public.can_manage_company(id, auth.uid()))
with check (public.can_manage_company(id, auth.uid()));

create policy company_members_select_same_company on public.company_members
for select to authenticated using (public.is_company_member(company_id, auth.uid()));
create policy company_members_manage_admin on public.company_members
for all to authenticated using (public.can_manage_company(company_id, auth.uid()))
with check (public.can_manage_company(company_id, auth.uid()));

create policy groups_select_member on public.groups
for select to authenticated using (
  created_by = auth.uid() or public.is_group_member(id, auth.uid())
  or (company_id is not null and public.can_manage_company(company_id, auth.uid()))
);
create policy groups_insert_creator on public.groups
for insert to authenticated with check (
  created_by = auth.uid() and (
    company_id is null or public.can_manage_company(company_id, auth.uid())
  )
);
create policy groups_update_manager on public.groups
for update to authenticated using (public.can_manage_group(id, auth.uid()))
with check (
  public.can_manage_group(id, auth.uid())
  and (company_id is null or public.can_manage_company(company_id, auth.uid()))
);

create policy group_members_select_group on public.group_members
for select to authenticated using (public.is_group_member(group_id, auth.uid()));
create policy group_members_manage_group on public.group_members
for all to authenticated using (public.can_manage_group(group_id, auth.uid()))
with check (public.can_manage_group(group_id, auth.uid()));

create policy invitations_manage_group on public.group_invitations
for all to authenticated using (public.can_manage_group(group_id, auth.uid()))
with check (public.can_manage_group(group_id, auth.uid()) and created_by = auth.uid());

create policy messages_select_group on public.messages
for select to authenticated using (
  public.is_group_member(group_id, auth.uid())
  and (recipient_id is null or auth.uid() in (sender_id, recipient_id))
);
create policy messages_insert_member on public.messages
for insert to authenticated with check (
  sender_id = auth.uid()
  and public.is_group_member(group_id, auth.uid())
  and (
    recipient_id is null
    or (
      public.is_group_member(group_id, recipient_id)
      and (
        public.is_group_guide(group_id, auth.uid())
        or public.is_group_guide(group_id, recipient_id)
      )
    )
  )
);
create policy messages_delete_sender on public.messages
for update to authenticated using (sender_id = auth.uid())
with check (sender_id = auth.uid());

create policy announcements_select_group on public.announcements
for select to authenticated using (public.is_group_member(group_id, auth.uid()));
create policy announcements_manage_group on public.announcements
for all to authenticated using (public.can_manage_group(group_id, auth.uid()))
with check (public.can_manage_group(group_id, auth.uid()) and author_id = auth.uid());

create policy programs_select_group on public.group_programs
for select to authenticated using (public.is_group_member(group_id, auth.uid()));
create policy programs_manage_group on public.group_programs
for all to authenticated using (public.can_manage_group(group_id, auth.uid()))
with check (public.can_manage_group(group_id, auth.uid()) and created_by = auth.uid());

create policy routes_select_group on public.group_routes
for select to authenticated using (public.is_group_member(group_id, auth.uid()));
create policy routes_manage_group on public.group_routes
for all to authenticated using (public.can_manage_group(group_id, auth.uid()))
with check (public.can_manage_group(group_id, auth.uid()) and created_by = auth.uid());

create policy location_shares_select_owner_or_manager on public.location_shares
for select to authenticated using (
  user_id = auth.uid() or public.can_manage_group(group_id, auth.uid())
);
create policy location_shares_insert_consent on public.location_shares
for insert to authenticated with check (
  user_id = auth.uid() and public.is_group_member(group_id, auth.uid())
  and status = 'active'
);
create policy location_shares_update_owner on public.location_shares
for update to authenticated using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and status in ('stopped', 'expired')
  and stopped_at is not null
);

create policy location_updates_select_owner_or_manager on public.location_updates
for select to authenticated using (
  user_id = auth.uid() or exists (
    select 1 from public.location_shares share
    where share.id = share_id and public.can_manage_group(share.group_id, auth.uid())
  )
);
create policy location_updates_insert_active_share on public.location_updates
for insert to authenticated with check (
  user_id = auth.uid() and exists (
    select 1 from public.location_shares share
    where share.id = share_id and share.user_id = auth.uid()
      and share.status = 'active'
      and (share.ends_at is null or share.ends_at > now())
  )
);

create policy push_tokens_own on public.device_push_tokens
for all to authenticated using (user_id = auth.uid())
with check (user_id = auth.uid());

alter publication supabase_realtime add table
  public.messages,
  public.announcements,
  public.group_programs,
  public.group_routes,
  public.location_shares,
  public.location_updates;

create policy group_realtime_read on realtime.messages
for select to authenticated using (
  public.is_group_member(
    public.group_id_from_realtime_topic(realtime.topic()),
    auth.uid()
  )
);
create policy group_realtime_write on realtime.messages
for insert to authenticated with check (
  public.is_group_member(
    public.group_id_from_realtime_topic(realtime.topic()),
    auth.uid()
  )
);
