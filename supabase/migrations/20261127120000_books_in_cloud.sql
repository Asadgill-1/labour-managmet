-- T22d: the books in the cloud, with the customer's consent (D-081 part 2, D-084). The app sends each record of its
-- books as it stands, and a summary of each month from "Malik ki sheet"; the cloud keeps the newest version of each.
-- Nothing is taken before the company's owner agreed on the consent page. Only a platform admin reads them, through
-- the admin_ functions; deleting the account removes them (D-066).

-- The company's answer on the consent page: when, and which wording (raised when the wording changes).
alter table public.tenants
  add column data_consent_at_utc timestamptz,
  add column data_consent_version integer check (data_consent_version > 0);

-- The app's own record types: its 30 book tables, and the month's figures it works out itself. Nothing else is taken.
create function private.book_entities() returns text[]
language sql immutable set search_path = '' as $$
  select array['tenant_profiles', 'clients', 'sites', 'workers', 'pay_contracts', 'billing_contracts', 'opening_balances',
    'worker_groups', 'worker_group_members', 'rooms', 'cash_entries', 'salary_allocations', 'period_locks', 'day_offs',
    'document_assets', 'document_templates', 'issued_documents', 'timesheets', 'timesheet_revisions', 'timesheet_lines',
    'billed_allocations', 'invoices', 'invoice_lines', 'invoice_allocations', 'attendance_batches', 'attendance_entries',
    'payroll_runs', 'payroll_lines', 'payroll_items', 'number_floors', 'month_summary']
$$;

-- The newest version of each record. Data null is a deleted record's mark, kept so an older copy cannot come back.
create table private.book_rows (
  tenant_id uuid not null references public.tenants (tenant_id) on delete cascade,
  entity text not null check (entity = any (private.book_entities())),
  record_id text not null check (char_length(record_id) between 1 and 100),
  record_version integer not null check (record_version > 0),
  data jsonb check (data is null or jsonb_typeof(data) = 'object'),
  device_id uuid not null,
  received_at_utc timestamptz not null default now(),
  primary key (tenant_id, entity, record_id)
);
create index book_rows_months on private.book_rows (record_id) where entity = 'month_summary';
revoke all on private.book_rows from public, anon, authenticated;

-- The company's owner agrees to send the books. A wording agreed again, or an older one, keeps the newest.
create function public.give_data_consent(p_tenant_id uuid, p_version integer) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
  v_at timestamptz;
begin
  if private.member_role(p_tenant_id) is distinct from 'owner' then
    raise exception 'only the owner gives consent' using errcode = '42501';
  end if;
  if p_version is null or p_version < 1 then
    raise exception 'consent needs its wording''s version' using errcode = '22023';
  end if;
  update public.tenants t set
      data_consent_at_utc = case when t.data_consent_version >= p_version then t.data_consent_at_utc else now() end,
      data_consent_version = greatest(coalesce(t.data_consent_version, 0), p_version),
      updated_at_utc = now(), version = t.version + 1
    where t.tenant_id = p_tenant_id
    returning t.data_consent_at_utc into v_at;
  return v_at;
end $$;
revoke all on function public.give_data_consent(uuid, integer) from public, anon;
grant execute on function public.give_data_consent(uuid, integer) to authenticated;

-- Takes up to 500 changed records from a member's phone: [{entity, id, version, data}], data null for a deleted one.
-- The phone must be on for the company and the company must have agreed. A version lower than the one kept is
-- ignored, so a resend or an older phone changes nothing; an equal one replaces, as the later send. All or nothing.
create function public.push_book_changes(p_tenant_id uuid, p_device_id uuid, p_changes jsonb) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_item jsonb;
  v_entity text;
  v_id text;
  v_version integer;
  v_data jsonb;
begin
  if v_user is null or private.member_role(p_tenant_id) is null then
    raise exception 'not a member of this company' using errcode = '42501';
  end if;
  if not exists (select 1 from public.devices d where d.tenant_id = p_tenant_id and d.user_id = v_user
      and d.device_id = p_device_id and d.revoked_at_utc is null) then
    raise exception 'this phone is not on for this company' using errcode = '42501';
  end if;
  if (select t.data_consent_at_utc from public.tenants t where t.tenant_id = p_tenant_id) is null then
    raise exception 'give consent first' using errcode = '42501';
  end if;
  if jsonb_typeof(p_changes) is distinct from 'array' or jsonb_array_length(p_changes) = 0 then
    raise exception 'changes are a list' using errcode = '22023';
  end if;
  if jsonb_array_length(p_changes) > 500 then
    raise exception 'at most 500 changes at a time' using errcode = '22023';
  end if;
  for v_item in select value from jsonb_array_elements(p_changes) loop
    v_entity := v_item ->> 'entity';
    v_id := v_item ->> 'id';
    v_version := case when jsonb_typeof(v_item -> 'version') = 'number' then (v_item ->> 'version')::integer end;
    v_data := case when jsonb_typeof(v_item -> 'data') = 'object' then v_item -> 'data' end;
    if v_entity is null or v_id is null or char_length(v_id) not between 1 and 100 or v_version is null or v_version < 1
        or coalesce(jsonb_typeof(v_item -> 'data'), 'missing') not in ('object', 'null') then
      raise exception 'a change needs its record type, id and version' using errcode = '22023';
    end if;
    if not v_entity = any (private.book_entities()) then
      raise exception 'unknown record type: %', v_entity using errcode = '22023';
    end if;
    if v_data ? 'tenant_id' and v_data ->> 'tenant_id' is distinct from p_tenant_id::text then
      raise exception 'a record of another company' using errcode = '42501';
    end if;
    if octet_length(v_data::text) > 500000 then
      raise exception 'a record is too big' using errcode = '22023';
    end if;
    insert into private.book_rows (tenant_id, entity, record_id, record_version, data, device_id)
      values (p_tenant_id, v_entity, v_id, v_version, v_data, p_device_id)
      on conflict (tenant_id, entity, record_id) do update
        set record_version = excluded.record_version, data = excluded.data, device_id = excluded.device_id, received_at_utc = now()
        where excluded.record_version >= private.book_rows.record_version;
  end loop;
  return jsonb_array_length(p_changes);
end $$;
revoke all on function public.push_book_changes(uuid, uuid, jsonb) from public, anon;
grant execute on function public.push_book_changes(uuid, uuid, jsonb) to authenticated;

-- A record's own time, kept by the app as Unix seconds.
create function private.book_time(p_data jsonb, p_key text) returns timestamptz
language sql immutable set search_path = '' as $$
  select case when jsonb_typeof(p_data -> p_key) = 'number' then to_timestamp((p_data ->> p_key)::bigint) end
$$;

-- A flag the app keeps as 1 or 0 in SQLite.
create function private.book_flag(p_data jsonb, p_key text) returns boolean
language sql immutable set search_path = '' as $$
  select coalesce(p_data ->> p_key, '1') in ('1', 'true')
$$;

-- One account's books for its page: the consent, when the books last arrived, counts, firsts, and every month.
create function public.admin_account_book(p_tenant uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_tenant public.tenants%rowtype;
begin
  perform private.require_admin();
  select * into v_tenant from public.tenants t where t.tenant_id = p_tenant;
  if not found then
    raise exception 'no such account' using errcode = '22023';
  end if;
  return jsonb_build_object(
    'consent_at', v_tenant.data_consent_at_utc,
    'consent_version', v_tenant.data_consent_version,
    'last_at', (select max(b.received_at_utc) from private.book_rows b where b.tenant_id = p_tenant),
    'records', (select count(*) from private.book_rows b where b.tenant_id = p_tenant and b.data is not null),
    'counts', (select jsonb_build_object(
        'workers', count(*) filter (where b.entity = 'workers' and private.book_flag(b.data, 'active')),
        'clients', count(*) filter (where b.entity = 'clients' and private.book_flag(b.data, 'active')),
        'sites', count(*) filter (where b.entity = 'sites' and private.book_flag(b.data, 'active')),
        'invoices', count(*) filter (where b.entity = 'invoices' and b.data ->> 'kind' = 'invoice' and b.data ->> 'status' in ('issued', 'credited')))
      from private.book_rows b where b.tenant_id = p_tenant and b.data is not null),
    'firsts', (select jsonb_build_object(
        'worker', min(private.book_time(b.data, 'created_at_utc')) filter (where b.entity = 'workers'),
        'attendance', min(private.book_time(b.data, 'created_at_utc')) filter (where b.entity = 'attendance_entries'),
        'invoice', min(private.book_time(b.data, 'created_at_utc')) filter (where b.entity = 'invoices' and b.data ->> 'status' in ('issued', 'credited')))
      from private.book_rows b where b.tenant_id = p_tenant and b.data is not null),
    'months', coalesce((select jsonb_agg(b.data order by b.record_id)
      from private.book_rows b where b.tenant_id = p_tenant and b.entity = 'month_summary' and b.data is not null), '[]'::jsonb)
  );
end $$;

-- One record type of one account's books, live records newest first, for the Kitab tab.
-- ponytail: all of them at once; page here when one company's attendance passes about 50,000 days.
create function public.admin_book(p_tenant uuid, p_entity text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  if p_entity is null or not p_entity = any (private.book_entities()) then
    raise exception 'unknown record type: %', p_entity using errcode = '22023';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', b.record_id, 'version', b.record_version, 'at', b.received_at_utc, 'data', b.data)
      order by b.received_at_utc desc, b.record_id)
    from private.book_rows b where b.tenant_id = p_tenant and b.entity = p_entity and b.data is not null), '[]'::jsonb);
end $$;

-- A month summary's figure, 0 when the app sent none.
create function private.fig(p_data jsonb, p_key text) returns bigint
language sql immutable set search_path = '' as $$
  select coalesce((p_data ->> p_key)::bigint, 0)
$$;

-- Every account's books added up for months [p_from, p_to] ('YYYY-MM'): the sheet's lines by month, each account's
-- total, and live labour and companies now. Only what the app worked out is added; nothing is worked out here.
create function public.admin_business(p_from text, p_to text, p_include_test boolean) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  if p_from !~ '^\d{4}-\d{2}$' or p_to !~ '^\d{4}-\d{2}$' then
    raise exception 'months are YYYY-MM' using errcode = '22023';
  end if;
  return (with t as (select * from public.tenants t where p_include_test or not t.is_test),
  m as (
    select b.tenant_id, b.record_id as month, b.data from private.book_rows b join t on t.tenant_id = b.tenant_id
    where b.entity = 'month_summary' and b.data is not null and b.record_id between p_from and p_to
  ),
  live as (
    select b.tenant_id,
      count(*) filter (where b.entity = 'workers' and private.book_flag(b.data, 'active')) as workers,
      count(*) filter (where b.entity = 'clients' and private.book_flag(b.data, 'active')) as clients,
      max(b.received_at_utc) as last_at
    from private.book_rows b join t on t.tenant_id = b.tenant_id where b.data is not null group by b.tenant_id
  )
  select jsonb_build_object(
    'months', coalesce((select jsonb_agg(x order by x ->> 'month') from (
      select jsonb_build_object('month', m.month, 'accounts', count(distinct m.tenant_id),
        'bill', sum(private.fig(m.data, 'bill')), 'wages', sum(private.fig(m.data, 'wages')),
        'salaries', sum(private.fig(m.data, 'salaries')), 'allowances', sum(private.fig(m.data, 'allowances')),
        'cuts', sum(private.fig(m.data, 'cuts')), 'room_in', sum(private.fig(m.data, 'room_in')),
        'room_out', sum(private.fig(m.data, 'room_out')), 'expenses', sum(private.fig(m.data, 'expenses')),
        'estimate', sum(private.fig(m.data, 'estimate')), 'days', sum(private.fig(m.data, 'days')),
        'invoices', sum(private.fig(m.data, 'invoices')), 'invoiced', sum(private.fig(m.data, 'invoiced')),
        'credited', sum(private.fig(m.data, 'credited'))) as x
      from m group by m.month) months), '[]'::jsonb),
    'accounts', coalesce((select jsonb_agg(a order by (a ->> 'bill')::bigint desc) from (
      select jsonb_build_object('tenant_id', t.tenant_id, 'name', t.name,
        'bill', coalesce(sum(private.fig(m.data, 'bill')), 0), 'wages', coalesce(sum(private.fig(m.data, 'wages')), 0),
        'estimate', coalesce(sum(private.fig(m.data, 'estimate')), 0), 'invoiced', coalesce(sum(private.fig(m.data, 'invoiced')), 0),
        'workers', coalesce(max(live.workers), 0), 'clients', coalesce(max(live.clients), 0), 'last_at', max(live.last_at)) as a
      from t join live on live.tenant_id = t.tenant_id left join m on m.tenant_id = t.tenant_id
      group by t.tenant_id, t.name) accounts), '[]'::jsonb),
    'workers', (select coalesce(sum(live.workers), 0) from live),
    'clients', (select coalesce(sum(live.clients), 0) from live),
    'with_books', (select count(*) from live),
    'consented', (select count(*) from t where t.data_consent_at_utc is not null),
    'accounts_total', (select count(*) from t)
  ));
end $$;

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array['public.admin_account_book(uuid)', 'public.admin_book(uuid, text)', 'public.admin_business(text, text, boolean)'] loop
    execute format('revoke all on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;
end $$;
revoke all on function private.book_entities(), private.book_time(jsonb, text), private.book_flag(jsonb, text), private.fig(jsonb, text) from public;

-- Each account's row gains its consent, when its books last arrived, and this Dubai month's bill and estimate.
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
  use_report as (select * from private.usage_reports r where r.tenant_id = p_tenant),
  month as (
    select b.data from private.book_rows b where b.tenant_id = p_tenant and b.entity = 'month_summary'
      and b.record_id = to_char(now() at time zone 'Asia/Dubai', 'YYYY-MM') and b.data is not null
  )
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
      - (select coalesce(sum(m.amount_fils), 0) from private.money_entries m where m.tenant_id = p_tenant and m.kind = 'refund'),
    'consent_at', t.data_consent_at_utc,
    'book_at', (select max(b.received_at_utc) from private.book_rows b where b.tenant_id = p_tenant),
    'bill_month', (select private.fig(data, 'bill') from month),
    'estimate_month', (select private.fig(data, 'estimate') from month))
  from t;
$$;
