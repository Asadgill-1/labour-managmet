-- T19c: a user deletes their own account from the app (AUTH-07, D-066). Each company the account owns goes with it,
-- with that company's members and devices, then the sign-in itself, so nothing personal is kept. A manager's
-- account takes only its own membership and devices; the company stays.
create function public.delete_account() returns void
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
  delete from public.devices d where d.tenant_id = any (v_owned) or d.user_id = v_user;
  delete from public.memberships m where m.tenant_id = any (v_owned) or m.user_id = v_user;
  delete from public.tenants t where t.tenant_id = any (v_owned);
  delete from auth.users u where u.id = v_user;
end $$;
revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
