-- No invented production retention interval: existing records keep retention_until.
-- A product-approved setting overrides the pilot client's requested retention.
create table public.location_retention_policy (
  singleton boolean primary key default true check (singleton),
  seconds_after_end integer check (seconds_after_end between 0 and 2592000)
);
insert into public.location_retention_policy(singleton) values (true);
alter table public.location_retention_policy enable row level security;
revoke all on public.location_retention_policy from public, anon, authenticated;

-- Being the original group creator is not sufficient after membership removal.
drop policy location_shares_select_owner_or_manager on public.location_shares;
create policy location_shares_select_owner_or_manager on public.location_shares
for select to authenticated using (
  user_id = auth.uid() or (
    public.is_group_member(group_id, auth.uid())
    and public.can_manage_group(group_id, auth.uid())
    and public.is_group_member(group_id, user_id)
    and status = 'active' and stopped_at is null
    and starts_at <= now() and ends_at > now() and retention_until > now()
  )
);
drop policy location_updates_select_owner_or_manager on public.location_updates;
create policy location_updates_select_owner_or_manager on public.location_updates
for select to authenticated using (
  exists (select 1 from public.location_shares s
    where s.id = share_id and s.user_id = location_updates.user_id
      and s.retention_until > now() and (
        location_updates.user_id = auth.uid() or (
          public.is_group_member(s.group_id, auth.uid())
          and public.can_manage_group(s.group_id, auth.uid())
          and public.is_group_member(s.group_id, s.user_id)
          and s.status = 'active' and s.stopped_at is null
          and s.starts_at <= now() and s.ends_at > now()
        )
      )
  )
);

create function public.apply_location_retention() returns trigger
language plpgsql security definer set search_path = public as $$
declare retention_seconds integer;
begin
  select seconds_after_end into retention_seconds from public.location_retention_policy;
  if retention_seconds is not null then
    NEW.retention_until := NEW.ends_at + make_interval(secs => retention_seconds);
  end if;
  return NEW;
end;
$$;
create trigger location_retention before insert on public.location_shares
  for each row execute function public.apply_location_retention();

-- Serialize insertion with revocation/cleanup and membership removal.
-- Membership first everywhere prevents share/member lock inversion.
create function public.lock_location_consent() returns trigger
language plpgsql security definer set search_path = public as $$
declare s public.location_shares; active_member boolean;
begin
  select * into s from public.location_shares where id = NEW.share_id;
  select status = 'active' into active_member from public.group_members
    where group_id = s.group_id and user_id = NEW.user_id for share;
  select * into s from public.location_shares where id = NEW.share_id for update;
  if s.id is null or s.user_id <> NEW.user_id or not coalesce(active_member, false)
    or s.status <> 'active' or s.stopped_at is not null
    or s.starts_at > clock_timestamp() or s.ends_at <= clock_timestamp()
    or s.retention_until <= clock_timestamp()
    or NEW.measured_at < s.starts_at or NEW.measured_at >= s.ends_at
    or NEW.measured_at > clock_timestamp() then
    raise exception 'location consent unavailable' using errcode = '42501';
  end if;
  NEW.sent_at := clock_timestamp();
  return NEW;
end;
$$;
create trigger location_update_consent before insert on public.location_updates
  for each row execute function public.lock_location_consent();

create function public.stop_removed_member_location() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'DELETE' or NEW.status <> 'active' then
    update public.location_shares set status = 'stopped', stopped_at = clock_timestamp()
      where group_id = OLD.group_id and user_id = OLD.user_id and status = 'active';
  end if;
  return null;
end;
$$;
create trigger member_location_revocation after update of status or delete on public.group_members
  for each row execute function public.stop_removed_member_location();

create function public.cleanup_expired_locations(batch_size integer default 100)
returns integer language plpgsql security definer set search_path = public as $$
declare removed integer;
begin
  if batch_size not between 1 and 1000 then raise exception 'invalid batch'; end if;
  -- Bound coordinate rows, rather than cascade-deleting an unbounded share history.
  with expired as (
    select u.id from public.location_updates u join public.location_shares s on s.id = u.share_id
    where s.retention_until <= clock_timestamp()
    order by s.retention_until, u.id limit batch_size for update of u skip locked
  ) delete from public.location_updates u using expired e where u.id = e.id;
  get diagnostics removed = row_count;
  return removed;
end;
$$;
revoke all on function public.apply_location_retention() from public, anon, authenticated;
revoke all on function public.lock_location_consent() from public, anon, authenticated;
revoke all on function public.stop_removed_member_location() from public, anon, authenticated;
revoke all on function public.cleanup_expired_locations(integer) from public, anon, authenticated;
grant execute on function public.cleanup_expired_locations(integer) to service_role;
