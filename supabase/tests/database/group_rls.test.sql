begin;
select plan(7);

insert into auth.users (id, aud, role, email, encrypted_password)
values
  ('00000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'a@example.test', ''),
  ('00000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'b@example.test', ''),
  ('00000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'c@example.test', ''),
  ('00000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'd@example.test', '');

insert into public.groups (id, name, created_by)
values
  ('10000000-0000-0000-0000-000000000001', 'Test Grup A', '00000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000002', 'Test Grup B', '00000000-0000-0000-0000-000000000002');

insert into public.group_members (group_id, user_id, role)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'group_admin'),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'member'),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'member'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'group_admin');

insert into public.messages (group_id, sender_id, client_id, body)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'A mesajı'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'B mesajı');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);

select results_eq(
  $$ select name from public.groups order by name $$,
  $$ values ('Test Grup A'::text) $$,
  'A kullanıcısı yalnız kendi grubunu görür'
);

select results_eq(
  $$ select body from public.messages order by body $$,
  $$ values ('A mesajı'::text) $$,
  'A kullanıcısı B grubunun mesajını göremez'
);

select throws_ok(
  $$ insert into public.messages (group_id, sender_id, client_id, body)
     values ('10000000-0000-0000-0000-000000000002',
             '00000000-0000-0000-0000-000000000001',
             '20000000-0000-0000-0000-000000000003', 'yetkisiz') $$,
  '42501',
  null,
  'Üye olmadığı gruba mesaj yazamaz'
);

select ok(
  public.is_group_member(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000003'
  ),
  'C kullanıcısı A grubunun aktif üyesidir'
);

select ok(
  public.can_manage_group(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001'
  ),
  'A yöneticisi kendi grubunu yönetebilir'
);

select is(
  public.group_id_from_realtime_topic('public-room'),
  null,
  'Geçersiz Realtime konusu grup kimliği üretmez'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$ insert into public.messages (
       group_id, sender_id, recipient_id, client_id, message_type, body
     ) values (
       '10000000-0000-0000-0000-000000000001',
       '00000000-0000-0000-0000-000000000003',
       '00000000-0000-0000-0000-000000000004',
       '20000000-0000-0000-0000-000000000004',
       'guide_private',
       'rehber olmayan üyeye özel mesaj'
     ) $$,
  '42501',
  null,
  'Özel mesajın bir tarafı rehber veya grup yöneticisi olmalı'
);

select * from finish();
rollback;
