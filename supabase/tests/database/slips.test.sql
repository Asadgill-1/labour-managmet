-- T21a: a company's owner sends a payment slip into the company's own folder, at most 3 waiting; the platform's owner
-- accepts or refuses it from the SQL editor, and nobody else can (D-074, BILL-01, BILL-02, BILL-04, MODEL-05). A
-- renewal continues the paid period from its end and keeps its anchor day. Deleting the account takes the slips.
begin;
create extension if not exists pgtap with schema extensions;
select plan(40);

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'owner@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'manager@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'beta@example.test', now());

select results_eq(
  $$ select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'payment-slips' $$,
  $$ values (false, 5242880::bigint, array['image/jpeg', 'image/png', 'application/pdf']) $$,
  'slips are kept private, up to 5 MB, as a photo or a PDF'
);
select ok(not has_function_privilege('anon', 'public.submit_slip(uuid, text, integer, text, uuid)', 'execute'), 'a visitor cannot send a slip');

set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ select public.create_tenant('Alpha Labour', 'aaaaaaaa-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001') $$,
  'the owner makes a company'
);
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select lives_ok(
  $$ select public.create_tenant('Beta Labour', 'bbbbbbbb-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002') $$,
  'and so does another'
);
reset role;
insert into public.memberships (tenant_id, user_id, role, actor_id, source_operation_id) values
  ('eeeeeeee-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'manager', '11111111-1111-1111-1111-111111111111', gen_random_uuid());

-- The owner sends slips; the path is in the company's own folder, and a retry returns the same one.
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select ok(
  public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000001') like 'eeeeeeee-0000-0000-0000-000000000001/%.jpg',
  'a slip''s file goes in the company''s own folder'
);
select is(
  public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000001'),
  (select file_path from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000001'),
  'a retry returns the same slip'
);
select lives_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'mid', 3, 'pdf', 'cccccccc-0000-0000-0000-000000000002') $$,
  'a second slip, for three months of Mid'
);
select is((select expected_fils from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000002'), 89700::bigint, 'expects 3 x 299 AED, in fils');
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'gif', gen_random_uuid()) $$,
  '22023', 'a slip is a jpg, png or pdf', 'another kind of file is refused'
);
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 0, 'jpg', gen_random_uuid()) $$,
  '22023', 'from 1 to 12 months', 'no months is refused'
);
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 13, 'jpg', gen_random_uuid()) $$,
  '22023', 'from 1 to 12 months', 'nor more than a year'
);
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'trial', 1, 'jpg', gen_random_uuid()) $$,
  '22023', 'no such plan on sale', 'the trial cannot be bought'
);
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'gold', 1, 'jpg', gen_random_uuid()) $$,
  '22023', 'no such plan on sale', 'nor a plan that does not exist'
);
select lives_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'png', 'cccccccc-0000-0000-0000-000000000003') $$,
  'a third slip'
);
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'png', gen_random_uuid()) $$,
  '22023', 'three slips are waiting already', 'a fourth waiting slip is refused'
);

-- Only the owner sends, and another company cannot reach these slips.
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'jpg', gen_random_uuid()) $$,
  '42501', 'only the company''s owner sends a slip', 'a manager cannot send a slip'
);
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'jpg', gen_random_uuid()) $$,
  '42501', 'only the company''s owner sends a slip', 'nor can another company''s owner'
);
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000002', 'small', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000001') $$,
  '23505', 'operation id already used', 'nor reach a slip by its operation id'
);
select is_empty('select * from public.payment_slips', 'another company sees none of the slips');

reset role;
do $$ begin
  perform set_config('test.path1', (select file_path from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000001'), true);
  perform set_config('test.path2', (select file_path from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000002'), true);
  perform set_config('test.slip1', (select id::text from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000001'), true);
  perform set_config('test.slip2', (select id::text from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000002'), true);
  perform set_config('test.slip3', (select id::text from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000003'), true);
end $$;

-- The file goes only to a waiting slip's own path, by its company's owner.
set local role authenticated;
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values ('payment-slips', current_setting('test.path2')) $$,
  '42501', null, 'another company cannot put a file at the slip''s path'
);
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ insert into storage.objects (bucket_id, name) values ('payment-slips', current_setting('test.path1')) $$,
  'the owner puts the slip''s file at its path'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values ('payment-slips', 'eeeeeeee-0000-0000-0000-000000000001/made-up.jpg') $$,
  '42501', null, 'but nowhere else'
);
select results_eq($$ select count(*)::int from storage.objects where bucket_id = 'payment-slips' $$, array[1], 'the owner sees the file');
select throws_ok($$ update public.payment_slips set state = 'accepted' $$, '42501', null, 'the owner cannot accept a slip');
select throws_ok(
  $$ select private.accept_slip(current_setting('test.slip1')::uuid, 19900, 'RAK-1', current_date) $$,
  '42501', null, 'nor run the platform''s accept'
);
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select is_empty($$ select * from storage.objects where bucket_id = 'payment-slips' $$, 'another company sees no file');

-- The platform's owner accepts after finding the money: a month from now, with the amount and the bank reference.
reset role;
select lives_ok(
  $$ select private.accept_slip(current_setting('test.slip1')::uuid, 19900, 'RAK-1', current_date, 'seen in the bank') $$,
  'the platform''s owner accepts the first slip'
);
select results_eq(
  $$ select s.starts_at_utc = now(), s.ends_at_utc = private.months_after(now(), 1), s.amount_fils, s.bank_reference, p.state
     from public.subscriptions s join public.payment_slips p on p.id = s.slip_id where p.id = current_setting('test.slip1')::uuid $$,
  $$ values (true, true, 19900::bigint, 'RAK-1', 'accepted') $$,
  'a month from now, with what was received'
);
select throws_ok(
  $$ select private.accept_slip(current_setting('test.slip1')::uuid, 19900, 'RAK-1', current_date) $$,
  'this slip was decided already', 'a slip is accepted once'
);
select throws_ok(
  $$ select private.accept_slip(current_setting('test.slip2')::uuid, 89700, ' ', current_date) $$,
  'the amount received, the bank reference and the date received are needed', 'not without the bank reference'
);
select lives_ok($$ select private.accept_slip(current_setting('test.slip2')::uuid, 89700, 'RAK-2', current_date) $$, 'then the second');
select results_eq(
  $$ select s.starts_at_utc = private.months_after(now(), 1), s.ends_at_utc = private.months_after(now(), 4), s.anchor_months
     from public.subscriptions s where s.slip_id = current_setting('test.slip2')::uuid $$,
  $$ values (true, true, 4) $$,
  'an early renewal continues from the end of the paid month, counted from the first paid day'
);
select throws_ok(
  $$ select private.refuse_slip(current_setting('test.slip3')::uuid, '  ') $$,
  'say why the slip is refused', 'a refusal needs a reason'
);
select lives_ok($$ select private.refuse_slip(current_setting('test.slip3')::uuid, 'No such transfer in the bank') $$, 'the third slip is refused');
select throws_ok(
  $$ select private.refuse_slip(current_setting('test.slip3')::uuid, 'again') $$,
  'no waiting slip with this id', 'once'
);

-- Paid to Feb 28 from Jan 31, two months more run to Apr 30, not Apr 28: the anchor day holds (BILL-04).
insert into public.payment_slips (id, tenant_id, plan_code, plan_version, months, expected_fils, file_path, state, decided_at_utc, submitted_by, source_operation_id) values
  ('5b000000-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002', 'small', 1, 1, 19900, 'eeeeeeee-0000-0000-0000-000000000002/old.jpg', 'accepted', now(), '33333333-3333-3333-3333-333333333333', gen_random_uuid());
insert into public.subscriptions (tenant_id, plan_code, plan_version, source, slip_id, starts_at_utc, ends_at_utc, anchor_at_utc, anchor_months, amount_fils, bank_reference, received_on) values
  ('eeeeeeee-0000-0000-0000-000000000002', 'small', 1, 'slip', '5b000000-0000-0000-0000-000000000001', '2027-01-31 10:00+04', '2027-02-28 10:00+04', '2027-01-31 10:00+04', 1, 19900, 'RAK-B1', current_date);
set local role authenticated;
select lives_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000002', 'small', 2, 'jpg', 'cccccccc-0000-0000-0000-000000000009') $$,
  'Beta sends a slip for two more months'
);
reset role;
select lives_ok(
  $$ select private.accept_slip((select id from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000009'), 39800, 'RAK-B2', current_date) $$,
  'and the platform''s owner accepts it'
);
select results_eq(
  $$ select s.starts_at_utc, s.ends_at_utc from public.subscriptions s join public.payment_slips p on p.id = s.slip_id
     where p.source_operation_id = 'cccccccc-0000-0000-0000-000000000009' $$,
  $$ values ('2027-02-28 10:00+04'::timestamptz, '2027-04-30 10:00+04'::timestamptz) $$,
  'which run from Feb 28 to Apr 30'
);

-- Deleting the account takes its slips and plan periods.
update public.memberships set revoked_at_utc = now() where user_id = '22222222-2222-2222-2222-222222222222';
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint)))::text, true);
select lives_ok('select public.delete_account()', 'the owner deletes the account');
reset role;
select is((select count(*)::int from public.payment_slips where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001'), 0, 'its slips went with it');

select * from finish();
rollback;
