# Selección de clientes para el reparto activo

> **Tipo:** referencia del estado actual · **Verificado contra el código:** 2026-09-29
> **Fuente de verdad:** `lib/services/client_recommendation_service.dart` (`ClientPurchaseMetrics`, `ClientRecommendationService.select`).
> Si cambias una constante o fórmula, actualiza este documento en el mismo commit.

## Flujo

```
section_delivery_page.dart :: _loadData()
  currentDeliveryNumber = started ? controller.getCurrentDeliveryNumber()
                                  : widget.resumeDeliveryNumber
        │
        ▼
DeliveryService.loadClientes(excludeDeliveryNumber)          delivery_service.dart
  1. getRecommendationSnapshot(sellerId)                     database_service.dart
     clientes, sales, deliveries e interacciones del vendedor de la sesión, en una transacción
  2. ClientRecommendationService.select(..., now: clock())   client_recommendation_service.dart
  3. devuelve (clientes, esRelleno, motivos = ClientRecommendation.tags)
```

- **Alcance:** sólo datos del vendedor de la sesión (`seller_id`). Es la decisión de producto vigente (ver `ARQUITECTURA.md` § Multi-vendedor).
- **Catálogo completo:** no hay pool top-N ni se lee `puntuacion`. Todo se recalcula en memoria en cada carga, así que un score persistido atrasado no cambia la lista.
- **Venta válida:** `quantity` finita y mayor que 0, y `date <= now`. Un cliente sin compras válidas **no entra** a la lista, aunque sigue disponible en el catálogo y la búsqueda.

## Métricas por cliente (`ClientPurchaseMetrics.calculate`)

Las ventas válidas se agrupan por **día calendario** (kg sumados por día).

| Métrica | Cálculo |
|---|---|
| `interval` | Toma los últimos 10 días de compra (9 huecos), descarta los huecos mayores a 3× la mediana y **promedia** el resto. Sin huecos queda en 0 y se usa 7 días como valor esperado. |
| `confidence` | `min(1, huecos/4) / (1 + desviación relativa)`. La desviación se mide sobre **todos** los huecos: las pausas descartadas bajan la confianza. Con 2 días de compra el máximo es 0.25. |
| `readiness` | `(1 − confidence)·0.6 + confidence·timing`, donde `ratio = días desde la última compra / intervalo`. `timing = ratio` si `ratio ≤ 1`; si no, `exp(−(ratio−1)/3)`. |
| Actividad | Suma de días de compra de los últimos 90 días, ponderados por `exp(−días/45)`. |
| Volumen | Kg de los últimos 90 días, con la misma ponderación. |
| `silenceFactor` | Vale 1 hasta `max(30, 3·intervalo)` días de silencio y luego decae con `exp(−exceso / max(30, 2·intervalo))`. |
| `weekdayScore` | Día preferido = el más frecuente en 90 días (0 = lunes). Vale 1 si hoy coincide, 0.7 a un día de distancia y 0.4 a dos (distancia circular, domingo↔lunes). Vale **0** si el día preferido tiene menos de 2 compras. |

### Prioridad (`score`)

```
activity = actividad / (actividad + 3)        // saturación: 0.5 con 3 eventos ponderados
volume   = volumen / (volumen + 100)          // 0.5 con 100 kg ponderados
base     = 0.45·readiness + 0.35·activity + 0.20·volume
early    = 0.15 + 0.85·clamp(díasDesdeÚltima / (0.8·intervalo), 0, 1)
score    = base · early · silenceFactor · (1 + 0.10·weekdayScore)
```

- La compra muy reciente **penaliza** (`early`, con piso de 0.15) pero no excluye. Ya no existe el umbral rígido del 80 %.
- El refuerzo por día de la semana es ×1.10, ×1.07 o ×1.04 como máximo.
- Las escalas son fijas: recalcular un cliente no cambia la escala de los demás. Es una prioridad heurística, **no** una probabilidad de venta.

### Grupos

- **Seguimiento inicial** (`initialFollowUp`): 1 o 2 días de compra y última compra hace 30 días o menos.
- **Reactivación** (`reactivation`): última compra hace más de `max(30, 3·intervalo)` días.

## Selección (`ClientRecommendationService.select`)

| Constante | Valor |
|---|---|
| `targetSize` | 60 |
| `followUpSlots` | 9 |
| `reactivationSlots` | 3 |
| `reactivationCooldownDays` | 14 |

1. **Exclusiones:**
   - Cualquier venta o interacción del reparto activo (`excludeDeliveryNumber`) excluye al cliente, sea cual sea el resultado.
   - Un cliente en reactivación con una interacción registrada hace menos de 14 días queda fuera. Sólo cuentan las interacciones registradas: haber aparecido en la lista no cuenta como contacto.
2. Los **48 mejores activos** (no en reactivación), ordenados por score.
3. Hasta **9 seguimientos iniciales** entre los activos que aún no entraron.
4. Hasta **3 reactivaciones**, empezando por quien lleva más tiempo sin intento (último contacto, o última compra si nunca hubo contacto).
5. Los huecos libres se llenan primero con más activos y después con más reactivaciones, por score.
6. El orden visible final es por score, con desempate por ID. Los cupos garantizan presencia, no dan prioridad en el orden.

La lista **no se fuerza** a llegar a 60: si no alcanzan los clientes con compras válidas, queda más corta.

## Etiquetas visibles (`ClientRecommendation.tags`)

Formato: `motivo · día · kg`, por ejemplo `Recompra · Lunes · 20kg`.

- **Motivo:** `Reactivación` → `Seguimiento` → `Recompra` (si `confidence ≥ 0.5` y `readiness ≥ 0.65`) → `Actividad`. Se evalúa en ese orden y gana el primero que aplica.
- **Día:** el día preferido de los últimos 90 días; si no hay compras recientes, el de todo el historial.
- **Kg habituales:** la moda de kg por día si se repite; si no se repite, la mediana.
- `esRelleno` se conserva sólo por compatibilidad y vale `initialFollowUp || reactivation`. Ya no existe el relleno ciego.

## Métricas persistidas en `Clientes`

Las columnas `eventos`, `kgTotal`, `moda`, `maximo`, `ultimas10`, `kgEvento`, `kgSemana`, `ventasVuelta`, `puntuacion`, `intervaloPromedio`, `diasDesdeUltimaVenta`, `cicloScore`, `diaSemanaPreferido`, `frecuenciasDiaSemana` y `weekdayScore` se calculan con el mismo `ClientPurchaseMetrics`. Sirven para análisis en Sheets, **no** para decidir la lista.

- `puntuacion` = `score`, `cicloScore` = `readiness` y `eventos` = número de registros de venta válidos (no incluye rechazos).
- `ultimas10` = fracción de los últimos 10 repartos con compra, y `ventasVuelta` = repartos con compra / repartos conocidos.
- **Quién escribe estas columnas:**
  - `SyncService.refreshSingleClientScore(clientId)`: se llama sin esperar (`unawaited`) desde `venta_form.dart` después de cada venta.
  - `SyncService.updateClientScores()` (`SyncType.rateClients`): recalcula todo el catálogo del vendedor.
  - Las escrituras pasan por una cola serializada (`_scoreQueue`). Si el cliente ya no tiene ventas válidas, se limpian los valores viejos.
- **Pendiente relacionado:** `ClienteInfoCard` todavía muestra `puntuacion` (`PLAN_MEJORAS.md` N4).

## Validación y límites

- **Pruebas:**
  - `test/client_recommendation_test.dart`: reloj fijo.
  - `test/client_recommendation_integration_test.dart`: Drift en memoria con 304 clientes y selección real mediante `DeliveryService`; comprueba que el recálculo individual y el general dan lo mismo.
  - `test/client_recommendation_widget_test.dart`: etiquetas.
  - Son pruebas de comportamiento, no una medición de precisión comercial.
- Los parámetros son iniciales. Antes de ajustar pesos hay que medir la cobertura de compradores y la conversión entre los clientes realmente contactados.
- No hay aprendizaje automático, registro de impresiones, estacionalidad ni optimización geográfica (ver `VISION.md`).

## Historial: propuestas anteriores y su destino

La heurística actual llegó en el commit `1c62312` (2026-09-18) y sustituyó a las propuestas de `archive/backlog/`.

| Propuesta | Destino |
|---|---|
| v2-A: bajar el peso de `cicloScore` de 0.15 a 0.08 | Superada: `cicloScore` ya no entra al score, que ahora usa `readiness` aditivo (45 %). |
| v2-B: excluir clientes con menos de 3 ventas | Superada con el diseño opuesto: basta 1 día de compra, y los de 1-2 días tienen 9 cupos de seguimiento. |
| v2-C: penalizar silencios mayores a 120 días | Superada por `silenceFactor` relativo al ciclo y el grupo de reactivación. |
| v2-D: tope de 60 | Implementada (`targetSize`). |
| v2: cola circular de reinserción | Cubierta por el orden de reactivaciones según el contacto más antiguo y el enfriamiento de 14 días. |
| v2: marca persistida `enPausa` | No se implementó; la pausa se detecta en tiempo de ejecución con `reactivation`. Baja relevancia. |
| Ornith #1: clientes de una sola venta atrapados | Superada: cupos de seguimiento con límite de 30 días. |
| Ornith #2: clientes "muertos" que reaparecen | Superada: `silenceFactor` y enfriamiento de reactivación. |
| Ornith #3: el multiplicador de ciclo anula el score | Superada: `readiness` aditivo con decaimiento gradual y `early` con piso de 0.15. |
| Ornith #4: una pausa infla el intervalo | Implementada con variante: se descartan los huecos mayores a 3× la mediana, y eso baja la confianza. |
