-- MProgress · Pagos fijos cada N meses (mensual, cada 2 meses, trimestral, semestral, anual o cada N meses).
-- No crea tablas nuevas: la columna queda cubierta por la seguridad por fila que ya tiene recurring
-- (20261106000000_init.sql). Los nombres de comercios viajan cifrados en sync_records (entidad merchant_alias),
-- así que no necesitan tabla propia. Se puede correr más de una vez.

alter table public.recurring
  add column if not exists interval_months smallint not null default 1;

do $$ begin
  alter table public.recurring add constraint recurring_interval_months_check check (interval_months between 1 and 24);
exception when duplicate_object then null;
end $$;

comment on column public.recurring.interval_months is 'Meses entre cobros cuando cycle = mensual: 1 cada mes, 2 cada 2 meses, 3 trimestral, 6 semestral (1 a 24). Los pagos de antes quedan en 1. Anual se guarda como cycle = anual';
