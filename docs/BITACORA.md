# MProgress · Bitácora

Una entrada por ticket, la más nueva arriba. Plantilla en `HANDOFF.md` 11.3.

## 2026-11-06 · F00-01 Diseño, migración y documentación · hecho

- Qué: diseño completo de iPhone (41 pantallas), migración inicial de Supabase con seguridad por fila, prueba de seguridad y documentación para trabajar con cualquier modelo.
- Archivos: AGENTS.md, CLAUDE.md, GEMINI.md, HANDOFF.md, README.md, docs/FASES.md, docs/PANTALLAS.md, docs/BITACORA.md, docs/diseno/MProgress_diseno_iPhone.pdf, supabase/migrations/20261106000000_init.sql, supabase/tests/rls_smoke.sql.
- Verificado: la migración corre completa en PostgreSQL 16 con un esquema de prueba que imita Supabase; la prueba de seguridad confirma que la pareja comparte gastos y un tercero no ve ni escribe nada.
- Commit: primer commit del repo.
- Pendiente: F00-02, Juan crea el proyecto en Xcode.
