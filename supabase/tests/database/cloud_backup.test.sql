-- T20d-a: the cloud backup (D-072, D-075, D-076; DATA-06, DATA-08, PLAN-05, PLAN-06, AUTH-05). The owner's phone that
-- is on sends the company's copy; the app never reaches the stored file. Without the add-on only the latest copy
-- stays and none comes back; with it a daily copy is kept 30 days. A new phone does not replace the old phone's copy
-- unasked. A deleted account's newest copy waits 60 days. Another company gets nothing.
begin;
create extension if not exists pgtap with schema extensions;
select plan(91);
-- Test plumbing only: the role that stands in for the storage server looks a copy's path up here.
grant select on public.cloud_backups to service_role;

insert into auth.users (id, aud, role, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'owner@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'manager@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'beta@example.test', now());

select results_eq(
  $$ select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'backups' $$,
  $$ values (false, 52428800::bigint, array['application/zip']) $$,
  'copies are kept private, up to 50 MB, as a zip'
);
select ok(not has_function_privilege('anon', 'public.backup_start(uuid, uuid, bigint, uuid, boolean)', 'execute'), 'a visitor cannot send a copy');
select ok(
  not has_function_privilege('authenticated', 'public.backup_removals_due()', 'execute')
    and not has_function_privilege('authenticated', 'public.backup_removals_done(text[])', 'execute'),
  'only the server lists and clears the files to remove'
);

-- Alpha's owner signed in on a phone a day ago and has a manager; Beta is another company.
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
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select lives_ok(
  $$ select public.create_tenant('Beta Labour', 'bbbbbbbb-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002') $$,
  'another owner makes another company'
);
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000c', 'Beta phone', 'android', gen_random_uuid()) $$,
  'and signs in on its phone'
);
reset role;
update public.devices set created_at_utc = now() - interval '1 day' where device_id = 'dddddddd-0000-0000-0000-00000000000a';
insert into public.memberships (tenant_id, user_id, role, actor_id, source_operation_id) values
  ('eeeeeeee-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'manager', '11111111-1111-1111-1111-111111111111', gen_random_uuid());
insert into public.devices (tenant_id, user_id, device_id, label, platform, actor_id, source_operation_id) values
  ('eeeeeeee-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'dddddddd-0000-0000-0000-00000000000d', 'Manager phone', 'android', '22222222-2222-2222-2222-222222222222', gen_random_uuid());

-- Only the owner sends, from a phone the company knows, a copy of a size the storage takes.
set local role authenticated;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000d', 1000, gen_random_uuid()) $$,
  '42501', 'only the company''s owner keeps the cloud copy', 'a manager cannot send the company''s copy'
);
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000c', 1000, gen_random_uuid()) $$,
  '42501', 'only the company''s owner keeps the cloud copy', 'nor can another company''s owner'
);
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000f', 1000, gen_random_uuid()) $$,
  '42501', 'this phone is not registered', 'nor a phone the company does not know'
);
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 52428801, gen_random_uuid()) $$,
  '22023', 'the copy is too large', 'a copy over 50 MB is refused'
);
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 0, gen_random_uuid()) $$,
  '22023', 'the copy''s size is needed', 'and so is one with no size'
);
select is(
  public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 3, 1) -> 'addon_until',
  'null'::jsonb, 'a trial''s licence carries no add-on'
);

-- The first copy: a path in the company's own folder; it counts only once its file is in storage.
select ok(
  public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 1000, 'cccccccc-0000-0000-0000-000000000001') ->> 'path'
    like 'eeeeeeee-0000-0000-0000-000000000001/%.zip',
  'a copy''s file goes in the company''s own folder'
);
select is(
  public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 1000, 'cccccccc-0000-0000-0000-000000000001'),
  jsonb_build_object('path', (select file_path from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000001'), 'arrived', false),
  'a retry returns the same path, with the file not yet there'
);
select throws_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001') $$,
  'P0001', 'the file has not arrived', 'a copy does not count before its file is in storage'
);
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000c', 1000, 'cccccccc-0000-0000-0000-000000000001') $$,
  '23505', 'operation id already used', 'another company cannot reach a copy by its operation id'
);
select throws_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000001') $$,
  '22023', 'no such copy', 'nor finish it as its own'
);
select throws_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001') $$,
  '42501', 'only the company''s owner keeps the cloud copy', 'nor as the other company''s'
);
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
reset role;
do $$ begin
  perform set_config('test.p1', (select file_path from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000001'), true);
end $$;
set local role authenticated;
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values ('backups', current_setting('test.p1')) $$,
  '42501', null, 'the app cannot put a file in the bucket itself'
);
-- The file arrives through the server's upload link.
set local role service_role;
insert into storage.objects (bucket_id, name, metadata)
  select 'backups', file_path, '{"size": 1000}'::jsonb from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000001';
set local role authenticated;
select is(
  public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 1000, 'cccccccc-0000-0000-0000-000000000001') -> 'arrived',
  'true'::jsonb, 'a retry after the upload says the file is there'
);
select lives_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001') $$,
  'the copy counts once its file is there'
);
select results_eq(
  $$ select size_bytes, device_id, finished_at_utc is not null, keep_until_utc is null from public.cloud_backups $$,
  $$ values (1000::bigint, 'dddddddd-0000-0000-0000-00000000000a'::uuid, true, true) $$,
  'with the size read from storage, and no daily keep without the add-on'
);
select is(
  public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001'),
  (select finished_at_utc from public.cloud_backups),
  'finishing again changes nothing'
);
select is_empty($$ select * from storage.objects where bucket_id = 'backups' $$, 'the owner cannot read the stored file itself');
select throws_ok(
  $$ select public.backup_download('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', (select id from public.cloud_backups)) $$,
  '42501', 'the add-on is needed', 'the trial does not bring a copy back'
);
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select is_empty('select * from public.cloud_backups', 'a manager does not see the copies');
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select is_empty('select * from public.cloud_backups', 'nor does another company');

-- Beta sends its own copy, to be found untouched at the end.
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000c', 300, 'cccccccc-0000-0000-0000-0000000000b1') $$,
  'the other company sends its own copy'
);
set local role service_role;
insert into storage.objects (bucket_id, name, metadata)
  select 'backups', file_path, '{"size": 300}'::jsonb from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-0000000000b1';
set local role authenticated;
select lives_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-0000000000b1') $$,
  'which counts too'
);

-- Without the add-on a newer copy takes the older one's place, and the older file is handed to the server to remove.
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 2000, 'cccccccc-0000-0000-0000-000000000002') $$,
  'the owner sends a second copy'
);
set local role service_role;
insert into storage.objects (bucket_id, name, metadata)
  select 'backups', file_path, '{"size": 2000}'::jsonb from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000002';
set local role authenticated;
select lives_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000002') $$,
  'and it counts'
);
select results_eq(
  $$ select source_operation_id from public.cloud_backups $$,
  $$ values ('cccccccc-0000-0000-0000-000000000002'::uuid) $$,
  'without the add-on only the latest copy stays'
);
reset role;
do $$ begin
  perform set_config('test.p2', (select file_path from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000002'), true);
end $$;
select results_eq(
  $$ select file_path, remove_after_utc <= now() from private.backup_removals $$,
  $$ values (current_setting('test.p1'), true) $$,
  'and the older file is due to go from storage'
);
set local role service_role;
select is(public.backup_removals_due(), array[current_setting('test.p1')], 'the server is told which files to remove');
select lives_ok($$ select public.backup_removals_done(array[current_setting('test.p1')]) $$, 'and notes that they went');
reset role;
select is((select count(*)::int from private.backup_removals), 0, 'so none is left to remove');

-- An upload left unfinished gives way to the next one.
set local role authenticated;
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 2000, 'cccccccc-0000-0000-0000-000000000003') $$,
  'an upload starts and is abandoned'
);
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 2000, 'cccccccc-0000-0000-0000-000000000004') $$,
  'and another starts'
);
reset role;
select results_eq(
  $$ select remove_after_utc - now() from private.backup_removals $$,
  $$ values (interval '3 hours') $$,
  'the abandoned one gives way, its file removed once its upload link has run out'
);

-- The phone is lost. The owner signs in on a new one and turns the old one off; the new phone's data does not
-- replace the old phone's copy unasked, and the copy does not come back without the add-on.
set local role authenticated;
select lives_ok(
  $$ select public.register_device('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 'New phone', 'android', gen_random_uuid()) $$,
  'the owner signs in on a new phone'
);
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 500, gen_random_uuid()) $$,
  '42501', 'another phone is on', 'which cannot send while the first is on'
);
select lives_ok(
  $$ select public.turn_phone_off((select id from public.devices where device_id = 'dddddddd-0000-0000-0000-00000000000a'), gen_random_uuid()) $$,
  'the owner turns the old phone off'
);
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', 500, gen_random_uuid()) $$,
  '42501', 'this device was revoked', 'and it can send no more'
);
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 500, gen_random_uuid()) $$,
  'P0001', 'the cloud copy is from another phone', 'the new phone''s data does not replace the old phone''s copy unasked'
);
select throws_ok(
  $$ select public.backup_download('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', (select id from public.cloud_backups where finished_at_utc is not null)) $$,
  '42501', 'the add-on is needed', 'and the copy does not come back without the add-on'
);

-- The add-on alone, by a slip like any other; a company with no paid plan names one.
select lives_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000011', 'addon') $$,
  'the owner sends a slip for the add-on alone, naming a plan'
);
select results_eq(
  $$ select covers, expected_fils from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000011' $$,
  $$ values ('addon', 2000::bigint) $$,
  'at that plan''s add-on price, 20 AED'
);
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000001', 'small', 1, 'jpg', gen_random_uuid(), 'gift') $$,
  '22023', 'a slip covers the plan, the plan with the add-on, or the add-on', 'a slip covers only what is sold'
);
reset role;
select lives_ok(
  $$ select private.accept_slip((select id from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000011'), 2000, 'RAK-A1', current_date) $$,
  'the platform''s owner accepts it'
);
select results_eq(
  $$ select kind, amount_fils, starts_at_utc = now(), ends_at_utc = private.months_after(now(), 1)
     from public.subscriptions where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001' and source = 'slip' $$,
  $$ values ('addon', 2000::bigint, true, true) $$,
  'which makes a month of the add-on from today and no plan period'
);
select set_config('test.month1', private.months_after(now(), 1)::text, true);
select set_config('test.month2', private.months_after(now(), 2)::text, true);
select set_config('test.month3', private.months_after(now(), 3)::text, true);
set local role authenticated;
select is(
  public.backup_download('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', (select id from public.cloud_backups where finished_at_utc is not null)),
  current_setting('test.p2'),
  'with the add-on the owner gets the copy''s path, on the new phone'
);
select throws_ok(
  $$ select public.backup_download('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', gen_random_uuid()) $$,
  '22023', 'no such copy', 'but not of a copy that is not there'
);
select throws_ok(
  $$ select public.backup_download('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000a', (select id from public.cloud_backups where finished_at_utc is not null)) $$,
  '42501', 'this device was revoked', 'nor on the phone that was turned off'
);
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok(
  $$ select public.backup_download('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000') $$,
  '42501', 'only the company''s owner keeps the cloud copy', 'nor does another company''s owner get it'
);
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select is(
  (public.licence_facts('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 0, 0) ->> 'addon_until')::timestamptz,
  current_setting('test.month1')::timestamptz,
  'the licence carries the add-on''s end'
);

-- The owner keeps the new phone's data. With the add-on a copy is a daily copy, one a day, kept 30 days.
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 700, 'cccccccc-0000-0000-0000-000000000005', true) $$,
  'the owner chooses to keep the new phone''s data'
);
set local role service_role;
insert into storage.objects (bucket_id, name, metadata)
  select 'backups', file_path, '{"size": 700}'::jsonb from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000005';
set local role authenticated;
select lives_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000005') $$,
  'and its copy counts'
);
select results_eq(
  $$ select source_operation_id, keep_until_utc = finished_at_utc + interval '30 days' from public.cloud_backups where finished_at_utc is not null $$,
  $$ values ('cccccccc-0000-0000-0000-000000000005'::uuid, true) $$,
  'with the add-on it is a daily copy kept 30 days, and the old phone''s copy gives way'
);
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 800, 'cccccccc-0000-0000-0000-000000000006') $$,
  'a second copy the same day'
);
set local role service_role;
insert into storage.objects (bucket_id, name, metadata)
  select 'backups', file_path, '{"size": 800}'::jsonb from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000006';
set local role authenticated;
select lives_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000006') $$,
  'counts'
);
select results_eq(
  $$ select source_operation_id from public.cloud_backups where finished_at_utc is not null $$,
  $$ values ('cccccccc-0000-0000-0000-000000000006'::uuid) $$,
  'and takes the day''s place: one daily copy a day'
);
-- That copy was made two days ago.
reset role;
update public.cloud_backups set finished_at_utc = finished_at_utc - interval '2 days', keep_until_utc = keep_until_utc - interval '2 days'
  where source_operation_id = 'cccccccc-0000-0000-0000-000000000006';
set local role authenticated;
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 900, 'cccccccc-0000-0000-0000-000000000007') $$,
  'today''s copy'
);
set local role service_role;
insert into storage.objects (bucket_id, name, metadata)
  select 'backups', file_path, '{"size": 900}'::jsonb from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000007';
set local role authenticated;
select lives_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000007') $$,
  'counts'
);
select is(
  (select count(*)::int from public.cloud_backups where finished_at_utc is not null), 2,
  'a daily copy of an earlier day stays beside today''s'
);
-- The older copy is past its days; the other was made yesterday.
reset role;
update public.cloud_backups set keep_until_utc = now() - interval '1 minute' where source_operation_id = 'cccccccc-0000-0000-0000-000000000006';
update public.cloud_backups set finished_at_utc = finished_at_utc - interval '1 day', keep_until_utc = keep_until_utc - interval '1 day'
  where source_operation_id = 'cccccccc-0000-0000-0000-000000000007';
set local role authenticated;
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 950, 'cccccccc-0000-0000-0000-000000000008') $$,
  'the next day''s copy'
);
set local role service_role;
insert into storage.objects (bucket_id, name, metadata)
  select 'backups', file_path, '{"size": 950}'::jsonb from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000008';
set local role authenticated;
select lives_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000008') $$,
  'counts'
);
select results_eq(
  $$ select source_operation_id from public.cloud_backups where finished_at_utc is not null order by finished_at_utc $$,
  $$ values ('cccccccc-0000-0000-0000-000000000007'::uuid), ('cccccccc-0000-0000-0000-000000000008'::uuid) $$,
  'a daily copy past its days goes; one inside them stays'
);

-- A changed app cannot fill the storage.
reset role;
update private.backup_starts set starts = 20 where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001';
set local role authenticated;
select throws_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 500, gen_random_uuid()) $$,
  '22023', 'too many copies today', 'a company starts at most 20 copies a day'
);
reset role;
update private.backup_starts set starts = 1 where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001';

-- The add-on ends: no copy comes back, the daily copies already made stay their days, and a new copy is not daily.
select lives_ok(
  $$ select private.revoke_subscription((select id from public.subscriptions where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001' and kind = 'addon'), 'the add-on ends') $$,
  'the add-on ends'
);
set local role authenticated;
select throws_ok(
  $$ select public.backup_download('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b',
       (select id from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000008')) $$,
  '42501', 'the add-on is needed', 'and no copy comes back any more'
);
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 990, 'cccccccc-0000-0000-0000-000000000009') $$,
  'a copy is still sent'
);
set local role service_role;
insert into storage.objects (bucket_id, name, metadata)
  select 'backups', file_path, '{"size": 990}'::jsonb from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000009';
set local role authenticated;
select lives_ok(
  $$ select public.backup_finish('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000009') $$,
  'and counts'
);
select results_eq(
  $$ select source_operation_id, keep_until_utc is null from public.cloud_backups where finished_at_utc is not null order by finished_at_utc $$,
  $$ values ('cccccccc-0000-0000-0000-000000000007'::uuid, false), ('cccccccc-0000-0000-0000-000000000008'::uuid, false),
            ('cccccccc-0000-0000-0000-000000000009'::uuid, true) $$,
  'daily copies already made stay their days; the new copy is not a daily one'
);

-- One slip for the plan with the add-on makes both periods; the add-on alone then goes with the company's own plan.
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select lives_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000002', 'mid', 2, 'pdf', 'cccccccc-0000-0000-0000-000000000021', 'plan_addon') $$,
  'the other company sends a slip for two months of Mid with the add-on'
);
select is(
  (select expected_fils from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000021'), 63800::bigint,
  'expecting 2 x (299 + 20) AED, in fils'
);
reset role;
select lives_ok(
  $$ select private.accept_slip((select id from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000021'), 63800, 'RAK-B1', current_date) $$,
  'the platform''s owner accepts it'
);
select results_eq(
  $$ select kind, amount_fils, ends_at_utc = private.months_after(now(), 2)
     from public.subscriptions where tenant_id = 'eeeeeeee-0000-0000-0000-000000000002' order by kind $$,
  $$ values ('addon', 4000::bigint, true), ('plan', 59800::bigint, true) $$,
  'which makes a plan period and an add-on period, their money adding up to what was received'
);
set local role authenticated;
select throws_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000002', 'small', 1, 'jpg', gen_random_uuid(), 'addon') $$,
  '22023', 'the add-on alone goes with the company''s own plan', 'the add-on alone cannot name another plan'
);
select lives_ok(
  $$ select public.submit_slip('eeeeeeee-0000-0000-0000-000000000002', 'mid', 1, 'jpg', 'cccccccc-0000-0000-0000-000000000022', 'addon') $$,
  'so the company sends one for its own plan'
);
reset role;
select lives_ok(
  $$ select private.accept_slip((select id from public.payment_slips where source_operation_id = 'cccccccc-0000-0000-0000-000000000022'), 2000, 'RAK-B2', current_date) $$,
  'which is accepted'
);
select results_eq(
  $$ select s.starts_at_utc = private.months_after(now(), 2), s.ends_at_utc = private.months_after(now(), 3), s.anchor_months
     from public.subscriptions s join public.payment_slips p on p.id = s.slip_id
     where p.source_operation_id = 'cccccccc-0000-0000-0000-000000000022' $$,
  $$ values (true, true, 3) $$,
  'the add-on continues from the end of its own period'
);
set local role authenticated;
select results_eq(
  $$ select f ->> 'state', (f ->> 'ends_at')::timestamptz = current_setting('test.month2')::timestamptz,
       (f ->> 'addon_until')::timestamptz = current_setting('test.month3')::timestamptz
     from (select public.licence_facts('eeeeeeee-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-00000000000c', 0, 0) f) x $$,
  $$ values ('paid', true, true) $$,
  'the licence carries the plan''s end, and the end of the add-on''s unbroken run'
);

-- Deleting the account: the newest copy waits 60 days with the company's id and the email, the rest go.
reset role;
update public.memberships set revoked_at_utc = now() where user_id = '22222222-2222-2222-2222-222222222222';
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ select public.backup_start('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-00000000000b', 100, 'cccccccc-0000-0000-0000-000000000012') $$,
  'an upload is under way'
);
reset role;
create temp table alpha_copies as
  select file_path, source_operation_id from public.cloud_backups where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001';
do $$ begin
  perform set_config('test.p9', (select file_path from public.cloud_backups where source_operation_id = 'cccccccc-0000-0000-0000-000000000009'), true);
end $$;
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint)))::text, true);
select lives_ok('select public.delete_account()', 'the owner deletes the account');
reset role;
select is((select count(*)::int from public.cloud_backups where tenant_id = 'eeeeeeee-0000-0000-0000-000000000001'), 0, 'its copies leave the list');
select results_eq(
  $$ select c.source_operation_id, r.email, r.remove_after_utc - now()
     from private.backup_removals r join alpha_copies c using (file_path) order by c.source_operation_id $$,
  $$ values ('cccccccc-0000-0000-0000-000000000007'::uuid, null::text, interval '0'),
            ('cccccccc-0000-0000-0000-000000000008'::uuid, null, interval '0'),
            ('cccccccc-0000-0000-0000-000000000009'::uuid, 'owner@example.test', interval '60 days'),
            ('cccccccc-0000-0000-0000-000000000012'::uuid, null, interval '3 hours') $$,
  'the newest copy waits 60 days with the email to find it by; the rest go at once, an upload under way once its link has run out'
);
set local role service_role;
select ok(not public.backup_removals_due() @> array[current_setting('test.p9')], 'the kept copy is not among the files to remove');
select lives_ok($$ select public.backup_removals_done(array[current_setting('test.p9')]) $$, 'and naming it early');
reset role;
select is(
  (select count(*)::int from private.backup_removals where file_path = current_setting('test.p9') and email = 'owner@example.test'), 1,
  'does not drop it'
);
select is(
  (select count(*)::int from public.cloud_backups where tenant_id = 'eeeeeeee-0000-0000-0000-000000000002' and finished_at_utc is not null), 1,
  'the other company''s copy is untouched'
);

select * from finish();
rollback;
