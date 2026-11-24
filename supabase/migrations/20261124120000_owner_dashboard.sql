-- T22a: the owner's dashboard, the cloud side (D-081, ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-08, BILL-01, BILL-04,
-- MET-03). Only a platform admin who typed a TOTP code reaches the admin_ functions, which the dashboard calls with
-- the public key and the admin's session; the site holds no secret. Every change writes its audit row in the same
-- transaction, and the audit log is never changed. Holds, limit overrides and given periods reach the licence, which
-- also keeps the app's version and when the phone was last seen.

-- 1. Who may use the dashboard, and the record of what they did.

-- Added by the owner in the SQL editor (RUNBOOK), never by the dashboard. One role until someone else needs a login.
create table private.platform_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'owner' check (role = 'owner'),
  added_at_utc timestamptz not null default now()
);

create function private.is_platform_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
    and exists (select 1 from private.platform_admins a where a.user_id = auth.uid());
$$;
revoke all on function private.is_platform_admin() from public;
grant execute on function private.is_platform_admin() to authenticated;

create function private.require_admin() returns void
language plpgsql stable set search_path = '' as $$
begin
  if not private.is_platform_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
end $$;

-- Holds and money: the code typed again in the last five minutes, so a dashboard left open cannot do them.
create function private.require_recent_mfa() returns void
language plpgsql stable set search_path = '' as $$
begin
  if not exists (
    select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
    where a ->> 'method' = 'totp' and (a ->> 'timestamp')::bigint > extract(epoch from now())::bigint - 300
  ) then
    raise exception 'type the code again' using errcode = '42501';
  end if;
end $$;

-- The platform's own record of every money and account action. No foreign key: it outlives a deleted account.
create table private.admin_actions (
  id uuid primary key default gen_random_uuid(),
  at_utc timestamptz not null default now(),
  actor_id uuid not null,
  action text not null check (action ~ '^[a-z_]{1,40}$'),
  tenant_id uuid,
  target_id uuid,
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  before jsonb,
  after jsonb
);
create index admin_actions_by_time on private.admin_actions (at_utc desc);
create index admin_actions_by_tenant on private.admin_actions (tenant_id, at_utc desc);

create function private.refuse_change() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception '% is never changed or deleted', tg_table_name;
end $$;
create trigger admin_actions_append_only before update or delete or truncate on private.admin_actions
  for each statement execute function private.refuse_change();

create function private.log_action(p_action text, p_tenant uuid, p_target uuid, p_reason text, p_before jsonb, p_after jsonb)
returns void
language plpgsql set search_path = '' as $$
begin
  if char_length(btrim(coalesce(p_reason, ''))) < 3 then
    raise exception 'say why' using errcode = '22023';
  end if;
  insert into private.admin_actions (actor_id, action, tenant_id, target_id, reason, before, after)
    values (auth.uid(), p_action, p_tenant, p_target, left(btrim(p_reason), 500), p_before, p_after);
end $$;

-- The owner's notes on an account: added, never changed; they go with the account (D-066).
create table private.tenant_notes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (tenant_id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  at_utc timestamptz not null default now(),
  actor_id uuid not null
);
create index tenant_notes_by_tenant on private.tenant_notes (tenant_id, at_utc desc);
create trigger tenant_notes_never_changed before update on private.tenant_notes
  for each statement execute function private.refuse_change();

-- 2. What the dashboard needs on existing tables.

alter table public.tenants add column is_test boolean not null default false;
alter table public.devices add column app_version text check (char_length(app_version) between 1 and 40);
alter table public.payment_slips
  add column payer_bank text check (char_length(btrim(payer_bank)) between 1 and 100),
  add column payer_last4 text check (payer_last4 ~ '^[0-9]{4}$');

-- A period the owner gives: free, with no slip, for the plan or the add-on. The checks the earlier migrations left
-- unnamed are found by what they say and replaced by named ones that also allow it.
do $$
declare
  v_name name;
begin
  for v_name in
    select c.conname from pg_constraint c
    where c.conrelid = 'public.subscriptions'::regclass and c.contype = 'c'
      and (pg_get_constraintdef(c.oid) like '%''trial''::text, ''slip''::text%'
        or pg_get_constraintdef(c.oid) like '%bank_reference IS NOT NULL%'
        or c.conname = 'addon_is_paid')
  loop
    execute format('alter table public.subscriptions drop constraint %I', v_name);
  end loop;
end $$;
alter table public.subscriptions
  add constraint subscriptions_source_known check (source in ('trial', 'slip', 'grant')),
  add constraint slip_periods_carry_payment check (source <> 'slip' or (slip_id is not null and bank_reference is not null and received_on is not null)),
  add constraint given_periods_are_free check (source <> 'grant' or (amount_fils = 0 and slip_id is null)),
  add constraint addon_is_paid_or_given check (kind = 'plan' or source in ('slip', 'grant'));

-- The dashboard opens a slip's file with a 60-second link.
create policy payment_slips_for_admins on storage.objects for select to authenticated
  using (bucket_id = 'payment-slips' and private.is_platform_admin());

-- 3. What the owner can set on an account.

create table private.limit_overrides (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (tenant_id) on delete cascade,
  what text not null check (what in ('workers', 'clients', 'managers')),
  cap integer not null check (cap between 0 and 1000000),
  until_utc timestamptz not null,
  reason text not null,
  created_at_utc timestamptz not null default now(),
  created_by uuid not null,
  ended_at_utc timestamptz
);
create index limit_overrides_by_tenant on private.limit_overrides (tenant_id);

-- Refunds and corrections against a period. A correction says what the right value is; the period stays as it was.
create table private.money_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (tenant_id) on delete cascade,
  kind text not null check (kind in ('refund', 'correction')),
  subscription_id uuid not null references public.subscriptions (id) on delete cascade,
  amount_fils bigint not null default 0 check (amount_fils >= 0),
  field text check (field in ('received_on', 'bank_reference', 'amount_fils', 'payer_bank', 'payer_last4')),
  value text check (char_length(btrim(value)) between 1 and 200),
  reference text,
  on_date date not null,
  reason text not null,
  created_at_utc timestamptz not null default now(),
  created_by uuid not null,
  check ((kind = 'refund') = (amount_fils > 0)),
  check ((kind = 'correction') = (field is not null and value is not null))
);
create index money_entries_by_tenant on private.money_entries (tenant_id);
create trigger money_entries_never_changed before update on private.money_entries
  for each statement execute function private.refuse_change();

-- A hold keeps the books readable on the phone and locks new entries (D-081 (7)); a block also refuses new phones.
create table private.tenant_holds (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (tenant_id) on delete cascade,
  kind text not null check (kind in ('suspend', 'block')),
  until_utc timestamptz,
  told text not null check (char_length(btrim(told)) between 1 and 300),
  note text,
  created_at_utc timestamptz not null default now(),
  created_by uuid not null,
  lifted_at_utc timestamptz,
  lifted_by uuid,
  lift_reason text,
  check ((lifted_at_utc is null) = (lifted_by is null))
);
create index tenant_holds_by_tenant on private.tenant_holds (tenant_id);

create function private.live_hold(p_tenant uuid) returns private.tenant_holds
language sql stable set search_path = '' as $$
  select h.* from private.tenant_holds h
  where h.tenant_id = p_tenant and h.lifted_at_utc is null and (h.until_utc is null or h.until_utc > now())
  order by h.created_at_utc desc limit 1;
$$;

-- The platform's own costs by month, for the owner's own profit (MET-04).
create table private.platform_costs (
  id uuid primary key default gen_random_uuid(),
  month date not null check (extract(day from month) = 1),
  item text not null check (char_length(btrim(item)) between 1 and 100),
  amount_fils bigint not null check (amount_fils >= 0),
  note text,
  created_at_utc timestamptz not null default now(),
  created_by uuid not null
);

-- 4. The owner's actions. Each checks the admin first and writes one audit row with the change.

create function public.admin_accept_slip(p_slip uuid, p_amount_fils bigint, p_bank_reference text, p_received_on date,
  p_payer_bank text, p_payer_last4 text, p_note text default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_before jsonb;
  v_period uuid;
begin
  perform private.require_admin();
  select to_jsonb(s) into v_before from public.payment_slips s where s.id = p_slip;
  if v_before is null then
    raise exception 'no such slip' using errcode = '22023';
  end if;
  update public.payment_slips set payer_bank = nullif(btrim(p_payer_bank), ''), payer_last4 = nullif(btrim(p_payer_last4), '')
    where id = p_slip and state = 'waiting';
  v_period := private.accept_slip(p_slip, p_amount_fils, p_bank_reference, p_received_on, p_note);
  perform private.log_action('accept_slip', (v_before ->> 'tenant_id')::uuid, p_slip, 'bank reference ' || btrim(p_bank_reference),
    v_before, (select to_jsonb(s) from public.payment_slips s where s.id = p_slip) || jsonb_build_object('period', v_period));
  return v_period;
end $$;

create function public.admin_refuse_slip(p_slip uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_before jsonb;
begin
  perform private.require_admin();
  select to_jsonb(s) into v_before from public.payment_slips s where s.id = p_slip;
  perform private.refuse_slip(p_slip, p_reason);
  perform private.log_action('refuse_slip', (v_before ->> 'tenant_id')::uuid, p_slip, p_reason, v_before,
    (select to_jsonb(s) from public.payment_slips s where s.id = p_slip));
end $$;

create function public.admin_revoke_period(p_period uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_before jsonb;
begin
  perform private.require_admin();
  select to_jsonb(s) into v_before from public.subscriptions s where s.id = p_period;
  perform private.revoke_subscription(p_period, p_reason);
  perform private.log_action('revoke_period', (v_before ->> 'tenant_id')::uuid, p_period, p_reason, v_before,
    (select to_jsonb(s) from public.subscriptions s where s.id = p_period));
end $$;

-- Free days for the plan or the add-on, from the end of the unbroken run of that kind's periods, or from now. With
-- no plan named, the latest plan period's plan and version; 'trial' gives the trial again.
create function public.admin_give_days(p_tenant uuid, p_kind text, p_plan_code text, p_days integer, p_reason text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_now timestamptz := now();
  v_start timestamptz;
  v_code text;
  v_version integer;
  v_id uuid;
begin
  perform private.require_admin();
  if p_kind is null or p_kind not in ('plan', 'addon') then
    raise exception 'the plan or the add-on' using errcode = '22023';
  end if;
  if p_days is null or p_days not between 1 and 366 then
    raise exception 'from 1 to 366 days' using errcode = '22023';
  end if;
  perform 1 from public.tenants t where t.tenant_id = p_tenant for update;
  if not found then
    raise exception 'no such account' using errcode = '22023';
  end if;
  if p_plan_code is null then
    select s.plan_code, s.plan_version into v_code, v_version from public.subscriptions s
      where s.tenant_id = p_tenant and s.kind = 'plan' and s.revoked_at_utc is null and s.plan_code <> 'trial'
      order by s.ends_at_utc desc limit 1;
    if v_code is null then
      raise exception 'say which plan' using errcode = '22023';
    end if;
  else
    select p.code, max(p.version) into v_code, v_version from public.plans p where p.code = p_plan_code group by p.code;
    if v_code is null then
      raise exception 'no such plan' using errcode = '22023';
    end if;
  end if;
  with recursive run (ends_at_utc) as (
    select max(s.ends_at_utc) from public.subscriptions s
      where s.tenant_id = p_tenant and s.kind = p_kind and s.revoked_at_utc is null and s.starts_at_utc <= v_now and s.ends_at_utc > v_now
    union
    select s.ends_at_utc from public.subscriptions s join run r on s.starts_at_utc = r.ends_at_utc
    where s.tenant_id = p_tenant and s.kind = p_kind and s.revoked_at_utc is null
  )
  select max(r.ends_at_utc) into v_start from run r;
  v_start := coalesce(v_start, v_now);
  perform private.log_action('give_days', p_tenant, null, p_reason, null,
    jsonb_build_object('kind', p_kind, 'plan', v_code, 'days', p_days, 'from', v_start));
  insert into public.subscriptions (tenant_id, kind, plan_code, plan_version, source, starts_at_utc, ends_at_utc, anchor_at_utc, amount_fils, note)
    values (p_tenant, p_kind, v_code, v_version, 'grant', v_start, v_start + make_interval(days => p_days), v_start, 0, btrim(p_reason))
    returning id into v_id;
  return v_id;
end $$;

create function public.admin_limit_override(p_tenant uuid, p_what text, p_cap integer, p_until timestamptz, p_reason text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  perform private.require_admin();
  if p_until is null or p_until <= now() then
    raise exception 'the end is in the past' using errcode = '22023';
  end if;
  perform private.log_action('limit_override', p_tenant, null, p_reason, null,
    jsonb_build_object('what', p_what, 'cap', p_cap, 'until', p_until));
  insert into private.limit_overrides (tenant_id, what, cap, until_utc, reason, created_by)
    values (p_tenant, p_what, p_cap, p_until, btrim(p_reason), auth.uid())
    returning id into v_id;
  return v_id;
end $$;

create function public.admin_end_override(p_override uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_row private.limit_overrides%rowtype;
begin
  perform private.require_admin();
  update private.limit_overrides set ended_at_utc = now() where id = p_override and ended_at_utc is null
    returning * into v_row;
  if not found then
    raise exception 'no live override with this id' using errcode = '22023';
  end if;
  perform private.log_action('end_override', v_row.tenant_id, p_override, p_reason, null, to_jsonb(v_row));
end $$;

create function public.admin_money_entry(p_tenant uuid, p_kind text, p_period uuid, p_amount_fils bigint, p_field text,
  p_value text, p_reference text, p_on_date date, p_reason text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_period public.subscriptions%rowtype;
  v_refunded bigint;
  v_id uuid;
begin
  perform private.require_admin();
  perform private.require_recent_mfa();
  select * into v_period from public.subscriptions s where s.id = p_period and s.tenant_id = p_tenant for update;
  if not found then
    raise exception 'no such period' using errcode = '22023';
  end if;
  if p_kind = 'refund' then
    select coalesce(sum(m.amount_fils), 0) into v_refunded from private.money_entries m
      where m.subscription_id = p_period and m.kind = 'refund';
    if p_amount_fils is null or p_amount_fils <= 0 or p_amount_fils > v_period.amount_fils - v_refunded then
      raise exception 'more than was paid' using errcode = '22023';
    end if;
  elsif p_kind = 'correction' then
    if p_field is null or nullif(btrim(p_value), '') is null then
      raise exception 'say what is corrected and to what' using errcode = '22023';
    end if;
  else
    raise exception 'a refund or a correction' using errcode = '22023';
  end if;
  perform private.log_action(p_kind, p_tenant, p_period, p_reason, to_jsonb(v_period),
    jsonb_build_object('amount_fils', p_amount_fils, 'field', p_field, 'value', p_value, 'reference', p_reference, 'on_date', p_on_date));
  insert into private.money_entries (tenant_id, kind, subscription_id, amount_fils, field, value, reference, on_date, reason, created_by)
    values (p_tenant, p_kind, p_period, case p_kind when 'refund' then p_amount_fils else 0 end,
      case p_kind when 'correction' then p_field end, case p_kind when 'correction' then btrim(p_value) end,
      nullif(btrim(p_reference), ''), coalesce(p_on_date, current_date), btrim(p_reason), auth.uid())
    returning id into v_id;
  return v_id;
end $$;

create function public.admin_hold(p_tenant uuid, p_kind text, p_until timestamptz, p_told text, p_note text, p_reason text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  perform private.require_admin();
  perform private.require_recent_mfa();
  perform 1 from public.tenants t where t.tenant_id = p_tenant for update;
  if not found then
    raise exception 'no such account' using errcode = '22023';
  end if;
  if p_until is not null and p_until <= now() then
    raise exception 'the end is in the past' using errcode = '22023';
  end if;
  if (private.live_hold(p_tenant)).id is not null then
    raise exception 'this account is held already' using errcode = '22023';
  end if;
  perform private.log_action('hold', p_tenant, null, p_reason, null,
    jsonb_build_object('kind', p_kind, 'until', p_until, 'told', p_told, 'note', p_note));
  insert into private.tenant_holds (tenant_id, kind, until_utc, told, note, created_by)
    values (p_tenant, p_kind, p_until, btrim(p_told), nullif(btrim(p_note), ''), auth.uid())
    returning id into v_id;
  return v_id;
end $$;

create function public.admin_lift_hold(p_hold uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_row private.tenant_holds%rowtype;
begin
  perform private.require_admin();
  perform private.require_recent_mfa();
  update private.tenant_holds set lifted_at_utc = now(), lifted_by = auth.uid(), lift_reason = btrim(p_reason)
    where id = p_hold and lifted_at_utc is null
    returning * into v_row;
  if not found then
    raise exception 'no live hold with this id' using errcode = '22023';
  end if;
  perform private.log_action('lift_hold', v_row.tenant_id, p_hold, p_reason, null, to_jsonb(v_row));
end $$;

-- The email's claim and the phone claims made with it (D-074), so the company can take a trial again.
create function public.admin_free_trial_claim(p_email text, p_reason text) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_tenant uuid;
  v_removed jsonb;
  v_count integer;
begin
  perform private.require_admin();
  select c.tenant_id into v_tenant from private.trial_claims c where c.hash = private.email_hash(btrim(p_email));
  if v_tenant is null then
    raise exception 'no trial claim for this email' using errcode = '22023';
  end if;
  with gone as (
    delete from private.trial_claims c
      where c.hash = private.email_hash(btrim(p_email)) or (c.kind = 'phone' and c.tenant_id = v_tenant)
      returning c.kind, c.tenant_id, c.claimed_at_utc
  )
  select jsonb_agg(to_jsonb(g)), count(*) into v_removed, v_count from gone g;
  perform private.log_action('free_trial_claim', v_tenant, null, p_reason, v_removed, null);
  return v_count;
end $$;

create function public.admin_set_test(p_tenant uuid, p_is_test boolean, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_before boolean;
begin
  perform private.require_admin();
  select t.is_test into v_before from public.tenants t where t.tenant_id = p_tenant;
  if not found then
    raise exception 'no such account' using errcode = '22023';
  end if;
  update public.tenants set is_test = coalesce(p_is_test, false) where tenant_id = p_tenant;
  perform private.log_action('set_test', p_tenant, null, p_reason, jsonb_build_object('is_test', v_before), jsonb_build_object('is_test', p_is_test));
end $$;

create function public.admin_rename(p_tenant uuid, p_name text, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_before text;
begin
  perform private.require_admin();
  select t.name into v_before from public.tenants t where t.tenant_id = p_tenant for update;
  if not found then
    raise exception 'no such account' using errcode = '22023';
  end if;
  update public.tenants set name = btrim(p_name), updated_at_utc = now(), version = version + 1 where tenant_id = p_tenant;
  perform private.log_action('rename', p_tenant, null, p_reason, jsonb_build_object('name', v_before), jsonb_build_object('name', btrim(p_name)));
end $$;

create function public.admin_note(p_tenant uuid, p_body text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  perform private.require_admin();
  insert into private.tenant_notes (tenant_id, body, actor_id) values (p_tenant, btrim(p_body), auth.uid()) returning id into v_id;
  perform private.log_action('note', p_tenant, v_id, 'note: ' || btrim(p_body), null, null);
end $$;

-- Turns a phone off for a lost device, or back on after a mistake, for any account (D-073).
create function public.admin_phone(p_device_row uuid, p_off boolean, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.devices%rowtype;
begin
  perform private.require_admin();
  select * into v_row from public.devices d where d.id = p_device_row for update;
  if not found then
    raise exception 'no such phone' using errcode = '22023';
  end if;
  if p_off is null or p_off = (v_row.revoked_at_utc is not null) then
    raise exception 'the phone is that way already' using errcode = '22023';
  end if;
  update public.devices
    set revoked_at_utc = case when p_off then now() end, updated_at_utc = now(), version = version + 1, actor_id = auth.uid()
    where id = p_device_row;
  perform private.log_action(case when p_off then 'phone_off' else 'phone_on' end, v_row.tenant_id, p_device_row, p_reason,
    to_jsonb(v_row), (select to_jsonb(d) from public.devices d where d.id = p_device_row));
end $$;

create function public.admin_add_cost(p_month date, p_item text, p_amount_fils bigint, p_note text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  perform private.require_admin();
  insert into private.platform_costs (month, item, amount_fils, note, created_by)
    values (date_trunc('month', p_month)::date, btrim(p_item), p_amount_fils, nullif(btrim(p_note), ''), auth.uid())
    returning id into v_id;
  perform private.log_action('add_cost', null, v_id, 'cost: ' || btrim(p_item), null,
    jsonb_build_object('month', date_trunc('month', p_month)::date, 'amount_fils', p_amount_fils));
  return v_id;
end $$;

create function public.admin_save_settings(p_bank_name text, p_account_number text, p_iban text, p_account_holder text,
  p_support_contact text, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_before jsonb;
begin
  perform private.require_admin();
  select to_jsonb(s) into v_before from public.platform_settings s;
  update public.platform_settings set bank_name = nullif(btrim(p_bank_name), ''), account_number = nullif(btrim(p_account_number), ''),
    iban = nullif(btrim(p_iban), ''), account_holder = nullif(btrim(p_account_holder), ''),
    support_contact = nullif(btrim(p_support_contact), ''), updated_at_utc = now();
  perform private.log_action('save_settings', null, null, p_reason, v_before, (select to_jsonb(s) from public.platform_settings s));
end $$;

-- 5. The licence: holds, overrides, given periods, the app's version and when the phone was last seen.

-- As before (T20d-a), and a running given period is continued like a paid one, from its end, as a new anchor.
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
  perform 1 from public.tenants t where t.tenant_id = v_slip.tenant_id for update;
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
      where s.tenant_id = v_slip.tenant_id and s.kind = v_kind and s.revoked_at_utc is null and s.ends_at_utc > now()
        and (s.source = 'slip' or (s.source = 'grant' and s.plan_code <> 'trial'))
      order by s.ends_at_utc desc limit 1;
    if found and v_prev.source = 'slip' then
      v_anchor := v_prev.anchor_at_utc;
      v_months := v_prev.anchor_months + v_slip.months;
      v_start := v_prev.ends_at_utc;
    elsif found then
      v_anchor := v_prev.ends_at_utc;
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

-- As before (BUG-024), and a blocked account takes no phone.
create or replace function public.register_device(p_tenant_id uuid, p_device_id uuid, p_label text, p_platform text, p_operation_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_role text := private.member_role(p_tenant_id);
  v_row public.devices%rowtype;
begin
  if v_user is null or v_role is null then
    raise exception 'not a member of this company' using errcode = '42501';
  end if;
  if (private.live_hold(p_tenant_id)).kind = 'block' then
    raise exception 'this account is blocked' using errcode = '42501';
  end if;
  if public.phone_account(p_device_id) is not null then
    raise exception 'this phone belongs to another account' using errcode = '42501';
  end if;
  select * into v_row from public.devices d where d.tenant_id = p_tenant_id and d.user_id = v_user and d.device_id = p_device_id;
  if not found then
    insert into public.devices (tenant_id, user_id, device_id, label, platform, actor_id, source_operation_id)
      values (p_tenant_id, v_user, p_device_id, btrim(p_label), p_platform, v_user, p_operation_id)
      returning * into v_row;
    return v_row.id;
  end if;
  if v_row.revoked_at_utc is not null and v_role <> 'owner' then
    raise exception 'this device was revoked' using errcode = '42501';
  end if;
  -- The password typed again in the last ten minutes, so a session kept on a lost phone cannot turn it back on.
  if v_row.revoked_at_utc is not null and not exists (
    select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
    where a ->> 'method' = 'password' and (a ->> 'timestamp')::bigint > extract(epoch from now())::bigint - 600
  ) then
    raise exception 'type the password again' using errcode = '42501';
  end if;
  update public.devices
    set revoked_at_utc = null, label = btrim(p_label), last_seen_at_utc = now(), updated_at_utc = now(), version = version + 1,
      actor_id = v_user, source_operation_id = p_operation_id
    where id = v_row.id;
  return v_row.id;
end $$;

-- As before (T20d-a), with the app's version, and: the phone's last check kept; a live hold gives no plan, with the
-- owner's words, so even an app that does not know holds locks entries; a live override raises a limit; a given
-- period counts as paid, and the state is trial only for the trial's own plan. An app that sends no version is still
-- served by the default.
drop function public.licence_facts(uuid, uuid, integer, integer);
create function public.licence_facts(p_tenant_id uuid, p_device_id uuid, p_active_workers integer, p_active_clients integer,
  p_app_version text default null)
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
  v_state text;
  v_members integer;
  v_hold private.tenant_holds%rowtype;
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

  update public.devices set last_seen_at_utc = v_now,
      app_version = coalesce(nullif(btrim(left(p_app_version, 40)), ''), app_version)
    where id = v_device.id;
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
  v_hold := private.live_hold(p_tenant_id);
  -- A paid or given plan before the trial when both cover today.
  select * into v_sub from public.subscriptions s
    where s.tenant_id = p_tenant_id and s.kind = 'plan' and s.revoked_at_utc is null and s.starts_at_utc <= v_now and s.ends_at_utc > v_now
    order by (s.plan_code <> 'trial') desc, (s.source = 'slip') desc, s.ends_at_utc desc
    limit 1;
  if v_sub.id is null or v_hold.id is not null then
    return jsonb_build_object('v', 1, 'iss', 'labour-app', 'jti', gen_random_uuid(), 'iat', v_now,
      'tenant_id', p_tenant_id, 'device_id', p_device_id, 'state', 'none',
      'plan', null, 'plan_version', null, 'plan_name', null, 'starts_at', null,
      'ends_at', (select max(s.ends_at_utc) from public.subscriptions s
        where s.tenant_id = p_tenant_id and s.kind = 'plan' and s.revoked_at_utc is null),
      'lease_until', coalesce(least(v_now + interval '7 days', v_hold.until_utc), v_now + interval '7 days'),
      'addon_until', v_addon,
      'hold', case when v_hold.id is null then null
        else jsonb_build_object('kind', v_hold.kind, 'until', v_hold.until_utc, 'told', v_hold.told) end,
      'limits', jsonb_build_object('workers', 0, 'clients', 0, 'managers', 0, 'devices', v_members));
  end if;
  v_end := v_sub.ends_at_utc;
  v_state := case when v_sub.plan_code = 'trial' then 'trial' else 'paid' end;
  -- A customer offline across a renewal keeps the plan: the end is that of the unbroken run of paid or given periods.
  if v_state = 'paid' then
    with recursive run (ends_at_utc) as (
      select v_sub.ends_at_utc
      union
      select s.ends_at_utc from public.subscriptions s join run r on s.starts_at_utc = r.ends_at_utc
      where s.tenant_id = p_tenant_id and s.kind = 'plan' and s.revoked_at_utc is null
        and (s.source = 'slip' or (s.source = 'grant' and s.plan_code <> 'trial'))
    )
    select max(r.ends_at_utc) into v_end from run r;
  end if;
  select * into v_plan from public.plans p where p.code = v_sub.plan_code and p.version = v_sub.plan_version;
  return jsonb_build_object('v', 1, 'iss', 'labour-app', 'jti', gen_random_uuid(), 'iat', v_now,
    'tenant_id', p_tenant_id, 'device_id', p_device_id, 'state', v_state,
    'plan', v_plan.code, 'plan_version', v_plan.version, 'plan_name', v_plan.name,
    'starts_at', v_sub.starts_at_utc, 'ends_at', v_end, 'lease_until', least(v_now + interval '7 days', v_end),
    'addon_until', v_addon,
    'hold', null,
    'limits', jsonb_build_object(
      'workers', private.with_override(v_plan.max_workers, p_tenant_id, 'workers'),
      'clients', private.with_override(v_plan.max_clients, p_tenant_id, 'clients'),
      'managers', private.with_override(v_plan.max_managers, p_tenant_id, 'managers'),
      'devices', v_members));
end $$;
revoke all on function public.licence_facts(uuid, uuid, integer, integer, text) from public, anon;
grant execute on function public.licence_facts(uuid, uuid, integer, integer, text) to authenticated;

-- A plan's limit, raised by a live override; no limit stays no limit.
create function private.with_override(p_limit integer, p_tenant uuid, p_what text) returns integer
language sql stable set search_path = '' as $$
  select case when p_limit is null then null
    else greatest(p_limit, coalesce((select max(o.cap) from private.limit_overrides o
      where o.tenant_id = p_tenant and o.what = p_what and o.ended_at_utc is null and o.until_utc > now()), 0)) end;
$$;

-- 6. What the dashboard's pages read. Every account at once; the browser filters, sorts and pages.

-- Each account's monthly recurring value at an instant: the plan price of its paid period covering it and the
-- add-on price of its add-on period covering it, each at the period's own price version. Given and trial periods
-- add nothing.
create function private.mrr_at(p_at timestamptz, p_include_test boolean)
returns table (tenant_id uuid, mrr_fils bigint)
language sql stable set search_path = '' as $$
  select t.tenant_id,
    coalesce((select p.price_fils from public.subscriptions s join public.plans p on p.code = s.plan_code and p.version = s.plan_version
      where s.tenant_id = t.tenant_id and s.kind = 'plan' and s.source = 'slip' and s.revoked_at_utc is null
        and s.starts_at_utc <= p_at and s.ends_at_utc > p_at
      order by s.ends_at_utc desc limit 1), 0)
    + coalesce((select p.addon_price_fils from public.subscriptions s join public.plans p on p.code = s.plan_code and p.version = s.plan_version
      where s.tenant_id = t.tenant_id and s.kind = 'addon' and s.source = 'slip' and s.revoked_at_utc is null
        and s.starts_at_utc <= p_at and s.ends_at_utc > p_at
      order by s.ends_at_utc desc limit 1), 0)
  from public.tenants t
  where p_include_test or not t.is_test;
$$;

-- One account as the dashboard lists it.
create function private.account_row(p_tenant uuid) returns jsonb
language sql stable set search_path = '' as $$
  with t as (select * from public.tenants where tenant_id = p_tenant),
  own as (
    select u.email, u.email_confirmed_at from public.memberships m join auth.users u on u.id = m.user_id
    where m.tenant_id = p_tenant and m.role = 'owner' order by m.created_at_utc limit 1
  ),
  cur as (
    select s.* from public.subscriptions s
    where s.tenant_id = p_tenant and s.kind = 'plan' and s.revoked_at_utc is null and s.starts_at_utc <= now() and s.ends_at_utc > now()
    order by (s.plan_code <> 'trial') desc, (s.source = 'slip') desc, s.ends_at_utc desc limit 1
  ),
  live as (select h.* from private.live_hold(p_tenant) h where h.id is not null),
  dev as (
    select count(*) filter (where d.revoked_at_utc is null) as phones_on, max(d.last_seen_at_utc) as last_seen,
      (array_agg(d.app_version order by d.last_seen_at_utc desc) filter (where d.app_version is not null))[1] as app_version
    from public.devices d where d.tenant_id = p_tenant
  ),
  use_report as (select * from private.usage_reports r where r.tenant_id = p_tenant)
  select jsonb_build_object(
    'tenant_id', t.tenant_id, 'name', t.name, 'created_at', t.created_at_utc, 'is_test', t.is_test,
    'owner_email', (select email from own), 'email_confirmed', (select email_confirmed_at is not null from own),
    'state', case
      when exists (select 1 from live) then 'held'
      when exists (select 1 from cur) then case when (select plan_code from cur) = 'trial' then 'trial' else 'paid' end
      when exists (select 1 from public.subscriptions s where s.tenant_id = p_tenant and s.kind = 'plan') then 'ended'
      else 'none' end,
    'plan', (select plan_code from cur),
    'plan_name', (select p.name from cur join public.plans p on p.code = cur.plan_code and p.version = cur.plan_version),
    'plan_ends_at', (select max(s.ends_at_utc) from public.subscriptions s where s.tenant_id = p_tenant and s.kind = 'plan' and s.revoked_at_utc is null),
    'addon_ends_at', (select max(s.ends_at_utc) from public.subscriptions s where s.tenant_id = p_tenant and s.kind = 'addon' and s.revoked_at_utc is null and s.ends_at_utc > now()),
    'hold', (select jsonb_build_object('id', h.id, 'kind', h.kind, 'until', h.until_utc, 'told', h.told) from live h),
    'phones_on', (select phones_on from dev), 'last_seen', (select last_seen from dev), 'app_version', (select app_version from dev),
    'workers', (select active_workers from use_report), 'clients', (select active_clients from use_report), 'reported_at', (select reported_at_utc from use_report),
    'limits', (select jsonb_build_object(
        'workers', private.with_override(p.max_workers, p_tenant, 'workers'),
        'clients', private.with_override(p.max_clients, p_tenant, 'clients'),
        'managers', private.with_override(p.max_managers, p_tenant, 'managers'))
      from cur join public.plans p on p.code = cur.plan_code and p.version = cur.plan_version),
    'slips_waiting', (select count(*) from public.payment_slips ps where ps.tenant_id = p_tenant and ps.state = 'waiting'),
    'paid_fils', (select coalesce(sum(s.amount_fils), 0) from public.subscriptions s where s.tenant_id = p_tenant and s.source = 'slip')
      - (select coalesce(sum(m.amount_fils), 0) from private.money_entries m where m.tenant_id = p_tenant and m.kind = 'refund'))
  from t;
$$;

create function public.admin_accounts(p_include_test boolean) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  -- ponytail: every account at once and the browser filters; page here past about 2,000 accounts.
  return coalesce((select jsonb_agg(private.account_row(t.tenant_id) order by t.created_at_utc desc)
    from public.tenants t where p_include_test or not t.is_test), '[]'::jsonb);
end $$;

create function public.admin_account(p_tenant uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_row jsonb;
begin
  perform private.require_admin();
  v_row := private.account_row(p_tenant);
  if v_row is null then
    raise exception 'no such account' using errcode = '22023';
  end if;
  return v_row || jsonb_build_object(
    'members', coalesce((select jsonb_agg(jsonb_build_object('user_id', m.user_id, 'email', u.email, 'role', m.role,
        'since', m.created_at_utc, 'revoked_at', m.revoked_at_utc) order by m.created_at_utc)
      from public.memberships m join auth.users u on u.id = m.user_id where m.tenant_id = p_tenant), '[]'::jsonb),
    'devices', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'label', d.label, 'platform', d.platform,
        'app_version', d.app_version, 'last_seen', d.last_seen_at_utc, 'since', d.created_at_utc, 'off_at', d.revoked_at_utc,
        'user_email', u.email) order by d.created_at_utc)
      from public.devices d left join auth.users u on u.id = d.user_id where d.tenant_id = p_tenant), '[]'::jsonb),
    'periods', coalesce((select jsonb_agg(to_jsonb(s) order by s.starts_at_utc desc)
      from public.subscriptions s where s.tenant_id = p_tenant), '[]'::jsonb),
    'slips', coalesce((select jsonb_agg(to_jsonb(ps) order by ps.submitted_at_utc desc)
      from public.payment_slips ps where ps.tenant_id = p_tenant), '[]'::jsonb),
    'money_entries', coalesce((select jsonb_agg(to_jsonb(m) order by m.created_at_utc desc)
      from private.money_entries m where m.tenant_id = p_tenant), '[]'::jsonb),
    'holds', coalesce((select jsonb_agg(to_jsonb(h) order by h.created_at_utc desc)
      from private.tenant_holds h where h.tenant_id = p_tenant), '[]'::jsonb),
    'overrides', coalesce((select jsonb_agg(to_jsonb(o) order by o.created_at_utc desc)
      from private.limit_overrides o where o.tenant_id = p_tenant), '[]'::jsonb),
    'notes', coalesce((select jsonb_agg(to_jsonb(n) order by n.at_utc desc)
      from private.tenant_notes n where n.tenant_id = p_tenant), '[]'::jsonb),
    'backups', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'size_bytes', b.size_bytes, 'finished_at', b.finished_at_utc,
        'keep_until', b.keep_until_utc) order by b.finished_at_utc desc)
      from public.cloud_backups b where b.tenant_id = p_tenant and b.finished_at_utc is not null), '[]'::jsonb),
    'story', coalesce((select jsonb_agg(jsonb_build_object('at', e.at, 'what', e.what, 'detail', e.detail) order by e.at desc)
      from (
        select u.created_at as at, 'account_made' as what, u.email as detail
          from public.memberships m join auth.users u on u.id = m.user_id where m.tenant_id = p_tenant and m.role = 'owner'
        union all
        select u.email_confirmed_at, 'email_confirmed', u.email
          from public.memberships m join auth.users u on u.id = m.user_id
          where m.tenant_id = p_tenant and m.role = 'owner' and u.email_confirmed_at is not null
        union all
        select t.created_at_utc, 'company_made', t.name from public.tenants t where t.tenant_id = p_tenant
        union all
        select s.created_at_utc, 'period_' || s.source, s.kind || ' ' || s.plan_code || ' ' || s.starts_at_utc::date || ' ' || s.ends_at_utc::date
          from public.subscriptions s where s.tenant_id = p_tenant
        union all
        select ps.submitted_at_utc, 'slip_sent', ps.plan_code || ' ' || ps.months || ' ' || ps.expected_fils
          from public.payment_slips ps where ps.tenant_id = p_tenant
        union all
        select d.created_at_utc, 'phone_added', d.label from public.devices d where d.tenant_id = p_tenant
        union all
        select d.revoked_at_utc, 'phone_off', d.label from public.devices d where d.tenant_id = p_tenant and d.revoked_at_utc is not null
        union all
        select a.at_utc, 'admin_' || a.action, a.reason from private.admin_actions a where a.tenant_id = p_tenant
      ) e where e.at is not null), '[]'::jsonb));
end $$;

create function public.admin_overview(p_from timestamptz, p_to timestamptz, p_include_test boolean) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_m0 timestamptz;
  v_m1 timestamptz;
  v_rows jsonb;
begin
  perform private.require_admin();
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'a range from a start to an end' using errcode = '22023';
  end if;
  v_m0 := date_trunc('month', p_to);
  v_m1 := least(p_to, v_m0 + interval '1 month');
  select coalesce(jsonb_agg(private.account_row(t.tenant_id)), '[]'::jsonb) into v_rows
    from public.tenants t where p_include_test or not t.is_test;
  return jsonb_build_object(
    'fetched_at', now(),
    'accounts', (select jsonb_build_object(
        'total', count(*),
        'trial', count(*) filter (where r ->> 'state' = 'trial'),
        'paying', count(*) filter (where r ->> 'state' = 'paid'),
        'ended', count(*) filter (where r ->> 'state' = 'ended'),
        'held', count(*) filter (where r ->> 'state' = 'held'))
      from jsonb_array_elements(v_rows) r),
    'mrr_fils', (select coalesce(sum(m.mrr_fils), 0) from private.mrr_at(p_to, p_include_test) m),
    'cash_fils', (select coalesce(sum(s.amount_fils), 0) from public.subscriptions s join public.tenants t using (tenant_id)
        where s.source = 'slip' and s.received_on between p_from::date and p_to::date and (p_include_test or not t.is_test))
      - (select coalesce(sum(m.amount_fils), 0) from private.money_entries m join public.tenants t using (tenant_id)
        where m.kind = 'refund' and m.on_date between p_from::date and p_to::date and (p_include_test or not t.is_test)),
    'trial_to_paid', (select jsonb_build_object('started', count(*),
        'paid', count(*) filter (where exists (select 1 from public.subscriptions p where p.tenant_id = s.tenant_id and p.source = 'slip')))
      from public.subscriptions s join public.tenants t using (tenant_id)
      where s.source = 'trial' and s.starts_at_utc >= p_from and s.starts_at_utc <= p_to and (p_include_test or not t.is_test)),
    'slips_waiting', (select count(*) from public.payment_slips ps join public.tenants t using (tenant_id)
      where ps.state = 'waiting' and (p_include_test or not t.is_test)),
    'today', jsonb_build_object(
      'slips', coalesce((select jsonb_agg(jsonb_build_object('id', ps.id, 'tenant_id', ps.tenant_id, 'name', t.name, 'plan', ps.plan_code,
          'months', ps.months, 'covers', ps.covers, 'expected_fils', ps.expected_fils, 'sent_at', ps.submitted_at_utc,
          'file_arrived', exists (select 1 from storage.objects o where o.bucket_id = 'payment-slips' and o.name = ps.file_path))
          order by ps.submitted_at_utc)
        from public.payment_slips ps join public.tenants t using (tenant_id)
        where ps.state = 'waiting' and (p_include_test or not t.is_test)), '[]'::jsonb),
      'over_limit', coalesce((select jsonb_agg(r) from jsonb_array_elements(v_rows) r
        where (r ->> 'workers')::integer > (r -> 'limits' ->> 'workers')::integer
           or (r ->> 'clients')::integer > (r -> 'limits' ->> 'clients')::integer), '[]'::jsonb),
      'trials_ending', coalesce((select jsonb_agg(r) from jsonb_array_elements(v_rows) r
        where r ->> 'state' = 'trial' and (r ->> 'plan_ends_at')::timestamptz < now() + interval '5 days'), '[]'::jsonb),
      'offline', coalesce((select jsonb_agg(r) from jsonb_array_elements(v_rows) r
        where r ->> 'state' in ('trial', 'paid') and coalesce((r ->> 'last_seen')::timestamptz, '-infinity') < now() - interval '7 days'), '[]'::jsonb)),
    'cash_by_month', (select jsonb_agg(jsonb_build_object('month', g.m::date,
        'cash_fils', (select coalesce(sum(s.amount_fils), 0) from public.subscriptions s join public.tenants t using (tenant_id)
            where s.source = 'slip' and date_trunc('month', s.received_on) = g.m and (p_include_test or not t.is_test))
          - (select coalesce(sum(m.amount_fils), 0) from private.money_entries m join public.tenants t using (tenant_id)
            where m.kind = 'refund' and date_trunc('month', m.on_date) = g.m and (p_include_test or not t.is_test))) order by g.m)
      from generate_series(v_m0 - interval '11 months', v_m0, interval '1 month') g (m)),
    'mrr_bridge', (
      with o as (select * from private.mrr_at(v_m0, p_include_test)),
      c as (select * from private.mrr_at(v_m1, p_include_test)),
      b as (
        select o.mrr_fils as o, c.mrr_fils as c,
          exists (select 1 from public.subscriptions s where s.tenant_id = o.tenant_id and s.source = 'slip' and s.revoked_at_utc is null
            and s.starts_at_utc < v_m0) as before
        from o join c using (tenant_id)
      )
      select jsonb_build_object('month', v_m0::date,
        'opening', coalesce(sum(b.o), 0),
        'new', coalesce(sum(b.c) filter (where b.o = 0 and b.c > 0 and not b.before), 0),
        'reactivation', coalesce(sum(b.c) filter (where b.o = 0 and b.c > 0 and b.before), 0),
        'expansion', coalesce(sum(b.c - b.o) filter (where b.o > 0 and b.c > b.o), 0),
        'contraction', coalesce(sum(b.o - b.c) filter (where b.c > 0 and b.c < b.o), 0),
        'churn', coalesce(sum(b.o) filter (where b.o > 0 and b.c = 0), 0),
        'closing', coalesce(sum(b.c), 0))
      from b),
    'plan_mix', (select coalesce(jsonb_object_agg(k, n), '{}'::jsonb) from (
        select coalesce(r ->> 'plan', r ->> 'state') as k, count(*) as n from jsonb_array_elements(v_rows) r group by 1) x),
    'addon_accounts', (select count(*) from jsonb_array_elements(v_rows) r where r ->> 'addon_ends_at' is not null),
    'costs_fils', (select coalesce(sum(c.amount_fils), 0) from private.platform_costs c where c.month = v_m0::date));
end $$;

create function public.admin_slips(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(to_jsonb(ps) || jsonb_build_object(
      'tenant_name', t.name, 'is_test', t.is_test,
      'sender_email', u.email, 'sender_role', m.role,
      'plan_name', p.name,
      'periods', coalesce((select jsonb_agg(to_jsonb(s) order by s.kind) from public.subscriptions s where s.slip_id = ps.id), '[]'::jsonb),
      'money_entries', coalesce((select jsonb_agg(to_jsonb(e) order by e.created_at_utc)
        from private.money_entries e join public.subscriptions s on s.id = e.subscription_id where s.slip_id = ps.id), '[]'::jsonb))
      order by ps.submitted_at_utc desc)
    from public.payment_slips ps
    join public.tenants t using (tenant_id)
    join public.plans p on p.code = ps.plan_code and p.version = ps.plan_version
    left join auth.users u on u.id = ps.submitted_by
    left join public.memberships m on m.tenant_id = ps.tenant_id and m.user_id = ps.submitted_by
    where ps.submitted_at_utc >= p_from and ps.submitted_at_utc <= p_to), '[]'::jsonb);
end $$;

create function public.admin_audit(p_from timestamptz, p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(x.row order by x.at_utc desc) from (
      select a.at_utc, to_jsonb(a) || jsonb_build_object('actor_email', u.email, 'tenant_name', t.name) as row
      from private.admin_actions a
      left join auth.users u on u.id = a.actor_id
      left join public.tenants t on t.tenant_id = a.tenant_id
      where a.at_utc >= p_from and a.at_utc <= p_to
      order by a.at_utc desc
      limit 5000) x), '[]'::jsonb);
end $$;

create function public.admin_settings() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return jsonb_build_object(
    'admins', coalesce((select jsonb_agg(jsonb_build_object('user_id', a.user_id, 'email', u.email, 'role', a.role, 'added_at', a.added_at_utc,
        'totp', exists (select 1 from auth.mfa_factors f where f.user_id = a.user_id and f.factor_type = 'totp' and f.status = 'verified')))
      from private.platform_admins a join auth.users u on u.id = a.user_id), '[]'::jsonb),
    'platform', (select to_jsonb(s) from public.platform_settings s),
    'plans', coalesce((select jsonb_agg(to_jsonb(p) order by p.sort_order, p.version) from public.plans p), '[]'::jsonb),
    'costs', coalesce((select jsonb_agg(to_jsonb(c) order by c.month desc, c.created_at_utc) from private.platform_costs c), '[]'::jsonb),
    'test_accounts', coalesce((select jsonb_agg(jsonb_build_object('tenant_id', t.tenant_id, 'name', t.name))
      from public.tenants t where t.is_test), '[]'::jsonb));
end $$;

-- Every admin_ function: signed-in users only, and each checks the admin itself.
do $$
declare
  v_fn regprocedure;
begin
  for v_fn in
    select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
  loop
    execute format('revoke all on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;
end $$;
revoke all on function private.require_admin(), private.require_recent_mfa(), private.refuse_change(),
  private.log_action(text, uuid, uuid, text, jsonb, jsonb), private.live_hold(uuid), private.with_override(integer, uuid, text),
  private.mrr_at(timestamptz, boolean), private.account_row(uuid) from public;
