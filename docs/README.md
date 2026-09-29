# Documentación

> **Última consolidación:** 2026-09-29. Todos los documentos vigentes se verificaron contra el código en esa fecha.

## Documentos vigentes

| Documento | Tipo | Para qué sirve |
|---|---|---|
| [ARQUITECTURA.md](ARQUITECTURA.md) | Estado actual | Stack, mapa de código, tablas (schema v19), multi-vendedor, sincronización y reparto activo |
| [SELECCION_CLIENTES.md](SELECCION_CLIENTES.md) | Estado actual | Heurística de la lista del reparto: fórmulas, cupos y etiquetas. Incluye el historial de propuestas anteriores |
| [REQUISITOS_UX.md](REQUISITOS_UX.md) | Requisitos con estado | Checklist de aceptación de UX (U01…), marcado ✅ / 🟡 / ❌ |
| [PLAN_MEJORAS.md](PLAN_MEJORAS.md) | Plan con estado | Bugs (B, D, V, E, N), usabilidad, fases de refactor y mejoras priorizadas |
| [VISION.md](VISION.md) | Requisitos futuros | Lo confirmado que aún no existe (PIN local) y las ideas por decidir |

`../CLAUDE.md` es la guía rápida para agentes: resume y apunta a estos documentos. `../README.md` es la presentación del proyecto.

## Decisiones de producto vigentes

| Fecha | Decisión | Dónde impacta |
|---|---|---|
| 2026-09-18 | La lista del reparto se calcula en memoria con `ClientRecommendationService` y no usa `puntuacion` | `SELECCION_CLIENTES.md` |
| 2026-09-29 | Los datos están aislados por vendedor. La escala objetivo es de 1 a 3 vendedores, sin flotilla | `ARQUITECTURA.md`, `REQUISITOS_UX.md` (descartados) |
| 2026-09-29 | Autenticación: PIN local a futuro; sin JWT ni backend | `VISION.md` |
| 2026-09-29 | La administración se hace en Google Sheets, no en la app | `REQUISITOS_UX.md` |

## Archivo (`archive/`)

Documentos históricos. **No usarlos como referencia**: cada uno lleva un aviso al inicio que explica por qué quedó obsoleto.

| Documento | Motivo |
|---|---|
| `ESPECIFICACION_TECNICA.md` | Diseño multi-tenant nunca construido y algoritmo de lista anterior a `1c62312` |
| `IMPLEMENTACION_REFERENCIAL.md` | Pseudocódigo de ese algoritmo anterior; se repite en un ~80 % con la anterior |
| `ESPECIFICACION_EXPERIENCIA_USUARIO.md` | Spec UX original; lo vigente pasó a `REQUISITOS_UX.md` |
| `backlog/heuristic_improvement_*.md` | Propuestas de heurística superadas (destino de cada una en `SELECCION_CLIENTES.md` § Historial) |
| `tickets/REGISTRO_INTERACCION_VENTA_FAB.md` | Ticket **cerrado** (resuelto con `insertSaleWithInteraction`) |

## Reglas de mantenimiento

1. **Código y documento en el mismo commit.** Si un cambio altera algo descrito en un documento vigente (una constante, una tabla, un flujo), ese documento se actualiza en el mismo commit.
2. **Cerrar items en su lugar.** Al resolver un item de `PLAN_MEJORAS.md` o `REQUISITOS_UX.md`, se cambia su estado (⬜ → ✅) y se agrega la fecha; no se borra. También se actualiza el tablero del plan.
3. **Separar estado actual de aspiración.** `ARQUITECTURA` y `SELECCION_CLIENTES` describen sólo lo que el código hace; lo que se quiere va en `VISION` o en `PLAN_MEJORAS`.
4. **Archivar, no dejar mentir.** Un documento que deja de describir el código se corrige o se mueve a `archive/` con un aviso de fecha y motivo.
5. **Fecha de verificación.** Cada documento vigente declara la fecha en que se contrastó con el código; si se revisa de nuevo, se actualiza.
6. **Preguntas abiertas explícitas.** Si un requisito no está claro, se anota como "por decidir" (`VISION.md`) en vez de inventar la respuesta.
