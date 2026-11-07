# MProgress · Plan F12B (pasos 1 a 4 antes de F10)

Lo pidió Juan el 2026-11-06. Este documento es la referencia común: iOS y Android implementan las mismas reglas con los mismos nombres y las mismas pruebas de dominio.

## Paso 1 · Android al nivel de iOS

- Pagos fijos completos: crear, editar, pausar, reanudar, borrar, poner fecha a los que no tienen, marcar pagado, configurar su aviso.
- Detalle de movimiento: tocar un movimiento abre edición (monto, nombre, categoría, fecha, con qué se pagó, notas), con borrar y duplicar.
- Categorías: las mismas de iOS (`Data/Seed`), con ícono y color; Agregar las pide; Resumen las usa.
- Transferir entre cuentas, bolsillos y efectivos; pagar tarjeta de crédito.
- Límites por categoría y metas de ahorro (iOS `Features/Planning`).
- Monedas: elegir la moneda del espacio (iOS `CurrencyView`), mismas monedas de `Currency.all`.
- Bloqueo con huella o rostro (BiometricPrompt), igual que "Bloqueo con Face ID".
- Avisos: notificaciones locales de pagos fijos y límites (ver "Avisos en dos niveles").
- Escáner de recibos: cámara y lectura de texto en el teléfono, mismo `ReceiptParser`.
- Historial con detalle, Novedades, Respaldo (archivo cifrado igual al de iOS cuando sea posible).

## Paso 2 · Mejoras en las dos apps

### Varios efectivos
Se pueden crear varios productos de tipo efectivo con nombre propio ("Billetera", "Casa", "Alcancía"), cada uno con su saldo, y transferir entre ellos. Se agrupan bajo "Efectivo" en Dinero.

### Pagos con fin (cuotas o fecha final)
Campos nuevos en pago fijo:
- `endDate` (fecha, opcional, incluida): no hay cobros después de esa fecha.
- `totalCount` (entero, opcional): número de cuotas. `paidCount` (entero, empieza en 0).
Reglas:
- `pendingOccurrences` y el calendario no generan fechas después de `endDate` ni más de `totalCount - paidCount` cobros.
- Marcar pagado suma 1 a `paidCount`. Al llegar a `totalCount`, o si la siguiente fecha pasa `endDate`, el pago queda `active = false` con estado "Terminado" y se avisa "Terminaste de pagar X".
- Texto: "Cuota 3 de 12" (la próxima es `paidCount + 1`), o "Hasta 15 mar 2027".
- Agregar y editar pago fijo tienen "Termina": Nunca / En una fecha / Después de N cuotas.
Pruebas mínimas: mensual de 3 cuotas desde el 10 nov genera 10 nov, 10 dic, 10 ene y nada más; con `paidCount = 1` el mes de noviembre no cuenta; con `endDate` 31 dic, un semanal no genera fechas de enero.

### Avisos en dos niveles
- General (Ajustes › Avisos): activado, días antes (0 a 14, 0 = el mismo día), hora.
- Por pago fijo: "Como el general", "Personalizado" (días y hora propios) o "Sin aviso".
- Límites: aviso al 80 % y al 100 % (ya existe en iOS).
- El permiso de notificaciones se pide en el momento justo: al crear el primer pago fijo (o al terminar el onboarding si hay fijos) con la pregunta "¿Te aviso antes de cada pago?". Nunca al abrir la app sin contexto. Si lo niega, Ajustes › Avisos muestra cómo activarlo.

### Fecha y hora más fáciles
En Agregar y editar: botones Hoy, Ayer, Mañana y "Otra fecha" que abre un calendario. La hora es opcional, escondida tras "Agregar hora". Para pagos fijos: "Día del mes" con una cuadrícula de 1 a 31.

### Puntos y millas
- Android tiene la misma sección que iOS (`RewardsSection`, `RewardMath`).
- Campo nuevo en tarjeta: `rewardProgramId` y `pointsPerThousand` (puntos por cada $ 1.000 gastados, decimal opcional).
- Al guardar un gasto con esa tarjeta, se suma `floor(monto / 1000 × pointsPerThousand)` al programa. Al borrarlo, se resta.

## Paso 3 · Especiales de cada sistema

### iPhone
- Doble toque sin abrir la app: `QuickAddIntent` pasa a `openAppWhenRun = false`. Pide el monto con el cuadro del sistema (`requestValue`), luego gasto o ingreso y de dónde sale o a dónde entra (lista de productos). Guarda y muestra en la isla dinámica una Live Activity corta: "− $ 84.300 · te quedan $ 1.901.100", con botón Deshacer, que se cierra sola a los 8 segundos. Si la persona prefiere, un ajuste deja el comportamiento anterior (abrir la app).
- Siri y Atajos: "Anota 20 mil de almuerzo en MProgress".

### Android
- Registro automático leyendo notificaciones (NotificationListenerService) de Google Wallet y de los bancos y billeteras (Bancolombia, Nequi, Davivienda, Daviplata, Nu, etc.), con el mismo `SmsParser`. Cuando no está seguro, queda para revisar. En la versión de pruebas también puede leer SMS con permiso.
- Botón "Registro rápido" en los ajustes rápidos (Quick Settings tile) que abre Agregar encima.
- Widgets de pantalla de inicio iguales a los de iOS: Próximo cargo (pequeño), Te quedan (mediano con + Gasto), Calendario (grande). Pantalla de bloqueo solo donde el teléfono lo permita.

## Paso 4 · Este mes y próximos meses, sin predicciones inventadas (las dos apps)

Cambio pedido por Juan el 2026-11-06: nada de proyecciones con el ritmo de gasto (el iPhone decía "Así vas a terminar noviembre: − $ 783.998" el día 6 por una sola compra grande y un sueldo mal escrito). Solo datos reales y pagos fijos programados. Se quitaron `variablePace`, `projectedEndOfMonth`, `endOfMonth`, `variableAverage`, `variableSpent` y sus textos y pruebas.

Funciones puras de dominio (`Forecast` en `Domain/Forecast.swift` y `domain/Forecast.kt`), con pruebas iguales:
- `monthFacts`: sale de `monthSummary`. `entered` (ingresos registrados del mes), `pendingIncome` (fijos de ingreso que faltan), `spent`, `pendingFixed` (fijos de gasto que faltan) y `remaining = ingresos − gastado − fijos pendientes`, el mismo Te quedan de Inicio.
- `overText(remaining)`: "Te pasaste $ |W| de lo que entra este mes", solo si `remaining < 0`.
- `nextMonths(3, recurring)`: para cada uno de los 3 meses siguientes, ingresos fijos y gastos fijos (respetando `endDate` y cuotas) y `net = ingresos fijos − gastos fijos`. `netText`: "Quedan $ X". Nota fija: "Solo cuenta tus pagos fijos".

Pantallas:
- Resumen: tarjeta "Este mes" con Entró, Por entrar (solo si hay), Gastaste, Fijos que faltan y Te quedan. Si Te quedan es negativo va en rojo con "Te pasaste $ X de lo que entra este mes". "Los próximos 3 meses" con barras de ingresos fijos y gastos fijos (sin barra de variable), "Quedan $ X" por mes y la nota.
- Inicio: bajo Te quedan, la línea roja "Te pasaste $ X de lo que entra este mes" solo si Te quedan ya es negativo. Ningún otro aviso.

### Revisión del sueldo en Inicio
`IncomeCheck` (`Domain/HomeChecks.swift`, `domain/HomeChecks.kt`): un ingreso fijo activo de menos de 1.000 unidades de la moneda (`1_000 × minorPerUnit`) saca la tarjeta "¿Tu sueldo es $ 2?" (con el nombre del fijo en minúscula inicial, salvo siglas) y los botones "Es $ 2.000" (× 1.000), "Es $ 2.000.000" (× 1.000.000) y "Sí, es correcto". Arreglar cambia el monto con el store (iOS `LedgerStore.setRecurringAmount`, Android `Store.setRecurringAmount`), así queda pendiente de sincronizar, con aviso de Deshacer. "Sí, es correcto" guarda el id en este dispositivo (`inicio.ingresosRevisados`) y la tarjeta no vuelve a salir para ese fijo.

### Próximos cargos plegables
`UpcomingFold`: Inicio pide hasta 20 próximos cargos y muestra 3; si hay más, "Ver todos (N)" abre la lista completa y "Ver menos" la cierra. La elección se guarda en el dispositivo (`inicio.proximosAbiertos`).

## Reglas de siempre

- Español de Colombia con tuteo, sin la raya.
- Nunca números completos de tarjetas ni claves: solo los últimos 4.
- La migración de Supabase y el respaldo cifrado se actualizan con cada campo nuevo.
