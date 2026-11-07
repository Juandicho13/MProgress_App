-- MProgress · Pagos fijos quincenales (dos días fijos al mes, por defecto el 15 y el último día).
-- Solo deja el esquema igual a los modelos de la app: hoy la app no escribe en public.recurring, todo viaja cifrado en
-- sync_records (entidad recurring con cycleRaw "quincenal", firstDay y secondDay dentro del sobre). No crea tablas nuevas:
-- las columnas quedan cubiertas por la seguridad por fila que ya tiene recurring (20261106000000_init.sql).
-- Se puede correr más de una vez.

alter type public.cycle_kind add value if not exists 'quincenal';

alter table public.recurring
  add column if not exists first_day smallint,
  add column if not exists second_day smallint;

do $$ begin
  alter table public.recurring add constraint recurring_quincena_days_check
    check ((first_day is null or first_day between 1 and 31) and (second_day is null or second_day between 1 and 31));
exception when duplicate_object then null;
end $$;

comment on column public.recurring.first_day is 'Primer día de un pago quincenal (1 a 28 al elegirlo). Null en los demás ciclos';
comment on column public.recurring.second_day is 'Segundo día de un pago quincenal; 31 es el último día del mes (30, 31, 28 o 29). Null en los demás ciclos';
