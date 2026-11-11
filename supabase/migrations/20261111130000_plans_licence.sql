-- T21a: plans, the trial, payment slips, and the facts a signed licence carries (D-074; BILL-02, BILL-03, BILL-05,
-- BILL-06, PLAN-03, PLAN-04, PLAN-06). Prices, limits and the bank details live here, never in the app or in git. A
-- customer writes only through server functions that take the user from the session (MODEL-05, AUTH-02); the platform's
-- owner accepts or refuses a slip from the SQL editor until T22.

create extension if not exists pgcrypto with schema extensions;

-- Plans, one row per version. A price change is a new version; a company keeps the version it paid for until it
-- renews. Money in integer fils (CALC-01); a null limit is unlimited. Platform config, so no tenant id: it holds no
-- company's data.
create table public.plans (
  code text not null check (code ~ '^[a-z_]{1,30}$'),
  version integer not null check (version >= 1),
  name text not null check (char_length(btrim(name)) between 1 and 100),
  price_fils bigint not null check (price_fils >= 0),
  addon_price_fils bigint not null check (addon_price_fils >= 0),
  max_workers integer check (max_workers >= 0),
  max_clients integer check (max_clients >= 0),
  max_managers integer check (max_managers >= 0),
  on_sale boolean not null default true,
  sort_order integer not null default 0,
  created_at_utc timestamptz not null default now(),
  primary key (code, version)
);
create unique index one_plan_version_on_sale on public.plans (code) where on_sale;
insert into public.plans (code, version, name, price_fils, addon_price_fils, max_workers, max_clients, max_managers, on_sale, sort_order) values
  ('trial', 1, 'Trial period', 0, 0, null, null, null, false, 0),
  ('small', 1, 'Small Company Plan', 19900, 2000, 15, 5, 1, true, 1),
  ('mid', 1, 'Mid Size Company Plan', 29900, 2000, 35, 9, 2, true, 2),
  ('large', 1, 'Large Size Company Plan', 49900, 4000, null, null, null, true, 3);

-- The bank details customers pay into, and the trial's length. One row. The bank fields stay empty in git and are
-- typed into the live project's SQL editor (AI-05).
create table public.platform_settings (
  id boolean primary key default true check (id),
  bank_name text,
  account_number text,
  iban text,
  account_holder text,
  trial_days integer not null default 15 check (trial_days between 1 and 90),
  updated_at_utc timestamptz not null default now()
);
insert into public.platform_settings (id) values (true);

-- A slip a company's owner sends after a bank transfer: the plan and months chosen, at that plan version's price.
create table public.payment_slips (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (tenant_id),
  plan_code text not null,
  plan_version integer not null,
  months integer not null check (months between 1 and 12),
  expected_fils bigint not null check (expected_fils >= 0),
  file_path text not null unique,
  state text not null default 'waiting' check (state in ('waiting', 'accepted', 'refused')),
  refuse_reason text,
  submitted_by uuid not null,
  submitted_at_utc timestamptz not null default now(),
  decided_at_utc timestamptz,
  source_operation_id uuid not null unique,
  foreign key (plan_code, plan_version) references public.plans (code, version),
  check ((state = 'refused') = (refuse_reason is not null)),
  check ((state = 'waiting') = (decided_at_utc is null))
);

-- A company's plan periods: its one trial, and one row per accepted slip, each its own entry (BILL-04). A month runs
-- from the anchor, the first paid day, to the same day [anchor_months] months on, clamped to the month's last day.
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (tenant_id),
  plan_code text not null,
  plan_version integer not null,
  source text not null check (source in ('trial', 'slip')),
  slip_id uuid unique references public.payment_slips (id),
  starts_at_utc timestamptz not null,
  ends_at_utc timestamptz not null,
  anchor_at_utc timestamptz not null,
  anchor_months integer not null default 0 check (anchor_months >= 0),
  amount_fils bigint not null default 0 check (amount_fils >= 0),
  bank_reference text,
  received_on date,
  note text,
  revoked_at_utc timestamptz,
  revoke_reason text,
  created_at_utc timestamptz not null default now(),
  foreign key (plan_code, plan_version) references public.plans (code, version),
  check (ends_at_utc > starts_at_utc),
  check ((revoked_at_utc is null) = (revoke_reason is null)),
  check (source = 'trial' or (slip_id is not null and bank_reference is not null and received_on is not null))
);
create unique index one_trial_per_tenant on public.subscriptions (tenant_id) where source = 'trial';

-- Who had a trial: a hash of the owner's email and of the phone's id, kept after an account is deleted so a new
-- signup on the same phone or email gets no second trial (D-074, disclosed in the privacy policy at T26).
create table private.trial_claims (
  hash text primary key,
  kind text not null check (kind in ('email', 'phone')),
  tenant_id uuid not null,
  claimed_at_utc timestamptz not null default now()
);

-- The counts of active workers and client companies each licence request reports, the latest per company, so the
-- platform's owner sees a company over its plan (T22). Workers stay on the phone until sync (T25).
create table private.usage_reports (
  tenant_id uuid primary key references public.tenants (tenant_id),
  device_id uuid not null,
  active_workers integer not null check (active_workers between 0 and 1000000),
  active_clients integer not null check (active_clients between 0 and 1000000),
  reported_at_utc timestamptz not null default now()
);
revoke all on private.trial_claims, private.usage_reports from public, anon, authenticated;

revoke all on public.plans, public.platform_settings, public.payment_slips, public.subscriptions from anon, authenticated;
grant select on public.plans, public.platform_settings, public.payment_slips, public.subscriptions to authenticated;
alter table public.plans enable row level security;
alter table public.platform_settings enable row level security;
alter table public.payment_slips enable row level security;
alter table public.subscriptions enable row level security;
create policy plans_for_signed_in on public.plans for select to authenticated using (true);
create policy platform_settings_for_signed_in on public.platform_settings for select to authenticated using (true);
create policy payment_slips_for_owner on public.payment_slips for select to authenticated
  using (private.member_role(tenant_id) = 'owner');
create policy subscriptions_for_members on public.subscriptions for select to authenticated
  using (private.member_role(tenant_id) is not null);

-- The anchor plus some months on Dubai's wall clock, clamped to the month's last day: Jan 31 + 1 is Feb 28, + 2 is
-- Mar 31 (BILL-04, D-105). Counting from the anchor each time keeps the 31st across renewals.
create function private.months_after(p_anchor timestamptz, p_months integer) returns timestamptz
language sql stable set search_path = '' as $$
  select ((p_anchor at time zone 'Asia/Dubai') + make_interval(months => p_months)) at time zone 'Asia/Dubai'
$$;
revoke all on function private.months_after(timestamptz, integer) from public;

-- One person's email, the same however it is written: lower case, no +tag, and for Gmail no dots.
create function private.email_hash(p_email text) returns text
language sql immutable set search_path = '' as $$
  select encode(extensions.digest('trial-email:' || case
      when split_part(e, '@', 2) in ('gmail.com', 'googlemail.com')
        then replace(split_part(split_part(e, '@', 1), '+', 1), '.', '') || '@gmail.com'
      else split_part(split_part(e, '@', 1), '+', 1) || '@' || split_part(e, '@', 2)
    end, 'sha256'), 'hex')
  from (select lower(btrim(p_email)) as e) x
  where p_email is not null
$$;
create function private.phone_hash(p_device_id uuid) returns text
language sql immutable set search_path = '' as $$
  select encode(extensions.digest('trial-phone:' || p_device_id::text, 'sha256'), 'hex')
$$;
revoke all on function private.email_hash(text), private.phone_hash(uuid) from public;

-- Companies made before this migration get their 15 days from today, so nobody testing is locked out at once, and
-- their owners' emails and phones count as having had the trial.
insert into public.subscriptions (tenant_id, plan_code, plan_version, source, starts_at_utc, ends_at_utc, anchor_at_utc)
  select t.tenant_id, 'trial', 1, 'trial', now(), now() + interval '15 days', now() from public.tenants t;
insert into private.trial_claims (hash, kind, tenant_id)
  select private.email_hash(u.email), 'email', t.tenant_id from public.tenants t join auth.users u on u.id = t.created_by
  where u.email is not null
  union all
  select private.phone_hash(d.device_id), 'phone', d.tenant_id from public.devices d
  on conflict (hash) do nothing;

-- What a licence for this phone says, for the licence function to sign (BILL-03). Called as the user, so membership
-- comes from the session. One phone per person: the caller's first phone still on. The owner's first request starts
-- the trial, once per company, email and phone. Each request leaves the phone's counts (T22).
create function public.licence_facts(p_tenant_id uuid, p_device_id uuid, p_active_workers integer, p_active_clients integer)
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

  if v_role = 'owner' and not exists (select 1 from public.subscriptions s where s.tenant_id = p_tenant_id) then
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

  select count(*) into v_members from public.memberships m where m.tenant_id = p_tenant_id and m.revoked_at_utc is null;
  -- A paid period before the trial when both cover today.
  select * into v_sub from public.subscriptions s
    where s.tenant_id = p_tenant_id and s.revoked_at_utc is null and s.starts_at_utc <= v_now and s.ends_at_utc > v_now
    order by (s.source = 'slip') desc, s.ends_at_utc desc
    limit 1;
  if v_sub.id is null then
    return jsonb_build_object('v', 1, 'iss', 'labour-app', 'jti', gen_random_uuid(), 'iat', v_now,
      'tenant_id', p_tenant_id, 'device_id', p_device_id, 'state', 'none',
      'plan', null, 'plan_version', null, 'plan_name', null, 'starts_at', null,
      'ends_at', (select max(s.ends_at_utc) from public.subscriptions s where s.tenant_id = p_tenant_id and s.revoked_at_utc is null),
      'lease_until', v_now + interval '7 days',
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
      where s.tenant_id = p_tenant_id and s.source = 'slip' and s.revoked_at_utc is null
    )
    select max(r.ends_at_utc) into v_end from run r;
  end if;
  select * into v_plan from public.plans p where p.code = v_sub.plan_code and p.version = v_sub.plan_version;
  return jsonb_build_object('v', 1, 'iss', 'labour-app', 'jti', gen_random_uuid(), 'iat', v_now,
    'tenant_id', p_tenant_id, 'device_id', p_device_id, 'state', v_state,
    'plan', v_plan.code, 'plan_version', v_plan.version, 'plan_name', v_plan.name,
    'starts_at', v_sub.starts_at_utc, 'ends_at', v_end, 'lease_until', least(v_now + interval '7 days', v_end),
    'limits', jsonb_build_object('workers', v_plan.max_workers, 'clients', v_plan.max_clients,
      'managers', v_plan.max_managers, 'devices', v_members));
end $$;
revoke all on function public.licence_facts(uuid, uuid, integer, integer) from public, anon;
grant execute on function public.licence_facts(uuid, uuid, integer, integer) to authenticated;

-- The Ed25519 key that signs licences, made by the licence function on its first run and kept in Vault. Nobody types
-- or sees it; only the server's own role may read it. Keeping stores only the first key, so two first runs agree.
create function public.licence_signing_key() returns jsonb
language sql stable security definer set search_path = '' as $$
  select s.decrypted_secret::jsonb from vault.decrypted_secrets s where s.name = 'licence_signing_key'
$$;
create function public.licence_signing_key_keep(p_key jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if p_key is null or jsonb_typeof(p_key -> 'private_pkcs8') is distinct from 'string'
    or jsonb_typeof(p_key -> 'public_raw') is distinct from 'string' then
    raise exception 'not a key' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtext('licence_signing_key'));
  if not exists (select 1 from vault.secrets s where s.name = 'licence_signing_key') then
    perform vault.create_secret(p_key::text, 'licence_signing_key', 'Signs app licences (T21). Made by the licence function.');
  end if;
  return public.licence_signing_key();
end $$;
revoke all on function public.licence_signing_key(), public.licence_signing_key_keep(jsonb) from public, anon, authenticated;
grant execute on function public.licence_signing_key(), public.licence_signing_key_keep(jsonb) to service_role;

-- The company's owner sends a slip for a plan on sale and some months; returns the path to upload the file to, in the
-- company's own folder. At most 3 wait at once. A retry with the same operation id returns the same path (MODEL-06).
create function public.submit_slip(p_tenant_id uuid, p_plan_code text, p_months integer, p_file_type text, p_operation_id uuid)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_plan public.plans%rowtype;
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
  select * into v_plan from public.plans p where p.code = p_plan_code and p.on_sale;
  if not found then
    raise exception 'no such plan on sale' using errcode = '22023';
  end if;
  perform 1 from public.tenants t where t.tenant_id = p_tenant_id for update;
  if (select count(*) from public.payment_slips s where s.tenant_id = p_tenant_id and s.state = 'waiting') >= 3 then
    raise exception 'three slips are waiting already' using errcode = '22023';
  end if;
  insert into public.payment_slips (id, tenant_id, plan_code, plan_version, months, expected_fils, file_path, submitted_by, source_operation_id)
    values (v_id, p_tenant_id, v_plan.code, v_plan.version, p_months, v_plan.price_fils * p_months,
      p_tenant_id::text || '/' || v_id::text || '.' || p_file_type, v_user, p_operation_id)
    returning * into v_slip;
  return v_slip.file_path;
end $$;
revoke all on function public.submit_slip(uuid, text, integer, text, uuid) from public, anon;
grant execute on function public.submit_slip(uuid, text, integer, text, uuid) to authenticated;

-- The slips' files: private, 5 MB, a photo or a PDF. A file goes only to a waiting slip's own path, by its company's
-- owner, who may read and remove their slips' files; the app removes them before deleting the account (T21b).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('payment-slips', 'payment-slips', false, 5242880, array['image/jpeg', 'image/png', 'application/pdf']);
create function private.slip_file_of_owner(p_name text, p_waiting_only boolean) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.payment_slips s
    where s.file_path = p_name and (s.state = 'waiting' or not p_waiting_only) and private.member_role(s.tenant_id) = 'owner'
  )
$$;
revoke all on function private.slip_file_of_owner(text, boolean) from public;
grant execute on function private.slip_file_of_owner(text, boolean) to authenticated;
create policy payment_slips_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'payment-slips' and private.slip_file_of_owner(name, true));
create policy payment_slips_read on storage.objects for select to authenticated
  using (bucket_id = 'payment-slips' and private.slip_file_of_owner(name, false));
create policy payment_slips_remove on storage.objects for delete to authenticated
  using (bucket_id = 'payment-slips' and private.slip_file_of_owner(name, false));

-- The platform's owner, from the SQL editor, after finding the money in the bank (BILL-01): accepting makes the plan's
-- period. It continues an unended paid period from its end, keeping its anchor, else starts now (BILL-04). Only
-- `postgres` may run these.
create function private.accept_slip(p_slip_id uuid, p_amount_fils bigint, p_bank_reference text, p_received_on date, p_note text default null)
returns uuid
language plpgsql set search_path = '' as $$
declare
  v_slip public.payment_slips%rowtype;
  v_prev public.subscriptions%rowtype;
  v_anchor timestamptz := now();
  v_start timestamptz := now();
  v_months integer;
  v_id uuid;
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
  v_months := v_slip.months;
  select * into v_prev from public.subscriptions s
    where s.tenant_id = v_slip.tenant_id and s.source = 'slip' and s.revoked_at_utc is null and s.ends_at_utc > now()
    order by s.ends_at_utc desc limit 1;
  if found then
    v_anchor := v_prev.anchor_at_utc;
    v_months := v_prev.anchor_months + v_slip.months;
    v_start := v_prev.ends_at_utc;
  end if;
  insert into public.subscriptions (tenant_id, plan_code, plan_version, source, slip_id, starts_at_utc, ends_at_utc,
      anchor_at_utc, anchor_months, amount_fils, bank_reference, received_on, note)
    values (v_slip.tenant_id, v_slip.plan_code, v_slip.plan_version, 'slip', v_slip.id, v_start,
      private.months_after(v_anchor, v_months), v_anchor, v_months, p_amount_fils, btrim(p_bank_reference), p_received_on, p_note)
    returning id into v_id;
  update public.payment_slips set state = 'accepted', decided_at_utc = now() where id = v_slip.id;
  return v_id;
end $$;
create function private.refuse_slip(p_slip_id uuid, p_reason text) returns void
language plpgsql set search_path = '' as $$
begin
  if nullif(btrim(p_reason), '') is null then
    raise exception 'say why the slip is refused';
  end if;
  update public.payment_slips set state = 'refused', refuse_reason = btrim(p_reason), decided_at_utc = now()
    where id = p_slip_id and state = 'waiting';
  if not found then
    raise exception 'no waiting slip with this id';
  end if;
end $$;
create function private.revoke_subscription(p_subscription_id uuid, p_reason text) returns void
language plpgsql set search_path = '' as $$
begin
  if nullif(btrim(p_reason), '') is null then
    raise exception 'say why the period is revoked';
  end if;
  update public.subscriptions set revoked_at_utc = now(), revoke_reason = btrim(p_reason)
    where id = p_subscription_id and revoked_at_utc is null;
  if not found then
    raise exception 'no live period with this id';
  end if;
end $$;
revoke all on function private.accept_slip(uuid, bigint, text, date, text), private.refuse_slip(uuid, text),
  private.revoke_subscription(uuid, text) from public;

-- As before (T19c), and the owned companies' usage, plan periods and slips go too (D-066). The trial claims stay
-- (D-074). Replacing it keeps its grants.
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
  delete from private.usage_reports r where r.tenant_id = any (v_owned);
  delete from public.subscriptions s where s.tenant_id = any (v_owned);
  delete from public.payment_slips p where p.tenant_id = any (v_owned);
  delete from public.devices d where d.tenant_id = any (v_owned) or d.user_id = v_user;
  delete from public.memberships m where m.tenant_id = any (v_owned) or m.user_id = v_user;
  delete from public.tenants t where t.tenant_id = any (v_owned);
  delete from auth.users u where u.id = v_user;
end $$;
