-- T22c: a plan changed from now (D-083, ADMIN-03, BILL-04). A period that ends early keeps its row as written; a cut
-- of its own ends it, the licence and the MRR read the cut, and the old plan's later periods never come back. A slip
-- accepted from now starts now with the owner's credit after it, and the next slip continues after the credit. Both
-- need the TOTP code of the last five minutes.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'admin@example.test', now()),
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'owner@example.test', now());
insert into private.platform_admins (user_id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Sets who is signed in, at which level, and how long ago a TOTP code was typed (null: never). Called as postgres.
create function pg_temp.claims(p_user uuid, p_aal text, p_totp_seconds_ago integer default null) returns text
language sql as $$
  select set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal,
    'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint))
      || case when p_totp_seconds_ago is null then '[]'::jsonb
         else jsonb_build_array(jsonb_build_object('method', 'totp', 'timestamp', extract(epoch from now())::bigint - p_totp_seconds_ago)) end
  )::text, true)
$$;

create function pg_temp.slip(p_operation text) returns uuid
language sql as $$ select id from public.payment_slips where source_operation_id = p_operation::uuid $$;

-- The customer's company, phone and trial, and two months of Small paid the usual way, the first begun 15 days ago.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select lives_ok($$ select public.create_tenant('Gamma Labour', gen_random_uuid(), 'eeeeeeee-0000-0000-0000-000000000003') $$, 'a customer makes a company');
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000003', 'dddddddd-0000-0000-0000-00000000000b', 'Phone', 'android', gen_random_uuid()) $$,
  'and registers a phone'
);
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000003', 'dddddddd-0000-0000-0000-00000000000b', 3, 1) ->> 'state', 'trial', 'the trial starts');
select lives_ok($$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000003', 'small', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000011') $$, 'a Small slip');
select lives_ok($$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000003', 'small', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000012') $$, 'and its renewal');
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select lives_ok($$ select public.admin_accept_slip(pg_temp.slip('cccccccc-0000-0000-0000-000000000011'), 19900, 'FT-G1', current_date, null, null) $$, 'accepted');
select lives_ok($$ select public.admin_accept_slip(pg_temp.slip('cccccccc-0000-0000-0000-000000000012'), 19900, 'FT-G2', current_date, null, null) $$, 'both');
update public.subscriptions set starts_at_utc = starts_at_utc - interval '15 days', ends_at_utc = ends_at_utc - interval '15 days',
  anchor_at_utc = anchor_at_utc - interval '15 days'
  where tenant_id = 'eeeeeeee-0000-0000-0000-000000000003' and source = 'slip';

-- Who may change a plan.
select ok(not has_function_privilege('anon', 'public.admin_change_plan(uuid, text, integer, text)', 'execute'), 'a visitor cannot change a plan');
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal2', 10);
set local role authenticated;
select throws_ok($$ select public.admin_change_plan('eeeeeeee-0000-0000-0000-000000000003', 'mid', 10, 'Mid chahiye') $$, '42501', 'admins only', 'a customer is refused');
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal1');
select throws_ok($$ select public.admin_change_plan('eeeeeeee-0000-0000-0000-000000000003', 'mid', 10, 'Mid chahiye') $$, '42501', 'admins only', 'so is the admin with only a password');
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 400);
select throws_ok($$ select public.admin_change_plan('eeeeeeee-0000-0000-0000-000000000003', 'mid', 10, 'Mid chahiye') $$, '42501', 'type the code again',
  'and the admin whose code is older than five minutes');
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select throws_ok($$ select public.admin_change_plan('eeeeeeee-0000-0000-0000-000000000003', 'trial', 10, 'Trial') $$, '22023', 'no such plan', 'the trial is not a plan to move to');
select throws_ok($$ select public.admin_change_plan('eeeeeeee-0000-0000-0000-000000000003', 'mid', 0, 'Mid chahiye') $$, '22023', 'from 1 to 366 days', 'at least one day');
select throws_ok($$ select public.admin_change_plan('eeeeeeee-0000-0000-0000-000000000003', 'mid', 10, 'x') $$, '22023', 'say why', 'and a reason');
select is((select count(*)::integer from private.period_cuts), 0, 'a refused change cuts nothing');

-- The change: both Small periods end now, as cuts of their own; the rows as written stay.
select lives_ok($$ select public.admin_change_plan('eeeeeeee-0000-0000-0000-000000000003', 'mid', 10, 'Customer ne Mid manga, bache din ka credit') $$, 'the admin moves the account to Mid');
select results_eq(
  $$ select p.ends_at_utc = greatest(p.starts_at_utc, now()), s.ends_at_utc > now() from private.periods p join public.subscriptions s using (id)
     where p.tenant_id = 'eeeeeeee-0000-0000-0000-000000000003' and p.source = 'slip' order by p.starts_at_utc $$,
  $$ values (true, true), (true, true) $$,
  'the running Small period ends now and its renewal never runs, while both rows stay as written'
);
select is((select count(*)::integer from private.period_cuts where tenant_id = 'eeeeeeee-0000-0000-0000-000000000003'), 2, 'one cut for each');
select throws_ok($$ update private.period_cuts set cut_at_utc = now() + interval '1 day' $$, 'P0001', 'period_cuts is never changed or deleted', 'a cut is never changed');
select results_eq(
  $$ select jsonb_array_length(before), after ->> 'plan', (after ->> 'days')::integer, reason from private.admin_actions where action = 'change_plan' $$,
  $$ values (2, 'mid'::text, 10, 'Customer ne Mid manga, bache din ka credit'::text) $$,
  'one audit row, with the periods as they were'
);

select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select results_eq(
  $$ select f ->> 'state', f ->> 'plan', (f ->> 'ends_at')::timestamptz
     from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000003', 'dddddddd-0000-0000-0000-00000000000b', 3, 1) f) x $$,
  $$ values ('paid'::text, 'mid'::text, now() + interval '10 days') $$,
  'the licence reads Mid until its given days end; the Small renewal never comes back'
);
reset role;
select is((select mrr_fils from private.mrr_at(now() - interval '1 day', true) where tenant_id = 'eeeeeeee-0000-0000-0000-000000000003'), 19900::bigint,
  'yesterday''s MRR still counts the Small plan');
select is((select mrr_fils from private.mrr_at(now() + interval '1 day', true) where tenant_id = 'eeeeeeee-0000-0000-0000-000000000003'), 0::bigint,
  'from now the given Mid brings no money');
select is((select mrr_fils from private.mrr_at(now() + interval '40 days', true) where tenant_id = 'eeeeeeee-0000-0000-0000-000000000003'), 0::bigint,
  'and the cut renewal never counts');

select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select is((select count(*)::integer from jsonb_array_elements(public.admin_account('eeeeeeee-0000-0000-0000-000000000003') -> 'periods') p where p ->> 'cut_at' is not null), 2,
  'the account page shows each cut');
select ok((select bool_and(m ? 'banned_until') from jsonb_array_elements(public.admin_account('eeeeeeee-0000-0000-0000-000000000003') -> 'members') m),
  'and each member''s ban in Supabase Auth');

-- A Large slip accepted from now: the given Mid ends, Large starts now, the credit follows it.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select lives_ok($$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000003', 'large', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000013') $$, 'a Large slip');
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 400);
select throws_ok(
  $$ select public.admin_accept_slip(pg_temp.slip('cccccccc-0000-0000-0000-000000000013'), 49900, 'FT-G3', current_date, 'FAB', '1234', null, true, 5) $$,
  '42501', 'type the code again', 'starting now needs a fresh code'
);
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select throws_ok(
  $$ select public.admin_accept_slip(pg_temp.slip('cccccccc-0000-0000-0000-000000000013'), 49900, 'FT-G3', current_date, 'FAB', '1234', null, true, 400) $$,
  '22023', 'from 0 to 366 days', 'and a credit of a year at most'
);
select lives_ok(
  $$ select public.admin_accept_slip(pg_temp.slip('cccccccc-0000-0000-0000-000000000013'), 49900, 'FT-G3', current_date, 'FAB', '1234', null, true, 5) $$,
  'the admin accepts it from now with 5 days of credit'
);
select results_eq(
  $$ select plan_code, source, starts_at_utc, ends_at_utc from private.periods
     where tenant_id = 'eeeeeeee-0000-0000-0000-000000000003' and kind = 'plan' and plan_code <> 'trial' and ends_at_utc > now() order by starts_at_utc $$,
  $$ values ('large'::text, 'slip'::text, now(), private.months_after(now(), 1)),
            ('large', 'grant', private.months_after(now(), 1), private.months_after(now(), 1) + interval '5 days') $$,
  'Large runs from now, then the credit; nothing of Mid or Small is left to run'
);
select results_eq(
  $$ select (after ->> 'start_now')::boolean, (after ->> 'credit_days')::integer, jsonb_array_length(before -> 'cut') from private.admin_actions
     where action = 'accept_slip' and target_id = pg_temp.slip('cccccccc-0000-0000-0000-000000000013') $$,
  $$ values (true, 5, 1) $$,
  'the audit row says it started now, the credit, and the period it cut'
);

-- The next slip continues after the credit.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select lives_ok($$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000003', 'large', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000014') $$, 'the renewal');
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select lives_ok($$ select public.admin_accept_slip(pg_temp.slip('cccccccc-0000-0000-0000-000000000014'), 49900, 'FT-G4', current_date, null, null) $$, 'accepted the usual way');
select results_eq(
  $$ select starts_at_utc, anchor_at_utc from public.subscriptions where slip_id = pg_temp.slip('cccccccc-0000-0000-0000-000000000014') $$,
  $$ values (private.months_after(now(), 1) + interval '5 days', private.months_after(now(), 1) + interval '5 days') $$,
  'it starts where the credit ends'
);

-- The add-on alone has its own period and never starts the plan from now.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select lives_ok($$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000003', 'large', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000015', 'addon') $$, 'an add-on slip');
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select throws_ok(
  $$ select public.admin_accept_slip(pg_temp.slip('cccccccc-0000-0000-0000-000000000015'), 4000, 'FT-G5', current_date, null, null, null, true, 0) $$,
  '22023', 'the add-on alone starts with its own period', 'is refused from now'
);

select * from finish();
rollback;
