-- OPTIONAL OPERATIONS SCRIPT, NOT AN AUTOMATIC MIGRATION.
-- Run only on a verified test project after migrations and Edge deployment.
-- Enable pg_cron/pg_net first. Put the dedicated job secret and exact verified
-- https://<project-ref>.supabase.co/functions/v1/group-push URL in Vault as:
-- kabe_server_job_secret / kabe_group_push_url. Never paste values into this file.
do $$
begin
  if not exists (select 1 from vault.decrypted_secrets
    where name = 'kabe_server_job_secret' and length(decrypted_secret) >= 32)
    or not exists (select 1 from vault.decrypted_secrets where name = 'kabe_group_push_url'
      and decrypted_secret ~ '^https://[a-z0-9]+\.supabase\.co/functions/v1/group-push$') then
    raise exception 'verified scheduler secrets missing';
  end if;
end;
$$;

-- Named schedules are replaced by pg_cron rather than duplicated.
select cron.schedule('kabe-location-cleanup', '* * * * *',
  'select public.cleanup_expired_locations(100)');
select cron.schedule('kabe-group-push', '* * * * *', $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'kabe_group_push_url'),
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization',
      'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'kabe_server_job_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 90000
  );
$job$);

-- Rollback/kill switch (execute separately after inspecting the target):
-- select cron.unschedule('kabe-group-push');
-- select cron.unschedule('kabe-location-cleanup');
-- Set PUSH_SEND_MODE=disabled and redeploy to stop sends without dropping data.
