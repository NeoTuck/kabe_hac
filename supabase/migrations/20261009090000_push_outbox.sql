-- Database-owned events. Mobile clients cannot choose recipients or enqueue sends.
create table public.push_deliveries (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('message', 'announcement', 'program')),
  source_id uuid not null,
  group_id uuid not null references public.groups(id) on delete cascade,
  token_id uuid not null references public.device_push_tokens(id) on delete cascade,
  token_version timestamptz not null,
  status text not null default 'pending' check (status in
    ('pending', 'leased', 'provider_accepted', 'cancelled', 'permanent_failure', 'exhausted')),
  attempts integer not null default 0 check (attempts between 0 and 5),
  next_attempt_at timestamptz not null default now(),
  lease_id uuid,
  lease_until timestamptz,
  last_code text,
  created_at timestamptz not null default clock_timestamp(),
  unique (kind, source_id, token_id)
);
alter table public.push_deliveries enable row level security;
revoke all on public.push_deliveries from public, anon, authenticated, service_role;
create index push_deliveries_due_idx on public.push_deliveries(next_attempt_at, id)
  where status in ('pending', 'leased');

create function public.version_push_token() returns trigger
language plpgsql set search_path = public as $$
begin
  if char_length(NEW.token) not between 1 and 4096 then
    raise exception 'invalid push token' using errcode = '22023';
  end if;
  NEW.updated_at := clock_timestamp();
  return NEW;
end;
$$;
create trigger push_token_version before insert or update on public.device_push_tokens
  for each row execute function public.version_push_token();

create function public.invalidate_member_push() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if NEW.status <> 'active' then
    update public.push_deliveries d set status = 'cancelled', lease_until = null
      from public.device_push_tokens t where d.token_id = t.id
      and t.user_id = NEW.user_id and d.group_id = NEW.group_id
      and d.status in ('pending', 'leased');
  elsif OLD.status <> 'active' then
    NEW.joined_at := clock_timestamp();
  end if;
  return NEW;
end;
$$;
create trigger member_push_revocation before update of status on public.group_members
  for each row execute function public.invalidate_member_push();

-- Re-evaluated before every attempt: no stale membership snapshot is sufficient.
create function public.push_delivery_allowed(d public.push_deliveries)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.device_push_tokens t join public.groups g on g.id = d.group_id
    join public.group_members gm on gm.group_id = g.id and gm.user_id = t.user_id
    where t.id = d.token_id and t.enabled and t.updated_at = d.token_version
      and char_length(t.token) between 1 and 4096 and gm.status = 'active'
      and gm.joined_at <= d.created_at and g.archived_at is null
      -- Ambiguous shared-device ownership fails closed (no cross-account sends).
      and not exists (select 1 from public.device_push_tokens other
        where other.token = t.token and other.user_id <> t.user_id and other.enabled)
      and (
        (d.kind = 'message' and exists (
          select 1 from public.messages m where m.id = d.source_id
            and m.group_id = d.group_id and m.deleted_at is null
            and m.sender_id <> t.user_id and public.is_group_member(m.group_id, m.sender_id)
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

create function public.enqueue_group_push() returns trigger
language plpgsql security definer set search_path = public as $$
declare event_kind text;
begin
  event_kind := case TG_TABLE_NAME when 'messages' then 'message'
    when 'announcements' then 'announcement' when 'group_programs' then 'program' end;
  insert into public.push_deliveries(kind, source_id, group_id, token_id, token_version)
    select event_kind, NEW.id, NEW.group_id, t.id, t.updated_at
    from public.device_push_tokens t join public.group_members gm
      on gm.user_id = t.user_id and gm.group_id = NEW.group_id
    where t.enabled and gm.status = 'active'
    on conflict (kind, source_id, token_id) do nothing;
  -- Remove ineligible deliveries within the same transaction, before exposure.
  delete from public.push_deliveries d where d.kind = event_kind and d.source_id = NEW.id
    and not public.push_delivery_allowed(d);
  return NEW;
end;
$$;
create trigger message_push after insert on public.messages
  for each row execute function public.enqueue_group_push();
create trigger announcement_push after insert on public.announcements
  for each row execute function public.enqueue_group_push();
create trigger program_push after insert on public.group_programs
  for each row execute function public.enqueue_group_push();

create function public.claim_push_deliveries(batch_size integer default 20)
returns table(id bigint, lease_id uuid) language plpgsql security definer
set search_path = public as $$
begin
  if batch_size is null or batch_size not between 1 and 100 then raise exception 'invalid batch'; end if;
  return query
    with due as (
      select d.id from public.push_deliveries d
      where (d.status = 'pending' and d.next_attempt_at <= clock_timestamp())
        or (d.status = 'leased' and d.lease_until <= clock_timestamp())
      order by d.next_attempt_at, d.id limit batch_size for update skip locked
    )
    update public.push_deliveries d set
      status = case when not public.push_delivery_allowed(d) then 'cancelled'
        when d.attempts >= 5 then 'exhausted' else 'leased' end,
      attempts = least(d.attempts + 1, 5), lease_id = gen_random_uuid(),
      lease_until = clock_timestamp() + interval '2 minutes'
    from due where d.id = due.id
    returning d.id, d.lease_id;
end;
$$;

create function public.prepare_push_delivery(delivery_id bigint, worker_lease uuid)
returns table(token text, kind text, group_id uuid, event_id text, user_id uuid, token_id uuid, attempts integer)
language plpgsql security definer set search_path = public as $$
declare d public.push_deliveries;
begin
  select * into d from public.push_deliveries where id = delivery_id for update;
  if not found or d.status <> 'leased' or d.lease_id is distinct from worker_lease
    or d.lease_until <= clock_timestamp() then return; end if;
  if not public.push_delivery_allowed(d) then
    update public.push_deliveries set status = 'cancelled', lease_until = null
      where id = d.id;
    return;
  end if;
  return query select t.token, d.kind, d.group_id, d.id::text, t.user_id, t.id, d.attempts
    from public.device_push_tokens t where t.id = d.token_id;
end;
$$;

create function public.finish_push_delivery(delivery_id bigint, worker_lease uuid,
  outcome text, safe_code text, retry_seconds integer default 60)
returns boolean language plpgsql security definer set search_path = public as $$
declare d public.push_deliveries;
begin
  if outcome is null or safe_code is null or retry_seconds is null
    or outcome not in ('provider_accepted', 'invalid_token', 'permanent_failure', 'retry', 'exhausted')
    or safe_code !~ '^[A-Z0-9_]{1,64}$' or retry_seconds not between 60 and 86400 then
    raise exception 'invalid outcome';
  end if;
  select * into d from public.push_deliveries where id = delivery_id for update;
  if not found or d.status <> 'leased' or d.lease_id is distinct from worker_lease
    or d.lease_until <= clock_timestamp() then return false; end if;
  if outcome = 'invalid_token' then
    update public.device_push_tokens set enabled = false
      where id = d.token_id and updated_at = d.token_version;
  end if;
  update public.push_deliveries set
    status = case when outcome = 'retry' and d.attempts < 5 then 'pending'
      when outcome = 'retry' then 'exhausted'
      when outcome = 'invalid_token' then 'permanent_failure' else outcome end,
    next_attempt_at = clock_timestamp() + make_interval(secs => retry_seconds),
    lease_until = null, last_code = safe_code
    where id = d.id;
  return true;
end;
$$;

revoke all on function public.push_delivery_allowed(public.push_deliveries) from public, anon, authenticated;
revoke all on function public.version_push_token() from public, anon, authenticated;
revoke all on function public.invalidate_member_push() from public, anon, authenticated;
revoke all on function public.enqueue_group_push() from public, anon, authenticated;
revoke all on function public.claim_push_deliveries(integer) from public, anon, authenticated;
revoke all on function public.prepare_push_delivery(bigint, uuid) from public, anon, authenticated;
revoke all on function public.finish_push_delivery(bigint, uuid, text, text, integer) from public, anon, authenticated;
grant execute on function public.claim_push_deliveries(integer) to service_role;
grant execute on function public.prepare_push_delivery(bigint, uuid) to service_role;
grant execute on function public.finish_push_delivery(bigint, uuid, text, text, integer) to service_role;
