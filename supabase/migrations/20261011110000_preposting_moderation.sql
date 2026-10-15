-- Trusted operators publish real rules. No production policy/approval is seeded.
-- Literal matching is bounded and deliberately avoids operator-supplied regex.
create function public.normalize_moderation_text(value text) returns text
language sql immutable strict set search_path = public as $$
  select regexp_replace(lower(translate(normalize(value, NFKC),
    chr(8203) || chr(8204) || chr(8205) || chr(65279), '')), '[[:space:]]+', ' ', 'g');
$$;
create function public.valid_moderation_phrases(phrases text[]) returns boolean
language sql immutable set search_path = public as $$
  select coalesce(cardinality(phrases) between 1 and 200 and not exists (
    select 1 from unnest(phrases) p
    where p is null or char_length(p) not between 1 and 160
      or char_length(btrim(public.normalize_moderation_text(p))) = 0
  ), false);
$$;
create table public.content_moderation_policies (
  version text primary key check (char_length(version) between 1 and 80),
  terms_version text not null references public.service_terms(version),
  denied_phrases text[] not null check (public.valid_moderation_phrases(denied_phrases)),
  policy_document_url text not null check (policy_document_url ~ '^https://[^[:space:]]+$'),
  policy_document_sha256 text not null check (policy_document_sha256 ~ '^[a-f0-9]{64}$'),
  published_at timestamptz not null default clock_timestamp(),
  current boolean not null default false
);
create unique index content_moderation_one_current
  on public.content_moderation_policies ((current)) where current;
alter table public.content_moderation_policies enable row level security;
revoke all on public.content_moderation_policies from public, anon, authenticated;
grant all on public.content_moderation_policies to service_role;
alter table public.messages add column moderation_policy_version text
  references public.content_moderation_policies(version),
  add column moderation_checked_at timestamptz;
alter table public.announcements add column moderation_policy_version text
  references public.content_moderation_policies(version),
  add column moderation_checked_at timestamptz;

create function public.immutable_moderation_policy() returns trigger
language plpgsql set search_path = public as $$
begin
  if (to_jsonb(new) - 'current') is distinct from (to_jsonb(old) - 'current') then
    raise exception 'publish a new moderation policy version' using errcode = '22023';
  end if;
  return new;
end; $$;
create trigger moderation_policy_immutable before update on public.content_moderation_policies
  for each row execute function public.immutable_moderation_policy();

create function public.require_message_content_policy() returns trigger
language plpgsql security definer set search_path = public as $$
declare policy public.content_moderation_policies; required_terms text; content text;
begin
  -- PostgREST's role is unchanged by SECURITY DEFINER. Existing RLS continues
  -- to govern identity/membership; trusted operator deletion remains available.
  if current_setting('role', true) <> 'authenticated' then return new; end if;
  if tg_table_name = 'messages' and tg_op = 'UPDATE' then
    if new.body is not distinct from old.body then return new; end if;
  end if;
  select version into required_terms from public.service_terms where current for share;
  select * into policy from public.content_moderation_policies where current for share;
  if policy.version is null or policy.terms_version is distinct from required_terms then
    raise exception 'content moderation unavailable' using errcode = '42501';
  end if;
  content := new.body;
  if tg_table_name = 'announcements' then content := new.title || E'\n' || content; end if;
  if char_length(content) > 8161 then
    raise exception 'invalid message length' using errcode = '22023';
  end if;
  content := public.normalize_moderation_text(content);
  if exists (select 1 from unnest(policy.denied_phrases) phrase
    where strpos(content, btrim(public.normalize_moderation_text(phrase))) > 0) then
    -- No body or matching rule is returned, logged or copied into reports.
    raise exception 'message content rejected' using errcode = '42501';
  end if;
  new.moderation_policy_version := policy.version;
  new.moderation_checked_at := clock_timestamp();
  return new;
end; $$;
-- Run after service_terms_write: stale/outbox consent remains the first error.
create trigger zz_content_policy before insert or update on public.messages
  for each row execute function public.require_message_content_policy();
create trigger zz_content_policy before insert or update on public.announcements
  for each row execute function public.require_message_content_policy();
revoke all on function public.normalize_moderation_text(text),
  public.valid_moderation_phrases(text[]), public.immutable_moderation_policy(),
  public.require_message_content_policy() from public, anon, authenticated;
grant execute on function public.normalize_moderation_text(text),
  public.valid_moderation_phrases(text[]) to service_role;
