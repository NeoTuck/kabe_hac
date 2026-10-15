-- Server-only, fail-closed account deletion preparation. Auth deletion is
-- performed by an operator using the Supabase Admin API, never by the client.
create table public.account_deletion_operations (
  request_id uuid primary key,
  user_id uuid,
  status text not null check (status in ('processing', 'deleted')),
  started_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  check ((status = 'processing' and user_id is not null and completed_at is null)
      or (status = 'deleted' and user_id is null and completed_at is not null))
);
alter table public.account_deletion_operations enable row level security;
revoke all on public.account_deletion_operations from public, anon, authenticated;
grant select, update on public.account_deletion_operations to service_role;

-- Both an owner's new records and a deletion request lock the same Auth row.
-- This makes the preparation count see any committed concurrent authoring.
create function public.lock_deletion_request_subject()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  perform 1 from auth.users where id = new.user_id for update;
  if not found then
    raise exception 'Account not found' using errcode = '23503';
  end if;
  return new;
end;
$$;
create trigger account_deletion_request_subject_lock
before insert on public.account_deletion_requests
for each row execute function public.lock_deletion_request_subject();
revoke all on function public.lock_deletion_request_subject()
  from public, anon, authenticated;

create function public.reject_owned_record_during_deletion()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare owner_id uuid;
begin
  owner_id := (to_jsonb(new) ->> tg_argv[0])::uuid;
  perform 1 from auth.users where id = owner_id for update;
  if exists (select 1 from public.account_deletion_requests
             where user_id = owner_id) then
    raise exception 'Account deletion requested; new owned content is blocked'
      using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.reject_owned_record_during_deletion()
  from public, anon, authenticated;

create trigger companies_deletion_owner_guard
before insert or update of created_by on public.companies
for each row execute function public.reject_owned_record_during_deletion('created_by');
create trigger groups_deletion_owner_guard
before insert or update of created_by on public.groups
for each row execute function public.reject_owned_record_during_deletion('created_by');
create trigger invitations_deletion_owner_guard
before insert or update of created_by on public.group_invitations
for each row execute function public.reject_owned_record_during_deletion('created_by');
create trigger announcements_deletion_owner_guard
before insert or update of author_id on public.announcements
for each row execute function public.reject_owned_record_during_deletion('author_id');
create trigger programs_deletion_owner_guard
before insert or update of created_by on public.group_programs
for each row execute function public.reject_owned_record_during_deletion('created_by');
create trigger routes_deletion_owner_guard
before insert or update of created_by on public.group_routes
for each row execute function public.reject_owned_record_during_deletion('created_by');

-- Auth deletion cascades through messages and reports. Refuse it if any
-- moderation record would be lost; a retention decision must come first.
create function public.prevent_moderation_loss_on_auth_delete()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if exists (
    select 1 from public.message_reports r
    join public.messages m on m.id = r.message_id
    where r.reporter_id = old.id or m.sender_id = old.id
       or m.recipient_id = old.id
  ) then
    raise exception 'Moderation records require a retention decision before account deletion'
      using errcode = '23503';
  end if;
  return old;
end;
$$;
create trigger account_deletion_preserve_moderation
before delete on auth.users
for each row execute function public.prevent_moderation_loss_on_auth_delete();
revoke all on function public.prevent_moderation_loss_on_auth_delete()
  from public, anon, authenticated;

-- A new report and an Auth deletion lock the same user rows. The delete
-- trigger above therefore sees a committed report or the insert fails after
-- the user/message disappears; a concurrent report cannot be cascaded away.
create function public.lock_moderation_report_subjects()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare message_row public.messages%rowtype;
begin
  select * into message_row from public.messages where id = new.message_id;
  if found then
    perform 1 from auth.users
      where id in (new.reporter_id, message_row.sender_id,
                   message_row.recipient_id)
      order by id for update;
  end if;
  return new;
end;
$$;
create trigger message_report_subject_lock
before insert on public.message_reports
for each row execute function public.lock_moderation_report_subjects();
revoke all on function public.lock_moderation_report_subjects()
  from public, anon, authenticated;

create function public.account_deletion_blockers(target_user uuid)
returns jsonb language sql stable security definer
set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'companies', (select count(*) from public.companies where created_by = target_user),
    'groups', (select count(*) from public.groups where created_by = target_user),
    'invitations', (select count(*) from public.group_invitations where created_by = target_user),
    'announcements', (select count(*) from public.announcements where author_id = target_user),
    'programs', (select count(*) from public.group_programs where created_by = target_user),
    'routes', (select count(*) from public.group_routes where created_by = target_user),
    'moderation_reports', (
      select count(*) from public.message_reports r
      join public.messages m on m.id = r.message_id
      where r.reporter_id = target_user or m.sender_id = target_user
         or m.recipient_id = target_user
    )
  );
$$;
revoke all on function public.account_deletion_blockers(uuid)
  from public, anon, authenticated;
grant execute on function public.account_deletion_blockers(uuid) to service_role;

create function public.inspect_account_deletion(target_request uuid)
returns jsonb language plpgsql security definer
set search_path = public, pg_temp as $$
declare request_row public.account_deletion_requests%rowtype;
  blockers jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Deletion service role required' using errcode = '42501';
  end if;
  select * into request_row from public.account_deletion_requests
    where id = target_request;
  if not found then
    raise exception 'Deletion request not found';
  end if;
  blockers := public.account_deletion_blockers(request_row.user_id);
  return jsonb_build_object('request_id', target_request,
    'user_id', request_row.user_id, 'status', request_row.status,
    'ready', request_row.status = 'pending' and not exists (
      select 1 from jsonb_each_text(blockers) as b where b.value::integer > 0
    ), 'blockers', blockers);
end;
$$;
revoke all on function public.inspect_account_deletion(uuid)
  from public, anon, authenticated;
grant execute on function public.inspect_account_deletion(uuid) to service_role;

create function public.prepare_account_deletion(target_request uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  request_row public.account_deletion_requests%rowtype;
  blockers jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Deletion service role required' using errcode = '42501';
  end if;
  select * into request_row from public.account_deletion_requests
    where id = target_request for update;
  if not found then
    raise exception 'Deletion request not found';
  end if;
  if request_row.status <> 'pending' then
    raise exception 'Deletion request is not pending';
  end if;
  perform 1 from auth.users where id = request_row.user_id for update;
  blockers := public.account_deletion_blockers(request_row.user_id);
  if exists (select 1 from jsonb_each_text(blockers) as b where b.value::integer > 0) then
    return jsonb_build_object('ready', false, 'blockers', blockers);
  end if;
  update public.location_shares set status = 'stopped', stopped_at = clock_timestamp()
    where user_id = request_row.user_id and status = 'active';
  delete from public.device_push_tokens where user_id = request_row.user_id;
  update public.account_deletion_requests
    set status = 'processing', updated_at = clock_timestamp()
    where id = target_request;
  insert into public.account_deletion_operations(request_id, user_id, status)
    values (target_request, request_row.user_id, 'processing');
  return jsonb_build_object('ready', true, 'request_id', target_request,
    'user_id', request_row.user_id);
end;
$$;
revoke all on function public.prepare_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.prepare_account_deletion(uuid) to service_role;

-- Prevent the requester from creating new non-cascading references while an
-- operator is handling the request. Existing content still needs a decision.
create policy companies_no_deletion_request on public.companies as restrictive
  for insert to authenticated with check (not exists (
    select 1 from public.account_deletion_requests where user_id = auth.uid()));
create policy groups_no_deletion_request on public.groups as restrictive
  for insert to authenticated with check (not exists (
    select 1 from public.account_deletion_requests where user_id = auth.uid()));
create policy invitations_no_deletion_request on public.group_invitations as restrictive
  for insert to authenticated with check (not exists (
    select 1 from public.account_deletion_requests where user_id = auth.uid()));
create policy announcements_no_deletion_request on public.announcements as restrictive
  for insert to authenticated with check (not exists (
    select 1 from public.account_deletion_requests where user_id = auth.uid()));
create policy programs_no_deletion_request on public.group_programs as restrictive
  for insert to authenticated with check (not exists (
    select 1 from public.account_deletion_requests where user_id = auth.uid()));
create policy routes_no_deletion_request on public.group_routes as restrictive
  for insert to authenticated with check (not exists (
    select 1 from public.account_deletion_requests where user_id = auth.uid()));
