-- MProgress · Tarjetas de crédito a fondo (docs/PLAN_TARJETAS.md). SIN APLICAR todavía.
--
-- Importante: desde F10 la app sincroniza solo por sync_records (sobres cifrados con el JSON de cada fila,
-- ver docs/PLAN_F10.md). Las tablas products y entries con columnas en claro no se usan para sincronizar, así
-- que la app NO necesita esta migración para funcionar: los campos nuevos viajan dentro del sobre cifrado como
-- campos opcionales del JSON (Backup.ProductRow y Backup.EntryRow en iOS, SyncRows y Backup en Android).
-- Esta migración solo mantiene el esquema en claro igual al modelo, como se hizo con interval_months.
--
-- Todas las columnas son opcionales (aceptan null) y tienen valor por defecto: las filas de antes siguen igual.
-- No crea tablas: quedan cubiertas por la seguridad por fila que ya tienen products y entries. Se puede correr
-- más de una vez.

-- Tarjeta de crédito: tarjeta del catálogo, cuota de manejo, compras a 1 cuota sin intereses, avances y método.

alter table public.products
  add column if not exists catalog_card_id text,
  add column if not exists handling_fee bigint default 0,
  add column if not exists one_installment_free boolean default true,
  add column if not exists advance_fee bigint default 0,
  add column if not exists installment_method text default 'capital_fijo';

do $$ begin
  alter table public.products add constraint products_handling_fee_check check (handling_fee is null or handling_fee >= 0);
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.products add constraint products_advance_fee_check check (advance_fee is null or advance_fee >= 0);
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.products add constraint products_installment_method_check
    check (installment_method is null or installment_method in ('capital_fijo', 'cuota_fija'));
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.products add constraint products_catalog_card_id_check
    check (catalog_card_id is null or char_length(catalog_card_id) between 1 and 80);
exception when duplicate_object then null;
end $$;

comment on column public.products.catalog_card_id is 'Tarjetas de crédito: id del catálogo (CardCatalog.json), por ejemplo bancolombia-visa-clasica. Null si la persona escribió el nombre';
comment on column public.products.handling_fee is 'Tarjetas de crédito: cuota de manejo mensual en unidades mínimas. 0 o null: sin cuota';
comment on column public.products.one_installment_free is 'Tarjetas de crédito: las compras a 1 cuota no pagan intereses (lo común en Colombia). Null cuenta como true';
comment on column public.products.advance_fee is 'Tarjetas de crédito: comisión fija por avance en unidades mínimas. 0 o null: sin comisión';
comment on column public.products.installment_method is 'Tarjetas de crédito: capital_fijo (capital igual más intereses sobre el saldo, por defecto) o cuota_fija (francés)';

-- Compras con tarjeta de crédito: número de cuotas y si es un avance.

alter table public.entries
  add column if not exists installments smallint default 1,
  add column if not exists is_advance boolean default false;

do $$ begin
  alter table public.entries add constraint entries_installments_check check (installments is null or installments between 1 and 48);
exception when duplicate_object then null;
end $$;

comment on column public.entries.installments is 'Gastos con tarjeta de crédito: número de cuotas (1 a 48). Null cuenta como 1';
comment on column public.entries.is_advance is 'Gastos con tarjeta de crédito: true si es un avance (intereses desde el día uno). Null cuenta como false';

-- Avance a una cuenta propia (Transferir desde la tarjeta de crédito): número de cuotas.

alter table public.transfers
  add column if not exists installments smallint default 1;

do $$ begin
  alter table public.transfers add constraint transfers_installments_check check (installments is null or installments between 1 and 48);
exception when duplicate_object then null;
end $$;

comment on column public.transfers.installments is 'Transferencia que sale de una tarjeta de crédito (avance): número de cuotas (1 a 48). Null cuenta como 1';
