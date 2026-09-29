# Plan de Mejoras v2 — Heurística de Selección de Clientes

**Fecha:** 2026-08-06  
**Revisión:** v2 (sustituye a `heuristic_improvement_proposal_ornith.md`)  
**Archivos afectados:**
- `lib/services/delivery_service.dart` — `loadClientes()`, `_sortByFreshScore()`
- `lib/services/sync_service.dart` — `updateClientScores()`, `refreshSingleClientScore()`

---

## 1. Correcciones del plan anterior

| Problema del plan v1 | Solución v2 |
|---|---|
| Corrección #4 ya estaba implementada (mediana) | ❌ Eliminada — `_calcIntervaloPromedio` ya usa mediana |
| `c.ventas.length` no existe en el modelo | ✅ Usar `c.eventos` (int con conteo de ventas) |
| `c.scoreFresco` no existe como campo | ✅ Penalización por silencio dentro de `_sortByFreshScore` |
| `enPausa`/`fechaEnPausa` requiere migración de BD | ✅ Enfoque sin schema changes — detección en runtime |
| cicloScore se resta sin normalizar en `_sortByFreshScore` | ✅ Bug fix: reducir peso a 0.08 mitiga el impacto |
| "Top-120" vs "Top-30" | ✅ Confirmado: ya es LIMIT 120 (nombre engañoso) |

---

## 2. Cambios a implementar

### Cambio A: Reducir peso de cicloScore de 0.15 → 0.08

**Objetivo:** Suavizar la penalización para que un cliente en pausa no pierda todo su score, pero conservar señal temporal.

- `sync_service.dart` línea 414 (`updateClientScores`): `0.15 * cs` → `0.08 * cs`, redistribuir 0.07 a kr (0.10→0.13) y c10 (0.15→0.19)
- `sync_service.dart` línea 631 (`refreshSingleClientScore`): misma fórmula
- `delivery_service.dart` líneas 133-137 (`_sortByFreshScore`): peso 0.15 → 0.08

### Cambio B: Filtrar clientes con insuficiente historial (< 3 ventas)

**Objetivo:** Clientes con < 3 ventas no entran al ranking activo.

- `delivery_service.dart:loadClientes()`: filtrar `topClientes` por `c.eventos >= 3` antes de los pasos de exclusión.

### Cambio C: Penalización por silencio prolongado (> 120 días)

**Objetivo:** Clientes que no compran hace > 120 días pierden relevancia gradualmente.

- `delivery_service.dart:_sortByFreshScore()`: factor multiplicativo `silenceFactor` que reduce el score proporcionalmente.

### Cambio D: Limitar lista generada a 60 clientes

**Objetivo:** Pool de 120 → lista visible de 60.

- `delivery_service.dart:loadClientes()`: `result.removeRange(60, result.length)` después de ordenar.

---

## 3. Orden de implementación

1. **Cambio A** — Mayor impacto, menor riesgo.
2. **Cambio D** — Trivial.
3. **Cambio B** — Simple.
4. **Cambio C** — Requiere testear el factor multiplicativo.

## 4. Lo que NO se implementa

- **Cola circular de re-inserción:** Descartado por ahora.
- **Detección de pausa persistida (`enPausa`):** Requiere migración de BD.
- **Cambio a `_calcIntervaloPromedio`:** Ya usa mediana.