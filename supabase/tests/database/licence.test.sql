-- T21a: what a licence says (D-074, BILL-03, BILL-05). Only a member's first phone still on gets one. The owner's
-- first request starts the 15-day trial, once per company, email and phone, even after the account is deleted. A
-- prepaid month keeps a paid company's plan offline across the renewal. Only the server reads the signing key.
begin;
create extension if not exists pgtap with schema extensions;
select plan(47);

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'owner@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'manager@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'other@example.test', now()),
  ('44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'beta@example.test', now()),
  ('55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated', 'beta.manager@example.test', now()),
  ('66666666-6666-6666-6666-666666666666', 'authenticated', 'authenticated', 'newcomer@example.test', now());

-- Alpha's owner makes the company and signed in on a phone a day ago; the company has a manager with a phone.
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ select public.create_tenant('Alpha Labour', 'aaaaaaaa-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001') $$,
  'the owner makes a company'
);
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 'First phone', 'android', gen_random_uuid()) $$,
  'and signs in on a phone'
);
reset role;
update public.devices set created_at_utc = now() - interval '1 day' where device_id = 'dddddddd-0000-0000-0000-00000000000a';
insert into public.memberships (tenant_id, user_id, role, actor_id, source_operation_id) values
  ('eeeeeeee-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'manager', '11111111-1111-1111-1111-111111111111', gen_random_uuid());
insert into public.devices (tenant_id, user_id, device_id, label, platform, actor_id, source_operation_id) values
  ('eeeeeeee-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'dddddddd-0000-0000-0000-00000000000c', 'Manager phone', 'android', '22222222-2222-2222-2222-222222222222', gen_random_uuid());
do $$ begin
  perform set_config('test.first', (select id::text from public.devices where device_id = 'dddddddd-0000-0000-0000-00000000000a'), true);
end $$;

-- The owner's first request starts the trial: 15 days, no limit, a phone each for the owner and the manager.
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 3, 1) ->> 'state', 'trial', 'the owner''s first request starts the trial');
select is(
  (select (f ->> 'ends_at')::timestamptz - (f ->> 'iat')::timestamptz from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 5, 2) f) x),
  interval '15 days', 'of 15 days'
);
select is(
  (select (f ->> 'lease_until')::timestamptz - (f ->> 'iat')::timestamptz from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 5, 2) f) x),
  interval '7 days', 'trusted offline for 7 days'
);
select is(
  (select f -> 'limits' from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 5, 2) f) x),
  '{"workers": null, "clients": null, "managers": null, "devices": 2}'::jsonb,
  'with no limit, and a phone each for the owner and the manager'
);
select ok(
  (select f ?& array['v', 'iss', 'jti', 'iat', 'tenant_id', 'device_id', 'plan', 'plan_version', 'starts_at', 'ends_at', 'lease_until', 'limits']
   from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 5, 2) f) x),
  'it carries the company, plan, limits, period, phone, issuer, token id and schema version'
);
reset role;
select is((select count(*)::int from public.subscriptions where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001'), 1, 'asking again made no second trial');
select results_eq('select active_workers, active_clients from private.usage_reports', $$ values (5, 2) $$, 'the latest counts are kept');
select is((select count(*)::int from private.trial_claims where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001'), 2, 'the owner''s email and phone count as having had the trial');

-- Refused: someone outside, a phone never signed in, counts below zero.
set local role authenticated;
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok(
  $$ select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 0, 0) $$,
  '42501', 'not a member of this company', 'someone outside the company gets no licence'
);
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select throws_ok(
  $$ select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', gen_random_uuid(), 0, 0) $$,
  '42501', 'this phone is not registered', 'nor does a phone that never signed in'
);
select throws_ok(
  $$ select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', -1, 0) $$,
  '22023', 'counts out of range', 'counts below zero are refused'
);

-- One phone per person: a new phone waits until the first one is turned off.
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 'New phone', 'android', gen_random_uuid()) $$,
  'the owner signs in on a new phone'
);
select throws_ok(
  $$ select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 0, 0) $$,
  '42501', 'another phone is on', 'the new phone gets no licence while the first is on'
);
select lives_ok($$ select public.turn_phone_off(current_setting('test.first')::uuid, gen_random_uuid()) $$, 'the owner turns the first phone off');
select throws_ok(
  $$ select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 0, 0) $$,
  '42501', 'this device was revoked', 'the phone turned off gets no licence'
);
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 0, 0) ->> 'state', 'trial', 'and the new phone gets the company''s trial');
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000c', 0, 0) ->> 'state', 'trial', 'the manager''s own phone gets one too');

-- A manager's request starts no trial; only the owner's does.
set local request.jwt.claims to '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}';
select lives_ok(
  $$ select public.create_tenant('Beta Labour', 'bbbbbbbb-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002') $$,
  'another owner makes a company'
);
reset role;
insert into public.memberships (tenant_id, user_id, role, actor_id, source_operation_id) values
  ('eeeeeeee-0000-0000-0000-000000000002', '55555555-5555-5555-5555-555555555555', 'manager', '44444444-4444-4444-4444-444444444444', gen_random_uuid());
insert into public.devices (tenant_id, user_id, device_id, label, platform, actor_id, source_operation_id) values
  ('eeeeeeee-0000-0000-0000-000000000002', '55555555-5555-5555-5555-555555555555', 'dddddddd-0000-0000-0000-00000000000e', 'Beta manager phone', 'android', '55555555-5555-5555-5555-555555555555', gen_random_uuid());
set local role authenticated;
set local request.jwt.claims to '{"sub": "55555555-5555-5555-5555-555555555555", "role": "authenticated"}';
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000e', 0, 0) ->> 'state', 'none', 'a manager''s request starts no trial');
reset role;
select is((select count(*)::int from public.subscriptions where tenant_id = 'eeeeeeee-0000-0000-0000-000000000002'), 0, 'and leaves no plan period');

-- The same owner's second company gets no second trial, so no new entries.
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ select public.create_tenant('Alpha Two', 'aaaaaaaa-0000-0000-0000-000000000002', 'eeeeeeee-0000-0000-0000-000000000003') $$,
  'the owner makes a second company'
);
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000003', 'dddddddd-0000-0000-0000-00000000000b', 'New phone', 'android', gen_random_uuid()) $$,
  'on the new phone'
);
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000003', 'dddddddd-0000-0000-0000-00000000000b', 0, 0) ->> 'state', 'none', 'which gets no second trial');
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000003', 'dddddddd-0000-0000-0000-00000000000b', 0, 0) -> 'limits' ->> 'workers', '0', 'and room for no new worker');

-- The owner deletes the account; the claims stay, so a new account on the first phone gets no trial either.
reset role;
update public.memberships set revoked_at_utc = now() where user_id = '22222222-2222-2222-2222-222222222222';
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint)))::text, true);
select lives_ok('select public.delete_account()', 'the owner deletes the account');
reset role;
select is((select count(*)::int from public.subscriptions where tenant_id in ('eeeeeeee-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000003')), 0, 'its plan periods went with it');
select is((select count(*)::int from private.trial_claims where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001'), 2, 'the trial claims stay');
set local role authenticated;
set local request.jwt.claims to '{"sub": "66666666-6666-6666-6666-666666666666", "role": "authenticated"}';
select lives_ok(
  $$ select public.create_tenant('Delta Labour', 'aaaaaaaa-0000-0000-0000-000000000004', 'eeeeeeee-0000-0000-0000-000000000004') $$,
  'a new account makes a company'
);
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000004', 'dddddddd-0000-0000-0000-00000000000a', 'First phone', 'android', gen_random_uuid()) $$,
  'on the first phone'
);
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000004', 'dddddddd-0000-0000-0000-00000000000a', 0, 0) ->> 'state', 'none', 'and gets no second trial on it');

-- One person's email, however written.
reset role;
select is(private.email_hash('A.B+shop@Gmail.com'), private.email_hash(' ab@googlemail.com '), 'Gmail''s dots, a +tag and capitals make no new person');
select is(private.email_hash('ali+2@example.test'), private.email_hash('Ali@example.test'), 'nor does a +tag elsewhere');
select isnt(private.email_hash('a.li@example.test'), private.email_hash('ali@example.test'), 'outside Gmail a dot is another address');

-- Delta paid this month and the next: the licence runs to the end of the next, renewed offline, rechecked weekly.
insert into public.payment_slips (id, tenant_id, plan_code, plan_version, months, expected_fils, file_path, state, decided_at_utc, submitted_by, source_operation_id) values
  ('5a000000-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000004', 'small', 1, 1, 19900, 'eeeeeeee-0000-0000-0000-000000000004/one.jpg', 'accepted', now(), '66666666-6666-6666-6666-666666666666', gen_random_uuid()),
  ('5a000000-0000-0000-0000-000000000002', 'eeeeeeee-0000-0000-0000-000000000004', 'small', 1, 1, 19900, 'eeeeeeee-0000-0000-0000-000000000004/two.jpg', 'accepted', now(), '66666666-6666-6666-6666-666666666666', gen_random_uuid());
insert into public.subscriptions (tenant_id, plan_code, plan_version, source, slip_id, starts_at_utc, ends_at_utc, anchor_at_utc, anchor_months, amount_fils, bank_reference, received_on) values
  ('eeeeeeee-0000-0000-0000-000000000004', 'small', 1, 'slip', '5a000000-0000-0000-0000-000000000001', now() - interval '27 days', now() + interval '3 days', now() - interval '27 days', 1, 19900, 'REF-1', current_date),
  ('eeeeeeee-0000-0000-0000-000000000004', 'small', 1, 'slip', '5a000000-0000-0000-0000-000000000002', now() + interval '3 days', now() + interval '33 days', now() - interval '27 days', 2, 19900, 'REF-2', current_date);
set local role authenticated;
set local request.jwt.claims to '{"sub": "66666666-6666-6666-6666-666666666666", "role": "authenticated"}';
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000004', 'dddddddd-0000-0000-0000-00000000000a', 0, 0) ->> 'state', 'paid', 'an accepted slip makes the company paid');
select is(
  (select (f ->> 'ends_at')::timestamptz - now() from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000004', 'dddddddd-0000-0000-0000-00000000000a', 0, 0) f) x),
  interval '33 days', 'paid to the end of the prepaid month, so the renewal needs no internet'
);
select is(
  (select (f ->> 'lease_until')::timestamptz - now() from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000004', 'dddddddd-0000-0000-0000-00000000000a', 0, 0) f) x),
  interval '7 days', 'still checked again within 7 days'
);
select is(
  (select f -> 'limits' from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000004', 'dddddddd-0000-0000-0000-00000000000a', 0, 0) f) x),
  '{"workers": 15, "clients": 5, "managers": 1, "devices": 1}'::jsonb,
  'with the Small plan''s limits'
);
reset role;
select private.revoke_subscription((select id from public.subscriptions where bank_reference = 'REF-1'), 'the transfer came back');
set local role authenticated;
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000004', 'dddddddd-0000-0000-0000-00000000000a', 0, 0) ->> 'state', 'none', 'a revoked period counts no more');

-- Only the server reads or keeps the signing key, and only the first key is kept.
reset role;
select ok(not has_function_privilege('authenticated', 'public.licence_signing_key()', 'execute'), 'a signed-in user cannot read the signing key');
select ok(not has_function_privilege('anon', 'public.licence_signing_key_keep(jsonb)', 'execute'), 'nor can a visitor store one');
set local role service_role;
select is(public.licence_signing_key(), null::jsonb, 'there is no key until the function makes one');
select is(public.licence_signing_key_keep('{"private_pkcs8": "first", "public_raw": "one"}') ->> 'public_raw', 'one', 'the first key is kept');
select is(public.licence_signing_key_keep('{"private_pkcs8": "second", "public_raw": "two"}') ->> 'public_raw', 'one', 'a second first run keeps the first key');
select throws_ok($$ select public.licence_signing_key_keep('{}') $$, '22023', 'not a key', 'and nothing but a key is stored');
reset role;
select is((select count(*)::int from vault.secrets where name = 'licence_signing_key'), 1, 'one key sits in Vault');

select * from finish();
rollback;
