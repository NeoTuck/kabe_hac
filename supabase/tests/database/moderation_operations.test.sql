begin;
select plan(10);

insert into auth.users (id, aud, role, email, encrypted_password) values
  ('90000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'reporter@example.test', ''),
  ('90000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'sender@example.test', '');
insert into public.groups (id, name, created_by) values
  ('90000000-0000-0000-0000-000000000003', 'Moderation test',
   '90000000-0000-0000-0000-000000000001');
insert into public.group_members (group_id, user_id, role) values
  ('90000000-0000-0000-0000-000000000003', '90000000-0000-0000-0000-000000000001', 'group_admin'),
  ('90000000-0000-0000-0000-000000000003', '90000000-0000-0000-0000-000000000002', 'member');
insert into public.messages (id, group_id, sender_id, client_id, body) values
  ('90000000-0000-0000-0000-000000000004', '90000000-0000-0000-0000-000000000003',
   '90000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000005', 'Test body');
insert into public.message_reports (id, message_id, group_id, reporter_id, reason) values
  ('90000000-0000-0000-0000-000000000006', '90000000-0000-0000-0000-000000000004',
   '90000000-0000-0000-0000-000000000003', '90000000-0000-0000-0000-000000000001', 'spam');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
select throws_ok($$ select * from public.list_moderation_reports(5) $$,
  '42501', null, 'A user cannot list all reports');
select throws_ok($$ select public.record_moderation_review(
  '90000000-0000-0000-0000-000000000006', 'pending', 'claimed', 'operator', 'test') $$,
  '42501', null, 'A user cannot review a report');
reset role;

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select is((select count(*) from public.list_moderation_reports(5)
  where report_id = '90000000-0000-0000-0000-000000000006'),
  1::bigint, 'Service role sees pending report');
select is(public.record_moderation_review(
  '90000000-0000-0000-0000-000000000006', 'pending', 'claimed', 'operator', 'Assigned for review'),
  true, 'Operator claims report');
select is((select count(*) from public.list_moderation_reports(5, 'reviewing')
  where report_id = '90000000-0000-0000-0000-000000000006'),
  1::bigint, 'Reviewing reports use a separate queue');
select is(public.record_moderation_review(
  '90000000-0000-0000-0000-000000000006', 'pending', 'claimed', 'operator', 'Stale claim'),
  false, 'Stale claim does not overwrite review');
select is(public.record_moderation_review(
  '90000000-0000-0000-0000-000000000006', 'reviewing', 'no_violation', 'operator', 'Checked against policy'),
  true, 'Operator closes reviewed report');
select throws_ok($$ select public.record_moderation_review(
  '90000000-0000-0000-0000-000000000006', 'resolved', 'claimed', 'operator', 'Invalid') $$,
  'P0001', null, 'Resolved report cannot be claimed');
reset role;

select is((select status from public.message_reports
  where id = '90000000-0000-0000-0000-000000000006'),
  'resolved', 'Final report status is resolved');
select is((select count(*) from public.message_report_audit
  where report_id = '90000000-0000-0000-0000-000000000006'),
  2::bigint, 'Only successful transitions were audited');
select * from finish();
rollback;
