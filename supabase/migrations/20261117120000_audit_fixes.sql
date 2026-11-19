-- Audit fixes (BUG-023, BUG-024, BUG-026; review 01 F01-1, F01-4, F01-6). Turning a phone off, and the owner turning
-- an old phone back on, now need the password typed in the last ten minutes, checked by the cloud as account deletion
-- does (D-066, D-073), so a session kept on a lost phone cannot do either. Accepting a slip locks the company, so two
-- slips accepted at once do not start from the same day. Each function is replaced with its grants kept.

-- As before (T20c), and only with the password typed again in the last ten minutes. The app asks for it when the
-- cloud says so.
create or replace function public.turn_phone_off(p_device_row uuid, p_operation_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_row public.devices%rowtype;
begin
  select * into v_row from public.devices d where d.id = p_device_row;
  if v_user is null or not found
    or (v_row.user_id <> v_user and private.member_role(v_row.tenant_id) is distinct from 'owner') then
    raise exception 'not a phone of yours' using errcode = '42501';
  end if;
  -- The password typed again in the last ten minutes, so a session kept on a lost phone cannot turn the others off.
  if not exists (
    select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
    where a ->> 'method' = 'password' and (a ->> 'timestamp')::bigint > extract(epoch from now())::bigint - 600
  ) then
    raise exception 'type the password again' using errcode = '42501';
  end if;
  if v_row.revoked_at_utc is null then
    update public.devices
      set revoked_at_utc = now(), updated_at_utc = now(), version = version + 1, actor_id = v_user, source_operation_id = p_operation_id
      where id = v_row.id;
  end if;
end $$;

-- As before (T20c), and turning an owner's phone back on needs the password typed in the last ten minutes, as D-073
-- says. A first sign-in on a phone, and a phone that is on, are as before.
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

-- As before (T20d-a), and the company's row is locked once the slip is read, so a second slip of the same company
-- accepted at the same time waits, then continues from the period this one makes (BILL-04).
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
