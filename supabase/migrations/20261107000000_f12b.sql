-- MProgress · F12B (docs/PLAN_F12B.md), pasos 2 a 4.
-- No crea tablas nuevas: las columnas quedan cubiertas por la seguridad por fila que ya tienen
-- products, recurring y reminders en 20261106000000_init.sql.
-- Se puede correr más de una vez.

-- Pagos con fin (cuotas o fecha final)

alter table public.recurring
  add column if not exists end_date date,
  add column if not exists total_count smallint,
  add column if not exists paid_count smallint not null default 0;

do $$ begin
  alter table public.recurring add constraint recurring_total_count_check check (total_count is null or total_count > 0);
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.recurring add constraint recurring_paid_count_check check (paid_count >= 0);
exception when duplicate_object then null;
end $$;

comment on column public.recurring.end_date is 'Último día con cobro, incluido. null = no termina por fecha';
comment on column public.recurring.total_count is 'Número de cuotas. null = no termina por cuotas';
comment on column public.recurring.paid_count is 'Cuotas pagadas: cada marcar pagado suma 1. Al llegar a total_count el pago queda inactivo (terminado)';

-- Avisos en dos niveles: cada pago fijo usa el aviso general, uno propio o ninguno.

alter table public.reminders
  add column if not exists mode text not null default 'personalizado';

do $$ begin
  alter table public.reminders add constraint reminders_mode_check check (mode in ('general', 'personalizado', 'ninguno'));
exception when duplicate_object then null;
end $$;

comment on column public.reminders.mode is 'general = días y hora de Ajustes › Avisos; personalizado = los de esta fila; ninguno = sin aviso';

-- Puntos por tarjeta

alter table public.products
  add column if not exists reward_program_id uuid references public.reward_programs (id) on delete set null,
  add column if not exists points_per_thousand numeric(8, 3);

do $$ begin
  alter table public.products add constraint products_points_per_thousand_check
    check (points_per_thousand is null or points_per_thousand > 0);
exception when duplicate_object then null;
end $$;

comment on column public.products.reward_program_id is 'Tarjetas: programa de puntos o millas donde acumula';
comment on column public.products.points_per_thousand is 'Tarjetas: puntos por cada 1.000 de la moneda gastados. Cada gasto suma floor(monto / 1000 × points_per_thousand) al programa; borrarlo los resta';
