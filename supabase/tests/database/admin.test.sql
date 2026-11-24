-- T22a: the owner's dashboard in the cloud (D-081, ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-08, BILL-01, BILL-04, MET-03).
-- Only a platform admin who typed a TOTP code reaches the admin_ functions; each change and its audit row land
-- together, and the audit log is never changed. Holds, limit overrides and given periods reach the licence. The
-- MRR bridge adds up on sample data.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'admin@example.test', now()),
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'owner@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'beta@example.test', now());
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

-- A paid slip and its periods, made directly, for the metrics on fixed dates.
create function pg_temp.paid(p_tenant uuid, p_covers text, p_code text, p_from date, p_to date) returns uuid
language plpgsql as $$
declare
  v_slip uuid := gen_random_uuid();
  v_plan public.plans%rowtype;
  v_kind text;
begin
  select * into v_plan from public.plans where code = p_code and version = 1;
  insert into public.payment_slips (id, tenant_id, plan_code, plan_version, months, covers, expected_fils, file_path, state,
      submitted_by, submitted_at_utc, decided_at_utc, source_operation_id)
    values (v_slip, p_tenant, p_code, 1, 1, p_covers, 0, p_tenant::text || '/' || v_slip::text || '.jpg', 'accepted',
      '11111111-1111-1111-1111-111111111111', p_from, p_from, gen_random_uuid());
  foreach v_kind in array case p_covers when 'plan' then array['plan'] else array['plan', 'addon'] end loop
    insert into public.subscriptions (tenant_id, kind, plan_code, plan_version, source, slip_id, starts_at_utc, ends_at_utc,
        anchor_at_utc, anchor_months, amount_fils, bank_reference, received_on)
      values (p_tenant, v_kind, p_code, 1, 'slip', v_slip, p_from, p_to, p_from, 1,
        case v_kind when 'plan' then v_plan.price_fils else v_plan.addon_price_fils end, 'REF-' || left(v_slip::text, 8), p_from);
  end loop;
  return v_slip;
end $$;

-- The customer's company and phone; the first licence check starts its trial.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select lives_ok($$ select public.create_tenant('Alpha Labour', gen_random_uuid(), 'eeeeeeee-0000-0000-0000-000000000001') $$, 'a customer makes a company');
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 'Phone', 'android', gen_random_uuid()) $$,
  'and registers a phone'
);
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 3, 1) ->> 'state', 'trial',
  'an app that sends no version is still served, and starts the trial');
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 3, 1, '1.4.0') -> 'hold', 'null'::jsonb,
  'a licence with no hold says so');
reset role;
select is((select app_version from public.devices where device_id = 'dddddddd-0000-0000-0000-00000000000a'), '1.4.0', 'the licence check keeps the app''s version');
select ok((select last_seen_at_utc = now() from public.devices where device_id = 'dddddddd-0000-0000-0000-00000000000a'), 'and when the phone was last seen');

-- Task 1: who reaches the dashboard.
select ok(not has_function_privilege('anon', 'public.admin_overview(timestamptz, timestamptz, boolean)', 'execute'), 'a visitor cannot read the dashboard');
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal2', 10);
set local role authenticated;
select throws_ok($$ select public.admin_overview(now() - interval '30 days', now(), false) $$, '42501', 'admins only', 'a customer is refused, even with a code typed');
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal1');
set local role authenticated;
select throws_ok($$ select public.admin_overview(now() - interval '30 days', now(), false) $$, '42501', 'admins only', 'the admin with only a password is refused');
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
set local role authenticated;
select lives_ok($$ select public.admin_overview(now() - interval '30 days', now(), false) $$, 'the admin with a code reads the overview');
reset role;
-- From here the admin's calls run as postgres with the admin's claims: the functions check the claims, and the
-- lookups in their arguments must not meet the customers' row level security.
select ok(has_function_privilege('authenticated', 'public.admin_accept_slip(uuid, bigint, text, date, text, text, text)', 'execute'), 'a signed-in user may call the actions, which check the admin themselves');
select throws_ok($$ update private.admin_actions set reason = 'changed' $$, 'P0001', 'admin_actions is never changed or deleted', 'the audit log is never changed');
select throws_ok($$ delete from private.admin_actions $$, 'P0001', 'admin_actions is never changed or deleted', 'nor deleted');
select throws_ok(
  $$ insert into public.subscriptions (tenant_id, kind, plan_code, plan_version, source, starts_at_utc, ends_at_utc, anchor_at_utc, amount_fils)
     values ('eeeeeeee-0000-0000-0000-000000000001', 'plan', 'small', 1, 'grant', now(), now() + interval '1 day', now(), 100) $$,
  '23514', null, 'a given period costs nothing'
);
select lives_ok(
  $$ insert into public.subscriptions (tenant_id, kind, plan_code, plan_version, source, starts_at_utc, ends_at_utc, anchor_at_utc, amount_fils)
     values ('eeeeeeee-0000-0000-0000-000000000001', 'addon', 'small', 1, 'grant', now() - interval '2 days', now() - interval '1 day', now() - interval '2 days', 0) $$,
  'the add-on can be given'
);

-- Task 2: the owner's actions, each with one audit row.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select lives_ok($$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000001') $$, 'the customer sends a slip');
select lives_ok($$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'mid', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000002') $$, 'and another');
reset role;
select throws_ok(
  $$ update public.payment_slips set payer_last4 = '12a4' where source_operation_id = 'cccccccc-0000-0000-0000-000000000001' $$,
  '23514', null, 'the payer''s account is 4 digits'
);
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select lives_ok(
  $$ select public.admin_accept_slip((select id from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000001'),
       19900, 'FT2611240001', current_date, 'Mashreq', '7731') $$,
  'the admin accepts a slip'
);
select lives_ok(
  $$ select public.admin_refuse_slip((select id from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000002'), 'Raqam bank mein nahin') $$,
  'and refuses the other'
);
select results_eq(
  $$ select payer_bank, payer_last4, state from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000001' $$,
  $$ values ('Mashreq'::text, '7731'::text, 'accepted'::text) $$,
  'the accepted slip keeps the payer''s bank and last 4 digits'
);
select is((select refuse_reason from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000002'), 'Raqam bank mein nahin', 'the refused slip keeps its reason');
select results_eq(
  $$ select action, actor_id, reason from private.admin_actions order by at_utc, action $$,
  $$ values ('accept_slip'::text, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'bank reference FT2611240001'::text),
            ('refuse_slip', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Raqam bank mein nahin') $$,
  'each decision leaves one audit row with who and why'
);

select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select lives_ok($$ select public.admin_give_days('eeeeeeee-0000-0000-0000-000000000001', 'plan', null, 10, 'Bank ki deri') $$, 'the admin gives 10 days');
select results_eq(
  $$ select starts_at_utc, ends_at_utc - starts_at_utc, plan_code from public.subscriptions
     where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001' and kind = 'plan' and source = 'grant' $$,
  $$ select s.ends_at_utc, interval '10 days', 'small'::text from public.subscriptions s join public.payment_slips p on p.id = s.slip_id
     where p.source_operation_id = 'cccccccc-0000-0000-0000-000000000001' $$,
  'given days start where the paid period ends, on the same plan'
);
select throws_ok($$ select public.admin_give_days('eeeeeeee-0000-0000-0000-000000000001', 'plan', null, 0, 'none') $$, '22023', 'from 1 to 366 days', 'at least a day');
select throws_ok($$ select public.admin_give_days('eeeeeeee-0000-0000-0000-000000000001', 'plan', null, 5, 'no') $$, '22023', 'say why', 'a reason of 3 characters or more');

select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 400);
select throws_ok(
  $$ select public.admin_hold('eeeeeeee-0000-0000-0000-000000000001', 'suspend', now() + interval '7 days', 'Support se rabta karein', null, 'Slip ka masla') $$,
  '42501', 'type the code again', 'a hold needs the code typed in the last 5 minutes'
);
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select lives_ok(
  $$ select public.admin_hold('eeeeeeee-0000-0000-0000-000000000001', 'suspend', now() + interval '7 days', 'Support se rabta karein', 'Do slips', 'Slip ka masla') $$,
  'with it, the account is suspended for a week'
);
select throws_ok(
  $$ select public.admin_hold('eeeeeeee-0000-0000-0000-000000000001', 'block', null, 'Band', null, 'Dhoka') $$,
  '22023', 'this account is held already', 'one live hold at a time'
);
select throws_ok(
  $$ select public.admin_hold('eeeeeeee-0000-0000-0000-000000000001', 'suspend', now() - interval '1 day', 'Band', null, 'Purani tareekh') $$,
  '22023', 'the end is in the past', 'a hold cannot end before it starts'
);
select throws_ok(
  $$ select public.admin_money_entry('eeeeeeee-0000-0000-0000-000000000001', 'refund',
       (select s.id from public.subscriptions s join public.payment_slips p on p.id = s.slip_id where p.source_operation_id = 'cccccccc-0000-0000-0000-000000000001'),
       20000, null, null, 'R-1', current_date, 'Zyada wapas') $$,
  '22023', 'more than was paid', 'a refund cannot pass what was paid'
);
select lives_ok(
  $$ select public.admin_money_entry('eeeeeeee-0000-0000-0000-000000000001', 'refund',
       (select s.id from public.subscriptions s join public.payment_slips p on p.id = s.slip_id where p.source_operation_id = 'cccccccc-0000-0000-0000-000000000001'),
       5000, null, null, 'R-1', current_date, 'Aadha mahina wapas') $$,
  'a part refund is recorded'
);
select lives_ok(
  $$ select public.admin_money_entry('eeeeeeee-0000-0000-0000-000000000001', 'correction',
       (select s.id from public.subscriptions s join public.payment_slips p on p.id = s.slip_id where p.source_operation_id = 'cccccccc-0000-0000-0000-000000000001'),
       0, 'received_on', '2026-11-23', null, current_date, 'Bank ki tareekh 23 thi') $$,
  'and a correction, without changing the period'
);
select is(public.admin_free_trial_claim('owner@example.test', 'Naya email, purani company band'), 2, 'freeing a trial frees its email and its phone');
select lives_ok($$ select public.admin_rename('eeeeeeee-0000-0000-0000-000000000001', 'Alpha Labour LLC', 'Spelling theek') $$, 'the admin renames the company');
select lives_ok($$ select public.admin_note('eeeeeeee-0000-0000-0000-000000000001', 'Large plan mein dilchaspi') $$, 'and writes a note');
select is((select received_on from public.subscriptions s join public.payment_slips p on p.id = s.slip_id where p.source_operation_id = 'cccccccc-0000-0000-0000-000000000001'),
  current_date, 'the corrected period keeps its first date');
select is((select before ->> 'name' from private.admin_actions where action = 'rename'), 'Alpha Labour', 'the rename keeps the old name');
select throws_ok($$ update private.tenant_notes set body = 'x' $$, 'P0001', 'tenant_notes is never changed or deleted', 'a note is never changed');

-- Task 3: what the licence says.
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select results_eq(
  $$ select f ->> 'state', f -> 'hold' ->> 'told', (f -> 'limits' ->> 'workers')::integer
     from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 3, 1, '1.4.0') f) x $$,
  $$ values ('none'::text, 'Support se rabta karein'::text, 0) $$,
  'a suspended account''s licence locks it, with the owner''s words'
);
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select lives_ok($$ select public.admin_lift_hold((select id from private.tenant_holds where lifted_at_utc is null), 'Slip mil gayi') $$, 'the admin lifts the suspension');
insert into private.tenant_holds (tenant_id, kind, until_utc, told, created_at_utc, created_by)
  values ('eeeeeeee-0000-0000-0000-000000000001', 'suspend', now() - interval '1 hour', 'Purana', now() - interval '2 days', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select results_eq(
  $$ select f ->> 'state', f -> 'hold', (f ->> 'ends_at')::timestamptz
     from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 3, 1) f) x $$,
  $$ select 'paid'::text, 'null'::jsonb, max(ends_at_utc) from public.subscriptions where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001' and source = 'grant' and kind = 'plan' $$,
  'a suspension past its end no longer holds, and the given days keep the plan paid to their end'
);
reset role;

select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select lives_ok($$ select public.admin_limit_override('eeeeeeee-0000-0000-0000-000000000001', 'workers', 40, now() + interval '30 days', 'Season ka kaam') $$, 'the admin raises the workers'' limit for a month');
select lives_ok($$ select public.admin_hold('eeeeeeee-0000-0000-0000-000000000001', 'block', null, 'Account band', null, 'Jaali slips') $$, 'and blocks the account');
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select throws_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 'New phone', 'android', gen_random_uuid()) $$,
  '42501', 'this account is blocked', 'a blocked account takes no phone'
);
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select lives_ok($$ select public.admin_lift_hold((select id from private.tenant_holds where lifted_at_utc is null and (until_utc is null or until_utc > now())), 'Baat ho gayi') $$, 'the block is lifted');
select pg_temp.claims('11111111-1111-1111-1111-111111111111', 'aal1');
set local role authenticated;
select is((public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 3, 1) -> 'limits' ->> 'workers')::integer, 40,
  'the raised limit reaches the licence');
reset role;

-- A company whose trial was taken back gets it again as a given period, and the licence says trial.
select pg_temp.claims('33333333-3333-3333-3333-333333333333', 'aal1');
set local role authenticated;
select lives_ok($$ select public.create_tenant('Beta Labour', gen_random_uuid(), 'eeeeeeee-0000-0000-0000-000000000002') $$, 'another company');
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000c', 'Phone', 'android', gen_random_uuid()) $$,
  'with its phone'
);
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000c', 1, 1) ->> 'state', 'trial', 'on its trial');
reset role;
select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select lives_ok(
  $$ select public.admin_revoke_period((select id from public.subscriptions where tenant_id = 'eeeeeeee-0000-0000-0000-000000000002' and source = 'trial'), 'Galti se') $$,
  'the admin takes the trial back'
);
select lives_ok($$ select public.admin_give_days('eeeeeeee-0000-0000-0000-000000000002', 'plan', 'trial', 5, 'Trial dobara') $$, 'and gives it again');
select pg_temp.claims('33333333-3333-3333-3333-333333333333', 'aal1');
set local role authenticated;
select is(public.licence_facts('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000c', 1, 1) ->> 'state', 'trial', 'a given trial reads as a trial');
reset role;

-- Task 4: what the pages read. Four sample accounts in June 2026, and a test account left out unless asked.
insert into public.tenants (tenant_id, name, created_by, source_operation_id, is_test) values
  ('f0000000-0000-0000-0000-000000000001', 'New Small', '11111111-1111-1111-1111-111111111111', gen_random_uuid(), false),
  ('f0000000-0000-0000-0000-000000000002', 'Small to Mid', '11111111-1111-1111-1111-111111111111', gen_random_uuid(), false),
  ('f0000000-0000-0000-0000-000000000003', 'Gone Small', '11111111-1111-1111-1111-111111111111', gen_random_uuid(), false),
  ('f0000000-0000-0000-0000-000000000004', 'On Trial', '11111111-1111-1111-1111-111111111111', gen_random_uuid(), false),
  ('f0000000-0000-0000-0000-000000000005', 'Test Large', '11111111-1111-1111-1111-111111111111', gen_random_uuid(), true);
select pg_temp.paid('f0000000-0000-0000-0000-000000000001', 'plan', 'small', '2026-06-10', '2026-07-10');
select pg_temp.paid('f0000000-0000-0000-0000-000000000002', 'plan', 'small', '2026-05-05', '2026-06-05');
select pg_temp.paid('f0000000-0000-0000-0000-000000000002', 'plan_addon', 'mid', '2026-06-05', '2026-07-05');
select pg_temp.paid('f0000000-0000-0000-0000-000000000003', 'plan', 'small', '2026-05-10', '2026-06-10');
select pg_temp.paid('f0000000-0000-0000-0000-000000000005', 'plan', 'large', '2026-06-02', '2026-07-02');
insert into public.subscriptions (tenant_id, plan_code, plan_version, source, starts_at_utc, ends_at_utc, anchor_at_utc)
  values ('f0000000-0000-0000-0000-000000000004', 'trial', 1, 'trial', '2026-06-01', '2026-06-16', '2026-06-01');
insert into private.money_entries (tenant_id, kind, subscription_id, amount_fils, reference, on_date, reason, created_by)
  select 'f0000000-0000-0000-0000-000000000001', 'refund', s.id, 5000, 'R-2', '2026-06-15', 'Aadha wapas', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  from public.subscriptions s where s.tenant_id = 'f0000000-0000-0000-0000-000000000001';

select pg_temp.claims('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aal2', 10);
select results_eq(
  $$ select (b ->> 'opening')::bigint, (b ->> 'new')::bigint, (b ->> 'expansion')::bigint, (b ->> 'reactivation')::bigint,
       (b ->> 'contraction')::bigint, (b ->> 'churn')::bigint, (b ->> 'closing')::bigint
     from (select public.admin_overview('2026-06-01', '2026-06-20', false) -> 'mrr_bridge' b) x $$,
  $$ values (39800::bigint, 19900::bigint, 12000::bigint, 0::bigint, 0::bigint, 19900::bigint, 51800::bigint) $$,
  'the MRR bridge on sample data: opening, new, expansion, churn and closing'
);
select ok(
  (select (b ->> 'opening')::bigint + (b ->> 'new')::bigint + (b ->> 'expansion')::bigint + (b ->> 'reactivation')::bigint
     - (b ->> 'contraction')::bigint - (b ->> 'churn')::bigint = (b ->> 'closing')::bigint
   from (select public.admin_overview('2026-06-01', '2026-06-20', false) -> 'mrr_bridge' b) x),
  'and it adds up'
);
select is((public.admin_overview('2026-06-01', '2026-06-20', true) -> 'mrr_bridge' ->> 'new')::bigint, 69800::bigint, 'a test account counts only when asked');
select is((public.admin_overview('2026-06-01', '2026-06-20', false) ->> 'cash_fils')::bigint, 46800::bigint, 'cash collected is what reached the bank in the range, less refunds');
select is((public.admin_overview('2026-06-01', '2026-06-20', false) ->> 'mrr_fils')::bigint, 51800::bigint, 'MRR on the last day of the range');
select is(jsonb_array_length(public.admin_accounts(false)), 6, 'every account but the test one');
select is(jsonb_array_length(public.admin_accounts(true)), 7, 'and the test one when asked');
select is(public.admin_account('eeeeeeee-0000-0000-0000-000000000001') ->> 'name', 'Alpha Labour LLC', 'one account by its id');
select ok(jsonb_array_length(public.admin_account('eeeeeeee-0000-0000-0000-000000000001') -> 'story') > 0, 'with its story');
select throws_ok($$ select public.admin_account('99999999-0000-0000-0000-000000000000') $$, '22023', 'no such account', 'an unknown account is refused');
select ok(jsonb_array_length(public.admin_slips(now() - interval '1 day', now() + interval '1 day')) = 2, 'the slips sent in the range');
select ok(jsonb_array_length(public.admin_audit(now() - interval '1 day', now() + interval '1 day')) >= 10, 'the audit log of the range');
select ok(public.admin_settings() ? 'admins', 'the settings name the admins');

select * from finish();
rollback;
