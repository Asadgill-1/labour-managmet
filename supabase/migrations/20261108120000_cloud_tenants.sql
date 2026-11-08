-- T19a: the first cloud control tables: companies (tenants), who belongs to each, and their devices (MODEL-02).
-- A signed-in user reads only rows of a company they belong to (AUTH-05). Every write goes through a server function
-- that takes the user from the verified session, never from the request (AUTH-02, MODEL-05).

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- One row per company. Its id is the tenant id every local and cloud row carries, made here and never changed.
create table public.tenants (
  tenant_id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 200),
  created_by uuid not null references auth.users (id),
  created_at_utc timestamptz not null default now(),
  updated_at_utc timestamptz not null default now(),
  version integer not null default 1,
  source_operation_id uuid not null unique
);

-- Who belongs to a company, and as what. Revoked, a row stays as the record.
create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (tenant_id),
  user_id uuid not null references auth.users (id),
  role text not null check (role in ('owner', 'manager')),
  revoked_at_utc timestamptz,
  created_at_utc timestamptz not null default now(),
  updated_at_utc timestamptz not null default now(),
  actor_id uuid not null,
  version integer not null default 1,
  source_operation_id uuid not null,
  unique (tenant_id, user_id)
);
create unique index one_owner_per_tenant on public.memberships (tenant_id) where role = 'owner' and revoked_at_utc is null;

-- A phone or computer a member signed in on, by the id the app made for it (AUTH-03).
create table public.devices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  user_id uuid not null,
  device_id uuid not null,
  label text not null check (char_length(btrim(label)) between 1 and 100),
  platform text not null check (platform in ('android', 'ios', 'windows', 'web')),
  revoked_at_utc timestamptz,
  last_seen_at_utc timestamptz not null default now(),
  created_at_utc timestamptz not null default now(),
  updated_at_utc timestamptz not null default now(),
  actor_id uuid not null,
  version integer not null default 1,
  source_operation_id uuid not null,
  unique (tenant_id, user_id, device_id),
  foreign key (tenant_id, user_id) references public.memberships (tenant_id, user_id)
);

-- A company's id and maker never change (AUTH-02).
create function private.tenant_keeps_identity() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.tenant_id <> old.tenant_id or new.created_by <> old.created_by then
    raise exception 'a tenant keeps its id and maker' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger tenants_keep_identity before update on public.tenants for each row execute function private.tenant_keeps_identity();

-- The signed-in user's live role in a company, or null. Policies use it, so it must not read through them.
create function private.member_role(p_tenant uuid) returns text
language sql stable security definer set search_path = '' as $$
  select m.role from public.memberships m
  where m.tenant_id = p_tenant and m.user_id = (select auth.uid()) and m.revoked_at_utc is null
$$;
revoke all on function private.member_role(uuid) from public;
grant execute on function private.member_role(uuid) to authenticated;

-- Supabase grants every new public table to its API roles; these tables are read-only to members and closed to others.
revoke all on public.tenants, public.memberships, public.devices from anon, authenticated;
grant select on public.tenants, public.memberships, public.devices to authenticated;

alter table public.tenants enable row level security;
alter table public.memberships enable row level security;
alter table public.devices enable row level security;

create policy tenants_for_members on public.tenants for select to authenticated
  using (private.member_role(tenant_id) is not null);
-- A member sees their own membership and devices; the owner sees the whole company's.
create policy memberships_own_or_owner on public.memberships for select to authenticated
  using (user_id = (select auth.uid()) or private.member_role(tenant_id) = 'owner');
create policy devices_own_or_owner on public.devices for select to authenticated
  using (user_id = (select auth.uid()) or private.member_role(tenant_id) = 'owner');

-- Makes a company for the signed-in user, who becomes its owner (UX-02). Only after the email is verified (AUTH-01).
-- [p_tenant_id] is the id the phone's data already carries, so it keeps working; an id in use is refused, and with
-- none the server makes one. A retry with the same operation id returns the company it made (MODEL-06).
create function public.create_tenant(p_name text, p_operation_id uuid, p_tenant_id uuid default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_tenant uuid;
begin
  if v_user is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if not exists (select 1 from auth.users u where u.id = v_user and u.email_confirmed_at is not null) then
    raise exception 'verify the email first' using errcode = '42501';
  end if;
  select t.tenant_id into v_tenant from public.tenants t where t.source_operation_id = p_operation_id;
  if found then
    if not exists (select 1 from public.memberships m where m.tenant_id = v_tenant and m.user_id = v_user) then
      raise exception 'operation id already used' using errcode = '23505';
    end if;
    return v_tenant;
  end if;
  insert into public.tenants (tenant_id, name, created_by, source_operation_id)
    values (coalesce(p_tenant_id, gen_random_uuid()), btrim(p_name), v_user, p_operation_id)
    returning tenant_id into v_tenant;
  insert into public.memberships (tenant_id, user_id, role, actor_id, source_operation_id)
    values (v_tenant, v_user, 'owner', v_user, p_operation_id);
  return v_tenant;
end $$;
revoke all on function public.create_tenant(text, uuid, uuid) from public, anon;
grant execute on function public.create_tenant(text, uuid, uuid) to authenticated;

-- Records the device a member signed in on, or marks it seen again; returns its row id (AUTH-03). A member of another
-- company, or a revoked member or device, is refused.
create function public.register_device(p_tenant_id uuid, p_device_id uuid, p_label text, p_platform text, p_operation_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_row public.devices%rowtype;
begin
  if v_user is null or private.member_role(p_tenant_id) is null then
    raise exception 'not a member of this company' using errcode = '42501';
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
revoke all on function public.register_device(uuid, uuid, text, text, uuid) from public, anon;
grant execute on function public.register_device(uuid, uuid, text, text, uuid) to authenticated;
