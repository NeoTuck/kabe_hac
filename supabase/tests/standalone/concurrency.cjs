// Real disposable PostgreSQL locking tests. Not Supabase Auth/HTTP/Realtime acceptance.
const { Client } = require('pg');
const { readFileSync, readdirSync } = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const user = '00000000-0000-0000-0000-000000000003';
const admin = '00000000-0000-0000-0000-000000000001';
const group = '10000000-0000-0000-0000-000000000001';
async function main() {
  if (process.env.GITHUB_ACTIONS !== 'true' && process.env.KABE_DISPOSABLE_DB !== 'true') throw new Error('Explicit disposable database required');
  // Fixed local fixture DB only; never uses a live DATABASE_URL.
  const clients = Array.from({ length: 3 }, () => new Client({ host: '/var/run/postgresql', user: 'postgres', database: 'kabe_concurrency' }));
  const [a,b,observer] = clients;
  let checks = 0;
  const ok = label => { checks++; console.log(`ok ${checks} - ${label}`); };
  const insert = id => b.query(`insert into public.location_updates(share_id,user_id,latitude,longitude,accuracy_meters,measured_at)
    values ($1,$2,21,39,5,clock_timestamp())`, [id,user]);
  const beginMember = async () => {
    await b.query('begin'); await b.query('set local role authenticated');
    await b.query("select set_config('request.jwt.claim.sub',$1,true)", [user]);
  };
  const share = async () => (await observer.query(`insert into public.location_shares
    (group_id,user_id,mode,starts_at,ends_at,retention_until) values ($1,$2,'one_time',clock_timestamp()-interval '1 minute',
      clock_timestamp()+interval '15 minutes',clock_timestamp()+interval '1 day') returning id`, [group,user])).rows[0].id;
  const blocked = async pid => {
    const deadline = Date.now()+5000;
    while (Date.now() < deadline) {
      const rows = (await observer.query("select wait_event_type from pg_stat_activity where pid=$1", [pid])).rows;
      if (rows[0]?.wait_event_type === 'Lock') return;
      await new Promise(resolve => setTimeout(resolve,20));
    }
    throw new Error('Expected transaction lock was not observed');
  };
  try {
    await Promise.all(clients.map(c => c.connect()));
    await observer.query(readFileSync(path.join(__dirname,'bootstrap.sql'),'utf8'));
    for (const f of readdirSync(path.join(root,'migrations')).filter(f => f.endsWith('.sql')).sort()) await observer.query(readFileSync(path.join(root,'migrations',f),'utf8'));
    await observer.query('insert into auth.users(id) values ($1),($2)', [user,admin]);
    await observer.query('insert into public.groups(id,name,created_by) values ($1,\'concurrency fixture\',$2)', [group,admin]);
    await observer.query('insert into public.group_members(group_id,user_id,role) values ($1,$2,\'member\'),($1,$3,\'group_admin\')', [group,user,admin]);
    const aPid = (await a.query('select pg_backend_pid() as pid')).rows[0].pid;
    const bPid = (await b.query('select pg_backend_pid() as pid')).rows[0].pid;

    const first = await share();
    await a.query('begin');
    await a.query('update public.location_shares set status=\'stopped\',stopped_at=clock_timestamp() where id=$1',[first]);
    await beginMember();
    const denied = insert(first).then(() => null, e => e);
    await blocked(bPid); await a.query('commit');
    assert.equal((await denied)?.code,'42501'); await b.query('rollback');
    ok('revocation first: concurrent insertion blocks and is rejected after commit');

    const second = await share();
    await beginMember(); await insert(second);
    await a.query('begin');
    const stop = a.query('update public.location_shares set status=\'stopped\',stopped_at=clock_timestamp() where id=$1',[second]);
    await blocked(aPid); await b.query('commit'); await stop; await a.query('commit');
    await a.query('begin'); await a.query('set local role authenticated');
    await a.query("select set_config('request.jwt.claim.sub',$1,true)",[admin]);
    assert.equal((await a.query('select count(*)::int as count from public.location_updates')).rows[0].count,0);
    await a.query('rollback');
    ok('insertion first: cancellation serializes and coordinates immediately disappear under RLS');

    const third = await share();
    await a.query('begin');
    await a.query('update public.group_members set status=\'removed\' where group_id=$1 and user_id=$2',[group,user]);
    await beginMember(); const removed = insert(third).then(() => null,e => e);
    await blocked(bPid); await a.query('commit');
    assert.equal((await removed)?.code,'42501'); await b.query('rollback');
    ok('membership removal first: concurrent insertion cannot use old membership');
    await observer.query('update public.group_members set status=\'active\' where group_id=$1 and user_id=$2',[group,user]);
    assert.equal((await observer.query('select status from public.location_shares where id=$1',[third])).rows[0].status,'stopped');
    ok('rejoining does not restore revoked consent');

    await observer.query('insert into public.device_push_tokens(user_id,platform,token) values ($1,\'android\',\'concurrency-token\')',[user]);
    for (let i=0;i<2;i++) await observer.query(`insert into public.messages(group_id,sender_id,client_id,body)
      values ($1,$2,gen_random_uuid(),'fixture')`,[group,admin]);
    await a.query('begin'); const claimA = (await a.query('select * from public.claim_push_deliveries(1)')).rows[0];
    await b.query('begin'); const claimB = (await b.query('select * from public.claim_push_deliveries(1)')).rows[0];
    assert.notEqual(claimA.id,claimB.id); await a.query('commit'); await b.query('commit');
    ok('two workers claim different jobs with SKIP LOCKED');
    console.log(`PASS ${checks} PostgreSQL concurrency checks`);
  } finally {
    await Promise.all(clients.map(async c => { await c.query('rollback').catch(() => {}); await c.end().catch(() => {}); }));
  }
}
main().catch(e => { console.error(e.message); process.exitCode=1; });
