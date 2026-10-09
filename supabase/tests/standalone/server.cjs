// Disposable PostgreSQL fixture, not live Supabase/Auth/Realtime acceptance.
const { PGlite } = require('@electric-sql/pglite');
const { pgcrypto } = require('@electric-sql/pglite/contrib/pgcrypto');
const { readFileSync, readdirSync } = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const uid = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const gid = n => `10000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
async function main() {
  const pg = new PGlite({ extensions: { pgcrypto } });
  let checks = 0;
  const query = async (sql, args = []) => (await pg.query(sql, args)).rows;
  const check = (actual, expected, label) => { assert.deepEqual(actual, expected, label); checks++; console.log(`ok ${checks} - ${label}`); };
  const denied = async (sql, args, label) => {
    await assert.rejects(query(sql, args), error => error.code === '42501', label); checks++; console.log(`ok ${checks} - ${label}`);
  };
  const scalar = async sql => Object.values((await query(sql))[0])[0];
  const role = async n => { await pg.exec('set role authenticated'); await query("select set_config('request.jwt.claim.sub', $1, false)", [uid(n)]); };
  const reset = () => pg.exec('reset role');
  const message = async (sender, recipient = null, group = 1) => (await query(`insert into public.messages
    (group_id, sender_id, recipient_id, client_id, message_type, body) values ($1,$2,$3,gen_random_uuid(),$4,'sensitive fixture') returning id`,
    [gid(group), uid(sender), recipient ? uid(recipient) : null, recipient ? 'guide_private' : 'chat']))[0].id;
  try {
    await pg.exec(readFileSync(path.join(__dirname, 'bootstrap.sql'), 'utf8'));
    for (const f of readdirSync(path.join(root, 'migrations')).filter(f => f.endsWith('.sql')).sort()) await pg.exec(readFileSync(path.join(root, 'migrations', f), 'utf8'));
    for (let n = 1; n <= 4; n++) await query('insert into auth.users(id) values ($1)', [uid(n)]);
    for (let n = 1; n <= 2; n++) await query('insert into public.groups(id,name,created_by) values ($1,$2,$3)', [gid(n), `Fixture ${n}`, uid(n)]);
    for (const [g, u, r] of [[1,1,'group_admin'],[1,3,'member'],[1,4,'member'],[2,2,'group_admin']]) {
      await query('insert into public.group_members(group_id,user_id,role) values ($1,$2,$3)', [gid(g),uid(u),r]);
      await query('insert into public.device_push_tokens(user_id,platform,token) values ($1,\'android\',$2)', [uid(u), `fixture-${u}`]);
    }
    await role(3);
    await denied('select * from public.claim_push_deliveries(5)', [], 'client cannot claim jobs');
    await denied('select public.cleanup_expired_locations(100)', [], 'client cannot clean location');
    await denied('select * from public.push_deliveries', [], 'client cannot inspect token recipients');
    await denied('insert into public.messages(group_id,sender_id,client_id,body) values ($1,$2,gen_random_uuid(),\'forged\')', [gid(2),uid(3)], 'cross-group forged source blocked');
    await denied('insert into public.announcements(group_id,author_id,title,body) values ($1,$2,\'forged\',\'forged\')', [gid(1),uid(3)], 'ordinary member cannot announce');
    const privateId = await message(3,1);
    await reset();
    check(await scalar(`select count(*)::int from public.push_deliveries where source_id = '${privateId}'`), 1, 'private message targets only other party');
    const chatId = await message(1);
    check(await scalar(`select count(*)::int from public.push_deliveries where source_id = '${chatId}'`), 2, 'chat excludes sender and other group');
    await query(`insert into public.messages(group_id,sender_id,client_id,body)
      select group_id,sender_id,client_id,body from public.messages where id=$1
      on conflict(sender_id,client_id) do nothing`, [chatId]);
    check(await scalar(`select count(*)::int from public.push_deliveries where source_id = '${chatId}'`), 2, 'offline replay does not enqueue duplicate sends');
    const announcement = (await query(`insert into public.announcements(group_id,author_id,title,body)
      values ($1,$2,'fixture','private fixture') returning id`, [gid(1),uid(1)]))[0].id;
    check(await scalar(`select count(*)::int from public.push_deliveries where source_id='${announcement}'`), 2, 'announcement uses current group recipients');
    const program = (await query(`insert into public.group_programs(group_id,created_by,version,title,program_date,document)
      values ($1,$2,1,'fixture',current_date,'{}') returning id`, [gid(1),uid(1)]))[0].id;
    check(await scalar(`select count(*)::int from public.push_deliveries where source_id='${program}'`), 2, 'program notification uses authorized source');
    await query('update public.push_deliveries set status=\'cancelled\' where source_id=any($1::uuid[])', [[announcement,program]]);
    await query(`update public.device_push_tokens set enabled=false where user_id=$1`, [uid(4)]);
    const disabledId = await message(1);
    check(await scalar(`select count(*)::int from public.push_deliveries where source_id='${disabledId}'`), 1, 'disabled preference excluded');
    const first = (await query(`select * from public.claim_push_deliveries(1)`))[0];
    const second = (await query(`select * from public.claim_push_deliveries(1)`))[0];
    check(first.id !== second.id, true, 'active lease not claimed twice');
    check((await query('select * from public.prepare_push_delivery($1,gen_random_uuid())', [first.id])).length, 0, 'wrong lease cannot fetch token');
    check((await query('select * from public.prepare_push_delivery($1,null)', [first.id])).length, 0, 'null lease cannot fetch token');
    check(await scalar(`select public.finish_push_delivery(${first.id},gen_random_uuid(),'provider_accepted','FCM_ACCEPTED',60)`), false, 'wrong lease cannot acknowledge');
    const prepared = (await query('select * from public.prepare_push_delivery($1,$2)', [first.id,first.lease_id]))[0];
    check(prepared.user_id, uid(1), 'prepared private recipient server-derived');
    await query('select public.finish_push_delivery($1,$2,\'provider_accepted\',\'FCM_ACCEPTED\',60)', [first.id,first.lease_id]);
    check(await scalar(`select status from public.push_deliveries where id=${first.id}`), 'provider_accepted', 'acceptance never labelled device delivered');
    await query('update public.group_members set status=\'removed\' where group_id=$1 and user_id=$2', [gid(1),uid(3)]);
    check((await query('select * from public.prepare_push_delivery($1,$2)', [second.id,second.lease_id])).length, 0, 'removed member invalidates pending lease');
    await query('update public.group_members set status=\'active\' where group_id=$1 and user_id=$2', [gid(1),uid(3)]);
    check((await query('select * from public.prepare_push_delivery($1,$2)', [second.id,second.lease_id])).length, 0, 'rejoin cannot reactivate cancelled lease');
    const retryId = await message(1);
    await pg.exec("update public.push_deliveries set status='cancelled' where status in ('pending','leased') and source_id <> '" + retryId + "'");
    let retry = (await query('select * from public.claim_push_deliveries(1)'))[0];
    await query('select public.finish_push_delivery($1,$2,\'retry\',\'HTTP_503\',120)', [retry.id,retry.lease_id]);
    check((await query('select * from public.claim_push_deliveries(1)')).length, 0, 'backoff prevents immediate retry');
    for (let i = 2; i <= 5; i++) {
      await query('update public.push_deliveries set next_attempt_at=now()-interval \'1 second\' where id=$1', [retry.id]);
      retry = (await query('select * from public.claim_push_deliveries(1)'))[0];
      await query('select public.finish_push_delivery($1,$2,\'retry\',\'HTTP_503\',60)', [retry.id,retry.lease_id]);
    }
    check(await scalar(`select status from public.push_deliveries where id=${retry.id}`), 'exhausted', 'five failures terminate retries');
    const invalidId = await message(1);
    const invalid = (await query('select * from public.claim_push_deliveries(1)'))[0];
    await query('select public.finish_push_delivery($1,$2,\'invalid_token\',\'UNREGISTERED\',60)', [invalid.id,invalid.lease_id]);
    check(await scalar(`select enabled from public.device_push_tokens where user_id='${uid(3)}'`), false, 'unregistered token disabled');
    check(await scalar(`select status from public.push_deliveries where id=${invalid.id}`), 'permanent_failure', 'permanent failure no longer blocks queue');
    await query('update public.device_push_tokens set enabled=true where user_id=$1', [uid(3)]);
    const refreshedId = await message(1);
    const refresh = (await query('select * from public.claim_push_deliveries(1)'))[0];
    await query('update public.device_push_tokens set token=\'fixture-renewed\' where user_id=$1', [uid(3)]);
    await query('select public.finish_push_delivery($1,$2,\'invalid_token\',\'UNREGISTERED\',60)', [refresh.id,refresh.lease_id]);
    check(await scalar(`select enabled from public.device_push_tokens where user_id='${uid(3)}'`), true, 'late old-token failure cannot revoke renewed token');
    await query('insert into public.device_push_tokens(user_id,platform,token) values ($1,\'android\',\'fixture-renewed\')', [uid(2)]);
    const ambiguousId = await message(1);
    check(await scalar(`select count(*)::int from public.push_deliveries where source_id='${ambiguousId}'`), 0, 'ambiguous cross-account device fails closed');

    const share = (await query(`insert into public.location_shares(group_id,user_id,mode,starts_at,ends_at,retention_until)
      values ($1,$2,'one_time',now()-interval '1 minute',now()+interval '15 minutes',now()+interval '1 day') returning id`, [gid(1),uid(3)]))[0].id;
    await role(3);
    await query('insert into public.location_updates(share_id,user_id,latitude,longitude,accuracy_meters,measured_at) values ($1,$2,21,39,5,now())', [share,uid(3)]);
    await query('update public.location_shares set status=\'stopped\',stopped_at=now() where id=$1', [share]);
    await denied('insert into public.location_updates(share_id,user_id,latitude,longitude,accuracy_meters,measured_at) values ($1,$2,21,39,5,now())', [share,uid(3)], 'post-cancellation insert rejected');
    await reset();
    await role(1);
    check(await scalar('select count(*)::int from public.location_updates'), 0, 'cancelled coordinate inaccessible before cleanup');
    await reset();
    await query('update public.location_shares set status=\'active\',stopped_at=null,ends_at=now() where id=$1', [share]);
    await role(1);
    check(await scalar('select count(*)::int from public.location_updates'), 0, 'exact expiry boundary inaccessible');
    await reset();
    await query('update public.location_shares set ends_at=now()+interval \'1 hour\',retention_until=now() where id=$1', [share]);
    await role(3);
    check(await scalar('select count(*)::int from public.location_updates'), 0, 'expired retention inaccessible even to owner');
    await reset();
    check(await scalar('select public.cleanup_expired_locations(1)'), 1, 'cleanup deletes expired coordinate within row batch');
    check(await scalar('select public.cleanup_expired_locations(1)'), 0, 'cleanup repeat is idempotent');
    await query('update public.location_shares set retention_until=now()+interval \'1 day\' where id=$1', [share]);
    await query('insert into public.location_updates(share_id,user_id,latitude,longitude,accuracy_meters,measured_at) values ($1,$2,21,39,5,now())', [share,uid(3)]);
    check(await scalar('select public.cleanup_expired_locations(1)'), 0, 'cleanup preserves valid active coordinate');
    await query('update public.group_members set status=\'removed\' where group_id=$1 and user_id=$2', [gid(1),uid(3)]);
    check(await scalar(`select status from public.location_shares where id='${share}'`), 'stopped', 'removal permanently stops consent');
    await query('update public.group_members set status=\'active\' where group_id=$1 and user_id=$2', [gid(1),uid(3)]);
    await role(1);
    check(await scalar('select count(*)::int from public.location_updates'), 0, 'rejoin cannot restore old location exposure');
    await reset();
    await query('update public.location_retention_policy set seconds_after_end=3600');
    const policy = (await query(`insert into public.location_shares(group_id,user_id,mode,ends_at,retention_until)
      values ($1,$2,'one_time',now()+interval '15 minutes',now()+interval '30 days') returning extract(epoch from retention_until-ends_at)::int as seconds`, [gid(1),uid(3)]))[0];
    check(policy.seconds, 3600, 'configured server policy overrides excessive client retention');
    await query('delete from public.device_push_tokens where user_id=$1', [uid(2)]);
    const leaseSource = await message(1);
    let lease = (await query('select * from public.claim_push_deliveries(1)'))[0];
    await query('update public.push_deliveries set lease_until=clock_timestamp()-interval \'1 second\' where id=$1', [lease.id]);
    check(await scalar(`select public.finish_push_delivery(${lease.id},'${lease.lease_id}','provider_accepted','FCM_ACCEPTED',60)`), false, 'expired worker cannot acknowledge');
    const renewedLease = (await query('select * from public.claim_push_deliveries(1)'))[0];
    check(renewedLease.lease_id !== lease.lease_id, true, 'expired lease recovered with new ownership');
    await query('update public.messages set deleted_at=clock_timestamp() where id=$1', [leaseSource]);
    check((await query('select * from public.prepare_push_delivery($1,$2)', [renewedLease.id,renewedLease.lease_id])).length, 0, 'deleted source cancelled at send preparation');
    const batchShare = (await query(`insert into public.location_shares(group_id,user_id,mode,starts_at,ends_at,retention_until)
      values ($1,$2,'one_time',now()-interval '1 minute',now()+interval '15 minutes',now()+interval '1 day') returning id`, [gid(1),uid(3)]))[0].id;
    for (const seconds of [10,20]) await query(`insert into public.location_updates(share_id,user_id,latitude,longitude,accuracy_meters,measured_at)
      values ($1,$2,21,39,5,now()-make_interval(secs => $3))`, [batchShare,uid(3),seconds]);
    await query('update public.group_members set status=\'removed\' where group_id=$1 and user_id=$2', [gid(1),uid(1)]);
    await role(1);
    check(await scalar('select count(*)::int from public.location_updates'), 0, 'removed original creator cannot view active member coordinates');
    await reset();
    await query('update public.location_shares set retention_until=now() where id=$1', [batchShare]);
    check(await scalar('select public.cleanup_expired_locations(1)'), 1, 'cleanup honors one-row bound on multi-row share');
    check(await scalar(`select count(*)::int from public.location_updates where share_id='${batchShare}'`), 1, 'remaining expired coordinate waits for next bounded batch');
    check(await scalar('select public.cleanup_expired_locations(1)'), 1, 'next cleanup drains remaining expired coordinate');
    console.log(`PASS ${checks} disposable server SQL checks; live service and concurrency acceptance pending.`);
  } finally { await pg.close(); }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
