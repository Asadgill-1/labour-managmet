-- Two companies on one cloud: neither can see, join or write the other's rows, and only a server function writes
-- (T19a: AUTH-02, AUTH-05, MODEL-05).
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'alpha@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'beta@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'unverified@example.test', null);

-- Alpha's owner makes a company; a retry of the same request returns the same one.
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok($$ select public.create_tenant('Alpha Labour', 'aaaaaaaa-0000-0000-0000-000000000001') $$, 'a verified user makes a company');
select is(
  public.create_tenant('Alpha Labour', 'aaaaaaaa-0000-0000-0000-000000000001'),
  (select tenant_id from public.tenants where name = 'Alpha Labour'),
  'a retry returns the company it made'
);
select results_eq('select count(*)::int from public.tenants', array[1], 'the retry made no second company');
select lives_ok(
  $$ select public.register_device((select tenant_id from public.tenants), 'dddddddd-0000-0000-0000-00000000000a', 'Alpha phone', 'android', 'aaaaaaaa-0000-0000-0000-000000000002') $$,
  'a member records their device'
);

-- Beta's owner makes another.
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select lives_ok($$ select public.create_tenant('Beta Labour', 'bbbbbbbb-0000-0000-0000-000000000001') $$, 'a second user makes a second company');
select throws_ok(
  $$ select public.create_tenant('Taken', 'aaaaaaaa-0000-0000-0000-000000000001') $$,
  '23505', 'operation id already used', 'another user cannot reuse an operation id to reach a company'
);
select results_eq('select name from public.tenants', array['Beta Labour'], 'Beta sees only its own company');
select results_eq('select count(*)::int from public.memberships', array[1], 'Beta sees only its own membership');
select is_empty('select * from public.devices', 'Beta does not see Alpha''s device');

-- Ids known only to the database, kept where any role can read them.
reset role;
do $$
begin
  perform set_config('test.alpha', (select tenant_id::text from public.tenants where name = 'Alpha Labour'), true);
  perform set_config('test.beta', (select tenant_id::text from public.tenants where name = 'Beta Labour'), true);
end $$;

-- Alpha cannot reach Beta by any write: no table grant, and the functions check membership from the session.
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select results_eq('select name from public.tenants', array['Alpha Labour'], 'Alpha sees only its own company');
select throws_ok(
  $$ insert into public.memberships (tenant_id, user_id, role, actor_id, source_operation_id)
     values (current_setting('test.beta')::uuid, '11111111-1111-1111-1111-111111111111', 'owner', '11111111-1111-1111-1111-111111111111', gen_random_uuid()) $$,
  '42501', null, 'a member cannot add themself to another company'
);
select throws_ok($$ insert into public.tenants (name, created_by, source_operation_id) values ('Mine', auth.uid(), gen_random_uuid()) $$, '42501', null, 'a company is made only by the server function');
select throws_ok($$ update public.tenants set name = 'Renamed' $$, '42501', null, 'a member cannot change a company row');
select throws_ok(
  $$ select public.register_device(current_setting('test.beta')::uuid, 'dddddddd-0000-0000-0000-00000000000b', 'Sneaky', 'android', gen_random_uuid()) $$,
  '42501', 'not a member of this company', 'a device cannot be put on another company'
);
select is(
  public.register_device(current_setting('test.alpha')::uuid, 'dddddddd-0000-0000-0000-00000000000a', 'Alpha phone', 'android', gen_random_uuid()),
  (select id from public.devices),
  'signing in again on the same device keeps one row'
);

-- An unverified email, or no session at all, makes nothing.
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok($$ select public.create_tenant('Gamma', gen_random_uuid()) $$, '42501', 'verify the email first', 'an unverified email cannot make a company');
select is_empty('select * from public.tenants', 'a user with no company sees none');
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select throws_ok('select * from public.tenants', '42501', null, 'without signing in nothing is readable');
select throws_ok($$ select public.create_tenant('Anon', gen_random_uuid()) $$, '42501', null, 'without signing in nothing is made');

-- Not even the server can move a company to another id.
reset role;
select throws_ok(
  $$ update public.tenants set tenant_id = gen_random_uuid() where name = 'Alpha Labour' $$,
  '42501', 'a tenant keeps its id and maker', 'a company keeps its id'
);

select * from finish();
rollback;
