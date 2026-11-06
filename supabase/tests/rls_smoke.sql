-- Prueba rápida de seguridad por fila. Se corre en una base local, nunca en producción.
-- Espera: Juan y Mariana comparten Hogar, un tercero no ve ni escribe nada.
grant all on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
insert into auth.users values
  ('00000000-0000-0000-0000-00000000000a', '{"name":"Juan"}'),
  ('00000000-0000-0000-0000-00000000000b', '{"name":"Mariana"}'),
  ('00000000-0000-0000-0000-00000000000c', '{"name":"Otro"}');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into spaces (id, owner_id, name, kind) values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 'Hogar', 'pareja') returning name;
insert into invites (space_id, code, created_by) values ('11111111-1111-1111-1111-111111111111', 'MP-48K2', '00000000-0000-0000-0000-00000000000a');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select accept_invite('mp-48k2');
insert into entries (space_id, kind, amount, name, paid_by) values ('11111111-1111-1111-1111-111111111111', 'gasto', 8430000, 'Mercado', '00000000-0000-0000-0000-00000000000b');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
select 'esperado 1', count(*) from entries;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
select 'esperado 0', count(*) from entries;
do $$ begin
  insert into entries (space_id, kind, amount, name) values ('11111111-1111-1111-1111-111111111111', 'gasto', 100, 'Intruso');
  raise exception 'FALLA: un tercero pudo escribir';
exception when insufficient_privilege then raise notice 'OK: tercero bloqueado';
end $$;
