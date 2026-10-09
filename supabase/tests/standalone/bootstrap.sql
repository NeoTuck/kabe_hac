-- Disposable PGlite-only fixture. Does not reproduce Supabase Auth/Realtime services.
create role authenticated nologin;
create role anon nologin;
create role service_role nologin bypassrls;
grant usage on schema public to service_role;
grant usage on schema public to anon;
create schema auth;
create schema realtime;
create schema extensions;
create table auth.users(id uuid primary key, aud text, role text, email text, encrypted_password text);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create table realtime.messages(id bigint, topic text);
alter table realtime.messages enable row level security;
create function realtime.topic() returns text language sql stable as $$
  select current_setting('realtime.topic', true)
$$;
grant usage on schema public, auth, realtime to authenticated;
create publication supabase_realtime;
