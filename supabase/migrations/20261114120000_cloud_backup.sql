-- T20d-a: the cloud side of the cloud backup, the paid add-on (D-072, D-075, D-076; DATA-02, DATA-06, DATA-07,
-- DATA-08, PLAN-03, PLAN-05, PLAN-06, BILL-02, AUTH-07). Every company's encrypted copy is kept here; bringing one
-- back needs the add-on, and the cloud decides that, not the app. The app has no access to the stored files at all:
-- the `backup` function hands out a one-time upload link or a 60-second download link after these functions say yes.

-- The add-on is its own period beside the plan's, so it can be bought the day a phone is lost. A slip covers the
-- plan, the plan with the add-on, or the add-on alone. A daily copy is kept `backup_keep_days` (PLAN-05).
alter table public.plans add column backup_keep_days integer not null default 30 check (backup_keep_days between 1 and 365);
-- Shown to a customer who forgot the backup password. Typed into the live SQL editor, like the bank details.
alter table public.platform_settings add column support_contact text;
alter table public.payment_slips
  add column covers text not null default 'plan' check (covers in ('plan', 'plan_addon', 'addon'));
alter table public.subscriptions
  add column kind text not null default 'plan' check (kind in ('plan', 'addon')),
  add constraint addon_is_paid check (kind = 'plan' or source = 'slip'),
  drop constraint subscriptions_slip_id_key,
  add constraint one_period_per_slip_and_kind unique (slip_id, kind);

-- One row per copy. A copy counts once its file is seen in storage (`finished_at_utc`); a daily copy carries the day
-- it may go (`keep_until_utc`). The company's owner reads these, add-on or not, so the app can say a copy exists.
create table public.cloud_backups (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (tenant_id),
  device_id uuid not null,
  file_path text not null unique,
  size_bytes bigint check (size_bytes > 0),
  started_by uuid not null,
  started_at_utc timestamptz not null default now(),
  finished_at_utc timestamptz,
  keep_until_utc timestamptz,
  source_operation_id uuid not null unique,
  check ((finished_at_utc is null) = (size_bytes is null)),
  check (keep_until_utc is null or finished_at_utc is not null)
);
create index cloud_backups_by_tenant on public.cloud_backups (tenant_id, finished_at_utc desc);
revoke all on public.cloud_backups from anon, authenticated;
grant select on public.cloud_backups to authenticated;
alter table public.cloud_backups enable row level security;
create policy cloud_backups_for_owner on public.cloud_backups for select to authenticated
  using (private.member_role(tenant_id) = 'owner');

-- Files that left a company's list, each with the time it goes from storage. Stored files cannot be removed from
-- SQL, so the `backup` function removes what is due after each finished upload. A deleted account's newest copy waits
-- here 60 days, with only the company's id and the email to find it by (D-072).
create table private.backup_removals (
  file_path text primary key,
  tenant_id uuid not null,
  email text,
  remove_after_utc timestamptz not null,
  queued_at_utc timestamptz not null default now()
);
-- How many copies a company started today, so a changed app cannot fill the storage.
create table private.backup_starts (
  tenant_id uuid not null,
  day date not null,
  starts integer not null default 1,
  primary key (tenant_id, day)
);
revoke all on private.backup_removals, private.backup_starts from public, anon, authenticated;

-- Private, 50 MB, a zip. No policy on `storage.objects` names this bucket, so only the server reaches it.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('backups', 'backups', false, 52428800, array['application/zip']);

-- The cloud copy is the owner's, from the one phone that is on: the same checks a licence gets.
create function private.require_owner_phone(p_tenant_id uuid, p_device_id uuid) returns void
language plpgsql set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_device public.devices%rowtype;
begin
  if v_user is null or private.member_role(p_tenant_id) is distinct from 'owner' then
    raise exception 'only the company''s owner keeps the cloud copy' using errcode = '42501';
  end if;
  select * into v_device from public.devices d
    where d.tenant_id = p_tenant_id and d.user_id = v_user and d.device_id = p_device_id;
  if not found then
    raise exception 'this phone is not registered' using errcode = '42501';
  end if;
  if v_device.revoked_at_utc is not null then
    raise exception 'this device was revoked' using errcode = '42501';
  end if;
  if v_device.id <> (select d.id from public.devices d
      where d.tenant_id = p_tenant_id and d.user_id = v_user and d.revoked_at_utc is null
      order by d.created_at_utc, d.id limit 1) then
    raise exception 'another phone is on' using errcode = '42501';
  end if;
end $$;
revoke all on function private.require_owner_phone(uuid, uuid) from public;

-- The phone asks to send a copy and gets its path, in the company's own folder. Refused when the cloud's latest copy
-- came from another phone, unless the owner chose to replace it, so a new phone's empty data never replaces the old
-- phone's copy unasked. An upload left unfinished gives way; its file goes once its upload link has run out. A retry
-- with the same operation id returns the same path, and says whether the file is already there (MODEL-06).
create function public.backup_start(p_tenant_id uuid, p_device_id uuid, p_size_bytes bigint, p_operation_id uuid, p_replace boolean default false)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.cloud_backups%rowtype;
  v_last uuid;
  v_day date := (now() at time zone 'Asia/Dubai')::date;
  v_starts integer;
  v_id uuid := gen_random_uuid();
begin
  perform private.require_owner_phone(p_tenant_id, p_device_id);
  select * into v_row from public.cloud_backups b where b.source_operation_id = p_operation_id;
  if found then
    if v_row.tenant_id <> p_tenant_id then
      raise exception 'operation id already used' using errcode = '23505';
    end if;
    return jsonb_build_object('path', v_row.file_path, 'arrived',
      exists (select 1 from storage.objects o where o.bucket_id = 'backups' and o.name = v_row.file_path));
  end if;
  if p_size_bytes is null or p_size_bytes < 1 then
    raise exception 'the copy''s size is needed' using errcode = '22023';
  end if;
  if p_size_bytes > (select k.file_size_limit from storage.buckets k where k.id = 'backups') then
    raise exception 'the copy is too large' using errcode = '22023';
  end if;
  perform 1 from public.tenants t where t.tenant_id = p_tenant_id for update;
  select b.device_id into v_last from public.cloud_backups b
    where b.tenant_id = p_tenant_id and b.finished_at_utc is not null
    order by b.finished_at_utc desc, b.id limit 1;
  if v_last <> p_device_id and not coalesce(p_replace, false) then
    raise exception 'the cloud copy is from another phone';
  end if;
  delete from private.backup_starts c where c.tenant_id = p_tenant_id and c.day < v_day;
  insert into private.backup_starts as c (tenant_id, day) values (p_tenant_id, v_day)
    on conflict (tenant_id, day) do update set starts = c.starts + 1
    returning c.starts into v_starts;
  if v_starts > 20 then
    raise exception 'too many copies today' using errcode = '22023';
  end if;
  -- An upload link lasts two hours, so the abandoned file is removed after three: nothing can land there later.
  with gone as (
    delete from public.cloud_backups b where b.tenant_id = p_tenant_id and b.finished_at_utc is null returning b.file_path
  )
  insert into private.backup_removals (file_path, tenant_id, remove_after_utc)
    select g.file_path, p_tenant_id, now() + interval '3 hours' from gone g;
  insert into public.cloud_backups (id, tenant_id, device_id, file_path, started_by, source_operation_id)
    values (v_id, p_tenant_id, p_device_id, p_tenant_id::text || '/' || v_id::text || '.zip', auth.uid(), p_operation_id)
    returning * into v_row;
  return jsonb_build_object('path', v_row.file_path, 'arrived', false);
end $$;

-- The upload is done: the copy counts once its file is in storage, with the size read there, not from the phone.
-- With an add-on period active it is a daily copy, kept the plan's days; an earlier daily copy of the same Dubai day
-- gives way, so a changed app keeps one a day at most. Then every other copy that is not a daily copy inside its
-- days leaves the list, only now that the newer one is safe. A second call changes nothing.
create function public.backup_finish(p_tenant_id uuid, p_operation_id uuid) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
  -- The clock, not the transaction's start, so two copies finished in one transaction keep their order.
  v_now timestamptz := clock_timestamp();
  v_row public.cloud_backups%rowtype;
  v_size bigint;
  v_days integer;
begin
  if auth.uid() is null or private.member_role(p_tenant_id) is distinct from 'owner' then
    raise exception 'only the company''s owner keeps the cloud copy' using errcode = '42501';
  end if;
  perform 1 from public.tenants t where t.tenant_id = p_tenant_id for update;
  select * into v_row from public.cloud_backups b where b.source_operation_id = p_operation_id and b.tenant_id = p_tenant_id;
  if not found then
    raise exception 'no such copy' using errcode = '22023';
  end if;
  if v_row.finished_at_utc is not null then
    return v_row.finished_at_utc;
  end if;
  select (o.metadata ->> 'size')::bigint into v_size from storage.objects o
    where o.bucket_id = 'backups' and o.name = v_row.file_path;
  if coalesce(v_size, 0) < 1 then
    raise exception 'the file has not arrived';
  end if;
  select p.backup_keep_days into v_days from public.subscriptions s
    join public.plans p on p.code = s.plan_code and p.version = s.plan_version
    where s.tenant_id = p_tenant_id and s.kind = 'addon' and s.revoked_at_utc is null
      and s.starts_at_utc <= v_now and s.ends_at_utc > v_now
    order by s.ends_at_utc desc limit 1;
  if v_days is not null then
    update public.cloud_backups b set keep_until_utc = null
      where b.tenant_id = p_tenant_id and b.keep_until_utc is not null
        and (b.finished_at_utc at time zone 'Asia/Dubai')::date = (v_now at time zone 'Asia/Dubai')::date;
  end if;
  update public.cloud_backups b
    set finished_at_utc = v_now, size_bytes = v_size,
      keep_until_utc = case when v_days is not null then v_now + make_interval(days => v_days) end
    where b.id = v_row.id;
  with gone as (
    delete from public.cloud_backups b
    where b.tenant_id = p_tenant_id and b.finished_at_utc is not null and b.id <> v_row.id
      and (b.keep_until_utc is null or b.keep_until_utc <= v_now)
    returning b.file_path
  )
  insert into private.backup_removals (file_path, tenant_id, remove_after_utc)
    select g.file_path, p_tenant_id, now() from gone g;
  return v_now;
end $$;

-- The path of a copy to bring back: only for the owner, on the phone that is on, while an add-on period is active.
-- The trial does not include it (D-075).
create function public.backup_download(p_tenant_id uuid, p_device_id uuid, p_backup_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_path text;
begin
  perform private.require_owner_phone(p_tenant_id, p_device_id);
  select b.file_path into v_path from public.cloud_backups b
    where b.id = p_backup_id and b.tenant_id = p_tenant_id and b.finished_at_utc is not null;
  if not found then
    raise exception 'no such copy' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.subscriptions s
    where s.tenant_id = p_tenant_id and s.kind = 'addon' and s.revoked_at_utc is null
      and s.starts_at_utc <= now() and s.ends_at_utc > now()
  ) then
    raise exception 'the add-on is needed' using errcode = '42501';
  end if;
  return v_path;
end $$;
revoke all on function public.backup_start(uuid, uuid, bigint, uuid, boolean), public.backup_finish(uuid, uuid),
  public.backup_download(uuid, uuid, uuid) from public, anon;
grant execute on function public.backup_start(uuid, uuid, bigint, uuid, boolean), public.backup_finish(uuid, uuid),
  public.backup_download(uuid, uuid, uuid) to authenticated;

-- For the `backup` function alone: the files due to go, and the note that they went. A file not yet due stays
-- listed even if it is named, so a kept copy cannot be dropped early.
create function public.backup_removals_due() returns text[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(r.file_path), '{}') from (
    select q.file_path from private.backup_removals q where q.remove_after_utc <= now() order by q.remove_after_utc limit 100
  ) r
$$;
create function public.backup_removals_done(p_paths text[]) returns void
language sql security definer set search_path = '' as $$
  delete from private.backup_removals q where q.file_path = any (p_paths) and q.remove_after_utc <= now()
$$;
revoke all on function public.backup_removals_due(), public.backup_removals_done(text[]) from public, anon, authenticated;
grant execute on function public.backup_removals_due(), public.backup_removals_done(text[]) to service_role;

-- As before (T21a), with what the slip covers. The add-on alone goes with the plan the company is on, at the version
-- it paid for; a company with no paid plan names one on sale. Its older five-argument form is replaced, and a call
-- without `p_covers` means the plan, as before.
drop function public.submit_slip(uuid, text, integer, text, uuid);
create function public.submit_slip(p_tenant_id uuid, p_plan_code text, p_months integer, p_file_type text, p_operation_id uuid, p_covers text default 'plan')
returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_plan public.plans%rowtype;
  v_own public.plans%rowtype;
  v_slip public.payment_slips%rowtype;
  v_id uuid := gen_random_uuid();
begin
  if v_user is null or private.member_role(p_tenant_id) is distinct from 'owner' then
    raise exception 'only the company''s owner sends a slip' using errcode = '42501';
  end if;
  select * into v_slip from public.payment_slips s where s.source_operation_id = p_operation_id;
  if found then
    if v_slip.tenant_id <> p_tenant_id then
      raise exception 'operation id already used' using errcode = '23505';
    end if;
    return v_slip.file_path;
  end if;
  if p_file_type is null or p_file_type not in ('jpg', 'png', 'pdf') then
    raise exception 'a slip is a jpg, png or pdf' using errcode = '22023';
  end if;
  if p_months is null or p_months not between 1 and 12 then
    raise exception 'from 1 to 12 months' using errcode = '22023';
  end if;
  if p_covers is null or p_covers not in ('plan', 'plan_addon', 'addon') then
    raise exception 'a slip covers the plan, the plan with the add-on, or the add-on' using errcode = '22023';
  end if;
  select * into v_plan from public.plans p where p.code = p_plan_code and p.on_sale;
  if p_covers = 'addon' then
    select p.* into v_own from public.subscriptions s
      join public.plans p on p.code = s.plan_code and p.version = s.plan_version
      where s.tenant_id = p_tenant_id and s.kind = 'plan' and s.source = 'slip' and s.revoked_at_utc is null
        and s.starts_at_utc <= now() and s.ends_at_utc > now()
      order by s.ends_at_utc desc limit 1;
    if v_own.code is not null then
      if v_own.code is distinct from p_plan_code then
        raise exception 'the add-on alone goes with the company''s own plan' using errcode = '22023';
      end if;
      v_plan := v_own;
    end if;
  end if;
  if v_plan.code is null then
    raise exception 'no such plan on sale' using errcode = '22023';
  end if;
  perform 1 from public.tenants t where t.tenant_id = p_tenant_id for update;
  if (select count(*) from public.payment_slips s where s.tenant_id = p_tenant_id and s.state = 'waiting') >= 3 then
    raise exception 'three slips are waiting already' using errcode = '22023';
  end if;
  insert into public.payment_slips (id, tenant_id, plan_code, plan_version, months, covers, expected_fils, file_path, submitted_by, source_operation_id)
    values (v_id, p_tenant_id, v_plan.code, v_plan.version, p_months, p_covers,
      p_months * case p_covers when 'plan' then v_plan.price_fils when 'addon' then v_plan.addon_price_fils
        else v_plan.price_fils + v_plan.addon_price_fils end,
      p_tenant_id::text || '/' || v_id::text || '.' || p_file_type, v_user, p_operation_id)
    returning * into v_slip;
  return v_slip.file_path;
end $$;
revoke all on function public.submit_slip(uuid, text, integer, text, uuid, text) from public, anon;
grant execute on function public.submit_slip(uuid, text, integer, text, uuid, text) to authenticated;

-- As before (T21a), making a period for each thing the slip covers. Each continues its own kind's unended period
-- from its end, keeping its anchor, else starts now (BILL-04). The money received is split so the two entries add up
-- to it: the add-on's entry takes its listed price, the plan's the rest. Returns the plan's period, or the add-on's
-- when the slip covers that alone.
create or replace function private.accept_slip(p_slip_id uuid, p_amount_fils bigint, p_bank_reference text, p_received_on date, p_note text default null)
returns uuid
language plpgsql set search_path = '' as $$
declare
  v_slip public.payment_slips%rowtype;
  v_prev public.subscriptions%rowtype;
  v_kinds text[];
  v_kind text;
  v_addon_fils bigint;
  v_anchor timestamptz;
  v_start timestamptz;
  v_months integer;
  v_id uuid;
  v_first uuid;
begin
  select * into v_slip from public.payment_slips s where s.id = p_slip_id for update;
  if not found then
    raise exception 'no such slip';
  end if;
  if v_slip.state <> 'waiting' then
    raise exception 'this slip was decided already';
  end if;
  if p_amount_fils is null or p_amount_fils <= 0 or nullif(btrim(p_bank_reference), '') is null or p_received_on is null then
    raise exception 'the amount received, the bank reference and the date received are needed';
  end if;
  v_kinds := case v_slip.covers when 'plan' then array['plan'] when 'addon' then array['addon'] else array['plan', 'addon'] end;
  v_addon_fils := case v_slip.covers
    when 'plan' then 0
    when 'addon' then p_amount_fils
    else least(p_amount_fils, v_slip.months * (select p.addon_price_fils from public.plans p
      where p.code = v_slip.plan_code and p.version = v_slip.plan_version))
  end;
  foreach v_kind in array v_kinds loop
    v_anchor := now();
    v_start := now();
    v_months := v_slip.months;
    select * into v_prev from public.subscriptions s
      where s.tenant_id = v_slip.tenant_id and s.kind = v_kind and s.source = 'slip' and s.revoked_at_utc is null and s.ends_at_utc > now()
      order by s.ends_at_utc desc limit 1;
    if found then
      v_anchor := v_prev.anchor_at_utc;
      v_months := v_prev.anchor_months + v_slip.months;
      v_start := v_prev.ends_at_utc;
    end if;
    insert into public.subscriptions (tenant_id, kind, plan_code, plan_version, source, slip_id, starts_at_utc, ends_at_utc,
        anchor_at_utc, anchor_months, amount_fils, bank_reference, received_on, note)
      values (v_slip.tenant_id, v_kind, v_slip.plan_code, v_slip.plan_version, 'slip', v_slip.id, v_start,
        private.months_after(v_anchor, v_months), v_anchor, v_months,
        case v_kind when 'addon' then v_addon_fils else p_amount_fils - v_addon_fils end,
        btrim(p_bank_reference), p_received_on, p_note)
      returning id into v_id;
    v_first := coalesce(v_first, v_id);
  end loop;
  update public.payment_slips set state = 'accepted', decided_at_utc = now() where id = v_slip.id;
  return v_first;
end $$;

-- As before (T21a), reading only the plan's periods, and carrying the add-on's end: that of the unbroken run of
-- add-on periods covering today, or null. Replacing it keeps its grants.
create or replace function public.licence_facts(p_tenant_id uuid, p_device_id uuid, p_active_workers integer, p_active_clients integer)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_role text := private.member_role(p_tenant_id);
  v_now timestamptz := now();
  v_device public.devices%rowtype;
  v_first uuid;
  v_email text;
  v_sub public.subscriptions%rowtype;
  v_plan public.plans%rowtype;
  v_end timestamptz;
  v_addon timestamptz;
  v_state text := 'trial';
  v_members integer;
begin
  if v_user is null or v_role is null then
    raise exception 'not a member of this company' using errcode = '42501';
  end if;
  if p_active_workers is null or p_active_clients is null
    or p_active_workers not between 0 and 1000000 or p_active_clients not between 0 and 1000000 then
    raise exception 'counts out of range' using errcode = '22023';
  end if;
  select * into v_device from public.devices d
    where d.tenant_id = p_tenant_id and d.user_id = v_user and d.device_id = p_device_id;
  if not found then
    raise exception 'this phone is not registered' using errcode = '42501';
  end if;
  if v_device.revoked_at_utc is not null then
    raise exception 'this device was revoked' using errcode = '42501';
  end if;
  select d.id into v_first from public.devices d
    where d.tenant_id = p_tenant_id and d.user_id = v_user and d.revoked_at_utc is null
    order by d.created_at_utc, d.id limit 1;
  if v_first <> v_device.id then
    raise exception 'another phone is on' using errcode = '42501';
  end if;

  insert into private.usage_reports (tenant_id, device_id, active_workers, active_clients, reported_at_utc)
    values (p_tenant_id, p_device_id, p_active_workers, p_active_clients, v_now)
    on conflict (tenant_id) do update set device_id = excluded.device_id, active_workers = excluded.active_workers,
      active_clients = excluded.active_clients, reported_at_utc = excluded.reported_at_utc;

  if v_role = 'owner' and not exists (select 1 from public.subscriptions s where s.tenant_id = p_tenant_id and s.kind = 'plan') then
    select u.email into v_email from auth.users u where u.id = v_user;
    if not exists (select 1 from private.trial_claims c where c.hash in (private.email_hash(v_email), private.phone_hash(p_device_id))) then
      insert into public.subscriptions (tenant_id, plan_code, plan_version, source, starts_at_utc, ends_at_utc, anchor_at_utc)
        select p_tenant_id, 'trial', (select max(p.version) from public.plans p where p.code = 'trial'), 'trial',
          v_now, v_now + make_interval(days => s.trial_days), v_now
        from public.platform_settings s
        on conflict (tenant_id) where source = 'trial' do nothing;
      insert into private.trial_claims (hash, kind, tenant_id)
        select v.hash, v.kind, p_tenant_id
        from (values (private.email_hash(v_email), 'email'), (private.phone_hash(p_device_id), 'phone')) v (hash, kind)
        where v.hash is not null
        on conflict (hash) do nothing;
    end if;
  end if;

  with recursive run (ends_at_utc) as (
    select max(s.ends_at_utc) from public.subscriptions s
      where s.tenant_id = p_tenant_id and s.kind = 'addon' and s.revoked_at_utc is null
        and s.starts_at_utc <= v_now and s.ends_at_utc > v_now
    union
    select s.ends_at_utc from public.subscriptions s join run r on s.starts_at_utc = r.ends_at_utc
    where s.tenant_id = p_tenant_id and s.kind = 'addon' and s.revoked_at_utc is null
  )
  select max(r.ends_at_utc) into v_addon from run r;

  select count(*) into v_members from public.memberships m where m.tenant_id = p_tenant_id and m.revoked_at_utc is null;
  -- A paid period before the trial when both cover today.
  select * into v_sub from public.subscriptions s
    where s.tenant_id = p_tenant_id and s.kind = 'plan' and s.revoked_at_utc is null and s.starts_at_utc <= v_now and s.ends_at_utc > v_now
    order by (s.source = 'slip') desc, s.ends_at_utc desc
    limit 1;
  if v_sub.id is null then
    return jsonb_build_object('v', 1, 'iss', 'labour-app', 'jti', gen_random_uuid(), 'iat', v_now,
      'tenant_id', p_tenant_id, 'device_id', p_device_id, 'state', 'none',
      'plan', null, 'plan_version', null, 'plan_name', null, 'starts_at', null,
      'ends_at', (select max(s.ends_at_utc) from public.subscriptions s
        where s.tenant_id = p_tenant_id and s.kind = 'plan' and s.revoked_at_utc is null),
      'lease_until', v_now + interval '7 days', 'addon_until', v_addon,
      'limits', jsonb_build_object('workers', 0, 'clients', 0, 'managers', 0, 'devices', v_members));
  end if;
  v_end := v_sub.ends_at_utc;
  -- A paid customer offline across a renewal keeps the plan: the end is that of the unbroken run of paid periods.
  if v_sub.source = 'slip' then
    v_state := 'paid';
    with recursive run (ends_at_utc) as (
      select v_sub.ends_at_utc
      union
      select s.ends_at_utc from public.subscriptions s join run r on s.starts_at_utc = r.ends_at_utc
      where s.tenant_id = p_tenant_id and s.kind = 'plan' and s.source = 'slip' and s.revoked_at_utc is null
    )
    select max(r.ends_at_utc) into v_end from run r;
  end if;
  select * into v_plan from public.plans p where p.code = v_sub.plan_code and p.version = v_sub.plan_version;
  return jsonb_build_object('v', 1, 'iss', 'labour-app', 'jti', gen_random_uuid(), 'iat', v_now,
    'tenant_id', p_tenant_id, 'device_id', p_device_id, 'state', v_state,
    'plan', v_plan.code, 'plan_version', v_plan.version, 'plan_name', v_plan.name,
    'starts_at', v_sub.starts_at_utc, 'ends_at', v_end, 'lease_until', least(v_now + interval '7 days', v_end),
    'addon_until', v_addon,
    'limits', jsonb_build_object('workers', v_plan.max_workers, 'clients', v_plan.max_clients,
      'managers', v_plan.max_managers, 'devices', v_members));
end $$;

-- As before (T21a), and the owned companies' cloud copies leave their list. The newest waits 60 days with the
-- company's id and the account's email, then goes; the rest go at once, an unfinished upload once its link has run
-- out (D-072). Replacing it keeps its grants.
create or replace function public.delete_account() returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_owned uuid[];
begin
  if v_user is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  -- The password typed again in the last ten minutes, so a phone left signed in cannot delete the account.
  if not exists (
    select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
    where a ->> 'method' = 'password' and (a ->> 'timestamp')::bigint > extract(epoch from now())::bigint - 600
  ) then
    raise exception 'type the password again' using errcode = '42501';
  end if;
  select coalesce(array_agg(o.tenant_id), '{}') into v_owned from (
    select t.tenant_id from public.tenants t where t.created_by = v_user
    union
    select m.tenant_id from public.memberships m where m.user_id = v_user and m.role = 'owner' and m.revoked_at_utc is null
  ) o;
  -- ponytail: a company someone else still works in is refused; handing it over comes with managers (T24).
  if exists (select 1 from public.memberships m where m.tenant_id = any (v_owned) and m.user_id <> v_user and m.revoked_at_utc is null) then
    raise exception 'the company has other members' using errcode = '42501';
  end if;
  insert into private.backup_removals (file_path, tenant_id, email, remove_after_utc)
    select b.file_path, b.tenant_id,
      case when b.newest then (select u.email from auth.users u where u.id = v_user) end,
      case when b.newest then now() + interval '60 days'
        when b.finished_at_utc is null then now() + interval '3 hours'
        else now() end
    from (
      select c.*, c.finished_at_utc is not null
        and row_number() over (partition by c.tenant_id order by c.finished_at_utc desc nulls last, c.id) = 1 as newest
      from public.cloud_backups c where c.tenant_id = any (v_owned)
    ) b;
  delete from public.cloud_backups b where b.tenant_id = any (v_owned);
  delete from private.backup_starts c where c.tenant_id = any (v_owned);
  delete from private.usage_reports r where r.tenant_id = any (v_owned);
  delete from public.subscriptions s where s.tenant_id = any (v_owned);
  delete from public.payment_slips p where p.tenant_id = any (v_owned);
  delete from public.devices d where d.tenant_id = any (v_owned) or d.user_id = v_user;
  delete from public.memberships m where m.tenant_id = any (v_owned) or m.user_id = v_user;
  delete from public.tenants t where t.tenant_id = any (v_owned);
  delete from auth.users u where u.id = v_user;
end $$;
