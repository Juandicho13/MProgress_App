# MProgress · Bitácora

Una entrada por ticket, la más nueva arriba. Plantilla en `HANDOFF.md` 11.3.

## 2026-11-07 · F10 bloques 2 y 3: cuenta, sincronización cifrada, recuperación y dispositivos · en curso

- Qué:
  - Entrar con enlace mágico y PKCE (`Data/Cloud/AuthClient.swift`): `POST /auth/v1/otp` con `create_user`, `code_challenge` S256 y `redirect_to=mprogress://auth-callback`; RootView recibe `?code=` y lo cambia por la sesión (`grant_type=pkce`). La sesión vive en el llavero (solo este dispositivo) y se renueva sola un minuto antes de vencer. El código de 6 dígitos queda listo detrás de `CloudConfig.allowsCodeEntry` (apagado hasta tener SMTP propio).
  - Configuración en un solo archivo (`Data/Cloud/CloudConfig.swift`): URL y publishable key de `supabase/PROYECTO.md`.
  - Sincronización (`Data/Cloud/CloudAccount.swift`, `CloudAPI.swift`, `Data/Sync/SwiftDataSyncStore.swift`): el espacio Personal de la nube pasa a ser el de los datos locales; este iPhone se registra con su llave pública; el primer dispositivo crea la llave del espacio, la envuelve para sí y para el código de recuperación y lo muestra ("Ya lo guardé"); los siguientes esperan aprobación o usan el código. Sobres por PostgREST con el `SyncEngine` de siempre. Sincroniza al abrir, al volver a primer plano, 3 segundos después de guardar y con "Sincronizar ahora"; sin conexión se acumula. Bajar dos veces el mismo cambio no escribe nada.
  - Pantallas: Ajustes › Cuenta y nube (correo, enlace, estado, sincronizar, reintentar, dispositivos, código nuevo, cerrar sesión), código de recuperación, escribir el código, dispositivos (aprobar y quitar) y el aviso "¿Apruebas tu otro dispositivo?" en cualquier pantalla. Pastilla "Sin conexión · N cambios sin sincronizar" en Inicio.
  - Borrar cuenta y datos: primero `delete_my_account` en la nube (si falla, no se borra nada) y luego todo lo local, llavero incluido.
  - El respaldo y la nube usan las mismas filas (`Data/Backup/BackupRows.swift`).
- Archivos: ios/MProgress/Data/Cloud/{CloudConfig,Keychain,SupabaseHTTP,AuthClient,CloudAPI,CloudAccount}.swift, Data/Sync/SwiftDataSyncStore.swift, Data/Backup/BackupRows.swift y BackupService.swift, Data/Account/AccountEraser.swift, Domain/ServerTime.swift, Features/Settings/AccountView.swift y SettingsView.swift, Features/Home/HomeView.swift, App/RootView.swift, App/MProgressApp.swift; pruebas MProgressTests/Domain/ServerTimeTests.swift y MProgressTests/Data/CloudSyncTests.swift; docs/PLAN_F10.md.
- Verificado: 144 pruebas de dominio en Linux. Falta compilar en Xcode, aplicar `20261108000000_f10.sql` en el proyecto real y probar con dos iPhone o un iPhone y el simulador.
- Pendiente: Sign in with Apple y Google (cuenta paga y cliente OAuth); quitar un dispositivo no cambia la llave del espacio (para eso habría que cifrar todo otra vez).

## 2026-11-07 · F10 bloque 1: migración y cifrado de extremo a extremo · en curso

- Qué:
  - Migración `supabase/migrations/20261108000000_f10.sql`: `devices.public_key`, `sync_records` (sobres cifrados con `changed_at` del teléfono y `updated_at`/`updated_by` que pone el servidor; un cambio más viejo no pisa uno más nuevo), `space_keys` (una por dispositivo y una de recuperación con `device_id` null, única por espacio), `device_in_space` para no envolver llaves para extraños y `delete_my_account`. Todo con RLS por miembro del espacio. Se puede correr dos veces.
  - Dominio (`Domain/E2EE.swift`): protocolo `CryptoProvider`, envolver la llave del espacio entre dos X25519 (con la pública del que comparte dentro y verificación de que es de la cuenta), código de recuperación (24 caracteres base32 sin ambiguos, en grupos de 4) y su llave, sobres AES-GCM con "espacio|entidad|id", PKCE (S256). `Domain/EncryptedSync.swift`: `SyncEnvelope`, `EnvelopeTransport` y `EncryptedRemote`, que cifra al subir y descifra al bajar con el `SyncEngine` de siempre. El motor ahora usa la hora del servidor como cursor y sincroniza también los puntos (`reward_programs`).
  - CryptoKit en `Data/Crypto/CryptoKitProvider.swift`.
  - Formato exacto para Android en `docs/PLAN_F10.md`.
- Archivos: supabase/migrations/20261108000000_f10.sql, supabase/tests/rls_f10.sql, ios/MProgress/Domain/E2EE.swift, EncryptedSync.swift, Sync.swift, ios/MProgress/Data/Crypto/CryptoKitProvider.swift; pruebas MProgressTests/Domain/E2EETests.swift (con un cifrador falso) y MProgressTests/Data/CryptoKitProviderTests.swift (con CryptoKit, incluye el ejemplo de PKCE del RFC 7636); docs/PLAN_F10.md.
- Verificado: 141 pruebas de dominio en Linux; las cuatro migraciones, `rls_smoke.sql` y `rls_f10.sql` en Postgres 16 local. La migración no se aplicó al proyecto real (lo hace el coordinador).
- Pendiente: bloque 2 (enlace mágico con PKCE, sesión en el llavero, Ajustes › Cuenta) y bloque 3 (sincronización con PostgREST, código de recuperación, aprobar dispositivos, borrar cuenta remota).

## 2026-11-06 · F12B Paso 4 iOS Predicciones (bloque 3) · en curso

- Qué: funciones puras en `Domain/Forecast.swift`: `variablePace` (gasto del mes sin `recurringId` entre el día del mes, mínimo 1), `endOfMonth` / `projectedEndOfMonth` (te quedan − ritmo × días que faltan, de `monthSummary`), `variableAverage` (promedio de los últimos 3 meses completos con gasto variable, buscando hasta 12 atrás) y `nextMonths(3)` (ingresos fijos, gastos fijos con fecha final y cuotas, y variable estimado: el promedio o, si no hay, ritmo × días del mes; `net = ingresos − fijos − variable`). Alerta "A este ritmo terminas el mes en − $ X" solo si la proyección es negativa.
- Pantallas: Resumen con la tarjeta "Así vas a terminar" (arriba, no depende del periodo ni del filtro) y la sección "Los próximos 3 meses" con barras de ingresos, fijos y variable, y lo que quedaría o faltaría cada mes. Inicio muestra la alerta bajo "Te quedan" solo cuando la proyección es negativa.
- Archivos: ios/MProgress/Domain/Forecast.swift (nuevo), Features/Summary/SummaryView.swift, Features/Home/HomeView.swift; pruebas MProgressTests/Domain/ForecastTests.swift.
- Verificado: 131 pruebas de dominio en Linux. No depende del bloque 2. Falta compilar en Xcode junto con el bloque 2.
- Pendiente: compilar y mirar en el iPhone de Juan.

## 2026-11-06 · F12B Paso 3 iPhone (bloque 2) · en curso

- Qué:
  - Registro rápido sin abrir la app: `QuickAddIntent` es `LiveActivityIntent` con `supportedModes = [.background, .foreground(.dynamic)]`. Pide el monto con el cuadro del sistema (`requestValue`), luego gasto o ingreso, y de dónde sale o a dónde entra (`requestDisambiguation` con los productos que aplican y "Sin elegir"). Guarda y muestra en la isla dinámica y en la pantalla bloqueada "− $ 84.300 · te quedan $ 1.901.100" con Deshacer (`UndoQuickAddIntent`, corre en el proceso de la app), y se cierra sola a los 8 segundos (tarea en segundo plano; al volver a la app se cierran las que quedaron).
  - Ajuste "Abrir la app al anotar" en la guía del doble toque: con él, el mismo atajo abre MProgress en Registro rápido como antes (`continueInForeground`). También queda la acción "Registro rápido en la app" en Atajos.
  - Siri: "Anota en MProgress", "Anota un gasto en MProgress", "Anota un ingreso en MProgress". Siri pregunta el monto ("20 mil").
  - Arreglo del bloque 1: la cuadrícula "Día del mes" escribe en la fecha de Agregar (antes se ignoraba la fecha y fallaban 3 pruebas de AddEntryTests). Un mensual de hoy vuelve a crear el movimiento de hoy enlazado y el fijo desde el mes que viene; el día 31 conserva su ancla.
- Archivos: ios/Shared/QuickAddActivity.swift, ios/MProgressWidgets/QuickAddLiveActivity.swift, ios/MProgress/Intents/QuickAddIntents.swift, ios/MProgress/Data/LiveActivity/QuickAddActivityController.swift, ios/MProgress/Domain/QuickAddMath.swift (nuevos); Intents/LogExpenseIntents.swift, MProgressWidgets/MProgressWidgets.swift, App/MProgressApp.swift, Features/AutoCapture/QuickAddView.swift, Features/AddEntry/AddEntryModel.swift y AddEntryView.swift, ios/MProgress-Info.plist (`NSSupportsLiveActivities`); pruebas QuickAddMathTests y F12BStoreTests (día del mes).
- Verificado: 125 pruebas de dominio en Linux. Falta compilar en Xcode y probar en el iPhone (la isla dinámica no se ve en el simulador igual).
- Límite: una frase de Atajos no puede traer un número ni texto libre, así que "Anota 20 mil de almuerzo en MProgress" no se reconoce de una vez: Siri pregunta el monto después de "Anota en MProgress". El concepto ("almuerzo") se puede pasar desde Atajos con el parámetro Concepto.
- Pendiente: compilar y probar en el iPhone de Juan; bloque 3 (predicciones).

## 2026-11-06 · F12B Paso 2 iOS (bloque 1) · en curso

- Qué:
  - Varios efectivos con nombre propio ("Billetera", "Casa", "Alcancía"), cada uno con su saldo, agrupados en el banco Efectivo de Dinero con "+ Efectivo"; se transfiere entre ellos con Transferir.
  - Pagos con fin: `endDate` (incluida), `totalCount` y `paidCount`. Mes, calendario, próximos y avisos salen de `RecurringEnd.dates`. Marcar pagado suma una cuota; con la última o al pasar la fecha final queda "Terminado" y avisa "Terminaste de pagar X". Textos "Cuota 3 de 12" y "Hasta 15 mar 2027". Agregar y editar tienen "Termina": Nunca, Fecha o Cuotas. Un fijo agregado con fecha vieja cuenta como pagadas las cuotas que quedaron atrás (`AddPlan.elapsed`).
  - Avisos en dos niveles: general (activado, 0 a 14 días, hora) y por pago fijo (Como el general, Personalizado, Sin aviso). Un fijo sin aviso propio usa el general. El permiso se pregunta "¿Te aviso antes de cada pago?" al crear el primer pago fijo o al terminar el onboarding con fijos; si lo niega, Ajustes › Avisos explica cómo activarlo y abre Ajustes del iPhone.
  - Fecha fácil: Hoy, Ayer, Mañana y Otra fecha (calendario), hora opcional tras "Agregar hora". Los mensuales nuevos usan "Día del mes" (1 a 31) con "Ya lo pagué este mes" cuando el día ya pasó; editar un mensual también usa la cuadrícula.
  - Puntos por tarjeta: `rewardProgramId` y `pointsPerThousand`; cada gasto suma floor(monto / 1.000 × puntos), editar recalcula, borrar resta.
- Archivos: ios/MProgress/Domain/RecurringEnd.swift y DateChoice.swift (nuevos), Records.swift, BalanceCalculator.swift, History.swift, Planning.swift, Rewards.swift, AddPlan.swift, Wallet.swift, Backup.swift; Data/Models/Models.swift, Data/Stores/LedgerStore.swift, MoneyStore.swift, PlanningStore.swift, AutoCaptureStore.swift, Data/Notifications/NotificationScheduler.swift, Data/Backup/BackupService.swift; Features/Shared/DatePieces.swift (nuevo), AddEntry/AddEntryModel.swift y AddEntryView.swift, Fixed/FixedView.swift y RecurringEditView.swift, Planning/ReminderEditView.swift y AlertsView.swift, Money/ProductFormView.swift, InstitutionDetailView.swift, AddInstitutionView.swift, RewardsSection.swift, Home/HomeView.swift, Calendar/CalendarView.swift, Settings/SettingsView.swift, Onboarding/OnboardingView.swift, App/RootView.swift; pruebas MProgressTests/Domain/RecurringEndTests.swift y MProgressTests/Data/F12BStoreTests.swift; supabase/migrations/20261107000000_f12b.sql (nueva, la inicial ya está aplicada y no se toca); HANDOFF.md 8.
- Verificado: 122 pruebas de dominio en Linux; las dos migraciones y `rls_smoke.sql` en Postgres 16 local (la nueva se puede correr dos veces). Falta compilar en Xcode y las pruebas de datos.
- Decisión tomada: el aviso general aplica a todos los pagos fijos (gastos e ingresos) que no tengan aviso propio, y avisa solo los días antes (sin el recordatorio extra del mismo día).
- Pendiente: compilar en el Mac de Juan; bloques 2 (registro rápido sin abrir la app y Live Activity) y 3 (predicciones).

## 2026-11-06 · F14-A1 Android: primera fase · en curso

- Qué: dominio en Kotlin igual al de iOS (dinero, ciclos, te quedan, próximos cargos, plan de Agregar, pagos fijos, accesos rápidos con el mismo formato de guardado), base local en un archivo JSON privado (`data/Store.kt`, se puede pasar a Room sin tocar pantallas), tema claro y oscuro con los mismos tokens, Inicio, Agregar con monto resaltado y teclado, Más acciones con lápiz y 3 fijadas, Pagos fijos con Pagado, onboarding (ingreso, bancos y tarjetas con últimos 4, fijos con Agregar otro, fechas y con qué se paga con Más tarde), Ajustes con Apariencia que cambia al instante, Borrar cuenta y datos y la firma oficial. Texto blanco sobre la brasa.
- Verificado: `./gradlew assembleDebug testDebugUnitTest` en Linux con el SDK 37: compila y pasan 10 pruebas de dominio.
- Pendiente (A2): Resumen, Dinero (bancos y saldos), Calendario, historial, límites, ahorro, avisos y widgets de Android; probar en un teléfono o emulador.

## 2026-11-06 · Ajustes pedidos por Juan (segunda ronda) · en curso

- Qué: texto blanco sobre naranja (la brasa pasa a #F55F1F para que el blanco tenga contraste); Más acciones con lápiz para ordenar y fijar 3 accesos rápidos en Inicio (`Domain/QuickActions.swift`); Registro automático muestra "Configurado" cuando el atajo llega a la app o el usuario lo confirma (`AutoSetup`); Ajustes › Cuenta › Borrar cuenta y datos (`Data/Account/AccountEraser.swift`); firma con la forma oficial (skill firma-juan-olarte-dev), centrada al final; Apariencia aplica el tema en todas las ventanas al instante, niveles de vidrio más marcados y "Seguir a iOS" como interruptor.
- Verificado: 103 pruebas de dominio en Linux; pruebas de Xcode en el simulador.
- Pendiente: Juan elige el ícono (A Anillo, B Trazo, C Progreso, D Barras) para generar las variantes.

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
