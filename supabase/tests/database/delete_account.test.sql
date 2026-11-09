-- Deleting an account (T19c, AUTH-07, D-066): only with the password typed again in the last minutes. A company the
-- account owns goes with it, members and devices too, and another company is untouched. A company others still work
-- in is refused; a manager leaving takes only their own rows.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'alpha@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'beta@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'gamma@example.test', now());

-- Alpha makes a company and signs in on a phone; so does Beta, whose company also has Gamma as a manager.
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint - 0)))::text, true);
select lives_ok($$ select public.create_tenant('Alpha Labour', 'aaaaaaaa-0000-0000-0000-000000000001') $$, 'Alpha makes a company');
select lives_ok(
  $$ select public.register_device((select tenant_id from public.tenants), 'dddddddd-0000-0000-0000-00000000000a', 'Phone', 'android', gen_random_uuid()) $$,
  'Alpha signs in on a phone'
);
select set_config('request.jwt.claims', jsonb_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint - 0)))::text, true);
select lives_ok($$ select public.create_tenant('Beta Labour', 'bbbbbbbb-0000-0000-0000-000000000001') $$, 'Beta makes a company');
reset role;
insert into public.memberships (tenant_id, user_id, role, actor_id, source_operation_id)
  select tenant_id, '33333333-3333-3333-3333-333333333333', 'manager', '22222222-2222-2222-2222-222222222222', gen_random_uuid() from public.tenants where name = 'Beta Labour';
insert into public.devices (tenant_id, user_id, device_id, label, platform, actor_id, source_operation_id)
  select tenant_id, '33333333-3333-3333-3333-333333333333', 'dddddddd-0000-0000-0000-00000000000c', 'Gamma phone', 'android', '33333333-3333-3333-3333-333333333333', gen_random_uuid()
  from public.tenants where name = 'Beta Labour';

select ok(not has_function_privilege('anon', 'public.delete_account()', 'execute'), 'a visitor cannot delete an account');

-- The password must be typed again just now.
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint - 3600)))::text, true);
select throws_ok('select public.delete_account()', '42501', 'type the password again', 'a password typed an hour ago is not enough');
select set_config('request.jwt.claims', jsonb_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'otp', 'timestamp', extract(epoch from now())::bigint - 0)))::text, true);
select throws_ok('select public.delete_account()', '42501', 'type the password again', 'an email code is not the password');

-- A company others still work in cannot go with its owner.
select set_config('request.jwt.claims', jsonb_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint - 0)))::text, true);
select throws_ok('select public.delete_account()', '42501', 'the company has other members', 'a company with a manager is refused');

-- Alpha deletes the account: its company, its phone and its sign-in go; Beta's company stays.
select set_config('request.jwt.claims', jsonb_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint - 0)))::text, true);
select lives_ok('select public.delete_account()', 'Alpha deletes the account');
reset role;
select is((select count(*)::int from auth.users where id = '11111111-1111-1111-1111-111111111111'), 0, 'the sign-in is gone');
select is((select count(*)::int from public.tenants where name = 'Alpha Labour'), 0, 'the company it owned is gone');
select is(public.phone_account('dddddddd-0000-0000-0000-00000000000a'), null::text, 'its phone is free');

-- Gamma, a manager, leaves: only Gamma's rows go.
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object('sub', '33333333-3333-3333-3333-333333333333', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint - 0)))::text, true);
select lives_ok('select public.delete_account()', 'the manager deletes the account');
reset role;
select results_eq(
  $$ select t.name || ':' || count(m.*) from public.tenants t join public.memberships m using (tenant_id) group by t.name $$,
  array['Beta Labour:1'],
  'the company and its owner stay; the manager and their phone are gone'
);

-- With no one else in it, Beta's company goes with Beta.
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint - 0)))::text, true);
select lives_ok('select public.delete_account()', 'the owner of a company with no one else deletes the account');

select * from finish();
rollback;
