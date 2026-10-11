-- No legal text is seeded. A responsible operator publishes an immutable version.
create table public.service_terms (
  version text primary key check (char_length(version) between 1 and 80),
  body text not null check (char_length(body) between 1 and 100000),
  document_url text not null check (document_url ~ '^https://[^[:space:]]+$'),
  document_sha256 text not null check (document_sha256 ~ '^[a-f0-9]{64}$'),
  published_at timestamptz not null default clock_timestamp(),
  current boolean not null default false
);
create unique index service_terms_one_current on public.service_terms ((current)) where current;
create table public.service_terms_acceptances (
  user_id uuid not null references auth.users(id) on delete cascade,
  terms_version text not null references public.service_terms(version),
  accepted_at timestamptz not null default clock_timestamp(),
  primary key (user_id, terms_version)
);
alter table public.service_terms enable row level security;
alter table public.service_terms_acceptances enable row level security;
revoke all on public.service_terms, public.service_terms_acceptances from public, anon, authenticated;
grant select on public.service_terms, public.service_terms_acceptances to authenticated;
grant all on public.service_terms, public.service_terms_acceptances to service_role;
create policy terms_read on public.service_terms for select to authenticated using (true);
create policy terms_acceptance_read on public.service_terms_acceptances for select to authenticated using (user_id = auth.uid());

create function public.immutable_service_terms() returns trigger language plpgsql as $$
begin
  if new.version is distinct from old.version or new.body is distinct from old.body
     or new.document_url is distinct from old.document_url
     or new.document_sha256 is distinct from old.document_sha256
     or new.published_at is distinct from old.published_at then
    raise exception 'publish a new terms version' using errcode = '22023';
  end if;
  return new;
end; $$;
create trigger immutable_terms before update on public.service_terms for each row execute function public.immutable_service_terms();

create function public.current_service_terms() returns table (
  version text, body text, document_url text, document_sha256 text,
  accepted_at timestamptz
) language sql stable security definer set search_path = public as $$
  select t.version, t.body, t.document_url, t.document_sha256, a.accepted_at
  from public.service_terms t left join public.service_terms_acceptances a
    on a.terms_version = t.version and a.user_id = auth.uid()
  where t.current and auth.uid() is not null;
$$;
create function public.accept_service_terms(displayed_version text) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare required_version text; accepted timestamptz;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  -- Row lock serializes acceptance against publishing a replacement version.
  select version into required_version from public.service_terms where current for share;
  if required_version is null or required_version is distinct from displayed_version then
    raise exception 'terms changed; read current version' using errcode = '42501';
  end if;
  if exists (select 1 from public.account_deletion_requests where user_id = auth.uid()) then
    raise exception 'account deletion pending' using errcode = '42501';
  end if;
  insert into public.service_terms_acceptances(user_id, terms_version)
    values(auth.uid(), required_version) on conflict do nothing;
  select accepted_at into accepted from public.service_terms_acceptances
    where user_id = auth.uid() and terms_version = required_version;
  return accepted;
end; $$;
revoke all on function public.current_service_terms(), public.accept_service_terms(text) from public, anon;
grant execute on function public.current_service_terms(), public.accept_service_terms(text) to authenticated;

create function public.require_current_service_terms() returns trigger
language plpgsql security definer set search_path = public as $$
declare required_version text;
begin
  -- Database operators and service jobs are separate trusted actors. The role
  -- GUC remains authenticated even inside existing SECURITY DEFINER RPCs.
  if current_setting('role', true) <> 'authenticated' then return new; end if;
  -- Revocation must remain available after a version change or offline retry.
  if tg_table_name = 'location_shares' and tg_op = 'UPDATE' then
    if new.status = 'stopped' then return new; end if;
  end if;
  if tg_table_name = 'device_push_tokens' and tg_op = 'UPDATE' then
    if not new.enabled then return new; end if;
  end if;
  select version into required_version from public.service_terms where current for share;
  if required_version is null or not exists (
    select 1 from public.service_terms_acceptances a
    where a.terms_version = required_version and a.user_id = auth.uid()
  ) then raise exception 'current service terms acceptance required' using errcode = '42501'; end if;
  return new;
end; $$;
-- Existing RLS remains authoritative for identity and active membership.
-- Reports, blocks, token DELETE, consent revocation and account deletion stay available.
do $$ declare tab text; begin
  foreach tab in array array['companies','company_members','groups','group_members',
    'group_invitations','messages','announcements','group_programs','group_routes',
    'location_shares','location_updates','device_push_tokens'] loop
    execute format('create trigger service_terms_write before insert or update on public.%I for each row execute function public.require_current_service_terms()', tab);
  end loop;
end; $$;
