-- One phone, one account (T19b, D-063): a phone a member signed in on is refused to every other account, and the app
-- can ask before signing in whose it is, by a masked email. The company turning the phone off frees it.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'alpha@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'beta@example.test', now());

-- Alpha's owner makes a company on the phone.
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok($$ select public.create_tenant('Alpha Labour', 'aaaaaaaa-0000-0000-0000-000000000001') $$, 'Alpha makes a company');
select lives_ok(
  $$ select public.register_device((select tenant_id from public.tenants), 'dddddddd-0000-0000-0000-00000000000a', 'Phone', 'android', gen_random_uuid()) $$,
  'Alpha signs in on the phone'
);
select is(public.phone_account('dddddddd-0000-0000-0000-00000000000a'), null::text, 'the phone is not refused to its own account');

-- Before anyone signs in, the phone says whose it is, without the whole email; a new phone belongs to no one.
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select is(public.phone_account('dddddddd-0000-0000-0000-00000000000a'), 'al***@example.test', 'the phone names its account, masked');
select is(public.phone_account(gen_random_uuid()), null::text, 'a new phone belongs to no one');

-- Beta can make a company, but not on Alpha's phone.
set local role authenticated;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select lives_ok($$ select public.create_tenant('Beta Labour', 'bbbbbbbb-0000-0000-0000-000000000001') $$, 'Beta makes a company');
select is(public.phone_account('dddddddd-0000-0000-0000-00000000000a'), 'al***@example.test', 'another account is told whose the phone is');
select throws_ok(
  $$ select public.register_device((select tenant_id from public.tenants), 'dddddddd-0000-0000-0000-00000000000a', 'Phone', 'android', gen_random_uuid()) $$,
  '42501', 'this phone belongs to another account', 'a second account cannot use the phone'
);
select lives_ok(
  $$ select public.register_device((select tenant_id from public.tenants), 'dddddddd-0000-0000-0000-00000000000b', 'Own phone', 'android', gen_random_uuid()) $$,
  'the second account uses a phone of its own'
);

-- Alpha's company turns the phone off, which frees it.
reset role;
update public.devices set revoked_at_utc = now() where device_id = 'dddddddd-0000-0000-0000-00000000000a';
set local role authenticated;
select is(public.phone_account('dddddddd-0000-0000-0000-00000000000a'), null::text, 'a phone its company turned off is free');
select lives_ok(
  $$ select public.register_device((select tenant_id from public.tenants), 'dddddddd-0000-0000-0000-00000000000a', 'Phone', 'android', gen_random_uuid()) $$,
  'another account can then use it'
);

select * from finish();
rollback;
