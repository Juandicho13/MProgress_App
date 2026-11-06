# MProgress · Instrucciones para cualquier modelo de IA

Este archivo lo lee cualquier asistente que trabaje en el repo (Claude, Gemini, GPT, Codex, Cursor u otro). `CLAUDE.md` y `GEMINI.md` solo apuntan aquí.

## Antes de hacer cualquier cosa

1. Lee `HANDOFF.md` completo. Es el manual: reglas, arquitectura, modelo de datos, diseño y cómo verificar.
2. Lee `docs/FASES.md`: ahí está el estado de cada ticket (`[ ]` pendiente, `[~]` en curso, `[x]` hecho) y su criterio de terminado.
3. Lee las últimas 5 entradas de `docs/BITACORA.md`.
4. Si vas a construir una pantalla, lee su sección en `docs/PANTALLAS.md` y mira su página en `docs/diseno/MProgress_diseno_iPhone.pdf`.
5. Si algo de los documentos choca con el código, manda el código del repo. Corrige el documento en el mismo commit.

## Órdenes que te puede dar Juan

| Orden | Qué haces |
| --- | --- |
| `Sigue` | Tomas el primer ticket `[ ]` de la fase en curso y lo haces |
| `Haz F03` | Haces todos los tickets de F03 en orden |
| `Sigue hasta F12` o `Haz de F03 a F12` | Avanzas ticket por ticket, fase por fase, hasta cerrar la fase indicada o hasta una parada obligatoria |
| `Estado` | Resumes en 5 líneas: fase actual, último ticket cerrado, siguiente, bloqueos |
| `Revisa F05-03` | Revisas ese ticket contra su criterio de terminado y listas lo que falta |

## Dos modos de trabajo

**Modo manual (por defecto).** Juan pega los archivos y aplica los cambios a mano.
- Entregas cada archivo completo con su ruta, nunca fragmentos.
- Das los comandos para verificar y los de git (`git add` con rutas, `git commit -m "..."`, `git push`).
- Esperas la salida de Juan antes de marcar el ticket como hecho.

**Modo con acceso.** Tienes acceso de escritura al repo (Claude Code, Codex, Gemini CLI u otro).
- Trabajas en una rama por fase: `feat/f03-inicio-agregar`.
- Un commit por ticket, con su id: `feat(inicio): F03-02 agrega la tarjeta de próximos cargos`.
- Después de cada ticket compilas y corres las pruebas (comandos en `HANDOFF.md` sección 10). Si fallan, lo arreglas antes de seguir.
- Al cerrar cada ticket: marcas `[x]` en `docs/FASES.md` y agregas su entrada en `docs/BITACORA.md`.
- Al cerrar una fase abres un PR contra `main` con el resumen de la fase y sigues con la siguiente solo si la orden lo incluye.

## Paradas obligatorias

Te detienes y le pides a Juan lo que haga falta cuando el ticket necesita:
- Su cuenta de Apple Developer, firma, perfiles o capacidades en Xcode.
- Probar en su iPhone 18 Pro o en su Apple Watch (lo que el simulador no prueba: Wallet, Atajos, notificaciones, widgets en pantalla bloqueada, Face ID).
- Claves o proyectos de Supabase, App Store Connect o Google.
- Una decisión de producto que no está en los documentos (plantilla en `HANDOFF.md` 11.4).

Dejas el ticket en `[~]`, escribes en la bitácora qué falta y por qué, y sigues con el siguiente ticket que no dependa de eso.

## Reglas que no se rompen

- No inventes APIs, archivos, versiones ni resultados. "Compila" solo se escribe después de verlo compilar.
- Nada de trabajo de una fase futura. Lo que no está en `docs/FASES.md` no se hace.
- No subas versiones de dependencias ni cambies nombres de tablas, modelos o paquetes ya publicados sin un ticket.
- Textos en español de Colombia con tuteo. Nunca la raya (el guion largo). Detalle en `HANDOFF.md` sección 3.
