-- MProgress · F10 (docs/PLAN_F10.md): cuentas, nube y cifrado de extremo a extremo.
-- Supabase solo guarda sobres cifrados: id, espacio, tipo y fechas en claro; el resto va en `payload` (AES-GCM).
-- Las tablas con columnas en claro de 20261106000000_init.sql se dejan sin uso (no se borran).
-- Se puede correr más de una vez.

-- Llave pública de cada dispositivo (X25519, 32 bytes en base64). La privada nunca sale del teléfono.

alter table public.devices
  add column if not exists public_key text,
  add column if not exists created_at timestamptz not null default now();

do $$ begin
  alter table public.devices add constraint devices_public_key_check
    check (public_key is null or char_length(public_key) between 40 and 100);
exception when duplicate_object then null;
end $$;

comment on column public.devices.public_key is 'X25519 pública en base64. Con ella otro dispositivo de la cuenta le envuelve la llave del espacio';

-- ¿El dispositivo es de alguien que está en el espacio? Para que nadie envuelva llaves para extraños.

create or replace function public.device_in_space(p_device uuid, p_space uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.devices d
    join public.space_members m on m.user_id = d.user_id
    where d.id = p_device and m.space_id = p_space
  );
$$;

revoke all on function public.device_in_space(uuid, uuid) from public, anon;
grant execute on function public.device_in_space(uuid, uuid) to authenticated;

-- Sobres cifrados

create table if not exists public.sync_records (
  id uuid primary key,
  space_id uuid not null references public.spaces (id) on delete cascade,
  entity text not null check (entity ~ '^[a-z_]{1,40}$'),
  payload text not null check (char_length(payload) between 1 and 200000),
  -- Cuándo cambió en el teléfono: decide quién gana si el mismo registro cambió en dos lados.
  changed_at timestamptz not null default now(),
  -- Cuándo llegó al servidor: lo pone el servidor y sirve de cursor para bajar cambios.
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  updated_by uuid references public.profiles (id) on delete set null
);

create index if not exists sync_records_pull_idx on public.sync_records (space_id, entity, updated_at);
create index if not exists sync_records_updated_idx on public.sync_records (updated_at);

comment on table public.sync_records is 'Registros cifrados de extremo a extremo. payload = base64(AES-GCM(JSON)) con datos asociados space_id|entity|id';

create or replace function public.sync_records_stamp()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    -- Gana el cambio más nuevo: si llega uno más viejo que el guardado, no se toca la fila.
    if new.changed_at < old.changed_at then
      return null;
    end if;
    new.space_id = old.space_id;
  end if;
  new.updated_at = clock_timestamp();
  new.updated_by = (select auth.uid());
  return new;
end;
$$;

drop trigger if exists sync_records_stamp on public.sync_records;
create trigger sync_records_stamp
before insert or update on public.sync_records
for each row execute function public.sync_records_stamp();

alter table public.sync_records enable row level security;

drop policy if exists sync_records_select on public.sync_records;
create policy sync_records_select on public.sync_records for select to authenticated
using (public.is_member(space_id));

drop policy if exists sync_records_insert on public.sync_records;
create policy sync_records_insert on public.sync_records for insert to authenticated
with check (public.can_write(space_id));

drop policy if exists sync_records_update on public.sync_records;
create policy sync_records_update on public.sync_records for update to authenticated
using (public.can_write(space_id))
with check (public.can_write(space_id));

-- Sin política de borrado: se borra con deleted_at (y en cascada al borrar el espacio o la cuenta).

-- Llaves de espacio envueltas: una por dispositivo y una de recuperación (device_id null).

create table if not exists public.space_keys (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  device_id uuid references public.devices (id) on delete cascade,
  wrapped_key text not null check (char_length(wrapped_key) between 40 and 1000),
  created_by uuid references public.profiles (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create unique index if not exists space_keys_space_device_uidx on public.space_keys (space_id, device_id) nulls not distinct;

comment on column public.space_keys.device_id is 'null = llave envuelta con el código de recuperación';

alter table public.space_keys enable row level security;

drop policy if exists space_keys_select on public.space_keys;
create policy space_keys_select on public.space_keys for select to authenticated
using (public.is_member(space_id));

drop policy if exists space_keys_insert on public.space_keys;
create policy space_keys_insert on public.space_keys for insert to authenticated
with check (
  public.can_write(space_id)
  and (device_id is null or public.device_in_space(device_id, space_id))
);

drop policy if exists space_keys_update on public.space_keys;
create policy space_keys_update on public.space_keys for update to authenticated
using (public.can_write(space_id))
with check (
  public.can_write(space_id)
  and (device_id is null or public.device_in_space(device_id, space_id))
);

drop policy if exists space_keys_delete on public.space_keys;
create policy space_keys_delete on public.space_keys for delete to authenticated
using (public.can_write(space_id));

-- Borrar cuenta y datos: borra el usuario de auth; perfil, espacios propios, sobres, llaves y dispositivos
-- se van en cascada. Los espacios de otros (F11) solo pierden a este miembro.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'Necesitas iniciar sesión';
  end if;
  delete from public.spaces where owner_id = v_user;
  delete from public.devices where user_id = v_user;
  delete from auth.users where id = v_user;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
