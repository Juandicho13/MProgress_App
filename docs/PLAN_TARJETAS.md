# MProgress · Plan de tarjetas de crédito a fondo

Estado (2026-11-07): dominio, pruebas, catálogo y migración listos en iPhone y Android. Faltan los modelos y las pantallas (siguiente tarea). Ticket: F14-07 en `docs/FASES.md`.

Archivos de esta parte:

| Qué | iPhone | Android |
| --- | --- | --- |
| Cálculos | `ios/MProgress/Domain/CreditCard.swift` | `android/app/src/main/java/com/olarte/mprogress/domain/CreditCard.kt` |
| Catálogo (lector y búsqueda) | `ios/MProgress/Domain/CardCatalog.swift` | `android/app/src/main/java/com/olarte/mprogress/domain/CardCatalog.kt` |
| Datos del catálogo | `ios/MProgress/Resources/CardCatalog.json` | `android/app/src/main/assets/card_catalog.json` (mismo archivo) |
| Pruebas | `ios/MProgressTests/Domain/CreditCardTests.swift`, `CardCatalogTests.swift` | `android/app/src/test/java/com/olarte/mprogress/domain/CreditCardTest.kt`, `CardCatalogTest.kt` |
| Modelo de referencia | `android/app/src/test/vectors/credit_card_vectors.py` (Python con Decimal: los números de las dos pruebas salen de aquí) | |
| Base de datos | `supabase/migrations/20261110000000_tarjetas.sql` (sin aplicar) | |

## 1. Cómo funciona para la persona

Una tarjeta de crédito en Colombia tiene **cupo**, **día de corte**, **día de pago** y una **tasa E.A.** (y a veces cuota de manejo). La app lo explica así:

- **Cupo disponible:** cupo menos todo lo que debes, incluidas las cuotas que todavía no te cobran. "Te quedan $ 3.200.000 de cupo". Si te pasas: "Te pasaste $ 120.000 del cupo".
- **Corte:** todo lo que compras hasta el día de corte (incluido) sale en el extracto de ese mes; lo que compras después, en el siguiente. Si el corte es 29, 30 o 31 y el mes es más corto, corta el último día.
- **Fecha de pago:** el primer día de pago después del corte. Con corte 30 y pago 15, el extracto del 30 de noviembre se paga hasta el 15 de diciembre.
- **Cuotas (lo normal en Colombia):** cada mes pagas una parte igual del capital más los intereses del saldo que falta. Por eso la primera cuota es la más cara y las siguientes van bajando. En el primer extracto los intereses van solo por los días desde la compra hasta el corte.
- **Compras a 1 cuota:** no pagan intereses (casi todas las tarjetas lo hacen así; se puede apagar por tarjeta). Van completas en el mínimo.
- **Avances:** pagan intereses desde el día uno, nunca son "sin intereses" y pueden tener una comisión fija.
- **Pago mínimo:** las cuotas de este mes (capital más intereses), la cuota de manejo, las comisiones de avance y lo que haya faltado del mes pasado.
- **Pago total:** el mínimo más todo el capital de las cuotas futuras. Si lo pagas, la tarjeta queda en cero y no pagas más intereses por esas compras.
- **Pagar entre el mínimo y el total:** lo que pasa del mínimo baja capital, primero de los avances y luego de la compra con más intereses por delante. Así los intereses de los meses siguientes bajan.
- **Pagar menos del mínimo:** antes de la fecha la app dice "Te faltan $ X para el mínimo"; después, "Pago incompleto" y en el extracto siguiente sale lo que faltó con un **interés de mora estimado** (la app no conoce la mora exacta del banco y lo dice).
- **Pagar de más:** queda saldo a favor y se usa en el siguiente extracto.
- **Tasa:** si la persona no la sabe, se sugiere el tope de usura del mes del catálogo (28,34 % E.A. en noviembre de 2026) con el texto "Tope legal de este mes, revisa tu extracto". Las tasas no van en el catálogo porque cambian cada mes.

Todo es aproximado y se dice así en pantalla. El banco calcula los intereses día a día y cada uno redondea distinto: la app sirve para decidir (mínimo o total, cuántas cuotas), no para reemplazar el extracto.

## 2. De dónde salen los datos (sin cambiar cómo se guarda hoy)

Hoy un gasto con tarjeta de crédito es un `Entry` de gasto con `productId` de la tarjeta, y pagar la tarjeta es un `Transfer` de la cuenta a la tarjeta. No hay cuotas. El motor de tarjetas se alimenta así:

| En la app | Para el motor |
| --- | --- |
| Gasto (`Entry` kind gasto) con `productId` = la tarjeta | `CardPurchase` (compra, con `installments` del gasto, o avance si `isAdvance`) |
| Ingreso (`Entry` kind ingreso) con la tarjeta (devolución) | `CardPayment` (abono) |
| `Transfer` hacia la tarjeta (Pagar tarjeta) | `CardPayment` |
| `Transfer` desde la tarjeta hacia una cuenta | `CardPurchase` de tipo avance (con `Transfer.installments`) |
| `Product.balanceMinor` en `balanceAt` (deuda con la que se creó) | `CardPurchase` "Saldo anterior" a 1 cuota en ese día |
| `Product` crédito: `creditLimitMinor`, `cutDay`, `dueDay`, `rateEA` y los campos nuevos | `CardTerms` con `CreditCardMath.terms(...)` (sin corte usa 30, sin pago 15 días después, sin tasa la usura del catálogo) |

Las fechas pasan a días sin hora: iPhone `CardDay(date, calendar: .current)`, Android `LocalDate` (ya lo usa). En Android `rateEA` es `Double`: pasarlo con `BigDecimal.valueOf(rateEA)`.

El saldo de la tarjeta que ya muestra la app (`MoneyCalculator.currentBalance`) no cambia: sigue siendo la deuda total. El motor agrega lo que antes no se sabía: cuánto es el mínimo, el total, los intereses y el cupo real.

## 3. Pantallas que siguen

1. **Elegir la tarjeta del catálogo al agregar una tarjeta de crédito** (Agregar a un banco › Tarjeta crédito). Con el nombre del banco (`CardCatalog.cards(forBank:)`, acepta "Bogotá", "Colpatria", "Nubank", "Itaú", sin tildes) se muestra la lista de tarjetas de ese banco con su franquicia y programa ("Visa · Puntos Colombia"). Al elegir una se llenan el nombre, la cuota de manejo si se sabe y el programa de puntos (si existe en Puntos, se enlaza). Siempre hay "Otra tarjeta" para escribirla. Si el banco no está verificado (`verified` false) se muestra su nota. Luego: cupo, día de corte, día de pago y tasa (con la usura sugerida y su texto).
2. **Detalle de la tarjeta:** barra de cupo (usado y disponible, "Te quedan $ X de cupo"), **próximo extracto** (`upcomingStatement`) con su corte y fecha de pago, **mínimo y total** lado a lado ("Mínimo $ 210.300" y "Paga $ 845.000 antes del 15 nov para no pagar intereses"), estado del último extracto (`status` y `CreditCardText.status`), y la lista de compras en cuotas con "Cuota 3 de 12" y lo que falta.
3. **Extracto del mes:** líneas con nombre, cuota k de n, capital e interés; cuota de manejo, comisiones de avance, lo pendiente del mes pasado y la mora estimada marcada como estimada. Se puede ir a extractos anteriores (`ledger(...).statements`).
4. **Simulador:** "Si pagas solo el mínimo" (`payOnlyMinimum`) y "Si pagas $ X al mes" (`payFixed`) con el teclado de monto; dice meses, fecha del último pago e intereses, o "Con $ X al mes no alcanzas el mínimo de $ Y". Aclara que no cuenta la cuota de manejo.
5. **Cuotas al registrar un gasto con tarjeta de crédito** (Agregar y ¿Con qué pagaste?): selector 1 a 48 cuotas (1 por defecto, accesos rápidos 1, 3, 6, 12, 24, 36), interruptor "Es un avance" y la línea "Esta compra a 12 cuotas te cuesta $ Y de intereses" (`purchaseCost`). El detalle del movimiento muestra el plan de cuotas.
6. **Pagar tarjeta:** al elegir la tarjeta, tres opciones: **Mínimo**, **Total** u **Otro valor** (el monto editable que ya existe). Debajo, qué pasa con cada una ("Con el mínimo terminas en 24 meses y pagas $ X de intereses"). Sigue siendo una transferencia; el motor la toma como pago.
7. **Avisos:** el aviso de pago de tarjeta (F06-07) pasa a decir el mínimo y el total del extracto en vez de solo la deuda, y usa la fecha de pago del extracto (`dueDate`).

## 4. Cambios en el modelo

Todos opcionales o con valor por defecto, para que los datos de antes sigan igual.

**Product (crédito)**, iPhone `Data/Models/Models.swift` y Android `data/Store.kt`:

| Campo | Tipo | Por defecto | Para qué |
| --- | --- | --- | --- |
| `catalogCardId` | `String?` | nil | Id del catálogo (`bancolombia-visa-clasica`) |
| `handlingFeeMinor` | `Int64?` / `Long?` | nil (sin cuota) | Cuota de manejo mensual |
| `oneInstallmentFree` | `Bool` | true | Compras a 1 cuota sin intereses |
| `advanceFeeMinor` | `Int64?` / `Long?` | nil | Comisión por avance |
| `installmentMethodRaw` | `String?` | nil (capital fijo) | `capitalFijo` o `cuotaFija` |

Ya existen y se empiezan a usar en serio: `creditLimitMinor`, `cutDay`, `dueDay`, `rateEA`, `rewardProgramId`, `pointsPerThousand`. `ProductRecord` (dominio) no trae cupo ni corte: o se agregan esos campos con valor nil por defecto o la pantalla arma `CardTerms` desde `Product` con `CreditCardMath.terms(...)`.

**Entry (gasto con tarjeta de crédito):**

| Campo | Tipo | Por defecto | Para qué |
| --- | --- | --- | --- |
| `installments` | `Int?` | nil (1 cuota) | Número de cuotas, 1 a 48 |
| `isAdvance` | `Bool` | false | Avance |

**Transfer (avance desde la tarjeta a una cuenta):** `installments: Int?`, nil es 1.

No confundir con las cuotas de un pago fijo (`Recurring.totalCount` y `paidCount`), que son otra cosa: un pago que se repite un número de veces.

**Respaldo y sincronización:** los campos nuevos van como opcionales en `Backup.ProductRow`, `Backup.EntryRow` y `Backup.TransferRow` (iPhone) y en `LedgerJson`, `Backup` y `SyncRows` (Android), con nil o el valor por defecto al leer archivos y sobres viejos.

## 5. Supabase

Revisado en el código: desde F10 la app sincroniza **solo** por `sync_records` (sobres cifrados con el JSON de cada fila; `CloudAPI.swift` y `CloudApi.kt` solo llaman a `sync_records`). Las tablas `products`, `entries` y `transfers` con columnas en claro no se usan. Por eso los campos nuevos funcionan en la nube sin tocar la base: viajan dentro del sobre como campos opcionales.

Igual quedó escrita `supabase/migrations/20261110000000_tarjetas.sql` para que el esquema en claro siga igual al modelo (como se hizo con `interval_months`): `products.catalog_card_id`, `handling_fee`, `one_installment_free`, `advance_fee`, `installment_method`; `entries.installments`, `is_advance`; `transfers.installments`. Todas aceptan null y tienen valor por defecto, con sus `check`. Probada en Postgres 16 local junto con las cuatro anteriores y corrida dos veces. **No está aplicada** al proyecto real; no es urgente porque la app no la necesita.

## 6. Catálogo de tarjetas

`CardCatalog.json` (mismo contenido en Android) trae 19 bancos y 133 tarjetas revisadas el 2026-11-07. Cada banco tiene `aliases` para buscar, `source` y `sources` (de dónde sale), `checkedAt`, `verified` y una nota cuando hace falta. Cada tarjeta tiene `id` estable, `name`, `franchise` (visa, mastercard, amex, diners o null si no se pudo confirmar), `tier` (texto libre), `rewards` (Puntos Colombia, LifeMiles, LATAM Pass, Puntos BBVA, Cashback…) y `handlingFeeCOP` (pesos al mes, solo si se publica claro; null si no se sabe). Arriba van `usuraEA` (0,2834) y `usuraMonth` ("2026-11").

Decisiones del catálogo:
- **Itaú:** su banca de personas pasó a Banco de Bogotá en agosto de 2026 y las tarjetas Itaú dejaron de funcionar el 21 de octubre; Banco de Bogotá las cambió por tarjetas propias. Itaú no tiene tarjetas propias: "Itaú" busca en Banco de Bogotá.
- **Scotiabank Colpatria:** desde abril de 2026 se llama **DAVIbank** (grupo Davivienda) y sus tarjetas siguen igual. "Colpatria" y "Scotiabank" buscan ahí.
- **Sin verificar del todo:** DAVIbank, Banco Popular, Caja Social (solo la Platinum), Lulo (nombre exacto), Banco Agrario, Pichincha (solo la Infinite) y **GNB Sudameris (ninguna tarjeta confirmada, lista vacía)**. Para ellos la pantalla deja escribir el nombre.
- No se incluyen tarjetas empresariales ni las que ya no se expiden (Viva, Esso, Pichincha Gold).
- Cuotas de manejo: Bancolombia del tarifario 2026-2027 (desde el 1 dic 2026), Serfinanza y Finandina de sus tarifarios, el resto de comparadores (Rankia) donde el valor es claro. Son indicativas: la persona las puede cambiar.

Para actualizar el catálogo: editar el JSON de iPhone, copiarlo igual a Android (la prueba `mismoArchivoQueIos` lo revisa), actualizar `checkedAt`, `usuraEA` y `usuraMonth`, y correr las pruebas de los dos. La usura se debería cambiar cada mes; más adelante puede bajar de la nube.

## 7. Reglas de cálculo (para quien toque el código)

- Montos en unidades mínimas; cada línea se redondea a la unidad que se ve (pesos enteros en COP) con mitad hacia arriba, solo al final.
- Tasa mensual = (1 + EA/100)^(1/12) − 1 con Newton en Decimal / BigDecimal, a 20 decimales (28,34 % E.A. da 0,02101040881997040579).
- Capital fijo: capital = saldo / cuotas que faltan (la última lleva el resto); interés = saldo × tasa mensual, y en el primer extracto × días desde la compra hasta el corte / días del periodo.
- Cuota fija (por si un banco lo usa): cuota = R·i·q / (q − 1) con q = (1 + i)^m; capital = cuota − interés del mes completo.
- Orden del mismo día: compras, pagos y al final el corte.
- Un pago cubre primero lo que falta del extracto; el excedente baja capital: avances, luego el saldo con más intereses por delante (saldo × (cuotas que faltan + 1)), luego el más viejo; lo que sobra queda a favor.
- Simuladores: sin compras nuevas, sin cuota de manejo, pagando el día de pago de cada extracto; cuentan los intereses de los extractos que faltan.
- Cambiar una regla: primero en `credit_card_vectors.py`, correrlo, y copiar los números a las dos pruebas.

## 8. Orden sugerido

1. Campos nuevos en los modelos, respaldo y sobres (con pruebas de leer datos viejos).
2. Elegir tarjeta del catálogo y condiciones al agregar o editar una tarjeta.
3. Cuotas y avance en Agregar.
4. Detalle de la tarjeta con cupo, próximo extracto, mínimo y total.
5. Pagar tarjeta con Mínimo, Total u Otro valor.
6. Extracto del mes y simulador.
7. Aviso de pago con el mínimo y el total.
