# MProgress · Fases y tickets

Estado: `[ ]` pendiente · `[~]` en curso o bloqueado (ver bitácora) · `[x]` hecho y verificado.
Cada ticket se cierra solo cuando cumple su criterio y el build con pruebas está en verde.
Las pantallas citadas están en `docs/PANTALLAS.md` y en el PDF de diseño.

**Fase en curso: F00**

---

## F00 · Base del proyecto

Objetivo: el proyecto compila, tiene el sistema de diseño y la barra de pestañas de vidrio.

- [x] F00-01 Diseño completo, migración SQL y documentación del repo. Criterio: archivos en `docs/` y `supabase/`.
- [ ] F00-02 Crear `ios/MProgress.xcodeproj`: app iOS 26, Swift 6 estricto, bundle `com.olarte.mprogress`, target `MProgressTests` con Swift Testing, App Group `group.com.olarte.mprogress`. **Parada:** Juan crea el proyecto en Xcode y elige su equipo de firma. Criterio: compila vacío en simulador e iPhone.
- [ ] F00-03 `Design/Tokens.swift` y `Design/Typography.swift`: colores oscuro y claro, estilos de texto, espaciado, radios y sombras de HANDOFF 10. Fuente Archivo en `Resources/Fonts` con su licencia OFL. Criterio: vista de catálogo en `#Preview` con todos los tokens.
- [ ] F00-04 Componentes base en `Design/Components/`: PrimaryButton, SecondaryButton, Card, ListRow, SegmentedPill, Chip, Badge, IconTile, Avatar, SectionLabel, SignatureFooter. Criterio: cada uno con `#Preview` y objetivo táctil de 48.
- [ ] F00-05 `Design/Glass.swift` y `App/RootView.swift`: barra de pestañas flotante de vidrio con 5 pestañas vacías (Inicio, Resumen, Dinero, Calendario, Ajustes), 4 niveles de transparencia y Reducir transparencia. Criterio: cambia de pestaña, se ve igual al PDF.
- [ ] F00-06 CI en `.github/workflows/ios.yml`: build y pruebas en cada push y PR. Criterio: CI en verde en `main`.

## F01 · Datos locales y dominio

Objetivo: modelos, cálculos y pruebas, sin pantallas.

- [ ] F01-01 `Domain/Money.swift`: tipo Money, suma, resta, formato por moneda (COP sin decimales) y lectura desde el teclado numérico. Criterio: 10 pruebas o más.
- [ ] F01-02 `Domain/Cycle.swift`: próxima fecha para puntual, semanal, mensual (fin de mes), anual (29 de febrero) y cada N días. Criterio: pruebas de todos los casos de HANDOFF 8.2.
- [ ] F01-03 Modelos SwiftData de HANDOFF 8.1 en `Data/Models/` con id, fechas, borrado suave y syncState, compatibles con iCloud. Criterio: crear, leer y borrar en una prueba en memoria.
- [ ] F01-04 `Data/Persistence/`: contenedor en el App Group, usuario local en el llavero, semilla con espacio Personal y las 15 categorías globales de la migración. Criterio: primera apertura crea la semilla una sola vez.
- [ ] F01-05 `Data/Stores/`: stores por agregado que ponen updatedAt y syncState, con borrado suave y deshacer. Criterio: pruebas de cada store.
- [ ] F01-06 `Domain/BalanceCalculator.swift` y afines: te quedan este mes, próximos cargos con urgencia, gasto por categoría, mes normal, saldo de producto, patrimonio y rendimiento de cajita. Criterio: 30 pruebas o más en verde.

## F02 · Bienvenida y onboarding

- [ ] F02-01 Bienvenida (pantalla 14). Criterio: igual al PDF, "Empezar" lleva al paso 1.
- [ ] F02-02 Ingreso y día de pago con teclado propio (pantalla 15). Criterio: crea un Recurring de ingreso; "Prefiero no decirlo" lo salta.
- [ ] F02-03 Gastos fijos con sugerencias editables (pantalla 16). Criterio: crea los Recurring marcados; "Agregar otro" abre Agregar.
- [ ] F02-04 Intereses (pantalla 17). Criterio: guarda la selección.
- [ ] F02-05 Carrusel de funciones según intereses (pantalla 18). Criterio: muestra solo lo elegido; "Ahora no" lo salta.
- [ ] F02-06 Guardar que el onboarding terminó y no volver a mostrarlo. Criterio: se puede reiniciar desde Ajustes en compilaciones de prueba.

## F03 · Inicio y Agregar movimiento

- [ ] F03-01 Inicio: selector de cuenta, "Te quedan", barra del mes y accesos rápidos (pantalla 1). Criterio: el número coincide con BalanceCalculator.
- [ ] F03-02 Próximos cargos agrupados por urgencia con marcar pagado. Criterio: Hoy, Pronto y Próximas con sus colores.
- [ ] F03-03 Agregar movimiento en hoja: teclado, gasto o ingreso, ciclo, fecha, categoría, cuenta y notas (pantalla 7). Criterio: guarda Entry o Recurring según el ciclo.
- [ ] F03-04 Selecciona ícono: Símbolos, Color y Marcas con iniciales (pantalla 8). Criterio: buscador funciona.
- [ ] F03-05 Categoría con recientes y todas (pantalla 9). Criterio: recientes según uso.
- [ ] F03-06 Inicio vacío y Cargando (pantallas 38 y 41). Criterio: se ven sin datos y mientras carga; Cargando quieto con Reducir movimiento.
- [ ] F03-07 Menú Más con solo las acciones de fases ya hechas (pantalla 20).

## F04 · Historial, detalle y calendario

- [ ] F04-01 Historial por mes con total y buscador (pantalla 11).
- [ ] F04-02 Detalle de movimiento: editar, duplicar y borrar con deshacer (pantalla 23).
- [ ] F04-03 Historial vacío (pantalla 39).
- [ ] F04-04 Calendario con puntos por día y detalle del día (pantalla 12).
- [ ] F04-05 Marcar pagado desde calendario y detalle mueve la próxima fecha. Criterio: prueba del flujo completo.

## F05 · Resumen

- [ ] F05-01 Filtro de periodo (este mes, 3, 6, 12 meses, personalizado) y chips de categoría (pantalla 10).
- [ ] F05-02 Ingresos y gastos en barras con Swift Charts.
- [ ] F05-03 Cómo va tu gasto (línea) y En qué gastas (barras por categoría).
- [ ] F05-04 Tu mes normal, El mes que viene y día a día contra el mes pasado. Criterio: cifras iguales a las del dominio, accesibles con VoiceOver.

## F06 · Mi dinero

- [ ] F06-01 Mi dinero: patrimonio, bancos y billeteras, ocultar saldos (pantalla 31).
- [ ] F06-02 Detalle de banco: cuentas, bolsillos o cajitas con rendimiento aprox. y tarjetas (pantalla 32).
- [ ] F06-03 Agregar a un banco: cuenta, débito, crédito o bolsillo (pantalla 33). Criterio: solo acepta 4 dígitos.
- [ ] F06-04 ¿Con qué pagaste? dentro de Agregar, con su efecto en saldos (pantalla 34).
- [ ] F06-05 Transferencias entre productos y pago de tarjeta. Criterio: no cuentan como gasto.
- [ ] F06-06 Mi dinero vacío (pantalla 40).
- [ ] F06-07 Aviso de fecha de pago de cada tarjeta de crédito.

## F07 · Avisos, límites y ahorro

- [ ] F07-01 Pedir permiso de notificaciones en el momento justo (al crear el primer aviso), no al abrir.
- [ ] F07-02 Avisos locales de pagos fijos de 0 a 14 días antes y a la hora elegida (pantalla 3, versión personal).
- [ ] F07-03 Pantalla Avisos con lista y ajustes (pantalla 22).
- [ ] F07-04 Límites total y por categoría con aviso al 80 y 100 % (pantalla 27).
- [ ] F07-05 Ahorro: metas, aportes y vínculo con una cajita (pantalla 26).

## F08 · Registro automático

Parada: necesita el iPhone de Juan y SMS reales.

- [ ] F08-01 App Intent "Registrar gasto" con monto, comercio, últimos 4 y fuente. Criterio: se puede llamar desde Atajos.
- [ ] F08-02 Atajo de Wallet (disparador Transacción) y guía paso a paso dentro de la app. Criterio: pagar con Apple Pay crea el gasto con su tarjeta.
- [ ] F08-03 Lector de SMS: el atajo de Mensajes envía el texto, la app extrae monto, comercio y últimos 4 por banco; si no está segura, queda "Revisar". Criterio: pruebas con al menos 5 SMS reales por banco.
- [ ] F08-04 Pantalla Registro automático (pantalla 35).
- [ ] F08-05 Escanear recibo con la cámara y crear un borrador.

## F09 · Ajustes, apariencia y respaldo

- [ ] F09-01 Ajustes con firma al pie (pantalla 13).
- [ ] F09-02 Apariencia: tema oscuro y claro, transparencia en 4 niveles (pantalla 5).
- [ ] F09-03 Moneda por cuenta (pantalla 28).
- [ ] F09-04 Ícono de la app con íconos alternos (pantalla 29).
- [ ] F09-05 Bloqueo con Face ID al abrir.
- [ ] F09-06 Respaldo: archivo cifrado automático en iCloud Drive, exportar e importar `.mprogress` y CSV (pantalla 4). Criterio: restaurar en un iPhone limpio deja todo igual.
- [ ] F09-07 Novedades (pantalla 30).

## F10 · Cuenta y sincronización

Parada: Juan crea el proyecto en Supabase.

- [ ] F10-01 Proyecto Supabase, migración aplicada y `supabase/tests/rls_smoke.sql` en verde.
- [ ] F10-02 Inicio de sesión con Apple, Google y correo, y "Seguir sin cuenta". **Falta diseño:** pedirlo antes de programar.
- [ ] F10-03 Motor de sincronización de HANDOFF 9 con pruebas de conflicto y de borrado.
- [ ] F10-04 Indicador sin conexión, hoja de estado y marcas de pendiente (pantallas 36 y 37).
- [ ] F10-05 Al iniciar sesión, subir los datos locales a la cuenta sin duplicar.
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

- [ ] F12-01 Widgets pequeño, mediano y grande (pantalla 6).
- [ ] F12-02 Pantalla bloqueada y StandBy.
- [ ] F12-03 Widgets interactivos: + Gasto y marcar pagado.
- [ ] F12-04 Widget del hogar.
- [ ] F12-05 Apple Watch: resumen, registrar gasto y complicación.
- [ ] F12-06 Asistente: preguntas sobre tus datos y registrar con una frase, con confirmación antes de guardar (pantalla 21). Decidir en el ticket si corre en el iPhone o en un servidor.

---

## Después de F12 (por planear, no se programa todavía)

- F13 Premium: qué es básico y qué es pago, precios, StoreKit 2 y paywall (pantallas 19 y 18 ajustadas).
- F14 Android nativo (Kotlin y Compose) con la misma base.
- F15 iPad y Mac.
- F16 Windows y Wear OS.
- F17 Publicación: política de privacidad, términos, App Store Connect.
