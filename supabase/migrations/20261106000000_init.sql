-- MProgress · migración inicial
-- Montos en enteros de la unidad mínima de la moneda (centavos). Nunca float.
-- Los ids los genera el cliente (uuid) para poder crear registros sin conexión.
-- Toda tabla lleva updated_at y deleted_at (borrado suave) para la sincronización.

create extension if not exists pgcrypto;

-- Tipos

create type public.space_kind as enum ('personal', 'pareja', 'familia', 'trabajo', 'viaje');
create type public.member_role as enum ('admin', 'miembro', 'lectura');
create type public.product_kind as enum ('cuenta', 'debito', 'credito', 'bolsillo', 'efectivo');
create type public.entry_kind as enum ('gasto', 'ingreso');
create type public.cycle_kind as enum ('puntual', 'semanal', 'mensual', 'anual', 'otra');
create type public.pay_method as enum ('wallet', 'fisica', 'en_linea', 'efectivo', 'transferencia');
create type public.entry_source as enum ('manual', 'wallet', 'sms', 'recibo', 'importacion', 'asistente');
create type public.remind_target as enum ('todos', 'persona', 'responsable');
create type public.device_platform as enum ('ios', 'ipados', 'macos', 'watchos', 'android', 'wearos', 'windows');

-- Utilidades

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Perfiles

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  currency char(3) not null default 'COP',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Espacios (cuentas personales y compartidas)

create table public.spaces (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  kind public.space_kind not null default 'personal',
  currency char(3) not null default 'COP',
  color text not null default '#ff6b2c',
  icon text,
  share_totals_only boolean not null default false,
  default_split smallint not null default 50 check (default_split between 0 and 100),
  ends_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.space_members (
  space_id uuid not null references public.spaces (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.member_role not null default 'miembro',
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (space_id, user_id)
);

create index space_members_user_idx on public.space_members (user_id);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  code text not null unique check (code ~ '^MP-[A-Z0-9]{4}$'),
  role public.member_role not null default 'miembro',
  created_by uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz not null default now() + interval '7 days',
  used_by uuid references public.profiles (id) on delete set null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

-- Funciones de acceso. security definer para no caer en recursión de RLS.

create or replace function public.is_member(p_space uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.space_members
    where space_id = p_space and user_id = (select auth.uid())
  );
$$;

create or replace function public.can_write(p_space uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.space_members
    where space_id = p_space
      and user_id = (select auth.uid())
      and role in ('admin', 'miembro')
  );
$$;

create or replace function public.is_admin(p_space uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.space_members
    where space_id = p_space
      and user_id = (select auth.uid())
      and role = 'admin'
  );
$$;

-- Catálogos

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  space_id uuid references public.spaces (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  icon text not null default 'square.grid.2x2',
  color text,
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on column public.categories.space_id is 'null = categoría global de la app, visible para todos';

-- Bancos, tarjetas y bolsillos

create table public.institutions (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  color text,
  icon text,
  hidden boolean not null default false,
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  institution_id uuid not null references public.institutions (id) on delete cascade,
  parent_product_id uuid references public.products (id) on delete set null,
  kind public.product_kind not null,
  name text not null check (char_length(name) between 1 and 40),
  last4 char(4) check (last4 ~ '^[0-9]{4}$'),
  balance bigint not null default 0,
  balance_at timestamptz not null default now(),
  credit_limit bigint check (credit_limit is null or credit_limit >= 0),
  cut_day smallint check (cut_day between 1 and 31),
  due_day smallint check (due_day between 1 and 31),
  rate_ea numeric(6, 3) check (rate_ea is null or rate_ea >= 0),
  locked_until date,
  in_wallet boolean not null default false,
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on column public.products.last4 is 'Solo los últimos 4 dígitos. Nunca el número completo.';
comment on column public.products.balance is 'Saldo de referencia en balance_at. Cuentas y bolsillos: lo que hay. Crédito: deuda (positiva). El saldo actual suma los movimientos posteriores a balance_at.';

create index products_institution_idx on public.products (institution_id);
create index products_space_idx on public.products (space_id);

-- Pagos fijos (plantillas recurrentes)

create table public.recurring (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  kind public.entry_kind not null default 'gasto',
  name text not null check (char_length(name) between 1 and 60),
  icon text,
  amount bigint not null check (amount > 0),
  cycle public.cycle_kind not null default 'mensual',
  interval_days smallint check (interval_days is null or interval_days > 0),
  next_date date not null,
  category_id uuid references public.categories (id) on delete set null,
  product_id uuid references public.products (id) on delete set null,
  responsible_id uuid references public.profiles (id) on delete set null,
  active boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (cycle <> 'otra' or interval_days is not null)
);

create index recurring_space_next_idx on public.recurring (space_id, next_date);

-- Movimientos reales

create table public.entries (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  kind public.entry_kind not null,
  amount bigint not null check (amount > 0),
  occurred_at timestamptz not null default now(),
  name text not null check (char_length(name) between 1 and 60),
  merchant text,
  icon text,
  category_id uuid references public.categories (id) on delete set null,
  product_id uuid references public.products (id) on delete set null,
  recurring_id uuid references public.recurring (id) on delete set null,
  paid_by uuid references public.profiles (id) on delete set null,
  method public.pay_method,
  source public.entry_source not null default 'manual',
  needs_review boolean not null default false,
  notes text check (notes is null or char_length(notes) <= 500),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index entries_space_date_idx on public.entries (space_id, occurred_at desc);
create index entries_product_idx on public.entries (product_id);

create table public.splits (
  entry_id uuid not null references public.entries (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  amount bigint not null check (amount >= 0),
  updated_at timestamptz not null default now(),
  primary key (entry_id, user_id)
);

create table public.transfers (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  from_product_id uuid not null references public.products (id) on delete cascade,
  to_product_id uuid not null references public.products (id) on delete cascade,
  amount bigint not null check (amount > 0),
  occurred_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (from_product_id <> to_product_id)
);

-- Avisos

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  recurring_id uuid not null references public.recurring (id) on delete cascade,
  days_before smallint not null default 3 check (days_before between 0 and 14),
  target public.remind_target not null default 'todos',
  user_id uuid references public.profiles (id) on delete cascade,
  at_time time not null default '09:00',
  notify_partner_on_paid boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (target <> 'persona' or user_id is not null)
);

-- Límites y ahorro

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  category_id uuid references public.categories (id) on delete cascade,
  monthly_limit bigint not null check (monthly_limit > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on column public.budgets.category_id is 'null = límite total del mes';

create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  target_amount bigint not null check (target_amount > 0),
  target_date date,
  product_id uuid references public.products (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.goal_contributions (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.savings_goals (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  amount bigint not null check (amount <> 0),
  occurred_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Dispositivos para push

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform public.device_platform not null,
  name text,
  push_token text,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, push_token)
);

-- Plantillas para leer SMS de bancos (solo lectura para usuarios)

create table public.detection_rules (
  id uuid primary key default gen_random_uuid(),
  institution_name text not null,
  sender text,
  pattern text not null,
  sample text,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Disparadores de updated_at

do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'spaces', 'space_members', 'categories', 'institutions', 'products',
    'recurring', 'entries', 'splits', 'transfers', 'reminders', 'budgets',
    'savings_goals', 'goal_contributions', 'devices', 'detection_rules'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_updated_at', t
    );
  end loop;
end;
$$;

-- Al crear un usuario: perfil y espacio Personal

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''));

  insert into public.spaces (owner_id, name, kind)
  values (new.id, 'Personal', 'personal');

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Al crear un espacio: el dueño entra como admin

create or replace function public.handle_new_space()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.space_members (space_id, user_id, role)
  values (new.id, new.owner_id, 'admin')
  on conflict do nothing;
  return new;
end;
$$;

create trigger on_space_created
after insert on public.spaces
for each row execute function public.handle_new_space();

-- Aceptar una invitación por código

create or replace function public.accept_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.invites%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'Necesitas iniciar sesión';
  end if;

  select * into v_invite
  from public.invites
  where code = upper(p_code)
    and used_at is null
    and expires_at > now()
  for update;

  if not found then
    raise exception 'El código no existe o ya venció';
  end if;

  insert into public.space_members (space_id, user_id, role)
  values (v_invite.space_id, (select auth.uid()), v_invite.role)
  on conflict (space_id, user_id) do nothing;

  update public.invites
  set used_by = (select auth.uid()), used_at = now()
  where id = v_invite.id;

  return v_invite.space_id;
end;
$$;

revoke all on function public.accept_invite(text) from public, anon;
grant execute on function public.accept_invite(text) to authenticated;

-- Seguridad por fila

alter table public.profiles enable row level security;
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.invites enable row level security;
alter table public.categories enable row level security;
alter table public.institutions enable row level security;
alter table public.products enable row level security;
alter table public.recurring enable row level security;
alter table public.entries enable row level security;
alter table public.splits enable row level security;
alter table public.transfers enable row level security;
alter table public.reminders enable row level security;
alter table public.budgets enable row level security;
alter table public.savings_goals enable row level security;
alter table public.goal_contributions enable row level security;
alter table public.devices enable row level security;
alter table public.detection_rules enable row level security;

-- Perfiles: el propio y los de quienes comparten un espacio contigo

create policy profiles_select on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or exists (
    select 1
    from public.space_members a
    join public.space_members b on a.space_id = b.space_id
    where a.user_id = (select auth.uid()) and b.user_id = profiles.id
  )
);

create policy profiles_update on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Espacios

create policy spaces_select on public.spaces for select to authenticated
using (public.is_member(id) or owner_id = (select auth.uid()));

create policy spaces_insert on public.spaces for insert to authenticated
with check (owner_id = (select auth.uid()));

create policy spaces_update on public.spaces for update to authenticated
using (public.is_admin(id))
with check (public.is_admin(id));

create policy spaces_delete on public.spaces for delete to authenticated
using (owner_id = (select auth.uid()));

-- Miembros: los ves si estás en el espacio; el admin gestiona; cada uno puede salirse

create policy members_select on public.space_members for select to authenticated
using (public.is_member(space_id));

create policy members_insert on public.space_members for insert to authenticated
with check (public.is_admin(space_id));

create policy members_update on public.space_members for update to authenticated
using (public.is_admin(space_id))
with check (public.is_admin(space_id));

create policy members_delete on public.space_members for delete to authenticated
using (public.is_admin(space_id) or user_id = (select auth.uid()));

-- Invitaciones: solo el admin las ve y crea; se aceptan con accept_invite

create policy invites_select on public.invites for select to authenticated
using (public.is_admin(space_id));

create policy invites_insert on public.invites for insert to authenticated
with check (public.is_admin(space_id) and created_by = (select auth.uid()));

create policy invites_delete on public.invites for delete to authenticated
using (public.is_admin(space_id));

-- Categorías: las globales las ve cualquiera; las del espacio, sus miembros

create policy categories_select on public.categories for select to authenticated
using (space_id is null or public.is_member(space_id));

create policy categories_insert on public.categories for insert to authenticated
with check (space_id is not null and public.can_write(space_id));

create policy categories_update on public.categories for update to authenticated
using (space_id is not null and public.can_write(space_id))
with check (space_id is not null and public.can_write(space_id));

create policy categories_delete on public.categories for delete to authenticated
using (space_id is not null and public.can_write(space_id));

-- Tablas con space_id: leer si eres miembro, escribir si no eres solo lectura

do $$
declare t text;
begin
  foreach t in array array[
    'institutions', 'products', 'recurring', 'entries', 'transfers', 'budgets', 'savings_goals'
  ] loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (public.is_member(space_id))',
      t || '_select', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (public.can_write(space_id))',
      t || '_insert', t);
    execute format(
      'create policy %I on public.%I for update to authenticated using (public.can_write(space_id)) with check (public.can_write(space_id))',
      t || '_update', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated using (public.can_write(space_id))',
      t || '_delete', t);
  end loop;
end;
$$;

-- Tablas hijas: heredan el acceso de su padre

create policy splits_select on public.splits for select to authenticated
using (exists (select 1 from public.entries e where e.id = entry_id and public.is_member(e.space_id)));

create policy splits_write on public.splits for all to authenticated
using (exists (select 1 from public.entries e where e.id = entry_id and public.can_write(e.space_id)))
with check (exists (select 1 from public.entries e where e.id = entry_id and public.can_write(e.space_id)));

create policy reminders_select on public.reminders for select to authenticated
using (exists (select 1 from public.recurring r where r.id = recurring_id and public.is_member(r.space_id)));

create policy reminders_write on public.reminders for all to authenticated
using (exists (select 1 from public.recurring r where r.id = recurring_id and public.can_write(r.space_id)))
with check (exists (select 1 from public.recurring r where r.id = recurring_id and public.can_write(r.space_id)));

create policy contributions_select on public.goal_contributions for select to authenticated
using (exists (select 1 from public.savings_goals g where g.id = goal_id and public.is_member(g.space_id)));

create policy contributions_write on public.goal_contributions for all to authenticated
using (exists (select 1 from public.savings_goals g where g.id = goal_id and public.can_write(g.space_id)))
with check (exists (select 1 from public.savings_goals g where g.id = goal_id and public.can_write(g.space_id)));

-- Dispositivos: solo los tuyos

create policy devices_own on public.devices for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- Plantillas de SMS: solo lectura

create policy detection_rules_select on public.detection_rules for select to authenticated
using (active);

-- Tiempo real para lo compartido

alter publication supabase_realtime add table
  public.entries, public.splits, public.recurring, public.reminders,
  public.transfers, public.savings_goals, public.goal_contributions,
  public.space_members;

-- Categorías globales

insert into public.categories (space_id, name, icon, sort) values
  (null, 'Entretenimiento', 'play.rectangle', 1),
  (null, 'Música', 'music.note', 2),
  (null, 'Productividad', 'briefcase', 3),
  (null, 'Servicios', 'wrench.and.screwdriver', 4),
  (null, 'Renta', 'house', 5),
  (null, 'Mercado', 'cart', 6),
  (null, 'Transporte', 'car', 7),
  (null, 'Salidas', 'fork.knife', 8),
  (null, 'Deporte', 'dumbbell', 9),
  (null, 'Salud', 'cross.case', 10),
  (null, 'Educación', 'graduationcap', 11),
  (null, 'Social', 'person.2', 12),
  (null, 'Negocios', 'building.2', 13),
  (null, 'Finanzas', 'banknote', 14),
  (null, 'Otros', 'square.grid.2x2', 99);
