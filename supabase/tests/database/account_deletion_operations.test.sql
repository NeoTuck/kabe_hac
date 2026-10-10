begin;
select plan(12);

insert into auth.users (id, aud, role, email, encrypted_password) values
  ('80000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'reporter@example.test', ''),
  ('80000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'author@example.test', ''),
  ('80000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'deletable@example.test', '');
insert into public.groups (id, name, created_by) values
  ('80000000-0000-0000-0000-000000000004', 'Deletion test',
   '80000000-0000-0000-0000-000000000002');
insert into public.group_members (group_id, user_id, role) values
  ('80000000-0000-0000-0000-000000000004', '80000000-0000-0000-0000-000000000001', 'member'),
  ('80000000-0000-0000-0000-000000000004', '80000000-0000-0000-0000-000000000002', 'group_admin');
insert into public.messages (id, group_id, sender_id, client_id, body) values
  ('80000000-0000-0000-0000-000000000005',
   '80000000-0000-0000-0000-000000000004',
   '80000000-0000-0000-0000-000000000002',
   '80000000-0000-0000-0000-000000000006', 'Reported message');
insert into public.message_reports (id, message_id, group_id, reporter_id, reason) values
  ('80000000-0000-0000-0000-000000000007',
   '80000000-0000-0000-0000-000000000005',
   '80000000-0000-0000-0000-000000000004',
   '80000000-0000-0000-0000-000000000001', 'spam');
insert into public.account_deletion_requests (id, user_id) values
  ('80000000-0000-0000-0000-000000000008',
   '80000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
select throws_ok($$ select public.inspect_account_deletion(
  '80000000-0000-0000-0000-000000000008') $$,
  '42501', null, 'A user cannot inspect the server deletion operation');
select throws_ok($$ select public.create_personal_group('New group') $$,
  '23514', null, 'Security-definer group creation cannot bypass a deletion request');
reset role;

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select is((public.inspect_account_deletion(
  '80000000-0000-0000-0000-000000000008')->>'ready')::boolean,
  false, 'Moderation evidence blocks deletion preview');
select is((public.account_deletion_blockers(
  '80000000-0000-0000-0000-000000000001')->>'moderation_reports')::integer,
  1, 'Preview counts the report that account deletion would cascade');
select is((public.prepare_account_deletion(
  '80000000-0000-0000-0000-000000000008')->>'ready')::boolean,
  false, 'Server preparation refuses report loss');
reset role;

select throws_ok($$ delete from auth.users where id =
  '80000000-0000-0000-0000-000000000001' $$,
  '23503', null, 'Auth deletion cannot cascade away a report');
select throws_ok($$ insert into public.groups(name, created_by) values
  ('Another group', '80000000-0000-0000-0000-000000000001') $$,
  '23514', null, 'Direct group insertion cannot bypass the deletion lock');
select throws_ok($$ update public.groups set created_by =
  '80000000-0000-0000-0000-000000000001' where id =
  '80000000-0000-0000-0000-000000000004' $$,
  '23514', null, 'Existing group cannot be reassigned to a deletion requester');

insert into public.account_deletion_requests (id, user_id) values
  ('80000000-0000-0000-0000-000000000009',
   '80000000-0000-0000-0000-000000000003');
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select is((public.prepare_account_deletion(
  '80000000-0000-0000-0000-000000000009')->>'ready')::boolean,
  true, 'Unencumbered account can be prepared');
reset role;
select is((select status from public.account_deletion_operations where request_id =
  '80000000-0000-0000-0000-000000000009'),
  'processing', 'Preparation leaves a durable operation record');
select lives_ok($$ delete from auth.users where id =
  '80000000-0000-0000-0000-000000000003' $$,
  'Unencumbered Auth user can be removed');
select is((select count(*) from public.account_deletion_requests where id =
  '80000000-0000-0000-0000-000000000009'),
  0::bigint, 'Auth deletion cascades the original request');

select * from finish();
rollback;
