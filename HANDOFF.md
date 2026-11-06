# MProgress · Manual de relevo

**Estado:** 6 de noviembre de 2026 · **Fase actual:** F02 · **Repositorio:** `Juandicho13/MProgress_App` · **Rama principal:** `main`

Este manual es para cualquier modelo de IA y para Juan. Junto con `docs/FASES.md`, `docs/PANTALLAS.md` y `docs/BITACORA.md` contiene todo lo necesario para seguir el proyecto sin abrir nada más. El plan, el lienzo de diseño y los documentos de Claude son privados; lo esencial está copiado aquí.

## Índice

0. Cómo usar este manual
1. La app en un minuto
2. Equipo y entorno de Juan
3. Reglas de Juan
4. Estado y bitácora
5. Stack y versiones
6. Estructura del repo y del proyecto iOS
7. Arquitectura y convenciones de código
8. Modelo de datos y reglas de cálculo
9. Sin conexión, respaldo y sincronización
10. Sistema de diseño
11. Verificación, comandos y plantillas
12. Decisiones y pendientes

---

## 0. Cómo usar este manual

| Documento | Qué tiene |
| --- | --- |
| `AGENTS.md` | Órdenes que da Juan (`Sigue`, `Haz F03`, `Sigue hasta F12`), modos de trabajo y paradas obligatorias |
| `HANDOFF.md` (este) | Reglas, arquitectura, datos, diseño, verificación y plantillas |
| `docs/FASES.md` | Fases F00 a F12 con sus tickets, estado y criterio de terminado |
| `docs/PANTALLAS.md` | Las 41 pantallas del diseño con su contenido, estados y fase |
| `docs/BITACORA.md` | Qué se hizo, cuándo, en qué commit y qué quedó pendiente |
| `docs/diseno/MProgress_diseno_iPhone.pdf` | Una página por pantalla, a tamaño real de iPhone |
| `supabase/migrations/` | Esquema de la base con seguridad por fila |

Orden de autoridad si algo choca: el código del repo, luego este manual, luego `docs/FASES.md`, luego `docs/PANTALLAS.md`. Lo que se corrige en uno se corrige en los demás en el mismo commit.

---

## 1. La app en un minuto

MProgress (de la familia de IronProgress: "M" de money) es una app de finanzas personales y en pareja para iPhone, hecha en Swift y SwiftUI. Te dice cuánto te queda este mes, te avisa antes de cada cobro, sabe de dónde sale tu plata (bancos, tarjetas, bolsillos y cajitas) y con qué pagaste, y permite llevar las cuentas del hogar con tu pareja o tu familia, cada uno en su celular.

**Principios**
1. Funciona sin internet y sin cuenta. Todo se guarda primero en el iPhone.
2. Nunca se conecta al banco ni pide claves. De las tarjetas solo se guardan los últimos 4 dígitos.
3. Registrar un gasto toma segundos: Apple Pay, SMS del banco, widget o tres toques.
4. Los datos nunca se pierden: guardado en cada cambio, borrado suave y respaldo.
5. Una pantalla, un trabajo. Una acción principal por pantalla.

**Qué la diferencia de Kelo (la app de referencia):** espacios en pareja y familia con avisos dirigidos a una persona, bancos con tarjetas y bolsillos, detección por SMS además de Apple Pay, transparencia ajustable y modo sin conexión visible.

**Orden de plataformas:** iPhone primero (F00 a F12). Después, sin fecha: Premium, Android, iPad y Mac, Windows y relojes Wear OS.

---

## 2. Equipo y entorno de Juan

| Pieza | Detalle |
| --- | --- |
| Computador | MacBook Air M4, macOS 26 (Tahoe), proyectos en disco externo |
| Teléfono de prueba | iPhone 18 Pro. El simulador es solo respaldo |
| Reloj | Apple Watch Series 12 (para F12) |
| IDE | Xcode 27 |
| Terminal | zsh |
| Backend | Supabase (desde F10) |

Juan es estudiante de Ingeniería de Software en UNIMINUTO. Proyecto personal, sin fecha de entrega.

---

## 3. Reglas de Juan

- Español de Colombia, con tuteo.
- **Nunca uses la raya ni el guion largo** en ningún texto: respuestas, comentarios, commits ni textos de la app. Usa comas, dos puntos, paréntesis o " · ".
- Identificadores en inglés, comentarios en español.
- Código: siempre el archivo completo con su ruta. Nada de ZIP, descargas, diffs ni "el resto queda igual".
- Con cada cambio van los comandos de git: `git add` con las rutas, `git commit -m "..."` y `git push`. Commits en Conventional Commits en español con el id del ticket: `feat(inicio): F03-02 agrega próximos cargos`.
- En bloques de comandos para zsh: sin líneas que empiecen con `#` y con los globs entre comillas.
- Firma: la pantalla Ajustes lleva al pie, abajo a la derecha, "juan-olarte-dev", una línea vertical y el monograma JO en color brasa.
- Textos de la app: tuteo, verbos, sin signos de exclamación y sin emoji. Montos con formato local ("$ 1.901.100"), separador " · ".
- Nunca se usan logos, nombres ni textos de Kelo. Las marcas de terceros (Netflix, Nu) solo aparecen como texto que escribe el usuario.

---

## 4. Estado y bitácora

El estado vive en `docs/FASES.md` (checkboxes) y el historial en `docs/BITACORA.md`. Cada ticket cerrado agrega una entrada con la plantilla 11.3. Nunca marques `[x]` sin haber visto compilar y pasar las pruebas.

---

## 5. Stack y versiones

| Pieza | Elección |
| --- | --- |
| Lenguaje | Swift 6, modo de concurrencia estricto |
| UI | SwiftUI. UIKit solo si SwiftUI no alcanza, envuelto |
| Datos locales | SwiftData |
| Gráficas | Swift Charts |
| iOS mínimo | iOS 26.0 (vidrio nativo `glassEffect`, SwiftData y App Intents maduros) |
| Widgets y reloj | WidgetKit, App Intents, watchOS (F12) |
| Notificaciones | UserNotifications locales; push con APNs desde F11 |
| Backend | Supabase con `supabase-swift` por Swift Package Manager (F10) |
| Pruebas | Swift Testing (`import Testing`) para dominio; XCUITest solo para flujos críticos |
| Dependencias | Ninguna hasta F10. Agregar una es un ticket aparte |
| Fuente | Archivo (Google Fonts, licencia OFL), incluida en el bundle |

Identificadores: bundle `com.olarte.mprogress`, App Group `group.com.olarte.mprogress`, contenedor iCloud `iCloud.com.olarte.mprogress`.

---

## 6. Estructura del repo y del proyecto iOS

```
MProgress_App/
  AGENTS.md  CLAUDE.md  GEMINI.md  HANDOFF.md  README.md
  docs/
    FASES.md  PANTALLAS.md  BITACORA.md
    diseno/MProgress_diseno_iPhone.pdf
  ios/
    MProgress.xcodeproj
    MProgress/
      App/            MProgressApp.swift, RootView.swift, AppState.swift
      Design/         Tokens.swift, Typography.swift, Glass.swift, Components/
      Domain/         Money.swift, Cycle.swift, BalanceCalculator.swift, ...
      Data/           Models/, Persistence/, Stores/, Seed/
      Sync/           (desde F10)
      Features/       Onboarding/, Home/, AddEntry/, History/, Summary/, Money/,
                      Calendar/, Alerts/, Settings/, Spaces/, Assistant/
      Intents/        App Intents (F08, F12)
      Resources/      Assets.xcassets, Fonts/, Localizable.xcstrings
    MProgressTests/
    MProgressWidgets/  (F12)
    MProgressWatch/    (F12)
  android/            (después de F12)
  supabase/
    migrations/20261106000000_init.sql
    tests/rls_smoke.sql
  .github/workflows/ios.yml
```

Cada pantalla vive en `Features/<Area>/` con `<Nombre>View.swift` y, si tiene lógica, `<Nombre>Model.swift` (`@Observable`).

---

## 7. Arquitectura y convenciones de código

- **Capas:** `Features` (vistas y modelos de pantalla) usa `Data/Stores` y `Domain`. `Domain` no importa SwiftUI ni SwiftData: son tipos y funciones puras que se prueban solas.
- **Estado de pantalla:** `@Observable final class XModel` con `@MainActor`. Las vistas no hablan con SwiftData directamente salvo `@Query` para listas simples.
- **Stores:** una por agregado (`EntryStore`, `RecurringStore`, `ProductStore`, ...). Todo cambio pasa por la store, que pone `updatedAt = .now` y `syncState = .pending`.
- **Borrado:** siempre suave (`deletedAt`). Las consultas filtran `deletedAt == nil`. Borrar muestra "Deshacer" 5 segundos.
- **Dinero:** `struct Money { var minor: Int64; var currency: String }`. Nunca `Double` para montos. Formato con `FormatStyle` de moneda; COP y CLP sin decimales en pantalla.
- **Fechas:** se guardan en UTC; se muestran en la zona del iPhone. "Este mes" se calcula con el calendario del usuario.
- **Textos:** todos en `Localizable.xcstrings`. Ningún texto visible escrito directo en una vista.
- **Colores y medidas:** solo desde `Design/Tokens.swift`. Ningún valor suelto en una vista.
- **Accesibilidad:** objetivo táctil de 48 pt, etiquetas de VoiceOver en botones de solo ícono, Dynamic Type hasta Accesibilidad 3 sin cortar montos, respetar Reducir movimiento y Reducir transparencia.
- **Feature flags:** `enum Feature` con lo que depende de Premium. Hoy todo está abierto (12.1).
- **Pruebas:** todo lo de `Domain` lleva pruebas. Nombres en español: `@Test("Mensual del 31 cae el 30 en abril")`.

---

## 8. Modelo de datos y reglas de cálculo

### 8.1 Modelos locales (SwiftData) y tablas (Supabase)

Los modelos locales replican las tablas de `supabase/migrations/20261106000000_init.sql`. Los nombres en Swift van en camelCase y en la base en snake_case.

| Modelo Swift | Tabla | Campos clave |
| --- | --- | --- |
| `Space` | `spaces` | name, kind (personal, pareja, familia, trabajo, viaje), currency, color, shareTotalsOnly, defaultSplit, endsOn |
| `SpaceMember` | `space_members` | spaceId, userId, role (admin, miembro, lectura) |
| `SpendCategory` | `categories` | name, icon (SF Symbol), color, sort; spaceId nil = global |
| `Institution` | `institutions` | name, color, icon, hidden |
| `Product` | `products` | institutionId, kind (cuenta, debito, credito, bolsillo, efectivo), name, last4, balance, balanceAt, creditLimit, cutDay, dueDay, rateEA, lockedUntil, parentProductId, inWallet, hidden |
| `Recurring` | `recurring` | kind (gasto, ingreso), name, icon, amount, cycle (puntual, semanal, mensual, anual, otra), intervalDays, nextDate, categoryId, productId, responsibleId, active |
| `Entry` | `entries` | kind, amount, occurredAt, name, merchant, icon, categoryId, productId, recurringId, paidBy, method (wallet, fisica, en_linea, efectivo, transferencia), source (manual, wallet, sms, recibo, importacion, asistente), needsReview, notes |
| `Split` | `splits` | entryId, userId, amount |
| `Transfer` | `transfers` | fromProductId, toProductId, amount, occurredAt |
| `Reminder` | `reminders` | recurringId, daysBefore (0 a 14), target (todos, persona, responsable), userId, atTime |
| `Budget` | `budgets` | categoryId (nil = total), monthlyLimit |
| `SavingsGoal` | `savings_goals` | name, targetAmount, targetDate, productId |
| `GoalContribution` | `goal_contributions` | goalId, userId, amount |

Todos llevan `id: UUID` (lo genera el iPhone), `spaceId`, `createdAt`, `updatedAt`, `deletedAt` y, solo en local, `syncState` (`local`, `pending`, `synced`, `failed`).

Reglas para que SwiftData pueda sincronizar con iCloud más adelante: toda propiedad con valor por defecto u opcional, relaciones opcionales y sin `@Attribute(.unique)`.

Sin cuenta (hasta F10) existe un solo usuario local con id fijo guardado en el llavero, y un espacio "Personal".

### 8.2 Reglas de cálculo

- **Te quedan este mes** = ingresos del mes (registrados más pagos fijos de ingreso que caen en el mes y aún no se registran) menos gastos del mes (registrados más pagos fijos de gasto que faltan en el mes). Las transferencias entre productos propios no cuentan.
- **Próxima fecha de un pago fijo:** mensual suma un mes y, si el día no existe, usa el último día del mes (31 de enero, 28 o 29 de febrero, 31 de marzo). Anual del 29 de febrero cae el 28 en años no bisiestos. Semanal suma 7 días. Otra suma `intervalDays`. Puntual no se repite.
- **Marcar pagado** un pago fijo crea un `Entry` con `recurringId` y mueve `nextDate` al siguiente ciclo.
- **Urgencia:** Hoy (vence hoy o ya venció sin pagar), Pronto (1 a 3 días), Próximas (más de 3 días). Colores en 10.1.
- **Saldo actual de un producto** = `balance` en `balanceAt` más los efectos de los movimientos y transferencias posteriores. Un gasto con cuenta o débito resta; con crédito suma deuda; un ingreso a una cuenta suma; pagar la tarjeta es una transferencia de la cuenta al crédito que baja la deuda.
- **Patrimonio neto** = suma de cuentas, bolsillos y efectivo no ocultos menos la deuda de las tarjetas de crédito.
- **Rendimiento estimado de una cajita al mes** = saldo × ((1 + rateEA / 100)^(1/12) − 1), redondeado a la unidad mínima. Se muestra como "aprox.".
- **Tu mes normal** = mediana del gasto de los últimos 12 meses con datos.
- **División en pareja:** por defecto `defaultSplit` del espacio (50). Saldo entre dos personas = lo que cada uno pagó menos su parte.

---

## 9. Sin conexión, respaldo y sincronización

- **Hasta F09** todo es local. No hay indicador de sincronización porque no hay nada que sincronizar.
- **Respaldo (F09):** archivo cifrado automático en iCloud Drive (una vez al día y al cerrar sesión de la app) y exportar o importar manual (`.mprogress` y CSV). Restaurar reemplaza los datos locales previa confirmación.
- **Cuenta y sincronización (F10):** bandeja de salida local. Cada cambio queda `pending`; el motor sube los pendientes en el orden en que se hicieron (upsert por id), luego baja lo que cambió en el servidor desde el último `updated_at` visto por tabla, borrados incluidos. Conflicto: gana el `updatedAt` más reciente. Si una subida falla 3 veces, queda `failed` y se muestra.
- **Indicador (F10):** `NWPathMonitor` más el conteo de pendientes. Sin conexión, una pastilla de vidrio bajo el encabezado de Inicio: "Sin conexión · 3 cambios sin sincronizar". Al tocarla, la hoja "Estado de sincronización" con la lista de pendientes y "Reintentar ahora". Cada movimiento pendiente muestra un reloj pequeño junto a su detalle. Estados: Sincronizado, Sincronizando, Sin conexión, Error. Se puede agregar, editar y borrar sin internet siempre.

---

## 10. Sistema de diseño

Mismos tokens que IronProgress (sistema Forja), en tema oscuro por defecto y claro desde F09.

### 10.1 Colores

| Token | Oscuro | Claro | Uso |
| --- | --- | --- | --- |
| fondo | #0a0b0d | #f3f4f6 | Fondo de pantalla |
| superficie1 | #15171b | #ffffff | Tarjetas |
| superficie2 | #1d2025 | #ffffff | Hojas y menús |
| superficie3 | #262a30 | #e8eaee | Campos, teclas, controles |
| controlActivo | #3a3f47 | #ffffff | Opción elegida en un control segmentado |
| linea | #ffffff14 | #0e101414 | Separadores |
| texto1 | #f3f4f6 | #0e1014 | Texto principal y cifras |
| texto2 | #a5abb4 | #545b66 | Texto secundario |
| brasa | #ff6b2c | #ff6b2c | Acción principal (una por pantalla), lo personal, cargos |
| sobreBrasa | #140a05 | #140a05 | Texto sobre brasa |
| brasaVelo | #3a241e | #ffeae1 | Fondo de chip o tarjeta elegida |
| hielo | #6cc4f2 | #166aa0 | Ingresos y lo compartido en pareja |
| hieloVelo | #23333d | #e6f2f9 | Fondo de lo compartido |
| oro | #f5c451 | #7e5a00 | Vence pronto |
| peligro | #ff5a6e | #c8243e | Borrar, límite superado, error |
| exito | #4ade80 | #15803d | Rendimiento, sincronizado |
| vidrio | #1a1c21 al 86 % | #ffffff al 84 % | Barra de pestañas, pastillas y hojas, con desenfoque 24 |

### 10.2 Tipografía (Archivo)

| Estilo | Tamaño / línea / peso | Uso |
| --- | --- | --- |
| titulo1 | 30 / 36 / 700 | Título de pestaña |
| titulo2 | 20 / 26 / 600 | Títulos de hoja y sección |
| titulo3 | 17 / 22 / 600 | Encabezado de tarjeta, nombre en filas |
| cuerpo | 16 / 24 / 400 | Texto corrido |
| cuerpo2 | 14 / 20 / 400 | Detalle de filas |
| etiqueta | 12 / 16 / 500, mayúsculas, espaciado 0,5 | Sobretítulos de sección |
| cifraHeroe | 46 a 56 / 700, ancho 112,5 % | Saldo principal, monto en Agregar |
| cifra | 16 a 22 / 600, cifras tabulares | Montos en filas |

Todo escala con Dynamic Type.

### 10.3 Medidas

Espaciado base 4 (4, 8, 12, 16, 20, 24, 28, 32). Margen lateral 20. Radios: 14 campos, 20 botones cuadrados y teclas, 28 tarjetas, 36 hojas, píldora para botones principales y chips. Botón principal 56 de alto, secundario 48. Toque mínimo 48.

### 10.4 Vidrio y transparencia

- Barra de pestañas flotante (Inicio, Resumen, Dinero, Calendario, Ajustes), pastillas de estado y hojas usan vidrio.
- Ajustes › Apariencia › Transparencia: Mucha, Normal, Poca, Ninguna (opacidad del tinte 40, 86, 95 y 100 %; desenfoque 32, 24, 12 y 0).
- Si iOS tiene Reducir transparencia (`accessibilityReduceTransparency`), el vidrio es sólido siempre, sin importar el ajuste.
- En iOS 26 se usa `glassEffect` nativo cuando el nivel es Normal; los demás niveles usan material propio.

### 10.5 Íconos

SF Symbols en trazo, 20 a 24 pt. Logos de marcas: no se incluyen hasta tener una librería con licencia; mientras tanto, iniciales sobre color.

---

## 11. Verificación, comandos y plantillas

### 11.1 Comandos

```
cd ios
xcodebuild -scheme MProgress -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
xcodebuild -scheme MProgress -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

Si el simulador no existe, `xcrun simctl list devices available` y se usa el iPhone más nuevo de la lista.

Pruebas del dominio sin Xcode (también en Linux con Swift 6.1 o superior). Los archivos de `MProgress/Domain` no pueden importar SwiftUI, SwiftData ni UIKit:

```
swift test --package-path ios
```

Nombres a tener en cuenta: la categoría se llama `SpendCategory` (`Category` choca con un tipo de Objective-C). Los modelos guardan enums como texto (`kindRaw`, `cycleRaw`) y exponen la propiedad tipada (`kind`, `cycle`). Cada modelo convierte a su valor del dominio con `.record`.

Base de datos local para probar la migración (requiere Supabase CLI):

```
supabase start
supabase db reset
```

### 11.2 Respuesta de un ticket en modo manual

1. Plan en 3 a 6 líneas.
2. Archivos completos, cada uno con su ruta.
3. Comandos para verificar.
4. Comandos de git.

### 11.3 Entrada de bitácora

```
## 2026-11-06 · F03-02 Próximos cargos · hecho
- Qué: tarjeta de próximos cargos agrupada por urgencia.
- Archivos: ios/MProgress/Features/Home/UpcomingCard.swift, ...
- Verificado: build y 42 pruebas en verde en simulador; probado en iPhone 18 Pro.
- Commit: abc1234
- Pendiente: nada.
```

### 11.4 Pedirle una decisión a Juan

```
Decisión necesaria · F07-04
Contexto: en una línea.
Opción A: ... (qué implica)
Opción B: ... (qué implica)
Recomiendo: A, porque ...
```

### 11.5 Mensaje de arranque para cualquier modelo

```
Proyecto MProgress. Lee AGENTS.md y HANDOFF.md del repo.
Orden: Sigue hasta F05.
Modo: con acceso (o manual).
```

---

## 12. Decisiones y pendientes

1. **Premium y precios:** sin definir. Hasta decidirlo, todo abierto y `Feature` preparado para cerrarlo. Se analiza después de F12.
2. **Inicio de sesión:** no hay hasta F10. Falta su diseño (pedirlo en F10-02).
3. **Logos de marcas:** buscar librería con licencia antes de F03-04 o quedarse con iniciales.
4. **SMS reales:** Juan junta capturas de SMS de compra de Bancolombia, Nu, Nequi y Davivienda antes de F08-03.
5. **Nombre comercial:** MProgress, verificar disponibilidad en App Store antes de publicar.
