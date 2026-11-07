# MProgress · Fases y tickets

Estado: `[ ]` pendiente · `[~]` en curso o bloqueado (ver bitácora) · `[x]` hecho y verificado.
Cada ticket se cierra solo cuando cumple su criterio y el build con pruebas está en verde.
Las pantallas citadas están en `docs/PANTALLAS.md` y en el PDF de diseño.

**Fase en curso (2026-11-06): F10 en iPhone y F14 (Android) en paralelo.** F12B (pasos 1 a 4 de `docs/PLAN_F12B.md`) está hecho en iPhone y en curso en Android. F08 espera SMS reales; F00-06 espera el archivo del CI; widgets con datos, iCloud y Apple Watch esperan la cuenta paga de Apple.

Android dejó de ser un esqueleto: app real en `android/` (Kotlin, Compose, Archivo, mismos tokens y pantallas que iOS), con APKs de prueba (0.1 a 1.2). Ver F14 abajo.

---

## F00 · Base del proyecto

Objetivo: el proyecto compila, tiene el sistema de diseño y la barra de pestañas de vidrio.

- [x] F00-01 Diseño completo, migración SQL y documentación del repo. Criterio: archivos en `docs/` y `supabase/`.
- [~] F00-02 Crear `ios/MProgress.xcodeproj`: app iOS 26, Swift 6 estricto, bundle `com.olarte.mprogress`, target `MProgressTests` con Swift Testing, App Group `group.com.olarte.mprogress`. **Parada:** Juan crea el proyecto en Xcode y elige su equipo de firma. Criterio: compila vacío en simulador e iPhone.
- [x] F00-03 `Design/Tokens.swift` y `Design/Typography.swift`: colores oscuro y claro, estilos de texto, espaciado, radios y sombras de HANDOFF 10. Fuente Archivo en `Resources/Fonts` con su licencia OFL. Criterio: vista de catálogo en `#Preview` con todos los tokens.
- [x] F00-04 Componentes base en `Design/Components/`: PrimaryButton, SecondaryButton, Card, ListRow, SegmentedPill, Chip, Badge, IconTile, Avatar, SectionLabel, SignatureFooter. Criterio: cada uno con `#Preview` y objetivo táctil de 48.
- [x] F00-05 `Design/Glass.swift` y `App/RootView.swift`: barra de pestañas flotante de vidrio con 5 pestañas vacías (Inicio, Resumen, Dinero, Calendario, Ajustes), 4 niveles de transparencia y Reducir transparencia. Criterio: cambia de pestaña, se ve igual al PDF.
- [~] F00-06 CI en `.github/workflows/ios.yml`: build y pruebas en cada push y PR. Criterio: CI en verde en `main`.

## F01 · Datos locales y dominio

Objetivo: modelos, cálculos y pruebas, sin pantallas.

- [x] F01-01 `Domain/Money.swift`: tipo Money, suma, resta, formato por moneda (COP sin decimales) y lectura desde el teclado numérico. Criterio: 10 pruebas o más.
- [x] F01-02 `Domain/Cycle.swift`: próxima fecha para puntual, semanal, mensual (fin de mes), anual (29 de febrero) y cada N días. Criterio: pruebas de todos los casos de HANDOFF 8.2.
- [x] F01-03 Modelos SwiftData de HANDOFF 8.1 en `Data/Models/` con id, fechas, borrado suave y syncState, compatibles con iCloud. Criterio: crear, leer y borrar en una prueba en memoria.
- [x] F01-04 `Data/Persistence/`: contenedor en el App Group, usuario local en el llavero, semilla con espacio Personal y las 15 categorías globales de la migración. Criterio: primera apertura crea la semilla una sola vez.
- [x] F01-05 `Data/Stores/`: stores por agregado que ponen updatedAt y syncState, con borrado suave y deshacer. Criterio: pruebas de cada store.
- [x] F01-06 `Domain/BalanceCalculator.swift` y afines: te quedan este mes, próximos cargos con urgencia, gasto por categoría, mes normal, saldo de producto, patrimonio y rendimiento de cajita. Criterio: 30 pruebas o más en verde.

## F02 · Bienvenida y onboarding

- [x] F02-01 Bienvenida (pantalla 14). Criterio: igual al PDF, "Empezar" lleva al paso 1.
- [x] F02-02 Ingreso y día de pago con teclado propio (pantalla 15). Criterio: crea un Recurring de ingreso; "Prefiero no decirlo" lo salta.
- [x] F02-03 Gastos fijos con sugerencias editables (pantalla 16). Criterio: crea los Recurring marcados; "Agregar otro" abre Agregar.
- [x] F02-04 Intereses (pantalla 17). Criterio: guarda la selección.
- [x] F02-05 Carrusel de funciones según intereses (pantalla 18). Criterio: muestra solo lo elegido; "Ahora no" lo salta.
- [x] F02-06 Guardar que el onboarding terminó y no volver a mostrarlo. Criterio: se puede reiniciar desde Ajustes en compilaciones de prueba.

## F03 · Inicio y Agregar movimiento

- [x] F03-01 Inicio: selector de cuenta, "Te quedan", barra del mes y accesos rápidos (pantalla 1). Criterio: el número coincide con BalanceCalculator.
- [x] F03-02 Próximos cargos agrupados por urgencia con marcar pagado. Criterio: Hoy, Pronto y Próximas con sus colores.
- [x] F03-03 Agregar movimiento en hoja: teclado, gasto o ingreso, ciclo, fecha, categoría, cuenta y notas (pantalla 7). Criterio: guarda Entry o Recurring según el ciclo.
- [~] F03-04 Selecciona ícono: Símbolos, Color y Marcas con iniciales (pantalla 8). Criterio: buscador funciona. Hecho: iniciales y símbolos con buscador en español. Falta: pestaña Color.
- [x] F03-05 Categoría con recientes y todas (pantalla 9). Criterio: recientes según uso.
- [~] F03-06 Inicio vacío y Cargando (pantallas 38 y 41). Criterio: se ven sin datos y mientras carga; Cargando quieto con Reducir movimiento. Hecho: Inicio vacío y `HomeSkeleton`. Falta: mostrar Cargando cuando llegue la sincronización (F10), hoy la base local carga al instante.
- [x] F03-07 Menú Más con solo las acciones de fases ya hechas (pantalla 20).

## F04 · Historial, detalle y calendario

- [x] F04-01 Historial por mes con total y buscador (pantalla 11).
- [x] F04-02 Detalle de movimiento: editar, duplicar y borrar con deshacer (pantalla 23).
- [x] F04-03 Historial vacío (pantalla 39).
- [x] F04-04 Calendario con puntos por día y detalle del día (pantalla 12).
- [x] F04-05 Marcar pagado desde calendario y detalle mueve la próxima fecha. Criterio: prueba del flujo completo.

## F05 · Resumen

- [x] F05-01 Filtro de periodo (este mes, 3, 6, 12 meses, personalizado) y chips de categoría (pantalla 10).
- [x] F05-02 Ingresos y gastos en barras con Swift Charts.
- [x] F05-03 Cómo va tu gasto (línea) y En qué gastas (barras por categoría).
- [x] F05-04 Tu mes normal, El mes que viene y día a día contra el mes pasado. Criterio: cifras iguales a las del dominio, accesibles con VoiceOver.

## F06 · Mi dinero

- [x] F06-01 Mi dinero: patrimonio, bancos y billeteras, ocultar saldos (pantalla 31).
- [x] F06-02 Detalle de banco: cuentas, bolsillos o cajitas con rendimiento aprox. y tarjetas (pantalla 32).
- [x] F06-03 Agregar a un banco: cuenta, débito, crédito o bolsillo (pantalla 33). Criterio: solo acepta 4 dígitos.
- [x] F06-04 ¿Con qué pagaste? dentro de Agregar, con su efecto en saldos (pantalla 34).
- [x] F06-05 Transferencias entre productos y pago de tarjeta. Criterio: no cuentan como gasto.
- [x] F06-06 Mi dinero vacío (pantalla 40).
- [x] F06-07 Aviso de fecha de pago de cada tarjeta de crédito. Tarjeta "Pago de tarjetas" en Inicio 7 días antes y notificación con los días antes por defecto (F07-02).

## F07 · Avisos, límites y ahorro

- [x] F07-01 Pedir permiso de notificaciones en el momento justo (al crear el primer aviso), no al abrir.
- [x] F07-02 Avisos locales de pagos fijos de 0 a 14 días antes y a la hora elegida (pantalla 3, versión personal). Incluye el pago de tarjetas y el resumen semanal. "¿A quién aviso?" y el reloj quedan para F11 y F12.
- [x] F07-03 Pantalla Avisos con lista y ajustes (pantalla 22).
- [x] F07-04 Límites total y por categoría con aviso al 80 y 100 % (pantalla 27).
- [x] F07-05 Ahorro: metas, aportes y vínculo con una cajita (pantalla 26).

## F08 · Registro automático

Parada: necesita el iPhone de Juan y SMS reales.

- [~] F08-01 App Intent "Registrar gasto" con monto, comercio, últimos 4 y fuente. Criterio: se puede llamar desde Atajos. Hecho: `LogExpenseIntent` y `LogSmsIntent` con frases de Siri, busca la tarjeta por sus 4 dígitos y evita duplicados de Apple Pay y SMS. Falta: probarlo en el iPhone de Juan.
- [~] F08-02 Atajo de Wallet (disparador Transacción) y guía paso a paso dentro de la app. Criterio: pagar con Apple Pay crea el gasto con su tarjeta. Hecho: guía paso a paso en Registro automático. Falta: pago real con Apple Pay.
- [~] F08-03 Lector de SMS: el atajo de Mensajes envía el texto, la app extrae monto, comercio y últimos 4 por banco; si no está segura, queda "Revisar". Criterio: pruebas con al menos 5 SMS reales por banco. Hecho: `SmsParser` con reglas generales y pruebas con ejemplos de la forma de los SMS. Falta: los SMS reales de Juan (HANDOFF 14.4) como pruebas.
- [x] F08-04 Pantalla Registro automático (pantalla 35). Fuentes, últimos detectados con Revisar o Guardado, probador de SMS con monto, comercio y tarjeta resaltados.
- [~] F08-05 Escanear recibo con la cámara y crear un borrador. Hecho: cámara de documentos o Fotos, texto con Vision en el iPhone, total y comercio con `ReceiptParser`, borrador en Agregar. Falta: probar con recibos reales en el iPhone.

## F09 · Ajustes, apariencia y respaldo

- [x] F09-01 Ajustes con firma al pie (pantalla 13). "Escríbeme" espera el correo de soporte que defina Juan; "Califica la app" llega al publicar.
- [x] F09-02 Apariencia: tema oscuro, claro y sistema (cambia al instante), vidrio Liquid Glass de Apple con 4 opciones (Como iOS, Clara, Tintada, Sólida) y Seguir a iOS (pantalla 5).
- [x] F09-03 Moneda por cuenta (pantalla 28).
- [x] F09-04 Ícono de la app (pantalla 29): 4 símbolos naranja (Trazo es el principal; Anillo, Progreso y Barras) con fondo negro o blanco. Igual en Android con alias del lanzador.
- [x] F09-05 Bloqueo con Face ID al abrir (con código del iPhone como respaldo).
- [~] F09-06 Respaldo: archivo cifrado automático en iCloud Drive, exportar e importar `.mprogress` y CSV (pantalla 4). Criterio: restaurar en un iPhone limpio deja todo igual. Hecho: respaldo cifrado diario (AES-GCM, llave en el llavero de iCloud) en Archivos › MProgress › Respaldos, exportar `.mprogress` y CSV, restaurar con prueba de iPhone limpio en verde. Falta: mover la carpeta a iCloud Drive cuando la app tenga firma (F00-02).
- [x] F09-07 Novedades (pantalla 30).

## F10 · Cuenta y sincronización

Plan detallado: `docs/PLAN_F10.md` (cifrado de extremo a extremo: Supabase solo guarda sobres cifrados).

- [x] F10-01 Proyecto Supabase en East US (ver `supabase/PROYECTO.md`), migraciones init y f12b aplicadas, RLS verificada. La migración f10 (sobres y llaves) está escrita y probada en local; se aplica al compilar el bloque 2.
- [~] F10-02 Entrar con correo y enlace mágico (PKCE, `mprogress://auth-callback`) y "Seguir sin cuenta". Apple y Google cuando haya cuenta paga y cliente OAuth. En curso en iPhone.
- [~] F10-03 Motor de sincronización de HANDOFF 9 con pruebas de conflicto y de borrado. Hecho: `SyncEngine` (subir en lotes y en orden, bajar por cursor, gana el `updatedAt` más reciente, 3 intentos y luego error) y el estado de la pastilla, con pruebas contra un servidor falso. Falta: conectar SwiftData (LocalSyncStore) y Supabase (RemoteSyncStore) cuando exista el proyecto (F10-01).
- [~] F10-04 Indicador sin conexión, hoja de estado y marcas de pendiente (pantallas 36 y 37). Hecho en iPhone y Android (APK 1.3): pastilla solo con cuenta ("Al día", "Sincronizando…", "Sin conexión · N pendientes", "Error al sincronizar") con `NWPathMonitor` / `NetworkCallback`; al tocarla, hoja "Estado de sincronización" (conexión, "Hace 2 min", pendientes por tipo, último error con Reintentar y dispositivos con acceso); reloj y "Pendiente" en los movimientos de Inicio e Historial que no han subido; reintento al volver el internet, al volver a la app y tras un error con espera de 5 s a 5 min (`SyncBackoff`). Lógica pura en `Domain/SyncStatusText.swift` y `domain/SyncStatusText.kt`. Falta: compilar iOS en Xcode y probar en los teléfonos.
- [~] F10-05 Al iniciar sesión, subir los datos locales a la cuenta sin duplicar. Hecho en iPhone y Android (APK 1.3): primera subida por espacio y usuario (`InitialUpload` en `Domain/InitialUpload.swift` y `domain/InitialUpload.kt`): baja todo primero, sube solo lo que la nube no tiene o lo que cambió aquí después, une categorías propias y reglas de comercio repetidas por clave estable (las referencias pasan al id de la nube y el duplicado se borra sin subir), los ajustes del espacio vienen de la nube, avance "Subiendo tus datos: 120 de 340" y "Tus datos ya están en la nube, cifrados". Falta: compilar iOS en Xcode y probar con dos teléfonos contra Supabase real.
- [ ] F10-06 Borrar cuenta y todos los datos desde Ajustes.

## F11 · Pareja y familia

- [ ] F11-01 Cuentas y espacios, y Nueva cuenta (pantallas 24 y 25).
- [ ] F11-02 Invitar con código, QR o enlace, y unirse con `accept_invite`.
- [ ] F11-03 Espacio en pareja: total, quién pagó, saldo entre ustedes y saldar (pantalla 2).
- [ ] F11-04 Dividir gastos 50/50, por porcentaje o por montos.
- [ ] F11-05 Avisos dirigidos (pantalla 3): función en Supabase con cron que envía push por APNs a todos, a una persona o al responsable.
- [ ] F11-06 Tiempo real: los gastos de la pareja aparecen al instante.
- [ ] F11-07 Metas de ahorro conjuntas con aporte de cada uno.

## F12 · Widgets, Apple Watch y asistente

- [~] F12-01 Widgets pequeño, mediano y grande (pantalla 6). Hecho: Próximo cargo, Te quedan con + Gasto y 4 cargos, Calendario de cobros, con la app escribiendo el resumen (`WidgetPublisher`). Falta: App Group, que pide la cuenta paga de Apple; sin él los widgets muestran "Abre MProgress".
- [~] F12-02 Pantalla bloqueada y StandBy. Hecho: anillo, rectangular e inline. Falta: datos con App Group.
- [~] F12-03 Widgets interactivos: + Gasto y marcar pagado. Hecho: + Gasto abre el registro rápido y el botón "Registro rápido" en el Centro de control. Falta: marcar pagado desde el widget (necesita App Group y la base compartida).
- [ ] F12-04 Widget del hogar.
- [ ] F12-05 Apple Watch: resumen, registrar gasto y complicación.
- [ ] F12-06 Asistente con IA (pantalla 21): ayuda a manejar la app, hace las cosas por la persona y le explica. Ideas de Juan (2026-11-07): responde sobre sus datos ("¿cuánto gasté en comida?", "¿me alcanza para el arriendo?"), registra y edita con una frase o por voz ("pagué 45 mil de almuerzo con la Visa"), crea pagos fijos, metas y límites, explica conceptos (cupo, corte, intereses, cuotas) con sus propios números, y guía paso a paso por las pantallas. Siempre muestra lo que va a hacer y pide confirmación antes de guardar. Decisión de arquitectura por tomar en el ticket: en el teléfono (Foundation Models de Apple en iOS 26, Gemini Nano en Android) para que los datos no salgan del cifrado, y un modo en servidor (Claude por una función de Supabase) solo si la persona lo activa, porque el servidor vería los datos descifrados.

---

## F12B · Mejoras antes de F10 (`docs/PLAN_F12B.md`)

- [x] iPhone, paso 2: varios efectivos, pagos con cuotas o fecha final, avisos en dos niveles con permiso en el momento justo, fecha y hora fáciles, puntos por tarjeta.
- [x] iPhone, paso 3: doble toque sin abrir la app con Live Activity en la isla y Deshacer; frases de Siri.
- [x] iPhone, paso 4: predicciones (así vas a terminar el mes, los próximos 3 meses, aviso en Inicio).
- [~] Android, pasos 1 a 4: hecho hasta el 0.7 (pagos fijos completos, detalle, categorías, avisos, huella, monedas, respaldo, transferir, límites, ahorro, puntos, varios efectivos). Falta: escáner, notificaciones de Wallet y bancos, botón de ajustes rápidos, widgets y predicciones.

## F14 · Android nativo

- [x] F14-01 Dominio en Kotlin igual al de iOS, con pruebas JVM.
- [x] F14-02 Todas las pestañas y pantallas con el mismo diseño de iOS (verificado con capturas Robolectric).
- [~] F14-03 Paridad de funciones (ver F12B).
- [~] F14-04 Cuentas, nube y cifrado con los mismos formatos de iOS (F10). Hecho en el APK 1.0: enlace mágico con PKCE, sesión y llaves cifradas con el Android Keystore, sobres AES-GCM y llaves X25519 iguales byte por byte a iOS (vectores en `android/app/src/test/vectors`), sincronización con PostgREST, código de recuperación, aprobar dispositivos y borrar la cuenta remota. Falta: probar en el teléfono de Juan contra Supabase real y con el iPhone.
- [x] F14-06 Nombres de comercios, montos editables (Pagar tarjeta, Marcar pagado, Transferir) y pagos fijos cada N meses en iPhone y Android (APK 1.2). Compilado en Xcode (232 pruebas), instalado en el iPhone, migración `20261109000000_interval_months.sql` aplicada. También: arreglar el sueldo en Inicio arregla el movimiento ya anotado.
- [x] F14-05 Dos versiones del APK: `estandar` (sin SMS ni lector de notificaciones, para que Play Protect no bloquee la instalación) y `completo` (todo el registro automático, se instala desde el Mac).
- [~] F14-07 Tarjetas de crédito a fondo en iPhone y Android (`docs/PLAN_TARJETAS.md`): corte, fecha de pago, cuotas, avances, mínimo y total, cupo disponible, pagos parciales, simuladores y catálogo de tarjetas por banco. Hecho: dominio con pruebas iguales en las dos plataformas, catálogo de 19 bancos y migración escrita. Falta: campos nuevos en los modelos y las pantallas.
- [~] F14-08 Quién te debe en iPhone y Android: deudas con otras personas (me debe, le debo), abonos con historia, saldadas plegadas, detalle por persona con neto, "Recordarle" con la hoja de compartir, aviso el día antes de la fecha límite y cuenta opcional que mueve el saldo con una transferencia contra un producto que no existe (no cuenta como gasto ni ingreso). Respaldo y nube (entidades `debts` y `debt_payments` en `sync_records`, sin tabla nueva). Hecho en Android con pruebas y capturas 18a a 18e; falta compilar iOS en Xcode.
- [~] F14-09 Bloquear después de (como WhatsApp): Inmediatamente, 30 segundos o 1 minuto, por dispositivo; en frío siempre bloquea y fuera de la app siempre queda tapada. Falta compilar iOS y probar en los teléfonos.
- [~] F14-10 Bolsillo y Cajita como tipos aparte (`cajita` con tasa E.A. y rendimiento, cuenta como plata disponible). Migración `20261112000000_cajita.sql` escrita (no hace falta: la app sincroniza por `sync_records`). Falta compilar iOS.

## Después de F12 (por planear, no se programa todavía)

- F11B Modo negocio: un espacio tipo negocio con ventas y gastos, clientes y proveedores, cuentas por cobrar y por pagar, resultado del mes y exportar para el contador (pensado para GestandoValor). Va después de F11 porque reutiliza los espacios.
- F13 Premium: qué es básico y qué es pago, precios, StoreKit 2 y paywall (pantallas 19 y 18 ajustadas). Encuesta de salida del paywall (idea de Juan, 2026-11-07): si alguien abre la pantalla de pago varias veces (por ejemplo 3 en una semana) sin comprar, una ventana corta pregunta qué lo frena (precio, no entiendo qué incluye, no lo necesito todavía, prefiero pago único, otro con texto). Una sola vez cada 30 días, con "No preguntar más". Respuestas anónimas, sin datos financieros y separadas de los datos cifrados, en una tabla propia de Supabase con un panel para analizarlas por versión, precio mostrado y país.
- F15 iPad y Mac.
- F16 Windows y Wear OS.
- F17 Publicación: política de privacidad, términos, App Store Connect.
