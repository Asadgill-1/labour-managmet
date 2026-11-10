-- T20c: the owner turns an old phone off from the new one (D-072, D-073). The old phone learns it at start, before any
-- sign-in. The owner signing in on it again turns it back on; a manager's phone stays off.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'owner@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'manager@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'other@example.test', now());

-- The owner makes the company and signs in on the old phone, then on the new one.
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ select public.create_tenant('Alpha Labour', 'aaaaaaaa-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001') $$,
  'the owner makes a company'
);
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 'Old phone', 'android', gen_random_uuid()) $$,
  'the owner signs in on the old phone'
);
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 'New phone', 'android', gen_random_uuid()) $$,
  'then on the new phone'
);

-- A manager of the company with a phone of their own, until invites exist (T24).
reset role;
insert into public.memberships (tenant_id, user_id, role, actor_id, source_operation_id) values
  ('eeeeeeee-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'manager', '11111111-1111-1111-1111-111111111111', gen_random_uuid());
insert into public.devices (tenant_id, user_id, device_id, label, platform, actor_id, source_operation_id) values
  ('eeeeeeee-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'dddddddd-0000-0000-0000-00000000000c', 'Manager phone', 'android', '22222222-2222-2222-2222-222222222222', gen_random_uuid());
do $$ begin
  perform set_config('test.old', (select id::text from public.devices where device_id = 'dddddddd-0000-0000-0000-00000000000a'), true);
  perform set_config('test.manager', (select id::text from public.devices where device_id = 'dddddddd-0000-0000-0000-00000000000c'), true);
end $$;

-- Before anyone signs in, a phone that is on is not off, nor is a phone the company never saw.
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select is(public.phone_is_off('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a'), false, 'a phone that is on is not off');
select is(public.phone_is_off('eeeeeeee-0000-0000-0000-000000000001', gen_random_uuid()), false, 'nor is a phone the company never saw');

-- Another company's owner cannot turn the phone off, nor can the manager.
set local role authenticated;
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok(
  $$ select public.turn_phone_off(current_setting('test.old')::uuid, gen_random_uuid()) $$,
  '42501', 'not a phone of yours', 'someone outside the company cannot turn the phone off'
);
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok(
  $$ select public.turn_phone_off(current_setting('test.old')::uuid, gen_random_uuid()) $$,
  '42501', 'not a phone of yours', 'a manager cannot turn off the owner''s phone'
);

-- From the new phone, the owner turns the old one off, and the manager's too.
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok($$ select public.turn_phone_off(current_setting('test.old')::uuid, gen_random_uuid()) $$, 'the owner turns the old phone off');
select lives_ok($$ select public.turn_phone_off(current_setting('test.old')::uuid, gen_random_uuid()) $$, 'turning it off again is no error');
select lives_ok($$ select public.turn_phone_off(current_setting('test.manager')::uuid, gen_random_uuid()) $$, 'the owner turns the manager''s phone off');
reset role;
select is((select version from public.devices where id = current_setting('test.old')::uuid), 2, 'the second time changed nothing');

-- The old phone learns it before anyone signs in; the new phone is still on.
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select is(public.phone_is_off('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a'), true, 'the old phone is told it is off');
select is(public.phone_is_off('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b'), false, 'the new phone is still on');

-- The manager's phone stays off. The owner signing in on the old phone again turns it back on, with its new name.
set local role authenticated;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000c', 'Manager phone', 'android', gen_random_uuid()) $$,
  '42501', 'this device was revoked', 'the manager''s phone stays off'
);
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 'Galaxy A51', 'android', gen_random_uuid()) $$,
  'the owner signs in on the old phone again'
);
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select is(public.phone_is_off('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a'), false, 'and it is on again');
reset role;
select is((select label from public.devices where device_id = 'dddddddd-0000-0000-0000-00000000000a'), 'Galaxy A51', 'under the name it sent');

select * from finish();
rollback;
