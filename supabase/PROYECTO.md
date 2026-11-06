# Proyecto de Supabase de MProgress

Creado el 2026-11-06. Plan Free, región East US (North Virginia, us-east-1): la más rápida desde Colombia.
(Se creó primero uno en Oregon y se borró vacío para quedar en la mejor región.)

- Project URL: https://qucnkajomuguqurwsvuy.supabase.co
- Publishable key: sb_publishable_XYShe2GRVe4sOi4Jh-Mb1Q_Ij_w5hGR

Estas dos van dentro de las apps: la publishable key tiene permisos bajos y los datos los protege la seguridad por fila (RLS).
La secret key (sb_secret_...) y la contraseña de la base de datos NUNCA van en el repo ni en las apps. Si algún día se necesita la contraseña, se cambia en Settings › Database.

## Migraciones aplicadas (SQL Editor)
- 2026-11-06: `migrations/20261106000000_init.sql`. Verificado: 18 tablas, todas con RLS, 15 categorías base.
- 2026-11-06: `migrations/20261107000000_f12b.sql` (cuotas, fecha final, modo de aviso, puntos por tarjeta).
