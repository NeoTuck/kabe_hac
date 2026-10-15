begin;
select no_plan();
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
insert into public.groups(id,name,created_by) values
 ('10000000-0000-0000-0000-000000000001','TEST ONLY','00000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002','OTHER TEST ONLY','00000000-0000-0000-0000-000000000002');
insert into public.group_members(group_id,user_id,role) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','group_admin'),
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','member');
insert into public.service_terms(version,body,document_url,document_sha256,current)
 values('qa-terms-v1','TEST ONLY','https://example.test/terms',repeat('a',64),true);
insert into public.service_terms_acceptances(user_id,terms_version) select id,'qa-terms-v1' from auth.users;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select throws_ok($$insert into public.messages(group_id,sender_id,client_id,body)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),gen_random_uuid(),'benign')$$,
 '42501','content moderation unavailable','no trusted policy means fail closed');
select throws_ok($$select * from public.content_moderation_policies$$,'42501',null,'clients cannot read private rule catalog');
select throws_ok($$insert into public.content_moderation_policies(version,terms_version,denied_phrases,policy_document_url,policy_document_sha256,current)
 values('forged','qa-terms-v1',array['irrelevant'],'https://example.test/forged',repeat('b',64),true)$$,
 '42501',null,'client cannot invent current rules');
reset role;
select throws_ok($$insert into public.content_moderation_policies(version,terms_version,denied_phrases,policy_document_url,policy_document_sha256,current)
 values('empty','qa-terms-v1',array[]::text[],'https://example.test/empty',repeat('b',64),true)$$,
 '23514',null,'empty rules cannot enable posting');
insert into public.content_moderation_policies(version,terms_version,denied_phrases,policy_document_url,policy_document_sha256,current)
 values('qa-policy-v1','qa-terms-v1',array['QA-BLOCKED-TEXT','qa phrase','qa%literal'],'https://example.test/policy',repeat('b',64),true);
select throws_ok($$update public.content_moderation_policies set denied_phrases=array['different']$$,
 '22023','publish a new moderation policy version','operator must version changed rules');
set local role authenticated;
select throws_ok($$insert into public.messages(group_id,sender_id,client_id,body)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),gen_random_uuid(),'qA-bLoCkEd-TeXt')$$,
 '42501','message content rejected','case normalization rejects prohibited phrase');
select throws_ok($$insert into public.messages(group_id,sender_id,client_id,body)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),gen_random_uuid(),'QA-'||chr(8203)||'BLOCKED-TEXT')$$,
 '42501','message content rejected','zero width insertion cannot bypass literal');
select throws_ok($$insert into public.messages(group_id,sender_id,client_id,body)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),gen_random_uuid(),E'qa\t\nphrase')$$,
 '42501','message content rejected','whitespace normalization is applied');
select throws_ok($$insert into public.messages(group_id,sender_id,recipient_id,client_id,message_type,body)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),'00000000-0000-0000-0000-000000000002',gen_random_uuid(),'guide_private','QA-BLOCKED-TEXT')$$,
 '42501','message content rejected','private messages filtered too');
select throws_ok($$insert into public.announcements(group_id,author_id,title,body)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),'QA-BLOCKED-TEXT','benign')$$,
 '42501','message content rejected','announcement title filtered');
select is((select count(*)::int from public.messages),0,'rejected text never inserted');
select lives_ok($$insert into public.messages(group_id,sender_id,client_id,body,moderation_policy_version,moderation_checked_at)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),gen_random_uuid(),'qaXliteral benign','qa-policy-v1','2000-01-01')$$,
 'literal percent is not a wildcard');
select ok((select moderation_checked_at > transaction_timestamp() from public.messages),'server overwrites forged review time');
select is((select moderation_policy_version from public.messages),'qa-policy-v1','trusted policy version stamped');
select throws_ok($$update public.messages set body='QA-BLOCKED-TEXT'$$,
 '42501','message content rejected','body update cannot bypass filter');
select lives_ok($$update public.messages set deleted_at=clock_timestamp()$$,'own soft deletion remains possible');
select throws_ok($$insert into public.messages(group_id,sender_id,client_id,body)
 values('10000000-0000-0000-0000-000000000002',auth.uid(),gen_random_uuid(),'benign')$$,
 '42501',null,'policy acceptance cannot bypass cross-group RLS');
reset role;
update public.service_terms set current=false;
insert into public.service_terms(version,body,document_url,document_sha256,current)
 values('qa-terms-v2','TEST ONLY NEW','https://example.test/terms/v2',repeat('c',64),true);
set local role authenticated;
select throws_ok($$insert into public.messages(group_id,sender_id,client_id,body)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),gen_random_uuid(),'benign')$$,
 '42501','current service terms acceptance required','stale outbox acceptance still first error');
select public.accept_service_terms('qa-terms-v2');
select throws_ok($$insert into public.messages(group_id,sender_id,client_id,body)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),gen_random_uuid(),'benign')$$,
 '42501','content moderation unavailable','old policy cannot authorize new terms');
reset role;
update public.content_moderation_policies set current=false;
insert into public.content_moderation_policies(version,terms_version,denied_phrases,policy_document_url,policy_document_sha256,current)
 values('qa-policy-v2','qa-terms-v2',array['QA-NEW-BLOCKED'],'https://example.test/policy/v2',repeat('d',64),true);
set local role authenticated;
select lives_ok($$insert into public.messages(group_id,sender_id,client_id,body,moderation_policy_version)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),gen_random_uuid(),'new benign','qa-policy-v1')$$,
 'new trusted policy enables benign post');
select is((select moderation_policy_version from public.messages where body='new benign'),'qa-policy-v2','forged old version overwritten');
select throws_ok($$insert into public.messages(group_id,sender_id,client_id,body)
 values('10000000-0000-0000-0000-000000000001',auth.uid(),gen_random_uuid(),'QA-NEW-BLOCKED')$$,
 '42501','message content rejected','new version rules effective');
reset role;
select * from finish();
rollback;
