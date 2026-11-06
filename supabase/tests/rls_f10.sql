-- Prueba de seguridad por fila de F10 (sync_records, space_keys, devices.public_key, delete_my_account).
-- Se corre en una base local con las tres migraciones, nunca en producción.
-- Espera: Dana solo ve y escribe lo suyo; Elías (otro usuario) no ve ni escribe nada de Dana.
grant all on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
insert into auth.users values
  ('00000000-0000-0000-0000-0000000000d1', '{"name":"Dana"}'),
  ('00000000-0000-0000-0000-0000000000e1', '{"name":"Elías"}');

-- Dana: su espacio Personal lo creó el servidor al crear la cuenta.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000d1', false);
select 'esperado 1 espacio', count(*) from spaces;
insert into devices (id, user_id, platform, name, public_key) values
  ('dddddddd-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000d1', 'ios', 'iPhone de Dana',
   'QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUE=');
insert into space_keys (space_id, device_id, wrapped_key)
select id, 'dddddddd-0000-0000-0000-000000000001', repeat('k', 80) from spaces;
insert into space_keys (space_id, device_id, wrapped_key)
select id, null, repeat('r', 80) from spaces;
do $$ begin
  insert into space_keys (space_id, device_id, wrapped_key) select id, null, repeat('x', 80) from spaces;
  raise exception 'FALLA: dos llaves de recuperación para el mismo espacio';
exception when unique_violation then raise notice 'OK: una sola llave de recuperación por espacio';
end $$;

-- El servidor pone updated_at aunque el teléfono mande otra cosa.
insert into sync_records (id, space_id, entity, payload, changed_at, updated_at)
select 'aaaaaaaa-0000-0000-0000-000000000001', id, 'entry', 'cifrado-1', '2026-11-08 10:00+00', '2099-01-01 00:00+00' from spaces;
select 'esperado updated_at de hoy', updated_at < '2099-01-01' from sync_records;
select 'esperado updated_by Dana', updated_by = '00000000-0000-0000-0000-0000000000d1' from sync_records;

-- Gana el cambio más nuevo: uno más viejo no pisa la fila.
insert into sync_records (id, space_id, entity, payload, changed_at)
select 'aaaaaaaa-0000-0000-0000-000000000001', id, 'entry', 'cifrado-viejo', '2026-11-08 09:00+00' from spaces
on conflict (id) do update set payload = excluded.payload, changed_at = excluded.changed_at;
select 'esperado cifrado-1', payload from sync_records;
insert into sync_records (id, space_id, entity, payload, changed_at)
select 'aaaaaaaa-0000-0000-0000-000000000001', id, 'entry', 'cifrado-2', '2026-11-08 11:00+00' from spaces
on conflict (id) do update set payload = excluded.payload, changed_at = excluded.changed_at;
select 'esperado cifrado-2', payload from sync_records;

-- Elías no ve nada de Dana ni puede escribir en su espacio.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e1', false);
select 'esperado 0 sobres', count(*) from sync_records;
select 'esperado 0 llaves', count(*) from space_keys;
select 'esperado 0 dispositivos ajenos', count(*) from devices;
insert into devices (id, user_id, platform, name, public_key) values
  ('eeeeeeee-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000e1', 'ios', 'iPhone de Elías',
   'QkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkI=');
do $$ begin
  insert into sync_records (id, space_id, entity, payload)
  select 'aaaaaaaa-0000-0000-0000-0000000000e1', s.id, 'entry', 'intruso'
  from spaces s where s.owner_id = '00000000-0000-0000-0000-0000000000d1';
  if found then raise exception 'FALLA: Elías vio el espacio de Dana'; end if;
  raise notice 'OK: Elías no ve el espacio de Dana';
end $$;
do $$ begin
  insert into sync_records (id, space_id, entity, payload) values
    ('aaaaaaaa-0000-0000-0000-0000000000e2', (select space_id from space_members where user_id = '00000000-0000-0000-0000-0000000000e1' limit 1), 'entry', 'ok');
  raise notice 'OK: Elías escribe en su propio espacio';
end $$;
do $$ begin
  update sync_records set payload = 'pisado' where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if found then raise exception 'FALLA: Elías cambió un sobre de Dana'; end if;
  raise notice 'OK: Elías no cambia sobres de Dana';
end $$;

-- Dana no puede envolver su llave para el dispositivo de Elías (no está en su espacio).
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000d1', false);
do $$ begin
  insert into space_keys (space_id, device_id, wrapped_key)
  select id, 'eeeeeeee-0000-0000-0000-000000000001', repeat('k', 80) from spaces where owner_id = '00000000-0000-0000-0000-0000000000d1';
  raise exception 'FALLA: se envolvió una llave para un dispositivo ajeno';
exception when insufficient_privilege then raise notice 'OK: no se envuelven llaves para extraños';
end $$;

-- Borrar cuenta: se va todo lo de Elías y lo de Dana queda.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e1', false);
select delete_my_account();
reset role;
select 'esperado 0 de Elías', count(*) from auth.users where id = '00000000-0000-0000-0000-0000000000e1';
select 'esperado 1 sobre (de Dana)', count(*) from sync_records;
select 'esperado 2 llaves (de Dana)', count(*) from space_keys;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000d1', false);
select delete_my_account();
reset role;
select 'esperado 0 sobres', count(*) from sync_records;
select 'esperado 0 llaves', count(*) from space_keys;
select 'esperado 0 dispositivos', count(*) from devices;
select 'esperado 0 espacios de Dana', count(*) from spaces where owner_id = '00000000-0000-0000-0000-0000000000d1';
