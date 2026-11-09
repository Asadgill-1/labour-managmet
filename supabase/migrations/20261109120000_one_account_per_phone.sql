-- T19b: a phone serves one account (D-063), so no company's data is left hidden on it under another account. The app
-- sends the phone's own id, which a reinstall keeps, so the phone is known again. A phone is held by the member whose
-- live device row carries its id; the company turning the phone off, or the member leaving, frees it.

-- The masked email of the account another user holds this phone with, or null. Callable before signing in, so the app
-- refuses a second signup before any email goes out. The id is random, so it cannot be guessed to find accounts.
create function public.phone_account(p_device_id uuid) returns text
language sql stable security definer set search_path = '' as $$
  select regexp_replace(u.email, '^(.{1,2})[^@]*(@.*)$', '\1***\2')
  from public.devices d
  join public.memberships m on m.tenant_id = d.tenant_id and m.user_id = d.user_id and m.revoked_at_utc is null
  join auth.users u on u.id = d.user_id
  where d.device_id = p_device_id and d.revoked_at_utc is null and d.user_id is distinct from (select auth.uid())
  limit 1
$$;
revoke all on function public.phone_account(uuid) from public;
grant execute on function public.phone_account(uuid) to anon, authenticated;

-- As before (T19a), and a phone another account holds is refused. Replacing it keeps its grants.
create or replace function public.register_device(p_tenant_id uuid, p_device_id uuid, p_label text, p_platform text, p_operation_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_row public.devices%rowtype;
begin
  if v_user is null or private.member_role(p_tenant_id) is null then
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
  if v_row.revoked_at_utc is not null then
    raise exception 'this device was revoked' using errcode = '42501';
  end if;
  update public.devices set last_seen_at_utc = now(), updated_at_utc = now(), version = version + 1, source_operation_id = p_operation_id
    where id = v_row.id;
  return v_row.id;
end $$;
