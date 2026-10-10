begin;
select plan(55);

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

insert into public.messages (id, group_id, sender_id, recipient_id, client_id, message_type, body)
values ('30000000-0000-0000-0000-000000000001',
 '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003',
 '00000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000005',
 'guide_private', 'C rehbere özel');
insert into public.location_shares (id, group_id, user_id, mode, starts_at, ends_at, retention_until)
values ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000003', 'trip', now() - interval '1 hour', now() + interval '1 hour', now() + interval '1 day');
insert into public.location_updates (share_id, user_id, latitude, longitude, accuracy_meters, measured_at)
values ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003',
 21.4, 39.8, 5, now() - interval '1 minute');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);

select results_eq(
  $$ select name from public.groups order by name $$,
  $$ values ('Test Grup A'::text) $$,
  'A kullanıcısı yalnız kendi grubunu görür'
);

select results_eq(
  $$ select body from public.messages where message_type = 'chat' order by body $$,
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

select throws_ok($$ update public.messages set recipient_id = '00000000-0000-0000-0000-000000000004' where id = '30000000-0000-0000-0000-000000000001' $$, '42501', null, 'Mesaj recipient_id değiştirilemez');
select throws_ok($$ update public.messages set message_type = 'chat' where id = '30000000-0000-0000-0000-000000000001' $$, '42501', null, 'Mesaj message_type değiştirilemez');
select throws_ok($$ update public.messages set group_id = '10000000-0000-0000-0000-000000000002' where id = '30000000-0000-0000-0000-000000000001' $$, '42501', null, 'Mesaj group_id değiştirilemez');
select throws_ok($$ update public.messages set sender_id = '00000000-0000-0000-0000-000000000004' where id = '30000000-0000-0000-0000-000000000001' $$, '42501', null, 'Mesaj sender_id değiştirilemez');
select throws_ok($$ update public.messages set client_id = '20000000-0000-0000-0000-000000000006' where id = '30000000-0000-0000-0000-000000000001' $$, '42501', null, 'Mesaj client_id değiştirilemez');
select throws_ok($$ update public.messages set created_at = now() where id = '30000000-0000-0000-0000-000000000001' $$, '42501', null, 'Mesaj created_at değiştirilemez');
select lives_ok($$ update public.messages set body = 'C düzenledi', deleted_at = now()
 where id = '30000000-0000-0000-0000-000000000001' $$, 'Gönderen metni ve silme zamanını düzenleyebilir');
select is((select body from public.messages where id = '30000000-0000-0000-0000-000000000001'), 'C düzenledi', 'Düzenleme kaydedildi');
select throws_ok($$ update public.location_shares set ends_at = now() + interval '2 days'
 where id = '40000000-0000-0000-0000-000000000001' $$, '42501', null, 'Rıza süresi güncelleme ile uzatılamaz');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.location_updates), 1::bigint, 'Yönetici aktif konumu görür');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select lives_ok($$ update public.location_shares set status = 'stopped', stopped_at = now()
 where id = '40000000-0000-0000-0000-000000000001' $$, 'Kullanıcı paylaşımı durdurabilir');
select throws_ok($$ insert into public.location_updates (share_id, user_id, latitude, longitude, accuracy_meters, measured_at)
 values ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 21, 39, 5, now()) $$,
 '42501', null, 'Durmuş paylaşıma yeni konum eklenemez');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.location_updates), 0::bigint, 'Durdurulan eski konum yöneticiye kapanır');
reset role;
update public.location_shares set status = 'active', stopped_at = null, ends_at = now() - interval '1 second';
set local role authenticated;
select is((select count(*) from public.location_updates), 0::bigint, 'Süresi biten eski konum yöneticiye kapanır');
reset role;
update public.location_shares set ends_at = now() + interval '1 hour', retention_until = now() - interval '1 second';
set local role authenticated;
select is((select count(*) from public.location_updates), 0::bigint, 'Saklama süresi biten konum kapanır');
reset role;
update public.location_shares set retention_until = now() + interval '1 day';
update public.group_members set status = 'removed' where user_id = '00000000-0000-0000-0000-000000000003';
set local role authenticated;
select is((select count(*) from public.location_updates), 0::bigint, 'Çıkarılan üyenin eski konumu yöneticiye kapanır');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select throws_ok($$ insert into public.location_updates (share_id, user_id, latitude, longitude, accuracy_meters, measured_at)
 values ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 21, 39, 5, now()) $$,
 '42501', null, 'Çıkarılan üye aktif rızayla da konum gönderemez');
select lives_ok($$ update public.messages set body = 'yetkisiz düzenleme'
 where id = '30000000-0000-0000-0000-000000000001' $$, 'Üyelik kalkınca UPDATE satırı görünmez');
reset role;
select is((select body from public.messages where id = '30000000-0000-0000-0000-000000000001'), 'C düzenledi', 'Çıkarılan üye eski mesajı değiştiremedi');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select is((select count(*) from public.location_updates), 0::bigint, 'Başka grup yöneticisi konumu göremez');
select is((select count(*) from public.location_shares), 0::bigint, 'Başka grup yöneticisi rızayı göremez');

select throws_ok($$ select public.create_personal_group(' ') $$, '22023', null, 'Boş grup adı reddedilir');
select lives_ok($$ select public.create_personal_group('  MVP Kafile  ') $$, 'Oturumlu kullanıcı atomik kafile oluşturur');
select is((select count(*) from public.groups where name = 'MVP Kafile'), 1::bigint, 'Grup adı normalize edilerek saklanır');
select is((select role from public.group_members where group_id = (select id from public.groups where name = 'MVP Kafile') and user_id = auth.uid()), 'group_admin', 'İlk kullanıcı yalnız kendi grubunun yöneticisi olur');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.groups where name = 'MVP Kafile'), 0::bigint, 'Başka kullanıcının yeni kafilesi görünmez');
select set_config('request.jwt.claim.sub', '', true);
select throws_ok($$ select public.create_personal_group('Yetkisiz') $$, '42501', null, 'JWT olmadan bootstrap çalışmaz');
reset role;
set local role anon;
select throws_ok($$ select public.create_personal_group('Anonim') $$, '42501', null, 'Anonim rol RPC çalıştıramaz');
reset role;

-- Fixed-time history fixtures exercise equal timestamp boundaries under RLS.
insert into public.messages (id, group_id, sender_id, client_id, body, created_at)
values
 ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 'history tie 1', '2020-01-01T00:00:00.123456Z'),
 ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'history tie 2', '2020-01-01T00:00:00.123456Z'),
 ('50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000004', 'history older', '2019-01-01T00:00:00Z');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select results_eq(
 $$ select body from public.messages where group_id = '10000000-0000-0000-0000-000000000001'
 and (created_at < '2020-01-01T00:00:00.123456Z' or (created_at = '2020-01-01T00:00:00.123456Z' and id < '50000000-0000-0000-0000-000000000003'))
 order by created_at desc, id desc limit 50 $$,
 $$ values ('history tie 2'::text), ('history tie 1'::text), ('history older'::text) $$,
 'History includes equal timestamps using the ID tie-breaker');
select results_eq(
 $$ select body from public.messages where group_id = '10000000-0000-0000-0000-000000000001'
 and (created_at < '2020-01-01T00:00:00.123456Z' or (created_at = '2020-01-01T00:00:00.123456Z' and id < '50000000-0000-0000-0000-000000000001'))
 order by created_at desc, id desc limit 50 $$,
 $$ values ('history older'::text) $$,
 'Next history page does not repeat its cursor message');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select is((select count(*) from public.messages where group_id = '10000000-0000-0000-0000-000000000001'
 and created_at <= '2020-01-01T00:00:00.123456Z'), 0::bigint, 'Another group cannot read old history');
reset role;

-- Personal blocking and reports stay inside the current group and JWT user.
insert into public.device_push_tokens (user_id, platform, token)
values ('00000000-0000-0000-0000-000000000001', 'android', 'block-test-token');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
select lives_ok($$ insert into public.messages (id, group_id, sender_id, client_id, body)
 values ('70000000-0000-0000-0000-000000000001',
 '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004',
 '71000000-0000-0000-0000-000000000001', 'D mesajı') $$,
 'Aktif üye genel mesaj yazabilir');
reset role;
select is((select public.push_delivery_allowed(d) from public.push_deliveries d
 where d.source_id = '70000000-0000-0000-0000-000000000001'), true,
 'Engel yokken mesaj bildirimi teslim edilebilir');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select lives_ok($$ insert into public.message_reports (message_id, group_id, reporter_id, reason)
 values ('70000000-0000-0000-0000-000000000001',
 '10000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000001', 'spam') $$,
 'Görünen başka üyenin mesajı şikâyet edilebilir');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select throws_ok($$ insert into public.message_reports (message_id, group_id, reporter_id, reason)
 values ('70000000-0000-0000-0000-000000000001',
 '10000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000002', 'spam') $$,
 '42501', null, 'Başka kafilenin mesajı şikâyet edilemez');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select lives_ok($$ insert into public.user_blocks (blocker_id, blocked_id) values
 ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004') $$,
 'Aynı kafiledeki kullanıcı engellenebilir');
reset role;
select is((select public.push_delivery_allowed(d) from public.push_deliveries d
 where d.source_id = '70000000-0000-0000-0000-000000000001'), false,
 'Engellenen kişinin kuyruktaki bildirimi teslim edilmez');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.messages where id = '70000000-0000-0000-0000-000000000001'),
 0::bigint, 'Engellenen gönderenin eski mesajı gizlenir');
select throws_ok($$ insert into public.messages (group_id, sender_id, recipient_id, client_id, message_type, body)
 values ('10000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004',
 '71000000-0000-0000-0000-000000000002', 'guide_private', 'özel') $$,
 '42501', null, 'Engelleyen kullanıcı özel mesaj gönderemez');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
select throws_ok($$ insert into public.messages (group_id, sender_id, recipient_id, client_id, message_type, body)
 values ('10000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001',
 '71000000-0000-0000-0000-000000000003', 'guide_private', 'özel') $$,
 '42501', null, 'Engellenen kullanıcı özel mesaj gönderemez');
reset role;
update public.group_members set status = 'removed'
 where group_id = '10000000-0000-0000-0000-000000000001' and user_id = '00000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.messages where group_id = '10000000-0000-0000-0000-000000000001'
 and created_at <= '2020-01-01T00:00:00.123456Z'), 0::bigint, 'Removed member cannot read old history');
reset role;

insert into public.location_shares (id, group_id, user_id, mode, starts_at, ends_at, retention_until)
values ('40000000-0000-0000-0000-000000000004',
 '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004',
 'trip', now(), now() + interval '1 hour', now() + interval '1 day');
insert into public.device_push_tokens (user_id, platform, token)
values ('00000000-0000-0000-0000-000000000004', 'android', 'delete-test-token');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
select lives_ok($$ insert into public.account_deletion_requests (user_id)
 values ('00000000-0000-0000-0000-000000000004') $$,
 'Kullanıcı hesap silme isteği gönderebilir');
select is((select count(*) from public.account_deletion_requests), 1::bigint,
 'Kullanıcı kendi silme isteğini görür');
select is((select count(*) from public.location_shares where status = 'active'), 0::bigint,
 'Silme isteği aktif konumu durdurur');
select is((select count(*) from public.device_push_tokens), 0::bigint,
 'Silme isteği bildirim tokenını kaldırır');
select throws_ok($$ insert into public.location_shares (group_id, user_id, mode, ends_at, retention_until)
 values ('10000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000004', 'trip', now() + interval '1 hour', now() + interval '1 day') $$,
 '42501', null, 'Silme isteğinden sonra konum yeniden açılamaz');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select is((select count(*) from public.account_deletion_requests), 0::bigint,
 'Başka kullanıcı silme isteğini göremez');
select throws_ok($$ insert into public.account_deletion_requests (user_id)
 values ('00000000-0000-0000-0000-000000000004') $$,
 '42501', null, 'Başka kullanıcı adına silme isteği açılamaz');
reset role;

select * from finish();
rollback;
