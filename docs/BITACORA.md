# MProgress · Bitácora

Una entrada por ticket, la más nueva arriba. Plantilla en `HANDOFF.md` 11.3.

## 2026-11-06 · F12 Widgets · en curso

- Qué: extensión MProgressWidgets con Próximo cargo (pequeño), Te quedan (mediano, + Gasto y 4 cargos), Calendario de cobros (grande), pantalla bloqueada (anillo, rectangular e inline) y botón "Registro rápido" para el Centro de control. La app escribe un resumen ya calculado (`Shared/WidgetSnapshot.swift`) al volver y al salir, y los widgets lo leen; los enlaces `mprogress://rapido`, `fijos`, `calendario` e `inicio` abren la app donde toca.
- Archivos: ios/MProgressWidgets/*, ios/Shared/WidgetSnapshot.swift, ios/MProgress/Data/Widgets/WidgetPublisher.swift, ios/MProgress-Info.plist (esquema de enlaces), ios/MProgressWidgets-Info.plist, MProgress.xcodeproj (objetivo nuevo y carpeta compartida), Persistence.swift (pasa la base al App Group el día que exista, sin perder nada), App/RootView.swift, App/MProgressApp.swift.
- Verificado: compila para el iPhone de Juan con la extensión.
- Pendiente: con la cuenta gratuita de Apple no hay App Group, así que los widgets no ven datos y muestran "Abre MProgress"; + Gasto y el Centro de control sí funcionan. Con la cuenta paga: en Xcode, Signing & Capabilities › + Capability › App Groups › `group.com.olarte.mprogress` en MProgress y en MProgressWidgets (los archivos `*.entitlements.listo-para-cuenta-paga` ya traen ese valor). Marcar pagado desde el widget y Apple Watch quedan para después.

## 2026-11-06 · Cambios pedidos por Juan al probar en el iPhone

- Qué:
  - Onboarding nuevo: ingreso › bancos y tarjetas (sugerencias, + Crédito, + Débito, + Cajita, 4 dígitos) › gastos fijos con "Agregar otro" › día y con qué se paga cada uno, con "Más tarde" por gasto y "Todo más tarde" › intereses. El sueldo pregunta a dónde llega.
  - Zona de Pagos fijos: total al mes, "Falta la fecha", gastos e ingresos, editar (nombre, monto, ciclo, fecha, con qué se paga, activo, aviso, borrar). Se entra desde Inicio (Próximos cargos › Pagos fijos) y desde Más. Un fijo sin fecha no avisa ni sale en próximos hasta tener fecha (`Recurring.dateUnset`).
  - Monto seleccionado en Agregar: borde brasa, fondo suave y cursor que parpadea (quieto con Reducir movimiento).
  - Registro rápido para el doble toque atrás: intent "Registro rápido" que abre la app en monto › gasto o ingreso › de dónde sale o a dónde entra › categoría opcional. Guía paso a paso en Ajustes y en Registro automático, y entrada en Más.
  - Puntos y millas en Dinero (Puntos Colombia, LifeMiles, LATAM Pass…): saldo, valor por punto opcional, valor aproximado, vencimiento y tarjeta con la que se acumulan. Tabla `reward_programs` con RLS y columna `recurring.date_unset` en la migración; respaldo incluido.
- Archivos: ios/MProgress/Features/Onboarding/*, Features/Fixed/*, Features/AutoCapture/QuickAddView.swift, Features/Money/RewardsSection.swift, Domain/Fixed.swift, Domain/Rewards.swift, Data/Models/Models.swift (RewardProgram, dateUnset), Data/Stores/*, Data/Backup/BackupService.swift, Domain/Backup.swift, Design/Components/NumericKeypad.swift, Intents/LogExpenseIntents.swift, supabase/migrations/20261106000000_init.sql; pruebas FixedTests, RewardsTests, OnboardingTests nuevas, FixedStoreTests y respaldo con puntos.
- Verificado: 98 pruebas de dominio en Linux y 141 en Xcode (simulador iPhone 17), todas en verde; migración aplicada en Postgres 16 y `rls_smoke.sql` en verde; compila e instala en el iPhone de Juan.
- Pendiente: el valor de cada punto lo pone la persona (no encontramos un valor oficial que no cambie).

## 2026-11-06 · F10-03 Motor de sincronización · en curso

- Qué: `SyncEngine` en el dominio con dos protocolos, `LocalSyncStore` (SwiftData) y `RemoteSyncStore` (Supabase). Sube los pendientes en lotes y en el orden en que se hicieron, baja cada tabla desde su cursor (borrados incluidos), gana el `updatedAt` más reciente (empate: servidor) y tras 3 intentos fallidos el cambio queda con error. Estado y texto de la pastilla "Sin conexión · 3 cambios sin sincronizar".
- Archivos: ios/MProgress/Domain/Sync.swift; pruebas SyncTests con servidor y teléfonos falsos.
- Verificado: 93 pruebas de dominio en Linux.
- Pendiente: Juan crea el proyecto en Supabase (F10-01); luego los dos adaptadores, la pastilla y la hoja de estado (F10-04), que solo se muestran con cuenta.

## 2026-11-06 · F09 Ajustes, apariencia y respaldo · hecho salvo iCloud Drive

- Qué: Ajustes con General (Face ID, Moneda, Apariencia, Ícono), Datos (Respaldo, Espacios pronto, Avisos), Información (Novedades) y firma al pie. Apariencia con vista previa del vidrio, 4 niveles, tema oscuro, claro o sistema y Seguir a iOS (Reducir transparencia manda). Moneda con buscador. Seis íconos de la app generados con los colores de la app (Brasa principal) y cambio de ícono. Bloqueo con Face ID o código al volver a la app. Respaldo: copia completa de la base en `.mprogress` (JSON) y movimientos en CSV para compartir; respaldo cifrado diario en el iPhone (últimos 7) con la llave en el llavero de iCloud; restaurar reemplaza todo con los mismos ids y antes guarda un respaldo de seguridad.
- Archivos: ios/MProgress/Domain/Backup.swift, Data/Backup/BackupService.swift, Features/Settings/*, App/LockGate.swift, App/MProgressApp.swift (tema, bloqueo, respaldo diario), App/RootView.swift, Resources/Assets.xcassets (AppIcon y 5 alternos, vistas previas), MProgress.xcodeproj (íconos alternos, Face ID, Archivos); pruebas BackupTests y BackupServiceTests.
- Verificado: 87 pruebas de dominio en Linux y 126 en Xcode con el simulador iPhone 17, todas en verde. Falta mirarlo en el iPhone.
- Pendiente: iCloud Drive para el respaldo cuando la app tenga firma (F00-02); correo de soporte para "Escríbeme".

## 2026-11-06 · F08 Registro automático · hecho salvo pruebas en el iPhone

- Qué: App Intents "Registrar gasto" (para el atajo de Wallet) y "Leer SMS del banco" (para el atajo de Mensajes) con frases de Siri. AutoCaptureStore guarda lo que llega, busca la tarjeta por sus últimos 4, marca "Revisar" si falta comercio o tarjeta y une Apple Pay y el SMS del mismo pago (10 minutos, mismo monto). Lector de SMS sin plantillas fijas: monto en los dos formatos, comercio, últimos 4, banco y si es gasto o ingreso. Pantalla Registro automático con fuentes, últimos detectados y probador de SMS, y guía paso a paso para crear los dos atajos. Escanear recibo con la cámara de documentos o desde Fotos: Vision lee el texto en el iPhone, se toma el total (no subtotal ni IVA) y el comercio, y abre Agregar con el borrador. Editar un detectado lo deja revisado. Contenedor compartido para que la app y los intents no abran la base dos veces. Permiso de cámara en el proyecto.
- Archivos: ios/MProgress/Domain/AutoCapture.swift, Data/Stores/AutoCaptureStore.swift, Intents/LogExpenseIntents.swift, Features/AutoCapture/*, Data/Persistence/Persistence.swift (`shared()`), Data/Stores/LedgerStore.swift, Features/AddEntry/*, Features/Home/HomeView.swift (Más: Escanear recibo y Registro automático), MProgress.xcodeproj (permiso de cámara y pruebas sin paralelo); pruebas AutoCaptureTests y AutoCaptureStoreTests.
- Verificado: 84 pruebas de dominio en Linux y 122 en Xcode con el simulador iPhone 17, todas en verde.
- Pendiente: probar los atajos y la cámara en el iPhone, y cambiar los ejemplos de SMS por SMS reales de Bancolombia, Nu, Nequi y Davivienda.
- Nota: los datos de los simuladores ya no estaban en el disco ("cannot be located on disk"). Se restableció el iPhone 17 desde Device Hub y las pruebas corren ahí; el iPhone 18 Pro se arregla igual (clic derecho › Reset Content and Settings).

## 2026-11-06 · F07 Avisos, límites y ahorro · hecho

- Qué: el permiso de notificaciones se pide al guardar el primer aviso, no al abrir. Aviso de pago por pago fijo (1 a 14 días antes, hora y el mismo día) con vista previa; se abre tocando un pago en Inicio › Configurar aviso. Las notificaciones se rehacen desde la base al volver a la app y después de cada cambio, con identificadores "mp." para no dejar avisos viejos; también avisa el pago de tarjetas y un resumen semanal opcional. Pantalla Avisos (campana en Inicio) con lo de hoy y mañana, límites cerca o superados y los ajustes. Límites con anillo del total, barras por categoría (brasa, oro cerca, peligro superado), lo que queda por día y aviso de exceso; al guardar un gasto que cruza el 80 % o el 100 % sale un aviso abajo. Ahorro con total, metas con barra, aporte mensual necesario para la fecha, metas ligadas a una cajita, aportar y retirar. Límites, Ahorro e Historial entran en el menú Más.
- Archivos: ios/MProgress/Domain/Planning.swift, Data/Stores/PlanningStore.swift, Data/Notifications/NotificationScheduler.swift, Data/Models/Models.swift (Reminder.sameDay y records), Features/Planning/*, Features/Home/HomeView.swift, Features/AddEntry/AddEntryView.swift, Features/Calendar/CalendarView.swift, App/MProgressApp.swift; pruebas PlanningTests y PlanningStoreTests.
- Verificado: 76 pruebas de dominio en Linux y 109 en Xcode, todas en verde. Las notificaciones reales se prueban en el iPhone.
- Pendiente: "¿A quién aviso?" y avisar a la pareja (F11), avisar en el reloj (F12). Marcar pagado desde Inicio ya no pide confirmación: se hace y se puede deshacer.

## 2026-11-06 · F06 Mi dinero · hecho salvo notificación

- Qué: Mi dinero con patrimonio neto (tienes, debes, rendimiento de cajitas), ojo para ocultar saldos, bancos y billeteras con totales, y "Más usada este mes". Detalle de banco con cuenta, cajitas con rendimiento aproximado y tarjetas con cupo disponible, corte y pago; cambiar nombre, ocultar y borrar banco. Agregar a un banco (cuenta, débito, crédito, bolsillo) que solo acepta 4 dígitos, y la misma hoja para editar o ajustar el saldo de hoy. "+ Banco" con sugerencias y color (solo color e iniciales, sin logos). ¿Con qué pagaste? dentro de Agregar con tarjeta, cuenta o efectivo y forma de pago (Apple Pay, física, en línea). Transferir y pagar tarjeta sin contar como gasto. Mi dinero vacío. Pago de tarjetas en Inicio 7 días antes.
- Archivos: ios/MProgress/Domain/Wallet.swift, Records.swift (dueDay), Data/Stores/MoneyStore.swift (ProductDraft, update, cash, borrar), Data/Stores/LedgerStore.swift, Features/Money/*, Features/AddEntry/*, Features/Home/HomeView.swift, App/RootView.swift; pruebas WalletTests, CardDueTests y WalletStoreTests.
- Verificado: 67 pruebas de dominio en Linux y 97 en Xcode, todas en verde.
- Pendiente: notificación del pago de tarjeta (F07-02). Ajustar el saldo de un producto lo toma como saldo de hoy; los movimientos anteriores dejan de moverlo.

## 2026-11-06 · F05 Resumen · hecho

- Qué: periodo (este mes, 3, 6 y 12 meses, personalizado con dos fechas), chips de las categorías con gasto, Ingresos y gastos en barras por mes con Swift Charts, Cómo va tu gasto en línea acumulada contra el mes pasado con la diferencia a la fecha, En qué gastas por categoría, Tu mes normal con cuántos meses quedaron arriba y El mes que viene con los pagos fijos ya programados. Resumen vacío con barras fantasma.
- Archivos: ios/MProgress/Domain/SummaryMath.swift, Features/Summary/SummaryView.swift, Design/Typography.swift (`AppFont.font` para los ejes), App/RootView.swift; pruebas SummaryTests.
- Verificado: 61 pruebas de dominio en Linux y 85 en Xcode, todas en verde. Falta mirarlo en el simulador o en el iPhone.
- Pendiente: con una categoría elegida, Ingresos y gastos muestra solo los gastos de esa categoría (las categorías son de gasto).

## 2026-11-06 · F04 Historial, detalle y calendario · hecho

- Qué: Historial por mes y por día con neto, entradas y salidas, buscador sin tildes que mira nombre, categoría, notas y monto; Historial vacío. Detalle de movimiento con editar (Agregar en modo edición), duplicar hoy y borrar, los tres con aviso "Deshacer" de 5 segundos sobre la barra. Calendario con cuadrícula según el primer día de la semana, puntos de gasto, ingreso y por pagar, total pendiente del mes y detalle del día. Marcar pagado desde Inicio y Calendario con deshacer que regresa la fecha y el estado.
- Archivos: ios/MProgress/Domain/History.swift, Money.swift (AmountInput desde un monto), Data/Stores/LedgerStore.swift (update, duplicate, undoPaid), Features/History/*, Features/Calendar/*, Features/Shared/*, Features/Home/HomeView.swift, App/RootView.swift; pruebas HistoryTests, HistoryStoreTests y AmountInputEditTests.
- Verificado: 55 pruebas de dominio en Linux y 79 en Xcode con el simulador iPhone 18 Pro, todas en verde.
- Pendiente: nada de la fase. Solo el cobro más cercano de un pago fijo se marca desde el calendario; los siguientes salen como "Programado".

## 2026-11-06 · F03 Inicio y Agregar movimiento · hecho salvo detalles

- Qué: Inicio con "Te quedan", barra del mes, accesos rápidos, próximos cargos con Hoy y Pronto y marcar pagado, últimos movimientos, Inicio vacío y menú Más. Agregar en hoja con teclado propio, gasto o ingreso, ciclo (puntual, mensual, anual, cada N días), fecha, categoría con recientes, ícono con iniciales o símbolo y notas. AddPlan decide si se guarda movimiento, pago fijo o ambos.
- Archivos: ios/MProgress/Domain/AddPlan.swift, Features/Home/*, Features/AddEntry/*, Design/Components/Skeleton.swift; pruebas AddPlanTests y AddEntryTests.
- Verificado: 67 pruebas en Xcode en verde.
- Pendiente: pestaña Color en el selector de ícono (F03-04) y usar Cargando cuando exista sincronización (F03-06).

## 2026-11-06 · F02 Bienvenida y onboarding · hecho

- Qué: Bienvenida, ingreso y día de pago con teclado propio, gastos fijos sugeridos editables, intereses y carrusel según intereses. Al terminar crea los pagos fijos y no vuelve a salir; en compilaciones de prueba se reinicia desde Ajustes.
- Archivos: ios/MProgress/Domain/OnboardingPlan.swift, Features/Onboarding/*, App/MProgressApp.swift; pruebas OnboardingPlanTests y OnboardingTests.
- Verificado: pruebas en Xcode en verde.

## 2026-11-06 · F01 Dominio, modelos, base local y stores · hecho

- Qué: Money y teclado de montos, ciclos con ancla (fin de mes y 29 de febrero), urgencia, resumen del mes, próximos cargos, gasto por categoría, mes normal, saldos de cuentas, débito y crédito, patrimonio y rendimiento de cajitas. 12 modelos SwiftData con borrado suave y syncState, contenedor en App Group con respaldo a la carpeta normal, usuario local en el llavero, semilla de Personal y 15 categorías con ids fijos, LedgerStore y MoneyStore.
- Archivos: ios/MProgress/Domain/*, ios/MProgress/Data/**, ios/MProgressTests/Domain/*, ios/MProgressTests/Data/StoreTests.swift, ios/Package.swift.
- Verificado: 36 pruebas de dominio en Linux con Swift 6.1 (`swift test --package-path ios`) y 47 pruebas en Xcode con el simulador iPhone 18 Pro, todas en verde.
- Pendiente: el App Group se activa cuando Juan firme (F00-02); mientras, la base vive en la carpeta normal de la app.

## 2026-11-06 · F00-03 a F00-06 Diseño base y CI · hecho salvo CI

- Qué: tokens con tema claro y oscuro, fuente Archivo variable (pesos y ancho 112,5 % para cifras) con Dynamic Type, vidrio con 4 niveles guardados en Ajustes y Reducir transparencia, componentes (botones, tarjeta, fila, control segmentado, chip, insignia, baldosa, avatar, estado vacío, firma) y catálogo en `#Preview`. Workflow de CI con un trabajo de dominio en Linux y otro de app en macOS.
- Archivos: ios/MProgress/Design/**, ios/MProgress/App/*, ios/MProgress/Resources/Fonts/*, .github/workflows/ios.yml.
- Verificado: compila y pasa en Xcode.
- Pendiente: Juan crea `.github/workflows/ios.yml` (la carpeta .github no se puede escribir de forma remota) y confirma el CI en verde en GitHub.

## 2026-11-06 · F00-02 Proyecto Xcode y esqueleto Android · en curso

- Qué: `ios/MProgress.xcodeproj` (iOS 26, Swift 6 estricto, carpetas sincronizadas, target de pruebas con Swift Testing), tokens de color, vidrio con niveles y barra de 5 pestañas. `android/` con Compose, los mismos tokens y la barra.
- Verificado: pendiente compilar en Xcode y en Android Studio en el Mac de Juan.
- Pendiente: Juan elige su equipo de firma en Xcode (Signing & Capabilities). App Group y fuente Archivo quedan para F00-03.

## 2026-11-06 · F00-01 Diseño, migración y documentación · hecho

- Qué: diseño completo de iPhone (41 pantallas), migración inicial de Supabase con seguridad por fila, prueba de seguridad y documentación para trabajar con cualquier modelo.
- Archivos: AGENTS.md, CLAUDE.md, GEMINI.md, HANDOFF.md, README.md, docs/FASES.md, docs/PANTALLAS.md, docs/BITACORA.md, docs/diseno/MProgress_diseno_iPhone.pdf, supabase/migrations/20261106000000_init.sql, supabase/tests/rls_smoke.sql.
- Verificado: la migración corre completa en PostgreSQL 16 con un esquema de prueba que imita Supabase; la prueba de seguridad confirma que la pareja comparte gastos y un tercero no ve ni escribe nada.
- Commit: primer commit del repo.
- Pendiente: F00-02, Juan crea el proyecto en Xcode.
