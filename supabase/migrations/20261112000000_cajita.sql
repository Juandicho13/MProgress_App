-- MProgress · Cajita como tipo de producto aparte del bolsillo.
-- Solo deja el esquema igual a los modelos de la app: hoy la app no escribe en public.products, todo viaja cifrado en
-- sync_records (entidad products con kindRaw "cajita" dentro del sobre). Los bolsillos de antes siguen siendo 'bolsillo'.
-- Quién te debe (entidades debts y debt_payments) tampoco necesita tablas: sync_records acepta cualquier entidad en minúsculas.
-- Se puede correr más de una vez. Sin aplicar.

alter type public.product_kind add value if not exists 'cajita';

comment on type public.product_kind is 'cuenta, debito, credito, bolsillo (plata apartada en una cuenta, como Nequi o Bancolombia), efectivo y cajita (ahorro aparte que suele rendir, como Nu)';
