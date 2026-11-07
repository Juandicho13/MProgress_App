# MProgress · Plan F10 (cuentas, nube y cifrado de extremo a extremo)

Lo pidió Juan el 2026-11-06: los datos en Supabase van cifrados y solo los dispositivos del usuario (o de su pareja o familia, en F11) pueden leerlos. Supabase nunca ve montos, nombres ni notas.

Proyecto: ver `supabase/PROYECTO.md` (URL y publishable key). Sin SDK de Supabase: llamadas HTTPS directas (Auth y PostgREST) para no agregar dependencias.

## Cuenta
- Entrar con correo y enlace mágico (Supabase Auth, sin contraseña). Flujo PKCE: la app genera `code_verifier`, llama `POST /auth/v1/otp` con `email`, `create_user: true`, `code_challenge` (S256), `code_challenge_method` y `redirect_to = mprogress://auth-callback`. El correo trae un enlace que abre la app con `?code=...`; la app lo cambia por la sesión con `POST /auth/v1/token?grant_type=pkce` (`auth_code`, `code_verifier`).
- Por qué enlace y no código de 6 dígitos: Supabase solo deja cambiar el texto del correo (para mostrar `{{ .Token }}`) con SMTP propio. Cuando Juan configure SMTP (por ejemplo Resend), se agrega también la opción de escribir el código con `POST /auth/v1/verify`.
- Ya configurado en Supabase: Site URL y Redirect URL `mprogress://auth-callback`. El correo por defecto de Supabase tiene límite de pocos envíos por hora: suficiente para probar.
- Sign in with Apple y Google quedan para cuando haya cuenta paga de Apple y cliente OAuth de Google.
- La sesión (access y refresh token) se guarda en el llavero del iPhone / EncryptedSharedPreferences o Keystore en Android. Se renueva sola.
- La app sigue funcionando sin cuenta: la nube es opcional. Al entrar por primera vez, todo lo local se sube cifrado.
- Borrar cuenta y datos borra también la cuenta remota (función `delete_my_account` con security definer que borra filas del usuario y su usuario de auth) y todo lo local.

## Cifrado
- Cada espacio tiene una llave de espacio aleatoria de 256 bits (AES-GCM).
- Cada dispositivo tiene un par de llaves Curve25519 (X25519) guardado en el llavero / Keystore. La pública se sube a `devices.public_key`.
- La llave del espacio se guarda en `space_keys` envuelta para cada dispositivo: X25519 entre el dispositivo que comparte y el que recibe, HKDF-SHA256 con info "mprogress-space-key", y AES-GCM sobre la llave.
- Código de recuperación: 24 caracteres en grupos de 4 (base32 sin ambiguos) que la persona guarda. De él sale una llave (HKDF) que envuelve las llaves de espacio en `space_keys` con `device_id = null`. Si pierde todos sus dispositivos, con el código las recupera en uno nuevo.
- Cada registro se sube como sobre: `id`, `space_id`, `entity` (texto: entry, recurring, product…), `updated_at`, `deleted_at` en claro (lo necesario para sincronizar), y `payload` = AES-GCM(JSON del registro) en base64, con `space_id|entity|id` como datos asociados.

## Esquema nuevo (migración `20261108000000_f10.sql`)
- `sync_records (id uuid pk, space_id uuid, entity text, payload text, changed_at timestamptz, updated_at timestamptz, deleted_at timestamptz, updated_by uuid)` con RLS: solo miembros del espacio leen y escriben; `updated_at` y `updated_by` los pone el servidor y un cambio con `changed_at` más viejo no pisa la fila.
- `space_keys (space_id, device_id null, wrapped_key text, created_by, created_at)` con RLS por miembro.
- `devices.public_key text`.
- Las tablas con columnas en claro de la migración inicial se dejan sin uso por ahora (no se borran).

## Sincronización
- Usa el `SyncEngine` de dominio que ya existe: sube lo cambiado desde la última vez, baja lo que cambió en el servidor desde `last_pulled_at`, y si el mismo registro cambió en los dos lados gana el `updated_at` más nuevo.
- Se sincroniza al abrir la app, al volver a primer plano, después de guardar (con un pequeño retraso) y con el botón "Sincronizar ahora".
- Sin conexión se acumula. También se sincroniza al volver el internet (`NWPathMonitor` en iOS, `ConnectivityManager.NetworkCallback` en Android). Tras un error de la nube (no de conexión) se reintenta solo con espera creciente de 5 s, 15 s, 30 s, 1 min, 2 min y luego cada 5 min (`SyncBackoff`); sin internet no hay reloj: se espera a que vuelva la conexión.
- Pastilla de Inicio (F10-04), solo con cuenta lista: "Al día", "Sincronizando…", "Sin conexión · N pendientes", "Error al sincronizar" (`SyncPill.state`). Al tocarla, la hoja "Estado de sincronización" con conexión, última sincronización, pendientes por tipo ("3 movimientos, 1 pago fijo"), el último error con "Reintentar" y los dispositivos con acceso. Los movimientos sin subir llevan un reloj y "Pendiente". En iOS sale del `syncState` de cada modelo; en Android del diario de cambios (`SyncJournal`).

## Primera subida (F10-05)
- Se hace una vez por espacio y usuario; la marca vive en las preferencias del dispositivo: `nube.subidaInicial.<espacio>.<usuario>`. Hasta que termina bien, cada sincronización es una primera subida (se puede cortar y retomar sin repetir: lo ya subido queda igual en los dos lados).
- Pasos (`SyncEngine.initialUpload`): 1) baja todos los sobres de todas las entidades sin cursor; 2) plan puro (`InitialUpload.plan`): por id, si la nube no la tiene se sube; si las dos la tienen gana el `changed_at` más nuevo (empate: no se hace nada); `spaces` siempre se toma de la nube si existe allá (la moneda de la cuenta no se pisa); 3) escribe lo que gana la nube y deja los cursores en la hora del servidor; 4) une duplicados; 5) marca pendiente lo que el plan sube (también filas ya "sincronizadas" con otra cuenta) y sube en lotes de 50 con avance "Subiendo tus datos: 120 de 340"; al final "Tus datos ya están en la nube, cifrados".
- Duplicados: las categorías de la semilla tienen ids fijos y no se sincronizan, así que nunca se suben dos veces. Lo que la persona creó igual en dos teléfonos antes de entrar se une con la fila de la nube por clave estable: categorías propias por nombre normalizado (minúsculas, sin tildes, solo letras y números, y el tipo si algún día lo tienen) y reglas de comercio por su clave. Las referencias locales (movimientos, pagos fijos, límites y reglas de comercio con esa categoría) pasan al id de la nube y el duplicado local se borra sin subirlo. Si la nube tiene dos con la misma clave se usa la más vieja.

## Pantallas
- Ajustes › Cuenta: "Crear cuenta o entrar" (correo → código), luego el correo, estado de sincronización, "Sincronizar ahora", "Código de recuperación", "Dispositivos" y "Cerrar sesión".
- Al crear la cuenta: pantalla del código de recuperación con "Ya lo guardé".
- Entrar en un segundo dispositivo: si ya hay otro dispositivo con la cuenta, este muestra "Aprueba este dispositivo en tu otro teléfono" y el otro ve el aviso para aprobarlo (envuelve la llave para él). Alternativa: escribir el código de recuperación.

## Pruebas de dominio
- Envolver y desenvolver la llave de espacio entre dos pares X25519.
- Cifrar y descifrar un sobre; falla si cambian `space_id`, `entity` o `id`.
- Código de recuperación: formato, y que el mismo código da la misma llave.
- SyncEngine con sobres.

## Formato exacto (iOS y Android producen los mismos bytes)

Lo implementa iOS en `ios/MProgress/Domain/E2EE.swift` y `EncryptedSync.swift`; Android debe hacer lo mismo.

- UUID en texto siempre en minúscula (como los devuelve Postgres). Textos en UTF-8. Binario en base64 estándar con relleno.
- AES-GCM: llave de 32 bytes, nonce de 12 al azar, etiqueta de 16. Formato combinado `nonce | cifrado | etiqueta`.
- Llave de espacio envuelta para un dispositivo (`space_keys.device_id` = el que recibe):
  - `secreto = X25519(privada del que comparte, pública del que recibe)`.
  - `llave = HKDF-SHA256(ikm = secreto, sal = id del espacio en texto, info = "mprogress-space-key", 32 bytes)`.
  - `sellado = AES-GCM(llave del espacio, llave, datos asociados = "espacio|dispositivo que recibe")`.
  - `wrapped_key = base64(0x01 | pública del que comparte (32) | sellado)`. El que recibe solo acepta si esa pública es de un dispositivo de su cuenta.
- Llave de espacio con el código de recuperación (`device_id = null`):
  - Código: 15 bytes al azar en base32 con el alfabeto `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (sin 0, O, 1 ni I), 24 caracteres, mostrado en 6 grupos de 4 con guiones. Al escribirlo se pasa a mayúsculas y se quitan espacios y guiones.
  - `llave = HKDF-SHA256(ikm = código limpio, sal = "mprogress-recovery", info = "mprogress-recovery-key", 32 bytes)`.
  - `wrapped_key = base64(0x02 | AES-GCM(llave del espacio, llave, datos asociados = "espacio|recuperacion"))`.
- Sobre de un registro: `payload = base64(AES-GCM(JSON, llave del espacio, datos asociados = "espacio|entidad|id"))`. El JSON es la fila del respaldo (`BackupSnapshot`, mismas claves) con las fechas en ISO 8601 UTC y 6 decimales (`2026-11-08T10:00:00.123456Z`), igual que las columnas de fecha que se mandan a PostgREST. Entidades: `spaces`, `categories` (solo las del espacio, no las globales), `institutions`, `reward_programs`, `products`, `recurring`, `entries`, `splits`, `transfers`, `reminders`, `budgets`, `savings_goals`, `goal_contributions`.
- Fechas en `sync_records`: `changed_at` es cuándo cambió en el teléfono y decide los choques (el servidor no deja que uno más viejo pise uno más nuevo); `updated_at` lo pone el servidor y es el cursor para bajar.
- PKCE: `code_verifier` = base64url sin relleno de 48 bytes al azar (64 caracteres); `code_challenge` = base64url sin relleno de SHA-256 del verificador.
- El espacio Personal de la nube es el que crea el servidor al crear la cuenta: cada dispositivo adopta su id para los datos locales al entrar.

## Reglas de siempre
Español de Colombia con tuteo, sin la raya. Nunca la secret key de Supabase en las apps. Nunca números completos de tarjetas.
