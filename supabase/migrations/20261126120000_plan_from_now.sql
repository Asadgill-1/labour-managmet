-- T22c: a plan changed from now, and the Auth ban shown on the account (D-083; ADMIN-03, BILL-04). A period is never
-- edited: ending one early is a row of its own in `private.period_cuts`, and every function that asks which period
-- covers a moment reads the periods through `private.periods`, which applies the cuts. The period as written stays,
-- so the money record and the audit log keep what was paid for.

create table private.period_cuts (
  subscription_id uuid primary key references public.subscriptions (id) on delete cascade,
  tenant_id uuid not null references public.tenants (tenant_id) on delete cascade,
  cut_at_utc timestamptz not null,
  reason text not null,
  created_at_utc timestamptz not null default now(),
  created_by uuid not null
);
create index period_cuts_by_tenant on private.period_cuts (tenant_id);
-- Never changed; a deleted account takes its cuts with it (D-066), so only an update is refused.
create trigger period_cuts_never_changed before update on private.period_cuts
  for each statement execute function private.refuse_change();

-- The periods as they run: a cut period ends at its cut, and one cut before it began starts and ends at the cut, so it
-- never runs and never looks still to come. Same columns, in the same order, as public.subscriptions.
create view private.periods as
  select s.id, s.tenant_id, s.plan_code, s.plan_version, s.source, s.slip_id,
    case when c.cut_at_utc is null then s.starts_at_utc else least(s.starts_at_utc, c.cut_at_utc) end as starts_at_utc,
    case when c.cut_at_utc is null then s.ends_at_utc else least(s.ends_at_utc, c.cut_at_utc) end as ends_at_utc,
    s.anchor_at_utc, s.anchor_months, s.amount_fils, s.bank_reference, s.received_on, s.note, s.revoked_at_utc, s.revoke_reason,
    s.created_at_utc, s.kind
  from public.subscriptions s
  left join private.period_cuts c on c.subscription_id = s.id;
revoke all on private.periods, private.period_cuts from public, anon, authenticated;

-- The functions that ask which period covers a moment, as before (T20d-a, T22a), reading the periods with their cuts.

create or replace function public.licence_facts(p_tenant_id uuid, p_device_id uuid, p_active_workers integer, p_active_clients integer,
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
  v_sub private.periods%rowtype;
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

  if v_role = 'owner' and not exists (select 1 from private.periods s where s.tenant_id = p_tenant_id and s.kind = 'plan') then
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
    select max(s.ends_at_utc) from private.periods s
      where s.tenant_id = p_tenant_id and s.kind = 'addon' and s.revoked_at_utc is null
        and s.starts_at_utc <= v_now and s.ends_at_utc > v_now
    union
    select s.ends_at_utc from private.periods s join run r on s.starts_at_utc = r.ends_at_utc
    where s.tenant_id = p_tenant_id and s.kind = 'addon' and s.revoked_at_utc is null
  )
  select max(r.ends_at_utc) into v_addon from run r;

  select count(*) into v_members from public.memberships m where m.tenant_id = p_tenant_id and m.revoked_at_utc is null;
  v_hold := private.live_hold(p_tenant_id);
  -- A paid or given plan before the trial when both cover today.
  select * into v_sub from private.periods s
    where s.tenant_id = p_tenant_id and s.kind = 'plan' and s.revoked_at_utc is null and s.starts_at_utc <= v_now and s.ends_at_utc > v_now
    order by (s.plan_code <> 'trial') desc, (s.source = 'slip') desc, s.ends_at_utc desc
    limit 1;
  if v_sub.id is null or v_hold.id is not null then
    return jsonb_build_object('v', 1, 'iss', 'labour-app', 'jti', gen_random_uuid(), 'iat', v_now,
      'tenant_id', p_tenant_id, 'device_id', p_device_id, 'state', 'none',
      'plan', null, 'plan_version', null, 'plan_name', null, 'starts_at', null,
      'ends_at', (select max(s.ends_at_utc) from private.periods s
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
      select s.ends_at_utc from private.periods s join run r on s.starts_at_utc = r.ends_at_utc
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

create or replace function private.mrr_at(p_at timestamptz, p_include_test boolean)
returns table (tenant_id uuid, mrr_fils bigint)
language sql stable set search_path = '' as $$
  select t.tenant_id,
    coalesce((select p.price_fils from private.periods s join public.plans p on p.code = s.plan_code and p.version = s.plan_version
      where s.tenant_id = t.tenant_id and s.kind = 'plan' and s.source = 'slip' and s.revoked_at_utc is null
        and s.starts_at_utc <= p_at and s.ends_at_utc > p_at
      order by s.ends_at_utc desc limit 1), 0)
    + coalesce((select p.addon_price_fils from private.periods s join public.plans p on p.code = s.plan_code and p.version = s.plan_version
      where s.tenant_id = t.tenant_id and s.kind = 'addon' and s.source = 'slip' and s.revoked_at_utc is null
        and s.starts_at_utc <= p_at and s.ends_at_utc > p_at
      order by s.ends_at_utc desc limit 1), 0)
  from public.tenants t
  where p_include_test or not t.is_test;
$$;

create or replace function private.account_row(p_tenant uuid) returns jsonb
language sql stable set search_path = '' as $$
  with t as (select * from public.tenants where tenant_id = p_tenant),
  own as (
    select u.email, u.email_confirmed_at from public.memberships m join auth.users u on u.id = m.user_id
    where m.tenant_id = p_tenant and m.role = 'owner' order by m.created_at_utc limit 1
  ),
  cur as (
    select s.* from private.periods s
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
      when exists (select 1 from private.periods s where s.tenant_id = p_tenant and s.kind = 'plan') then 'ended'
      else 'none' end,
    'plan', (select plan_code from cur),
    'plan_name', (select p.name from cur join public.plans p on p.code = cur.plan_code and p.version = cur.plan_version),
    'plan_ends_at', (select max(s.ends_at_utc) from private.periods s where s.tenant_id = p_tenant and s.kind = 'plan' and s.revoked_at_utc is null),
    'addon_ends_at', (select max(s.ends_at_utc) from private.periods s where s.tenant_id = p_tenant and s.kind = 'addon' and s.revoked_at_utc is null and s.ends_at_utc > now()),
    'hold', (select jsonb_build_object('id', h.id, 'kind', h.kind, 'until', h.until_utc, 'told', h.told) from live h),
    'phones_on', (select phones_on from dev), 'last_seen', (select last_seen from dev), 'app_version', (select app_version from dev),
    'workers', (select active_workers from use_report), 'clients', (select active_clients from use_report), 'reported_at', (select reported_at_utc from use_report),
    'limits', (select jsonb_build_object(
        'workers', private.with_override(p.max_workers, p_tenant, 'workers'),
        'clients', private.with_override(p.max_clients, p_tenant, 'clients'),
        'managers', private.with_override(p.max_managers, p_tenant, 'managers'))
      from cur join public.plans p on p.code = cur.plan_code and p.version = cur.plan_version),
    'slips_waiting', (select count(*) from public.payment_slips ps where ps.tenant_id = p_tenant and ps.state = 'waiting'),
    'paid_fils', (select coalesce(sum(s.amount_fils), 0) from private.periods s where s.tenant_id = p_tenant and s.source = 'slip')
      - (select coalesce(sum(m.amount_fils), 0) from private.money_entries m where m.tenant_id = p_tenant and m.kind = 'refund'))
  from t;
$$;

create or replace function private.accept_slip(p_slip_id uuid, p_amount_fils bigint, p_bank_reference text, p_received_on date, p_note text default null)
returns uuid
language plpgsql set search_path = '' as $$
declare
  v_slip public.payment_slips%rowtype;
  v_prev private.periods%rowtype;
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
    select * into v_prev from private.periods s
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

create or replace function public.admin_give_days(p_tenant uuid, p_kind text, p_plan_code text, p_days integer, p_reason text) returns uuid
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
    select s.plan_code, s.plan_version into v_code, v_version from private.periods s
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
    select max(s.ends_at_utc) from private.periods s
      where s.tenant_id = p_tenant and s.kind = p_kind and s.revoked_at_utc is null and s.starts_at_utc <= v_now and s.ends_at_utc > v_now
    union
    select s.ends_at_utc from private.periods s join run r on s.starts_at_utc = r.ends_at_utc
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

create or replace function public.submit_slip(p_tenant_id uuid, p_plan_code text, p_months integer, p_file_type text, p_operation_id uuid, p_covers text default 'plan')
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
    select p.* into v_own from private.periods s
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

create or replace function public.admin_account(p_tenant uuid) returns jsonb
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
        'since', m.created_at_utc, 'revoked_at', m.revoked_at_utc, 'banned_until', u.banned_until) order by m.created_at_utc)
      from public.memberships m join auth.users u on u.id = m.user_id where m.tenant_id = p_tenant), '[]'::jsonb),
    'devices', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'label', d.label, 'platform', d.platform,
        'app_version', d.app_version, 'last_seen', d.last_seen_at_utc, 'since', d.created_at_utc, 'off_at', d.revoked_at_utc,
        'user_email', u.email) order by d.created_at_utc)
      from public.devices d left join auth.users u on u.id = d.user_id where d.tenant_id = p_tenant), '[]'::jsonb),
    'periods', coalesce((select jsonb_agg(to_jsonb(s) || jsonb_build_object('cut_at', c.cut_at_utc) order by s.starts_at_utc desc)
      from public.subscriptions s left join private.period_cuts c on c.subscription_id = s.id where s.tenant_id = p_tenant), '[]'::jsonb),
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

-- Ends now every paid or given plan period of the account still running or still to come; the trial is left, as a
-- paid or given plan already comes before it. Returns the periods as they were written.
create function private.cut_plan(p_tenant uuid, p_reason text) returns jsonb
language plpgsql set search_path = '' as $$
declare
  v_cut jsonb;
begin
  with gone as (
    insert into private.period_cuts (subscription_id, tenant_id, cut_at_utc, reason, created_by)
      select s.id, s.tenant_id, now(), btrim(p_reason), auth.uid() from private.periods s
      where s.tenant_id = p_tenant and s.kind = 'plan' and s.plan_code <> 'trial' and s.revoked_at_utc is null and s.ends_at_utc > now()
      returning subscription_id
  )
  select coalesce(jsonb_agg(to_jsonb(s) order by s.starts_at_utc), '[]'::jsonb) into v_cut
    from public.subscriptions s join gone g on g.subscription_id = s.id;
  return v_cut;
end $$;
revoke all on function private.cut_plan(uuid, text) from public;

-- As before (T22a), and a slip may start its plan now: the running plan ends now, and the days the owner credits for
-- what was left follow the new period as a given one, so the next slip continues after them.
drop function public.admin_accept_slip(uuid, bigint, text, date, text, text, text);
create function public.admin_accept_slip(p_slip uuid, p_amount_fils bigint, p_bank_reference text, p_received_on date,
  p_payer_bank text, p_payer_last4 text, p_note text default null, p_start_now boolean default false, p_credit_days integer default 0)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_before jsonb;
  v_tenant uuid;
  v_cut jsonb := '[]'::jsonb;
  v_period uuid;
  v_end timestamptz;
begin
  perform private.require_admin();
  select to_jsonb(s) into v_before from public.payment_slips s where s.id = p_slip;
  if v_before is null then
    raise exception 'no such slip' using errcode = '22023';
  end if;
  v_tenant := (v_before ->> 'tenant_id')::uuid;
  if coalesce(p_start_now, false) then
    perform private.require_recent_mfa();
    if v_before ->> 'covers' = 'addon' then
      raise exception 'the add-on alone starts with its own period' using errcode = '22023';
    end if;
    if p_credit_days is null or p_credit_days not between 0 and 366 then
      raise exception 'from 0 to 366 days' using errcode = '22023';
    end if;
    perform 1 from public.tenants t where t.tenant_id = v_tenant for update;
    v_cut := private.cut_plan(v_tenant, 'plan from now, slip ' || p_slip::text);
  end if;
  update public.payment_slips set payer_bank = nullif(btrim(p_payer_bank), ''), payer_last4 = nullif(btrim(p_payer_last4), '')
    where id = p_slip and state = 'waiting';
  v_period := private.accept_slip(p_slip, p_amount_fils, p_bank_reference, p_received_on, p_note);
  if coalesce(p_start_now, false) and p_credit_days > 0 then
    select s.ends_at_utc into v_end from public.subscriptions s where s.id = v_period;
    insert into public.subscriptions (tenant_id, kind, plan_code, plan_version, source, starts_at_utc, ends_at_utc, anchor_at_utc, amount_fils, note)
      values (v_tenant, 'plan', v_before ->> 'plan_code', (v_before ->> 'plan_version')::integer, 'grant', v_end,
        v_end + make_interval(days => p_credit_days), v_end, 0, 'credit for the plan ended early');
  end if;
  perform private.log_action('accept_slip', v_tenant, p_slip, 'bank reference ' || btrim(p_bank_reference),
    v_before || jsonb_build_object('cut', v_cut),
    (select to_jsonb(s) from public.payment_slips s where s.id = p_slip)
      || jsonb_build_object('period', v_period, 'start_now', coalesce(p_start_now, false), 'credit_days', case when p_start_now then p_credit_days else 0 end));
  return v_period;
end $$;

-- Moves an account to another plan from now, with no money: the running plan ends now and the new plan is given for
-- the days the owner chooses, the credit for what was left. The next slip continues after it.
create function public.admin_change_plan(p_tenant uuid, p_plan_code text, p_days integer, p_reason text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_version integer;
  v_cut jsonb;
  v_id uuid;
begin
  perform private.require_admin();
  perform private.require_recent_mfa();
  perform 1 from public.tenants t where t.tenant_id = p_tenant for update;
  if not found then
    raise exception 'no such account' using errcode = '22023';
  end if;
  select max(p.version) into v_version from public.plans p where p.code = p_plan_code and p.code <> 'trial';
  if v_version is null then
    raise exception 'no such plan' using errcode = '22023';
  end if;
  if p_days is null or p_days not between 1 and 366 then
    raise exception 'from 1 to 366 days' using errcode = '22023';
  end if;
  v_cut := private.cut_plan(p_tenant, p_reason);
  insert into public.subscriptions (tenant_id, kind, plan_code, plan_version, source, starts_at_utc, ends_at_utc, anchor_at_utc, amount_fils, note)
    values (p_tenant, 'plan', p_plan_code, v_version, 'grant', now(), now() + make_interval(days => p_days), now(), 0, btrim(p_reason))
    returning id into v_id;
  perform private.log_action('change_plan', p_tenant, v_id, p_reason, v_cut,
    jsonb_build_object('plan', p_plan_code, 'days', p_days, 'from', now()));
  return v_id;
end $$;

revoke all on function public.admin_accept_slip(uuid, bigint, text, date, text, text, text, boolean, integer),
  public.admin_change_plan(uuid, text, integer, text) from public, anon;
grant execute on function public.admin_accept_slip(uuid, bigint, text, date, text, text, text, boolean, integer),
  public.admin_change_plan(uuid, text, integer, text) to authenticated;
