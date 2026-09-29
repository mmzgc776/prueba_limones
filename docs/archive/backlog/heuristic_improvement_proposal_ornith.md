> **ARCHIVADO (2026-09-29) — no usar como referencia.** Superado por `ClientRecommendationService` (commit `1c62312`). Estado de cada defecto en `SELECCION_CLIENTES.md` § Historial.
> Documentación vigente: [`docs/README.md`](../../README.md).

# Propuesta de Mejoras para la Heurística de Generación de Listas

**Fecha:** 2026-08-05  
**Análisis realizado por:** Ornit (modelo ornith-1.0-9b)  
**Repositorio:** `C:\Users\mmzgc\dev\prueba_limones`  
**Archivos afectados:**
- `lib/services/delivery_service.dart` — Lógica de listado (`loadClientes`, `_sortByFreshScore`)
- `lib/services/sync_service.dart` — Cálculo de métricas (`updateClientScores`)

---

## 1. Resumen Ejecutivo

El sistema actual usa una heurística de dos fases para generar la lista de clientes en cada reparto:

1. **Fase 1 (rateClients):** Calcula scores base + weekdayBoost y los almacena en BD
2. **Fase 2 (loadClientes):** Filtra el pool top-120 por umbral de intervalo, excluye del delivery activo, y reordena temporalmente con scores frescos

**Defecto central:** El sistema asume que todos los clientes son predecibles y recurrentes. No tiene mecanismo para:
- Detectar clientes "nuevos" sin suficiente historial
- Penalizar la ausencia prolongada sin eliminar al cliente del pool
- Proteger a clientes con buen historial que entran en pausa temporal (viaje, enfermedad, etc.)

---

## 2. Arquitectura Actual de las Métricas

### 2.1 Fórmula general

```
puntuacionFinal = baseScore × weekdayBoost

donde:

baseScore = 0.30 × co + 0.30 × v + 0.10 × kr + 0.15 × c10 + 0.15 × cs

co   (consistencia) = 0.4·cv + 0.4·mc + 0.2·kv     → [0, 1]
v    (volumen)      = 0.4·tv + 0.4·cm + 0.2·ks     → [0, 1]
kr   (frecuencia)           ventasVuelta / maxVentasVuelta   → [0, 1]
c10  (recencia)              ultimas10 / maxUltimas10         → [0, 1]
cs   (ciclo)        cicloScore / maxCicloScore          → [0, 1]

weekdayBoost = 1.0 + weekdayScore × 0.15            → [1.00, 1.15]
```

### 2.2 Componentes de baseScore

| Métrica | Qué mide | Cómo se calcula | Rango |
|---|---|---|---|
| **co** (consistencia) | Predecibilidad del volumen habitual | Basado en las últimas 10 ventas: frecuencia de eventos, moda, kg evento | [0, 1] |
| **v** (volumen) | Magnitud total de consumo | Kg total acumulado, máximo individual, promedio semanal | [0, 1] |
| **kr** (frecuencia) | Cantidad de clientes distintos visitados | `ventasVuelta / maxVentasVuelta` | [0, 1] |
| **c10** (recencia) | Actividad reciente del cliente | `ultimas10 / maxUltimas10` — ventas en las últimas 10 oportunidades | [0, 1] |
| **cs** (ciclo) | Proximidad al intervalo esperado de compra | Ver sección 2.3 | [0, 1] |

### 2.3 Componentes de weekdayBoost

| Variable | Definición |
|---|---|
| `frecuenciasDiaSemana` | Mapeo `{lunes: N, martes: N, ..., domingo: N}` desde ventas históricas |
| `diaSemanaPreferido` | Día con mayor frecuencia (requiere ≥ 2 compras en ese día) |

**Cálculo del weekdayScore:**

| Distancia al día preferido | weekdayScore | Boost multiplicador |
|---|---|---|
| 0 días (hoy ES el día) | 1.0 | ×1.15 (+15%) |
| 1 día de diferencia | 0.7 | ×1.105 (+10.5%) |
| 2 días de distancia | 0.4 | ×1.06 (+6%) |
| 3+ días | 0.0 | ×1.00 (sin boost) |

### 2.4 CicloScore — La métrica más compleja

#### Componentes

```
intervaloPromedio = promedio de días entre compras consecutivas
                   (calculado con las últimas 10 ventas, excluyendo gaps > 3× mediana)

diasDesdeUltimaVenta = DateTime.now() - fechaDeLaUltimaVenta

cicloScore = max(0.0, 1.0 - |diasDesde - intervaloPromedio| / intervaloPromedio)
```

#### Diagrama de cicloScore

```
cicloScore = max(0, 1 - |diasDesde - intervaloPromedio| / intervaloPromedio)

Score = 1.0 ──┐                                                    ┌── Score = 0.0
              │                                                    │
   ┌─────────┼────────────┬────────────┬──────────────────────────┘
   │         │            │            │
  Ideal    Muy lejos    Mucho más     Imposible
           del intervalo  que el       alcanzar en un ciclo
```

#### Cálculo del `intervaloPromedio` (paso a paso)

1. Tomar las últimas N ventas (N=10 para adaptabilidad a cambios recientes)
2. Calcular intervalos entre compras consecutivas: `[díasEntreVentas[i], díasEntreVentas[i+1], ...]`
3. Filtar outliers: eliminar gaps > 3× la mediana
4. Promediar los intervalos restantes

#### Problema de contaminación por pausa

Cuando ocurre una **pausa larga** en las ventas, el intervalo se distorsiona:

| Escenario | Intervalos calculados | Intervalo resultante |
|---|---|---|
| Cliente compra cada 7 días sin pausa | `[7, 7, 7, 7]` | **~7.0** ← correcto |
| Cliente compra cada 7 días, PAUSA de 30 días, luego retoma | `[7, 7, 20, 7]` | **~10.3** ← contaminado! |
| Cliente compra cada 7 días, PAUSA de 60 días (ruptura completa) | `[7, 65, 7]` | **~26.3** ← totalmente roto! |

El filtro `gaps > 3× mediana` ayuda pero no corrige cuando la pausa es larga comparada con el intervalo normal.

---

## 3. Relación entre cicloScore y exclusión

Esta relación es fundamental para entender por qué los clientes "desaparecen":

```
Umbral de exclusión: diasDesde < intervaloPromedio × 0.8

Si cicloScore = 1.0 → diasDesde ≈ intervaloPromedio → en el límite del umbral
Si cicloScore = 0.5 → diasDesde ≈ 0.5×intervalo → NO excluido (score alto)
Si cicloScore = 0.0 → diasDesde >> intervaloPromedio → muy lejos, pero...
```

El problema: un cliente con `cicloScore = 0` y buen historial puede tener baseScore ≈ 0 si recencia también es 0, cayendo fuera del top-120 y desapareciendo completamente.

---

## 4. Defectos Identificados (tras pausa en ventas)

### 4.1 Defecto #1: Clientes con una sola venta quedan atrapados en la lista

**Síntoma:** Al reanudar las ventas, clientes que solo compraron una vez aparecen repetidamente sin penalización ni exclusión.

**Causa raíz:** El sistema usa `ventas.length >= 2` como condición para calcular intervalos, pero **no filtra estos clientes del pool top-120**. Para clientes sin intervalo calculado, se usa el fallback de 7 días:

```dart
final intervalo = cliente.intervaloPromedio != null && 
                  cliente.intervaloPromedio! > 0
    ? cliente.intervaloPromedio!
    : fallbackDias;   // ← FALLO: usa 7 días para TODOS los clientes sin historial
return diasDesde < (intervalo * umbral);
```

**Consecuencia:** Un cliente con una sola venta hace 60 días aparece cada día en la lista. El sistema no puede decir "este cliente tiene un patrón" porque nunca ha tenido datos suficientes, pero tampoco lo excluye.

---

### 4.2 Defecto #2: Clientes "muertos" reaparecen sin penalización tras pausa larga

**Síntoma:** Un cliente que compraba cada quincena dejó de comprar por 60 días (viaje). Al retornar, sigue apareciendo en la lista como si nada hubiera pasado.

**Causa raíz:** El umbral de exclusión es estático — solo mira `díasDesde < intervalo × 0.8` — pero **no tiene un factor de recencia absoluto ni periodo máximo de silencio**:

```dart
const double umbral = 0.8;
return diasDesde < (intervalo * umbral);   // ← Sin límite superior!
```

**Ejemplo práctico tras una pausa:**

| Cliente | Intervalo habitual | Pausa | Días desde última venta al retornar | ¿Aparece? |
|---|---|---|---|---|
| A (semanal) | 7 días | 60 días | 59 días | ✅ SÍ (umbral = 5.6, 59 > 5.6 ✓) — pero score ≈ 0 |
| B (quincenal) | 14 días | 60 días | 46 días | ✅ SÍ (umbral = 11.2, 46 > 11.2 ✓) — pero score ≈ 0 |
| C (compró 1 vez hace 90 días) | 7 días (fallback) | 60 días | 35 días | ✅ SÍ (umbral = 5.6, 35 > 5.6 ✓) — score ≈ 0 |

**Consecuencia:** Clientes con historial completo aparecen en la lista solo si su intervalo lo permite, pero siempre con `cicloScore = 0` porque `díasDesde >> intervaloPromedio`:

```dart
// Ciclo después de una pausa:
intervaloPromedio = 14
diasDesdeUltimaVenta = 50
deviation = |50 - 14| / 14 = 2.57
cicloScore = max(0, 1 - 2.57) = 0   // ← ANULADO por clamp()
```

---

### 4.3 Defecto #3: Clientes buenos que dejaron de comprar "desaparecen" sin rastro

**Síntoma:** Un cliente que compraba todos los jueves con buena voluntad, pero se fue de viaje 3 semanas... desaparece para siempre hasta que rateClients lo recalcule y vuelva a entrar al top-120.

**Causa raíz:** El `cicloScore` es un multiplicador destructivo aplicado en la fórmula:

```dart
final baseWithoutCiclo = (puntuacion / weekdayBoost) 
                         - 0.15 * cicloScore;    // ← Penalización directa
scores[c.id] = (baseWithoutCiclo + 0.15 * freshCiclo) * freshWeekdayBoost;
// freshCiclo = 0 cuando no estamos cerca del intervalo → penalty total = 0.15
```

**Ejemplo:** Cliente con baseScore histórico de 0.84 pero en pausa:

| Componente | Valor antes de pausa | Valor después de 21 días sin comprar |
|---|---|---|
| Consistencia (co) | 0.90 | 0.90 |
| Volumen (v) | 0.85 | 0.85 |
| Frecuencia (kr) | 0.70 | 0.70 |
| Recencia (c10) | 0.60 → 0 | **CAE A CERO** |
| Ciclo (cs) | 0.50 → 0 | **CAE A CERO** |
| **baseScore** | **~0.84** | **~0.30** |

Si su score cae fuera del top-120 → NO aparece en NINGUNA lista. El vendedor ya no sabe que ese cliente existe.

---

### 4.4 Defecto #4: Pausa contamina el intervaloPromedio artificialmente

**Síntoma:** Tras una pausa de ventas, los clientes vuelven a aparecer más tarde de lo esperado o directamente con cicloScore=0.

**Causa raíz:** El cálculo del `intervaloPromedio` usa las últimas 10 ventas incluyendo el gap de la pausa:

```dart
// Ejemplo: cliente compra cada 7 días, pausa 30 días, luego compra 5 veces
Ventas ordenadas: [Día -42, -35, -28, -21, -14, -7, +3, +10, +17, +24]

Intervals (todas): [7, 7, 7, 7, 7, 17, 7, 7, 7] ← el 17 es la pausa

// _calcIntervaloPromedio filtra gaps > 3× mediana:
mediana = ~8.0
filtro: [7, 7, 7, 7, 7, 17, 7, 7, 7] → ¿es 17 > 24? NO (3×8 = 24)
→ Se mantiene en cálculo
intervaloPromedio = ~8.4  // ← inflado por la pausa!

// Luego: cicloScore para las próximas ventas:
cicloScore = max(0, 1 - |díasDesde - 8.4| / 8.4)  
           = max(0, 1 - |17 - 8.4| / 8.4)   // ← si ya pasó ~17 días desde última
           = max(0, 1 - 1.02) = 0           // ← score anulado!
```

---

## 5. Plan de Correcciones

### Corrección #1: Filtrar clientes con una sola venta (sin historial)

**Problema:** Clientes sin intervalo calculado quedan atrapados en el pool cada vez.

**Propuesta: Estrategia híbrida — excluir del ranking activo si < 3 ventas, pero dar boost de descubrimiento decreciente para clientes con 2-4 ventas.**

```dart
// En delivery_service.dart:loadClientes()

final Set<int> historialNulo = topClientes
    .where((c) => c.ventas.length < 3)        // mínimo 3 ventas para tener un patrón
    .map((c) => c.id)
    .toSet();

// Penalización por falta de historial (boost decreciente)
final List<Cliente> result = topClientes
    .where((c) {
      if (historialNulo.contains(c.id)) return false; // <3 ventas → excluir del ranking
  
      // Penalizar clientes sin patrón para dar prioridad a los que sí tienen uno
      final penalty = c.ventas.length > 0 
          ? ((12 - c.ventas.length) / 12).clamp(0, 1) * 0.3  
          : 0;
      
      return true; // todos pasan el filtro base
    })
    .toList();

// En _sortByFreshScore:
scores[c.id] = ((baseWithoutCiclo + 0.15 * freshCiclo) - penalty) 
              * freshWeekdayBoost;
```

**Impacto esperado:** Lista más limpia (menor scroll), pero el vendedor aún puede descubrir clientes nuevos gracias al boost decreciente para aquellos con 2-4 ventas.

---

### Corrección #2: Umbral máximo de silencio — penalizar clientes que no compran mucho tiempo

**Problema:** Un cliente puede estar en "pausa indefinida" pero seguir apareciendo si su intervalo lo permite.

**Propuesta: Agregar umbral máximo de silencio absoluto (120 días) con penalidad progresiva al score.**

```dart
// En loadClientes(), antes del filtro final:
final now = DateTime.now();
const double maxSilenceDays = 120;  // cliente en pausa > 4 meses → penalización severa

result = result.where((c) {
  final ultimaVenta = lastSaleDates[c.id];
  if (ultimaVenta == null) return true;  // sin ventas → no penalizar
  
  final diasDesde = now.difference(ultimaVenta).inDays;
  
  if (diasDesde > maxSilenceDays) {
    // Penalización: reduce score proporcionalmente al tiempo de silencio
    final silencePenalty = ((diasDesde - maxSilenceDays) / maxSilenceDays).clamp(0.0, 1.0);
    return c.scoreFresco > (silencePenalty * 0.5); // requiere score > 50% de penalidad
  }
  
  return true;
});

// En _sortByFreshScore:
scores[c.id] = ((baseWithoutCiclo + 0.15 * freshCiclo) - penalty) 
              * freshWeekdayBoost;
```

**Impacto esperado:** Clientes abandonados pierden relevancia gradual (no desaparecen bruscamente ni aparecen cada día), el vendedor sigue pudiendo redescubrirlos si tienen buen historial.

---

### Corrección #3: Evitar que cicloScore anule completamente el score total

**Problema:** Un cliente con baseScore = 0.85 (buen consumidor) pero en pausa pierde todo su score → sale del top-120 y desaparece.

**Propuesta: Ciclo como bonus aditivo (+0.15 max) en vez de multiplicativo reemplazo.**

```dart
// En _sortByFreshScore(), REEMPLAZAR la fórmula actual:

// ACTUAL (penalizante):
final baseWithoutCiclo = (c.puntuacion / storedWeekdayBoost) 
                         - 0.15 * (c.cicloScore ?? 0.0);  // ← penalización directa

scores[c.id] = (baseWithoutCiclo + 0.15 * freshCiclo) * freshWeekdayBoost;
// Resultado: cicloScore bajo → baseWithoutCiclo más alto, pero...
// El problema es que freshCiclo = 0 cuando no estamos cerca del intervalo

// PROPOSTA (no penalizador):
final baseWithoutCiclo = (c.puntuacion / storedWeekdayBoost);  // ← sin restar cicloScore!

// El cicloScore fresco como BONUS adicional (no reemplazo)
final cicloBonus = freshCiclo * 0.15;  // máximo +0.15 al score base

scores[c.id] = (baseWithoutCiclo + cicloBonus) * freshWeekdayBoost;
```

**Efecto en el ejemplo práctico:**

| Cliente | Scenario | baseScore | weekdayBoost | cicloScore | Score final (actual) | Score final (propuesto) |
|---|---|---|---|---|---|---|
| Buena compra | Día perfecto del intervalo | 0.84 | ×1.15 | 1.0 | **0.97** | **0.97** |
| Buena compra | Sin intervalos (pausa) | 0.84 | ×1.15 | 0.0 | 0.30 ← DESAPARECE | **0.97** ← Mantiene su ranking! |
| Buena compra | A mitad de ciclo | 0.84 | ×1.15 | 0.5 | 0.62 | **0.90** |

---

### Corrección #4: Protección contra contaminación de pausa larga

**Problema:** La pausa infla artificialmente el `intervaloPromedio` y por ende el umbral de exclusión.

**Propuesta: Usar mediana en vez de media para calcular intervalos + detección de pausa prolongada.**

```dart
// En sync_service.dart: _calcIntervaloPromedio() — REEMPLAZAR

static double _calcIntervaloPromedio(List<double> intervals) {
  if (intervals.isEmpty) return 0.0;
  
  // Usar MEDIANA en vez de media para resistir outliers (pausas largas)
  final sorted = [...intervals]..sort();
  final mid = sorted.length ~/ 2;
  final mediana = sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2.0;
  
  // Filtro de outliers: eliminar gaps > 3× la MEDIANA (no la media)
  final clean = intervals.where((i) => i <= mediana * 3.0).toList();
  if (clean.isEmpty) return mediana;
  
  return clean.reduce((a, b) => a + b) / clean.length;
}

// Efecto en ejemplo de pausa:
intervals = [7, 7, 7, 7, 7, 30, 7, 7]
media_bruta = ~8.4      → filtro > 25.2 (el 30 se filtra) → promedio = 7 ✓
mediana = ~7            → filtro > 21 (el 30 se filtra) → promedio = 7 ✓

// Ambas estrategias funcionan, pero la mediana es más robusta
// ante múltiples gaps largos distribuidos uniformemente.
```

**Estrategia adicional: Detección de pausa prolongada**

```dart
// En rateClients(), antes del cálculo del intervalo:
final salesDates = ventasCliente.map((v) => v.date).toList()..sort();
if (salesDates.length >= 2) {
  final ultimoIntervalo = salesDates[salesDates.length - 1]
    .difference(salesDates[salesDates.length - 2]).inDays;
  final intervaloActual = _calcIntervaloPromedio(intervals);
  
  // Si el intervalo actual > 3× del último intervalo conocido → pausa detectada
  if (intervaloActual > 0 && ultimoIntervalo > 0) {
    final ratio = intervaloActual / ultimoIntervalo;
    if (ratio > 3.0) {
      // Marca el cliente como "en pausa" temporalmente
      await _databaseService.updateClienteEnPausa(
        clientId: cliente.id,
        enPausa: true,
        fechaDetectada: DateTime.now(),
      );
    }
  }
}

// En loadClientes():
final Set<int> pausados = clientes.where((c) {
  return c.enPausa == true && 
         now.difference(c.fechaEnPausa).inDays < maxPausaDias;
}).map((c) => c.id).toSet();

// Clientes en pausa: NO aparecen en el ranking temporal, pero sí reciben
// un boost de "potencial" para que los redescubran pronto
```

---

## 6. Resumen Comparativo

| # | Defecto | Corrección propuesta | Impacto esperado |
|---|---------|---------------------|-----------------|
| **1** | Clientes con 1 venta atrapados en la lista | Híbrido: excluir del ranking si <3 ventas, boost de descubrimiento decreciente para 2-4 ventas | Lista más limpia + descubrimiento activo de nuevos clientes |
| **2** | Cliente "muerto" reaparece sin penalización tras pausa larga | Umbral máximo de silencio (120 días) con penalidad progresiva al score | Clientes abandonados pierden relevancia gradual, no desaparecen bruscamente ni aparecen cada día |
| **3** | cicloScore anula completamente el score total | Ciclo como bonus aditivo (+0.15 max) en vez de multiplicativo reemplazo | Cliente con buen historial mantiene ranking incluso en pausa; ciclo da ventaja extra solo cuando estamos cerca del momento ideal |
| **4** | Pausa contamina intervaloPromedio | Mediana + detección de pausa prolongada (ratio > 3×) | Clientes con pausas largas no contaminan su umbral de exclusión ni reaparecen más tarde de lo esperado |

---

## 7. Impacto en el Flujo Completo del Sistema

### Antes (actual):
```
Cliente compra → historial se construye → score alto
Cliente pausa 30 días → cicloScore = 0, recencia = 0 → score cae a ~0.30
Si < top-120 → DESAPARECE para el vendedor
Cuando retoma ventas → rateClients recalcula → puede reaparecer si vuelve al top-120
```

### Después (con correcciones):
```
Cliente compra → historial se construye → score alto
Cliente pausa 30 días → cicloScore = 0 pero baseScore se mantiene → score ≈ 0.54
Aparece en la lista con ranking según su calidad histórica + weekdayBoost
Cuando retoma ventas → rateClients recalcula → score vuelve a su nivel óptimo
```

---

## 8. Consideraciones de Implementación

### Dependencias entre correcciones

- La **Corrección #3** (ciclo como bonus) es la más crítica: sin ella, las otras correcciones no resuelven el problema de desaparición total del cliente
- La **Corrección #1** debe aplicarse en `loadClientes()` antes de entrar al pool candidato
- Las **Correcciones #2 y #4** son independientes y pueden aplicarse separadamente

### Riesgos

| Corrección | Riesgo potencial | Mitigación |
|---|---|---|
| #1 (filtrar sin historial) | Vendedor pierde contacto con clientes nuevos | Boost decreciente para 2-4 ventas permite descubrimiento gradual |
| #2 (umbral de silencio) | Clientes en pausa temporal pierden relevancia innecesaria | Penalidad progresiva (no binaria) → cliente puede reaparecer si tiene buen score histórico |
| #3 (ciclo como bonus) | Score final puede ser más alto que antes para algunos clientes | El boost es aditivo (+0.15 max), no multiplicativo → cambio gradual y predecible |
| #4 (mediana) | Peor rendimiento con datos muy dispersos | La mediana ya se usa parcialmente en el filtro; cambio a mediana solo para el cálculo del promedio |

### Orden recomendado de implementación

1. **Corrección #3** — Más alto impacto, más baja complejidad
2. **Corrección #1** — Cambio mínimo (solo añadir filtro + penalización)
3. **Corrección #4** — Cambia una función existente (`_calcIntervaloPromedio`)
4. **Corrección #2** — Añadir nueva condición de filtrado en `loadClientes()`

---

## 9. Estructura de Archivos Modificados

### `lib/services/delivery_service.dart`

| Función | Cambio | Líneas aproximadas |
|---|---|---|
| `loadClientes()` | Añadir filtro de historial mínimo (ventas.length >= 3) + penalización por silencio | Después del Paso 1 (pool candidato), antes del Paso 2 |
| `_sortByFreshScore()` | Reemplazar fórmula: cicloScore como bonus aditivo en vez de penalizador; añadir penalidad por historial y silencio | Líneas 85-140 |

### `lib/services/sync_service.dart`

| Función | Cambio | Líneas aproximadas |
|---|---|---|
| `_calcIntervaloPromedio()` | Cambiar de media a mediana para resistencia a outliers (pausas) | Línea 628, ~10 líneas |
| `updateClientScores()` | Agregar detección de pausa prolongada (ratio > 3× entre intervalos consecutivos) + campo `enPausa` en el cliente | Dentro del bucle por cliente (~línea 350-400) |
