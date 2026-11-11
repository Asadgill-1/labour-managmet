-- T21a: the plans and the bank details are the cloud's config, readable by anyone signed in and written by nobody
-- through the API (D-074). A month runs to the same day next month, clamped, on Dubai's clock (BILL-04, D-105).
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'owner@example.test', now());

set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select results_eq(
  'select code, price_fils, addon_price_fils from public.plans where on_sale order by sort_order',
  $$ values ('small', 19900::bigint, 2000::bigint), ('mid', 29900::bigint, 2000::bigint), ('large', 49900::bigint, 4000::bigint) $$,
  'three plans are on sale at 199, 299 and 499 AED, in fils'
);
select results_eq(
  'select max_workers, max_clients, max_managers from public.plans where on_sale order by sort_order',
  $$ values (15, 5, 1), (35, 9, 2), (null::int, null::int, null::int) $$,
  'with their limits, Large without any'
);
select results_eq(
  $$ select on_sale, max_workers from public.plans where code = 'trial' $$,
  $$ values (false, null::int) $$,
  'the trial is not for sale and has no limit'
);
select is((select trial_days from public.platform_settings), 15, 'the trial is 15 days');
select throws_ok(
  $$ insert into public.plans (code, version, name, price_fils, addon_price_fils) values ('free', 1, 'Free', 0, 0) $$,
  '42501', null, 'a signed-in user cannot add a plan'
);
select throws_ok($$ update public.plans set price_fils = 0 $$, '42501', null, 'nor change a price');
select throws_ok($$ delete from public.plans $$, '42501', null, 'nor remove a plan');
select throws_ok($$ update public.platform_settings set account_number = '1' $$, '42501', null, 'nor change the bank details');
select throws_ok($$ select private.months_after(now(), 1) $$, '42501', null, 'nor run the month arithmetic');

set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select throws_ok('select * from public.plans', '42501', null, 'a visitor reads no plan');
select throws_ok('select * from public.platform_settings', '42501', null, 'nor the bank details');

reset role;
set local timezone to 'UTC';
select is(private.months_after('2027-01-31 10:00+04', 1), '2027-02-28 10:00+04'::timestamptz, 'Jan 31 plus a month is Feb 28');
select is(private.months_after('2027-01-31 10:00+04', 2), '2027-03-31 10:00+04'::timestamptz, 'and plus two months is Mar 31');
select is(private.months_after('2028-01-31 10:00+04', 1), '2028-02-29 10:00+04'::timestamptz, 'Feb 29 in a leap year');
select is(private.months_after('2027-01-31 02:00+04', 1), '2027-02-28 02:00+04'::timestamptz, 'early on the 31st in Dubai, still the 30th in UTC, is the 31st');
select is(private.months_after('2026-12-31 01:00+04', 2), '2027-02-28 01:00+04'::timestamptz, 'counted on Dubai''s clock, not UTC''s');

select * from finish();
rollback;
