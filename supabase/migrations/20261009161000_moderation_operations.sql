-- Moderation is an operator action. Mobile users can submit and view their own
-- reports, but cannot review or resolve them. No automatic content sanction is
-- inferred from a report or from an operator's review outcome.
create table public.message_report_audit (
  id bigint generated always as identity primary key,
  report_id uuid not null,
  previous_status text not null,
  next_status text not null,
  action_code text not null check (action_code in
    ('claimed', 'escalated', 'no_violation', 'handled_offline')),
  operator_label text not null check (char_length(operator_label) between 3 and 120),
  note text not null check (char_length(note) between 1 and 1000),
  created_at timestamptz not null default clock_timestamp()
);
create index message_report_audit_report_idx
  on public.message_report_audit (report_id, created_at);
alter table public.message_report_audit enable row level security;
revoke all on public.message_report_audit from public, anon, authenticated,
  service_role;

-- Only the trusted service role can see the cross-user moderation queue.
create function public.list_moderation_reports(
  batch_size integer default 50, queue_status text default 'pending')
returns table (
  report_id uuid, reported_at timestamptz, report_status text,
  reason text, detail text, group_id uuid, message_id uuid,
  reporter_id uuid, sender_id uuid, message_body text, message_deleted_at timestamptz
) language plpgsql security definer set search_path = public as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'moderation service role required' using errcode = '42501';
  end if;
  if batch_size is null or batch_size not between 1 and 100 then
    raise exception 'invalid batch size';
  end if;
  if queue_status is null or queue_status not in ('pending', 'reviewing') then
    raise exception 'invalid queue status';
  end if;
  return query
    select r.id, r.created_at, r.status, r.reason, r.detail,
      r.group_id, r.message_id, r.reporter_id, m.sender_id,
      case when m.deleted_at is null then m.body else null end, m.deleted_at
    from public.message_reports r
    join public.messages m on m.id = r.message_id
    where r.status = queue_status
    order by r.created_at, r.id
    limit batch_size;
end;
$$;

-- Optimistic status check prevents an operator from silently overwriting a
-- concurrent review. The audit insert and report update commit together.
create function public.record_moderation_review(
  target_report_id uuid, expected_status text, action_code text,
  operator_label text, note text
) returns boolean language plpgsql security definer set search_path = public as $$
declare current_status text;
  next_status text;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'moderation service role required' using errcode = '42501';
  end if;
  if target_report_id is null or expected_status is null or action_code is null
    or operator_label is null or note is null
    or char_length(btrim(operator_label)) not between 3 and 120
    or char_length(btrim(note)) not between 1 and 1000 then
    raise exception 'invalid moderation input';
  end if;
  if (expected_status = 'pending' and action_code = 'claimed') then
    next_status := 'reviewing';
  elsif (expected_status = 'reviewing' and action_code = 'escalated') then
    next_status := 'reviewing';
  elsif (expected_status = 'reviewing' and action_code in
    ('no_violation', 'handled_offline')) then
    next_status := 'resolved';
  else
    raise exception 'invalid moderation transition';
  end if;

  select r.status into current_status from public.message_reports r
    where r.id = target_report_id for update;
  if not found or current_status <> expected_status then
    return false;
  end if;
  update public.message_reports r set status = next_status
    where r.id = target_report_id;
  insert into public.message_report_audit
    (report_id, previous_status, next_status, action_code, operator_label, note)
    values (target_report_id, current_status, next_status, action_code,
      btrim(operator_label), btrim(note));
  return true;
end;
$$;

revoke all on function public.list_moderation_reports(integer, text)
  from public, anon, authenticated;
revoke all on function public.record_moderation_review(uuid, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.list_moderation_reports(integer, text) to service_role;
grant execute on function public.record_moderation_review(uuid, text, text, text, text)
  to service_role;
