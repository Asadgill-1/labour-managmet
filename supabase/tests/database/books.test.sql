-- T22d: the books in the cloud (D-081 part 2, D-084). Nothing is taken before the company's owner gives consent; a
-- push takes only this company's member, from a phone that is on, of the app's own record types; each record keeps its
-- newest version, a resend changes nothing and a delete's mark keeps an older copy out. Only a platform admin with a
-- TOTP code reads them, and deleting the account removes them.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'admin@example.test', now()),
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'alpha@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'beta@example.test', now()),
  ('44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'stranger@example.test', now());
insert into private.platform_admins (user_id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Sets who is signed in, at which level, with a password typed just now. Called as postgres.
create function pg_temp.claims(p_user uuid, p_aal text) returns text
language sql as $$
  select set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal,
    'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint)))::text, true)
$$;

-- Alpha's push from its phone, as its owner. Called as postgres; leaves the role as it was.
create function pg_temp.alpha_push(p_changes jsonb) returns integer
language plpgsql as $$
declare
  v_taken integer;
begin
  perform pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
  set local role authenticated;
  v_taken := public.push_book_changes('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', p_changes);
  reset role;
  return v_taken;
end $$;

create function pg_temp.alpha_row(p_entity text, p_id text) returns private.book_rows
language sql as $$
  select * from private.book_rows where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001' and entity = p_entity and record_id = p_id
$$;

-- The companies and their phones.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select lives_ok($$ select public.create_tenant('Alpha Labour', gen_random_uuid(), 'eeeeeeee-0000-0000-0000-000000000001') $$, 'Alpha makes its company');
select lives_ok($$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 'Phone', 'android', gen_random_uuid()) $$,
  'and registers its phone');
select lives_ok($$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 'Old phone', 'android', gen_random_uuid()) $$,
  'and an old phone');
select throws_ok(
  $$ select public.push_book_changes('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', '[{"entity": "workers", "id": "w1", "version": 1, "data": {"name": "Ali"}}]') $$,
  '42501', 'give consent first', 'push refused without consent');
reset role;

select pg_temp.claims('33333333-3333-3333-3333-333333333333', 'aal1');
set local role authenticated;
select lives_ok($$ select public.create_tenant('Beta Manpower', gen_random_uuid(), 'eeeeeeee-0000-0000-0000-000000000002') $$, 'Beta makes its company');
select lives_ok($$ select public.register_device('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000c', 'Phone', 'android', gen_random_uuid()) $$,
  'and registers its phone');
reset role;

-- Consent: the owner's, kept with the wording's version.
select pg_temp.claims('44444444-4444-4444-4444-444444444444', 'aal1');
set local role authenticated;
select throws_ok($$ select public.give_data_consent('eeeeeeee-0000-0000-0000-000000000001', 1) $$, '42501', 'only the owner gives consent',
  'consent refused for someone not the owner');
reset role;
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select lives_ok($$ select public.give_data_consent('eeeeeeee-0000-0000-0000-000000000001', 2) $$, 'Alpha''s owner gives consent');
select lives_ok($$ select public.give_data_consent('eeeeeeee-0000-0000-0000-000000000001', 1) $$, 'and an older wording again');
select is((select data_consent_version from public.tenants where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001'), 2, 'consent kept with its version');
select ok((select data_consent_at_utc is not null from public.tenants where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001'), 'a lower version does not lower it, nor takes the date away');
reset role;
select pg_temp.claims('33333333-3333-3333-3333-333333333333', 'aal1');
set local role authenticated;
select lives_ok($$ select public.give_data_consent('eeeeeeee-0000-0000-0000-000000000002', 1) $$, 'Beta''s owner gives consent');
select throws_ok(
  $$ select public.push_book_changes('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000c', '[{"entity": "workers", "id": "w9", "version": 1, "data": {}}]') $$,
  '42501', 'not a member of this company', 'push refused for another company');
reset role;

-- The phone must be one the company has on.
update public.devices set revoked_at_utc = now() where device_id = 'dddddddd-0000-0000-0000-00000000000b';
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select throws_ok(
  $$ select public.push_book_changes('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', '[{"entity": "workers", "id": "w9", "version": 1, "data": {}}]') $$,
  '42501', 'this phone is not on for this company', 'push refused from a turned-off phone');
select throws_ok(
  $$ select public.push_book_changes('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-0000000000ff', '[{"entity": "workers", "id": "w9", "version": 1, "data": {}}]') $$,
  '42501', 'this phone is not on for this company', 'push refused from a phone never registered');
reset role;

-- Each record keeps its newest version.
select is(pg_temp.alpha_push('[
  {"entity": "workers", "id": "w1", "version": 1, "data": {"name": "Ali", "active": 1, "created_at_utc": 1790000000}},
  {"entity": "clients", "id": "c1", "version": 1, "data": {"name": "Acme", "active": 1}},
  {"entity": "month_summary", "id": "2026-10", "version": 1, "data": {"month": "2026-10", "bill": 100000, "wages": 60000, "estimate": 30000, "days": 40}}
]'), 3, 'the push says how many it read');
select is((select count(*)::int from private.book_rows where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001'), 3, 'push keeps each record');
select pg_temp.alpha_push('[{"entity": "workers", "id": "w1", "version": 1, "data": {"name": "Ali", "active": 1, "created_at_utc": 1790000000}}]');
select is((select count(*)::int from private.book_rows where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001'), 3, 'a resend changes nothing');
select is((pg_temp.alpha_row('workers', 'w1')).data ->> 'name', 'Ali', 'and keeps the same record');
select pg_temp.alpha_push('[{"entity": "workers", "id": "w1", "version": 2, "data": {"name": "Ali Khan", "active": 1, "created_at_utc": 1790000000}}]');
select is((pg_temp.alpha_row('workers', 'w1')).data ->> 'name', 'Ali Khan', 'a newer version replaces');
select pg_temp.alpha_push('[{"entity": "workers", "id": "w1", "version": 2, "data": {"name": "Ali K", "active": 1, "created_at_utc": 1790000000}}]');
select is((pg_temp.alpha_row('workers', 'w1')).data ->> 'name', 'Ali K', 'an equal version replaces');
select pg_temp.alpha_push('[{"entity": "workers", "id": "w1", "version": 1, "data": {"name": "Old", "active": 1}}]');
select is((pg_temp.alpha_row('workers', 'w1')).data ->> 'name', 'Ali K', 'an older version never replaces a newer one');
select pg_temp.alpha_push('[{"entity": "workers", "id": "w1", "version": 3, "data": null}]');
select is((pg_temp.alpha_row('workers', 'w1')).data, null, 'a delete goes as a mark with no data');
select pg_temp.alpha_push('[{"entity": "workers", "id": "w1", "version": 2, "data": {"name": "Back"}}]');
select is((pg_temp.alpha_row('workers', 'w1')).data, null, 'a delete''s mark keeps an older copy out');

-- Only the app's own record types, only this company's records, in batches the cloud can take.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select throws_ok(
  $$ select public.push_book_changes('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', '[{"entity": "secrets", "id": "s1", "version": 1, "data": {}}]') $$,
  '22023', 'unknown record type: secrets', 'an unknown record type is refused');
select throws_ok(
  $$ select public.push_book_changes('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a',
       '[{"entity": "workers", "id": "w8", "version": 1, "data": {"tenant_id": "eeeeeeee-0000-0000-0000-000000000002"}}]') $$,
  '42501', 'a record of another company', 'a record naming another company is refused');
select throws_ok(
  $$ select public.push_book_changes('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a',
       (select jsonb_agg(jsonb_build_object('entity', 'workers', 'id', 'x' || n, 'version', 1, 'data', '{}'::jsonb)) from generate_series(1, 501) n)) $$,
  '22023', 'at most 500 changes at a time', 'more than 500 changes are refused');
select throws_ok(
  $$ select public.push_book_changes('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', '[{"entity": "workers", "id": "w7", "version": 0, "data": {}}]') $$,
  '22023', 'a change needs its record type, id and version', 'a version below 1 is refused');
reset role;

-- More of Alpha's books: two workers, one archived, an invoice, this month's summary; and Beta's month.
select pg_temp.alpha_push(jsonb_build_array(
  jsonb_build_object('entity', 'workers', 'id', 'w2', 'version', 1, 'data', jsonb_build_object('name', 'Babar', 'active', 1, 'created_at_utc', 1780000000)),
  jsonb_build_object('entity', 'workers', 'id', 'w3', 'version', 1, 'data', jsonb_build_object('name', 'Chand', 'active', 0, 'created_at_utc', 1785000000)),
  jsonb_build_object('entity', 'invoices', 'id', 'i1', 'version', 1, 'data', jsonb_build_object('status', 'issued', 'kind', 'invoice', 'created_at_utc', 1791000000)),
  jsonb_build_object('entity', 'month_summary', 'id', to_char(now() at time zone 'Asia/Dubai', 'YYYY-MM'), 'version', 1,
    'data', jsonb_build_object('month', to_char(now() at time zone 'Asia/Dubai', 'YYYY-MM'), 'bill', 7000, 'estimate', 2000))
));
select pg_temp.claims('33333333-3333-3333-3333-333333333333', 'aal1');
set local role authenticated;
select is(public.push_book_changes('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000c',
  '[{"entity": "month_summary", "id": "2026-10", "version": 1, "data": {"month": "2026-10", "bill": 50000, "wages": 45000, "estimate": -5000, "days": 20}},
    {"entity": "workers", "id": "bw1", "version": 1, "data": {"name": "Dara", "active": 1}}]'), 2, 'Beta sends its month');
reset role;

-- The owner's reads.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select throws_ok($$ select public.admin_account_book('eeeeeeee-0000-0000-0000-000000000001') $$, '42501', 'admins only', 'admin reads refused for a customer');
select throws_ok($$ select public.admin_business('2026-10', '2026-10', true) $$, '42501', 'admins only', 'the business totals too');
select throws_ok($$ select public.admin_book('eeeeeeee-0000-0000-0000-000000000001', 'workers') $$, '42501', 'admins only', 'and the books');
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal1');
set local role authenticated;
select throws_ok($$ select public.admin_account_book('eeeeeeee-0000-0000-0000-000000000001') $$, '42501', 'admins only', 'admin reads refused at aal1');
reset role;

select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2');
set local role authenticated;
select is(jsonb_array_length(public.admin_account_book('eeeeeeee-0000-0000-0000-000000000001') -> 'months'), 2, 'the account''s book has its months');
select is((public.admin_account_book('eeeeeeee-0000-0000-0000-000000000001') -> 'counts' ->> 'workers')::int, 1, 'and counts live, active labour');
select is((public.admin_account_book('eeeeeeee-0000-0000-0000-000000000001') -> 'counts' ->> 'clients')::int, 1, 'and companies');
select is((public.admin_account_book('eeeeeeee-0000-0000-0000-000000000001') -> 'counts' ->> 'invoices')::int, 1, 'and issued invoices');
select is((public.admin_account_book('eeeeeeee-0000-0000-0000-000000000001') ->> 'consent_version')::int, 2, 'and says which wording was agreed');
select is((public.admin_account_book('eeeeeeee-0000-0000-0000-000000000001') -> 'firsts' ->> 'worker')::timestamptz, to_timestamp(1780000000),
  'and when the first worker was made');
select is((public.admin_business('2026-10', '2026-10', true) -> 'months' -> 0 ->> 'bill')::bigint, 150000::bigint, 'business adds up two accounts'' months');
select is((public.admin_business('2026-10', '2026-10', true) -> 'months' -> 0 ->> 'estimate')::bigint, 25000::bigint, 'profit and loss together');
select is((public.admin_business('2026-10', '2026-10', true) -> 'months' -> 0 ->> 'accounts')::int, 2, 'and says from how many accounts');
select is((public.admin_business('2026-10', '2026-10', true) ->> 'workers')::int, 2, 'live, active labour across accounts');
select is(jsonb_array_length(public.admin_book('eeeeeeee-0000-0000-0000-000000000001', 'workers')), 2, 'admin_book lists live workers only');
select throws_ok($$ select public.admin_book('eeeeeeee-0000-0000-0000-000000000001', 'secrets') $$, '22023', 'unknown record type: secrets',
  'admin_book refuses an unknown record type');
select is((public.admin_account('eeeeeeee-0000-0000-0000-000000000001') ->> 'bill_month')::bigint, 7000::bigint, 'account_row shows this month''s bill');
select ok((public.admin_account('eeeeeeee-0000-0000-0000-000000000001') ->> 'book_at') is not null, 'and when the books last arrived');
reset role;

update public.tenants set is_test = true where tenant_id = 'eeeeeeee-0000-0000-0000-000000000002';
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2');
set local role authenticated;
select is((public.admin_business('2026-10', '2026-10', false) -> 'months' -> 0 ->> 'bill')::bigint, 100000::bigint, 'business leaves test accounts out');
reset role;

-- Deleting the account removes its books at once (D-066).
select pg_temp.claims('33333333-3333-3333-3333-333333333333', 'aal1');
set local role authenticated;
select lives_ok('select public.delete_account()', 'Beta''s owner deletes the account');
reset role;
select is((select count(*)::int from private.book_rows where tenant_id = 'eeeeeeee-0000-0000-0000-000000000002'), 0, 'deleting the account removes its book rows');

select ok(not has_function_privilege('anon', 'public.push_book_changes(uuid, uuid, jsonb)', 'execute'), 'a visitor cannot push');
select ok(not has_table_privilege('authenticated', 'private.book_rows', 'select'), 'nobody reads the book rows but through the functions');

select * from finish();
rollback;
