-- T20c: the owner turns an old phone off from the new one, free (DATA-06, D-072, D-073). The old phone asks at start
-- whether it is off, and if so removes the company from itself. The owner's own password, typed on that phone again,
-- turns it back on.

-- Turns one of the company's phones off. The owner may turn off any of the company's phones, a member only their own.
-- A phone already off stays as it was, so a retry changes nothing (MODEL-06).
create function public.turn_phone_off(p_device_row uuid, p_operation_id uuid) returns void
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
  if v_row.revoked_at_utc is null then
    update public.devices
      set revoked_at_utc = now(), updated_at_utc = now(), version = version + 1, actor_id = v_user, source_operation_id = p_operation_id
      where id = v_row.id;
  end if;
end $$;
revoke all on function public.turn_phone_off(uuid, uuid) from public, anon;
grant execute on function public.turn_phone_off(uuid, uuid) to authenticated;

-- Whether the company turned this phone off. The phone asks at start, before anyone signs in, with the two ids it keeps;
-- both are random, so they cannot be guessed, and the answer is only yes or no.
create function public.phone_is_off(p_tenant_id uuid, p_device_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.devices d where d.tenant_id = p_tenant_id and d.device_id = p_device_id and d.revoked_at_utc is not null)
    and not exists (select 1 from public.devices d where d.tenant_id = p_tenant_id and d.device_id = p_device_id and d.revoked_at_utc is null)
$$;
revoke all on function public.phone_is_off(uuid, uuid) from public;
grant execute on function public.phone_is_off(uuid, uuid) to anon, authenticated;

-- As before (T19b), with two changes. The phone's name is kept fresh, so the owner can tell phones apart. And the owner
-- signing in again on a phone the company turned off turns it back on: the password is the owner's authorization, and
-- the phone removed the company when it was told. A manager's phone stays off. Replacing it keeps its grants.
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
  update public.devices
    set revoked_at_utc = null, label = btrim(p_label), last_seen_at_utc = now(), updated_at_utc = now(), version = version + 1,
      actor_id = v_user, source_operation_id = p_operation_id
    where id = v_row.id;
  return v_row.id;
end $$;
