> **ARCHIVADO (2026-09-29) — no usar como referencia.** Pseudocódigo del algoritmo anterior a `1c62312` (pool top-60, exclusión rígida 0.8, Estrategia B, pesos 30/35/10/15, refuerzo ×1.15) con alcance "global" entre vendedores. Nada de eso existe en el código; ver `SELECCION_CLIENTES.md`.
> Documentación vigente: [`docs/README.md`](../README.md).

# Implementación Referencial Extendida — Algoritmos Críticos Multi-Tenant

Esta sección complementa la especificación técnica extendida con **pseudocódigo directamente ejecutable** (con semántica clara independientemente del lenguaje) para los algoritmos más complejos del sistema multi-vendedor, junto con casos de borde documentados. Está pensada como referencia implementacional: alguien que la lea debe poder escribir el código funcional sin ambigüedades.

---

## A1. Algoritmo Completo Extendido de Generación de Lista — Pseudocódigo Referencial Multi-Tenant

```
ALGORITMO GenerateDeliveryClientList(vendorId)
    INPUT: vendorId (identificador del vendedor autenticado)
    OUTPUT: List[Cliente] ordenado por prioridad de visita
    
    // =========================================
    // FASE 1: Obtención del pool candidato GLOBAL
    // =========================================
    
    candidatos = SELECT * FROM Clientes 
                  WHERE vendedor_id IS NULL OR vendedor_id = vendorId
                  ORDER BY puntuacion DESC 
                  LIMIT 60
    
    candidateIds = {c.id for c in candidatos}
    
    // =========================================
    // FASE 2: Fecha de última venta real por cliente (GLOBAL)
    // =========================================
    
    lastSaleDates = {}  // Mapa{clientId → DateTime}
    FOR cada cliente IN candidatos DO
        resultado = SELECT * FROM Ventas 
                    WHERE cliente_id = cliente.id   // BÚSQUEDA GLOBAL: TODAS las ventas
                    ORDER BY fecha DESC 
                    LIMIT 1
        
        IF resultado NO ES VACIO entonces
            lastSaleDates[cliente.id] = resultado.fecha
        
        // Si no tiene ventas globales, no se almacena → indica cliente nuevo
    
    // =========================================
    // FASE 3: Exclusiones temporales por intervalo propio (GLOBAL)
    // =========================================
    
    umbral = 0.8
    fallbackDias = 7.0
    hoy = DateTime.now()
    
    excluidosPorIntervalo = {}  // Set de clientIds
    
    FOR cada cliente IN candidatos DO
        ultimaVenta = lastSaleDates[cliente.id]  // Puede ser null
        
        SI ultimaVenta ES NULA entonces
            // Cliente sin ventas registradas globalmente → nunca excluir
            continuar con siguiente
        
        diasDesdeUltima = (hoy - ultimaVenta).days_entre_fechas
        
        // Determinar el intervalo esperado GLOBAL
        SI cliente.intervalo_promedio > 0 entonces
            intervaloEfetivo = cliente.intervalo_promedio  // Calculado globalmente
        SINO
            // Fallback: 7 días para clientes sin historial suficiente
            intervaloEfetivo = fallbackDias
        
        umbralExclusion = umbral × intervaloEfetivo
        
        SI diasDesdeUltima < umbralExclusion entonces
            excluidosPorIntervalo.add(cliente.id)
    
    // =========================================
    // FASE 4: Exclusiones por reparto actual (PER-VEENDEDOR)
    // =========================================
    
    ventasDelDiaPropio = SELECT * FROM Ventas 
                         WHERE delivery_number = numeroRepartoActual
                         AND vendedor_id = vendorId
    
    rechazadosHoyPorMi = SELECT DISTINCT cliente_id FROM Interacciones 
                        WHERE resultado = 'Rechazó' 
                        AND timestamp >= hoy.midnight
                        AND vendedor_id = vendorId  // SOLO rechazos de este vendedor
    
    excluidosPorReparto = {v.clienteId for v in ventasDelDiaPropio}
    excluidosPorReparto.addAll(rechazadosHoyPorMi)
    
    // =========================================
    // FASE 5: Filtrado final
    // =========================================
    
    todosExcluidos = union(excluidosPorIntervalo, excluidosPorReparto)
    
    listaFiltrada = [c for c in candidatos 
                     IF c.id NO ESTÁ en todosExcluidos]
    
    // =========================================
    // FASE 6: Re-ordenamiento inteligente (Estrategia B — In-Memoria Global)
    // =========================================
    
    hoyDiaSemana = hoy.weekday_indexed()
    scoresFrescos = {}  // Mapa{clientId → double}
    
    FOR cada cliente IN listaFiltrada DO
        
        // --- Calcular ciclo_score fresco GLOBAL (tiempo real) ---
        ultimaVentaGlobal = lastSaleDates[cliente.id]
        
        SI cliente.intervalo_promedio > 0 Y ultimaVentaGlobal != NULA entonces
            diasDesde = (hoy - ultimaVentaGlobal).days_entre_fechas.toDouble()
            desviacionCiclo = abs(diasDesde - cliente.intervalo_promedio) 
                              / cliente.intervalo_promedio
            cicloFresco = max(0.0, 1.0 - desviacionCiclo)
        SINO
            cicloFresco = 0.0
        FIN SI
        
        // --- Calcular weekday_score fresco GLOBAL ---
        diasDiferenciaSemana = abs(hoyDiaSemana - cliente.dia_semana_preferido)
        
        SI clientes.frecuencias_dia_semana tiene al menos 2 ventas en su dia_preferido GLOBAL entonces
            SI diasDiferenciaSemana == 0 entonces
                weekdayFresco = 1.0    // Coincide exactamente con el día preferido global
            SI diasDiferenciaSemana == 1 entonces
                weekdayFresco = 0.7   // Día adyacente
            SI diasDiferenciaSemana == 2 entonces
                weekdayFresco = 0.4   // Dos días de diferencia
            SINO
                weekdayFresco = 0.0   // +3 o más: sin boost
        SINO
            weekdayFresco = 0.0    // Sin patrón semanal global detectado
        FIN SI
        
        // --- Reconstruir puntuación aproximada GLOBAL ---
        
        // Extraer el score base eliminando componentes que ya están almacenados
        storedWeekdayBoost = 1.0 + ((cliente.weekday_score ?? 0) × 0.15)
        IF storedWeekdayBoost <= 0 entonces
            storedWeekdayBoost = 1.0
        
        scoreBaseSinCiclo = (cliente.puntuacion / storedWeekdayBoost) 
                           - 0.15 × (cliente.ciclo_score ?? 0)
        
        // Añadir el componente de ciclo fresco + weekday boost fresco GLOBAL
        scoresFrescos[cliente.id] = (scoreBaseSinCiclo + 0.15 × cicloFresco) 
                                   × (1.0 + weekdayFresco × 0.15)
    FIN FOR
    
    // Ordenar por score fresco descendente
    listaFinal = listaFiltrada.sort_by(scoresFrescos DESC)
    
    RETURN listaFinal

FIN ALGORITMO


// =========================================
// CASO DE BORDE: Cliente sin historial global (ningún vendedor lo ha vendido)
// =========================================
//
// Si un cliente NO tiene ventas registradas por ningún vendedor:
//   - PASO 1: Aparece en el pool candidato (puntuación = 0.0)
//   - PASO 2: lastSaleDates[cliente.id] no existe (no se inserta nada)
//   - PASO 3: UltimaVenta es NULA → NO excluido por intervalo
//   - PASO 4: Solo excluido si ya atendió o rechazó hoy este vendedor
//   - PASO 6: cicloFresco = 0.0, weekdayFresco = 0.0
//     scoreFresco = (puntuacion / storedWeekdayBoost) × 1.0
//     → Aparecerá en la lista pero con bajo ranking
//
// Interpretación: Un cliente nuevo siempre está disponible globalmente, 
// pero no tiene prioridad porque el sistema aún no conoce su comportamiento


// =========================================
// CASO DE BORDE: Cliente que compró hace exactamente su intervalo GLOBAL
// =========================================
//
// Si un cliente compra cada 7 días y hoy es exactamente día 7 desde última compra (cualquier vendedor):
//   diasDesde = 7.0
//   desviacionCiclo = abs(7.0 - 7.0) / 7.0 = 0.0
//   cicloFresco = max(0, 1.0 - 0.0) = 1.0 ← MÁXIMO SCORE DE CICLO GLOBAL
//
// → Este cliente subirá al TOPO de la lista


// =========================================
// CASO DE BORDE: Cliente que compró hace poco por un vendedor A
// pero otro vendedor B lo atendió ayer (globalmente hace 1 día)
// =========================================
//
// Vendedor A vendió al cliente el día 5 → vendedor B vende hoy (día 6):
//   diasDesdeUltimaVentaGlobal = 1 día desde la venta de B
//   intervaloPromedio = ~7 días (calculado con ventas globales)
//   umbralExclusion = 0.8 × 7 = 5.6
//   
//   SI 1 < 5.6 → VERDADERO → EXCLUIDO GLOBALMENTE
//
// Interpretación: Aunque el vendedor B no vendió hace mucho, 
// el intervalo global (basado en todas las ventas de cualquier vendedor)
// indica que el cliente probablemente ya compró hace poco y no necesita producto nuevo.


// =========================================
// CASO DE BORDE: Reparto sin ventas previas del mismo día por el mismo vendedor
// =========================================
//
// Si numeroRepartoActual = NULA (primera vez que se abre SectionDeliveryPage):
//   excluidosPorReparto = {}  // Set vacío, no hay ventas propias hoy
// → No hay exclusiones por reparto actual de este vendedor


// =========================================
// CASO DE BORDE: Cliente rechazó hoy por el VENDEDOR A pero no compró
// =========================================
//
// Si un cliente marcó "Rechazó" HOY en una interacción del vendedor A:
//   - Aparece en excluidosPorReparto (PASO 4, solo para este vendedor)
//   - NO aparece en ventasDelDiaPropio (no hay venta registrada para él por el mismo vendedor)
// → Se excluye correctamente porque rechazó


// =========================================
// CASO DE BORDE: Cliente rechazó ayer pero compró hoy por otro vendedor B
// =========================================
//
// Vendedor A rechazó al cliente ayer → Vendedor B vendió hoy (mismo día):
//   - El rechazo de ayer NO excluye globalmente (solo era exclusión temporal de A)
//   - La venta de hoy de B lo excluye de la lista de A hoy (PASO 4 propio)
//   
// Interpretación: Los rechazos son per-vendedor pero las ventas actualizan 
// el intervalo global, así que si alguien vendió hoy, nadie más puede visitar.


```

---

## A2. Algoritmo Extendido de Cálculo de Puntuación — Pseudocódigo Referencial Multi-Tenant

```
ALGORITMO CalcScoreCompletoGlobal(clienteId)
    INPUT: clientId
    OUTPUT: Mapeo completo de métricas del cliente (GLOBAL — TODAS las ventas)
    
    // =========================================
    // PASO 1: Obtener TODAS las ventas del cliente (GLOBAL)
    // =========================================
    
    ventas = SELECT * FROM Ventas 
             WHERE cliente_id = clientId
             ORDER BY fecha ASC
    
    IF ventas ES VACIO entonces
        // Cliente sin historial global — valores por defecto
        resultado = {
            eventos: 0,
            kg_total: 0.0,
            moda_kg: 0.0,
            maximo_kg: 0.0,
            ultimas10: 0.0,
            kg_promedio_evento: 0.0,
            kg_promedio_semana: 0.0,
            frecuencia_reparto: 0.0,
            intervalo_promedio: NULL,
            dias_desde_ultima_venta: NULL,
            ciclo_score: NULL,
            dia_semana_preferido: NULL,
            frecuencias_dia_semana: "{}",
            weekday_score: NULL,
        }
        
        RETURN resultado
    
    // =========================================
    // PASO 2: Métricas de volumen (GLOBAL)
    // =========================================
    
    kgTotal = SUM(v.cantidad_kg for v in ventas)
    maximoKg = MAX(v.cantidad_kg for v in ventas)
    
    // =========================================
    // PASO 3: Modas (cantidad más frecuente comprada GLOBAL)
    // =========================================
    
    conteoCantidad = {}  // Mapa{cantidad → frecuencia}
    FOR cada venta IN ventas DO
        cantidad = venta.cantidad_kg
        conteoCantidad[cantidad] = (conteoCantidad.get(cantidad, 0)) + 1
    
    modaKg = NULL
    maxFrecuencia = 0
    FOR (cantidad, frecuencia) EN conteoCantidad.items ordenado DESC por frecuencia DO
        SI frecuencia > maxFrecuencia entonces
            modaKg = cantidad
            maxFrecuencia = frecuencia
            BREAK  // Tomar la primera (más frecuente)
        FIN SI
    
    IF modaKg ES NULA entonces
        modaKg = 0.0
    FIN
    
    // =========================================
    // PASO 4: Kg promedio por evento GLOBAL
    // =========================================
    
    eventos = ventas.cantidad_total()  // Número total de ventas/interacciones globales
    kgPromedioEvento = IF eventos > 0 entonces kgTotal / eventos SINO 0.0
    
    // =========================================
    // PASO 5: Kg promedio semanal GLOBAL (rolling window)
    // =========================================
    
    semanasKg = {}  // Mapa{semana_iso → suma_kg}
    FOR cada venta IN ventas DO
        semana = venta.fecha.semana_iso()  // ISO week string
        semanasKg[semana] = (semanasKg.get(semana, 0.0)) + venta.cantidad_kg
    
    kgPromedioSemana = medias(semanasKg.values())
    
    // =========================================
    // PASO 6: Frecuencia por reparto GLOBAL
    // =========================================
    
    ventasConRepartoGlobal = [v for v in ventas IF v.delivery_number NO ES NULA]
    repartosUnicosGlobales = {v.delivery_number for v in ventasConReparto}
    frecuenciaReparto = IF len(repartosUnicosGlobales) > 0 entonces 
                         ventasConRepartoGlobal.cantidad_total() / len(repartosUnicosGlobales) 
                     SINO 0.0
    
    // =========================================
    // PASO 7: Últimas 10 rondas globales (recencia global)
    // =========================================
    
    ventasRecientes = ventas 
                      .filter(v => v.delivery_number NO ES NULA)  
                      .order_by(fecha DESC)
                      .limit(10)
    
    IF ventasRecientes.isNotEmpty entonces
        ultimoKgTotalGlobal = SUM(v.cantidad_kg for v in ventas)  // Total histórico global
        ultimas10 = IF ultimoKgTotalGlobal > 0 entonces 
                     ventasRecientes.kg_total() / ultimoKgTotalGlobal × 100  // % participación global
                 SINO 0.0
    SINO
        ultimas10 = 0.0
    FIN
    
    // =========================================
    // PASO 8: Ciclo de compra GLOBAL — intervalo promedio
    // =========================================
    
    ventasOrdenadasGlobal = ventas.order_by(fecha ASC)
    
    intervalos = []
    FOR i EN range(1, len(ventasOrdenadasGlobal)) DO
        diff = (ventasOrdenadasGlobal[i].fecha - ventasOrdenadasGlobal[i-1].fecha).days_entre_fechas()
        intervalos.add(diff)
    
    IF intervalos.isNotEmpty entonces
        intervaloPromedio = media(intervalos)  // GLOBAL: TODAS las ventas consecutivas
        
        // Guardar el intervalo como decimal con precisión razonable
        intervaloPromedio = round(intervaloPromedio, 1)  // Un decimal suficiente
        
        // Calcular dias_desde_ultima_venta global en tiempo real
        ultimaVentaHoyGlobal = ventasOrdenadasGlobal.last().fecha
        diasDesdeUltimaVenta = (DateTime.now() - ultimaVentaHoyGlobal).days_entre_fechas()
        
    SINO
        intervaloPromedio = NULL
        diasDesdeUltimaVenta = NULL
    FIN
    
    // =========================================
    // PASO 9: Ciclo Score GLOBAL — cuántos días desde el momento óptimo
    // =========================================
    
    cicloScore = NULL
    IF intervaloPromedio != NULL Y intervaloPromedio > 0 entonces
        diasDesde = (DateTime.now() - ultimaVentaHoyGlobal).days_entre_fechas().toDouble()
        
        desviacion = abs(diasDesde - intervaloPromedio) / intervaloPromedio
        cicloScore = max(0.0, 1.0 - desviacion)
    SINO
        cicloScore = NULL
    FIN
    
    // =========================================
    // PASO 10: Detección de día preferido (weekday pattern GLOBAL)
    // =========================================
    
    frecuenciasDiaSemanaGlobal = {}  // Mapa{dia_iso → frecuencia}
    diaSemanaPreferidoGlobal = NULL
    
    FOR cada venta IN ventas DO
        diaSemana = venta.fecha.weekday_indexed()  // 0=domingo, ..., 6=sábado
        
        frecuenciasDiaSemanaGlobal[diaSemana] = 
            (frecuenciasDiaSemanaGlobal.get(diaSemana, 0)) + 1
    
    // Determinar día preferido GLOBAL: el que tiene más compras
    maxFrecuenciaDiasemanaGlobal = 0
    FOR (dia, frecuencia) EN frecuenciasDiaSemanaGlobal.items ordenado DESC DO
        SI frecuencia > maxFrecuenciaDiasemanaGlobal entonces
            diaSemanaPreferidoGlobal = dia
            maxFrecuenciaDiasemanaGlobal = frecuencia
        SINO
            BREAK
        FIN SI
    
    // Solo considerar día preferido si hay al menos 2 compras en ese día GLOBALMENTE
    IF diaSemanaPreferidoGlobal != NULL Y maxFrecuenciaDiasemanaGlobal >= 2 entonces
        frecuenciasDiaSemanaJSON = serialize_map(frecuenciasDiaSemanaGlobal)
    SINO
        frecuenciasDiaSemanaJSON = "{}"
        diaSemanaPreferidoGlobal = NULL
    FIN
    
    // =========================================
    // PASO 11: Weekday Score GLOBAL — boost multiplicativo por coincidencia
    // =========================================
    
    hoyDiaSemana = DateTime.now().weekday_indexed()
    weekdayScore = NULL
    
    SI diaSemanaPreferidoGlobal != NULL entonces
        diff = abs(hoyDiaSemana - diaSemanaPreferidoGlobal)
        
        IF diff == 0 entonces
            weekdayScore = 1.0   // Exacto (global)
        SI diff == 1 entonces
            weekdayScore = 0.7   // Adyacente
        SI diff == 2 entonces
            weekdayScore = 0.4   // Dos días de distancia
        SINO
            weekdayScore = NULL  // +3: sin boost significativo
        
    SINO
        weekdayScore = NULL
    
    // =========================================
    // PASO 12: Puntuación compuesta final GLOBAL
    // =========================================
    
    IF ventas.isNotEmpty entonces
        
        // Factores de Consistencia GLOBAL (~30%)
        scoreConsistencia = eventos + 
                           (kgPromedioEvento × 100.0) +  // Escalar kg para que sea comparable globalmente
                           (IF modaKg > 0 entonces frecuenciaDeModaGlobal SINO 0)
        
        // Factores de Volumen GLOBAL (~35%)
        scoreVolumen = (kgTotal / IF max(ventas.cantidad_kg.max()) then 1 else 100.0) × 100 + 
                       maximoKg +
                       kgPromedioSemana
        
        // Factores de Recencia GLOBAL (~10%)
        scoreRecencia = ultimas10
        
        // Normalizar cada factor a [0, 1] para que sea comparable globalmente
        puntuacionBase = 
            (scoreConsistencia / max(scoreConsistencia, 1)) × 0.3 +
            (scoreVolumen / max(scoreVolumen, 1)) × 0.35 +
            (scoreRecencia / 100.0) × 0.1
        
        // Aplicar boost del ciclo temporal GLOBAL (~15%)
        IF cicloScore != NULL entonces
            puntuacionBase = puntuacionBase + (cicloScore × 0.15)
        FIN
    
    SINO
        puntuacionBase = 0.0
    
    END IF
    
    // =========================================
    // PASO 13: Aplicar weekday boost multiplicativo final GLOBAL
    // =========================================
    
    IF puntuacionBase > 0 Y weekdayScore != NULL entonces
        
        // Mapeo weekday → multiplicative factor GLOBAL
        weekdayFactors = {
            1.0: 1.15,   // Coincide exactamente (global)
            0.7: 1.105,  // Adyacente
            0.4: 1.06,   // Dos días de distancia
        }
        
        factor = weekdayFactors.get(weekdayScore) ?? 1.0
        
        puntuacionFinal = puntuacionBase × factor
    
    SINO
        puntuacionFinal = puntuacionBase
    FIN
    
    resultado = {
        eventos: eventos,
        kg_total: kgTotal,
        moda_kg: modaKg ?? 0.0,
        maximo_kg: maximoKg,
        ultimas10: ultimas10,
        kg_promedio_evento: kgPromedioEvento,
        kg_promedio_semana: kgPromedioSemana,
        frecuencia_reparto: frecuenciaReparto,
        intervalo_promedio: intervaloPromedio ?? 0.0,
        dias_desde_ultima_venta: diasDesdeUltimaVenta ?? 0,
        ciclo_score: cicloScore,
        dia_semana_preferido: diaSemanaPreferidoGlobal ?? 0,
        frecuencias_dia_semana: frecuenciasDiaSemanaJSON,
        weekday_score: weekdayScore,
        puntuacion: puntuacionFinal,
    }
    
    RETURN resultado

FIN ALGORITMO


// =========================================
// CASO DE BORDE: Cliente con exactamente 1 venta global (un vendedor)
// =========================================
//
// ventas = [v1] (una sola de cualquier vendedor)
// intervaloPromedio = NULL (no hay pares consecutivos → no se puede calcular)
// diasDesdeUltimaVenta = N/A global
// modaKg = v1.cantidad_kg (solo un valor, es la moda por defecto)
// maximoKg = v1.cantidad_kg
// kgPromedioEvento = v1.cantidad_kg
// kgPromedioSemana = v1.cantidad_kg
// frecuenciaReparto = 0.0 o 1.0 (dependiendo de si tiene delivery_number)
// cicloScore = NULL
// diaSemanaPreferidoGlobal = weekday de v1.fecha
// frecuenciasDiaSemanaGlobal = {v1.weekday: 1} → maxFrecuenciaDiasemanaGlobal = 1
//   → No cumple el requisito "al menos 2 compras" → frecuencia_dia_semana = "{}"
//   → diaSemanaPreferidoGlobal = NULL
// weekdayScore = NULL
//
// Interpretación: Un cliente nuevo (1 venta total) tiene NULL para todo ciclo,
// no tiene día preferido detectado globalmente. Aparecerá en la lista pero con ranking bajo.


// =========================================
// CASO DE BORDE: Cliente con ventas de dos vendedores en días distintos
// =========================================
//
// Vendedor A compró al cliente el lunes → Vendedor B compró el jueves:
//   frecuenciasDiaSemanaGlobal = {1: 2, 4: 0} (solo hay una compra por día)
//   maxFrecuenciaDiasemanaGlobal = 1 → No cumple "al menos 2" → NULL
//
// Sin embargo si el vendedor A compró dos veces en lunes y una vez jueves:
//   frecuenciasDiaSemanaGlobal = {1: 3, 4: 0} (o sea {lunes: 3})
//   maxFrecuenciaDiasemanaGlobal = 3 ≥ 2 → cumple el mínimo GLOBALMENTE
//   diaSemanaPreferidoGlobal = lunes


// =========================================
// CASO DE BORDE: Cliente con ventas en todas las semanas posibles
// =========================================
//
// Si el cliente tiene ventas en W01, W02, ..., W13 (varias semanas):
//   kg_promedio_semana = media de los totales semanales globales
//   intervalo_promedio = calculado con TODAS las ventas consecutivas
//
// Ejemplo: 
//   Vendedor A vendió el día 5 → Vendedor B vendió el día 12 (diferencia global = 7 días)
//   → intervaloPromedio = 7 días (calculado correctamente a nivel global)


```

---

## A3. Algoritmo Extendido de Sincronización con Google Sheets Centralizado — Pseudocódigo Referencial Multi-Tenant

```
ALGORITMO SyncDataToGoogleSheetsCentralized(spreadsheetId, tipoDeSincronizacion, vendorId)
    INPUT: 
        spreadsheetId: String (ID del spreadsheet centralizado compartido)
        tipoDeSincronizacion: Enum {deliveries, sales, clients}  // Per-vendedor
        vendorId: Int (identificador del vendedor que sincroniza)
    OUTPUT: Resultado de sincronización (éxito/fracaso + conteo)
    
    // =========================================
    // VALIDACIÓN PREVIAS MULTI-TENANT
    // =========================================
    
    IF api_sheets NO ESTÁ inicializada entonces
        ERROR("Google Sheets API no está inicializada")
    
    // =========================================
    // FILTRADO POR VENDEDOR ANTES DE LA OPERACIÓN
    // =========================================
    
    switch tipoDeSincronizacion:
        case deliveries:
            datos = SELECT * FROM Repartos 
                    WHERE vendedor_id = vendorId 
                    ORDER BY numero_reparto ASC
            rango = "Repartos!A:I"  // Incluye vendor_id como columna A
        
        case sales:
            datos = SELECT * FROM Ventas 
                    WHERE vendedor_id = vendorId 
                    ORDER BY id ASC
            rango = "Ventas!A:H"  // Incluye vendor_id como columna extra
        
        case clients:
            datos = SELECT * FROM Clientes 
                    WHERE vendedor_id IS NULL OR vendedor_id = vendorId
                    ORDER BY id ASC
            rango = "Clientes!A:AC"  // Cliente consolidado de múltiples vendedores
    
    // =========================================
    // CONVERSIÓN A FORMATO GOOGLE SHEETS API MULTI-TENANT
    // =========================================
    
    valueRange = ValueRange(
        values: datos.map(d => d.to_list_de_valores())  
                // Cada fila ya incluye vendor_id como primera columna
    )
    
    // =========================================
    // OPERACIÓN DE ESCRITURA AL SHEET CENTRALIZADO
    // =========================================
    
    try {
        IF tipoDeSincronizacion == "read" entonces
            response = api.sheets.values.get(spreadsheetId, rango)
            RETURN SyncResult(success: true, message: "Datos leídos exitosamente", 
                             itemsProcessed: response.values.length())
        
        SINO  // Es una escritura
            await api.sheets.values.update(
                valueRange: valueRange,
                spreadsheetId: spreadsheetId,  // Centralizado para todos los vendedores
                range: rango,
                valueInputOption: 'USER_ENTERED'
            )
            
            RETURN SyncResult(
                success: true, 
                message: "${tipoDeSincronizacion} sincronizados exitosamente",
                itemsProcessed: datos.length()
            )
        
    } catch (e) {
        // Manejar errores de red, permisos, formato, etc.
        RETURN SyncResult(
            success: false, 
            message: "Error en sincronización: ${e.toString()}"
        )
    }

FIN ALGORITMO


// =========================================
// CASO DE BORDE: Vendedor nuevo sin datos previos
// =========================================
//
// Si el vendedor es nuevo y no tiene ventas ni repartos:
//   datos = []  // Array vacío
//   
//   La sincronización envía un array vacío al range
//   Google Sheets API escribe una fila vacía en el rango (potencial problema)


// =========================================
// CASO DE BORDE: Vendedor A y B sincronizan repartos simultáneamente
// =========================================
//
// Ambos vendedores escriben en el mismo range "Repartos!A:I":
//   - La API de Google Sheets maneja esto correctamente (es append)
//   - Cada fila tiene vendor_id distinto → sin colisión de datos


```

---

## A4. Algoritmo Extendido de Exclusión por Intervalo — Detalle Matemático Multi-Tenant Completo

### 4.1 Definición Formal Extendida

Dado:
- `c`: un cliente candidato en el pool de top N GLOBAL
- `d_last_global(c)`: fecha de la última venta real de `c` (de CUALQUIER vendedor, NULL si ningún vendedor vendió nunca)
- `I_global(c)`: intervalo promedio estimado entre compras de `c` calculado GLOBALMENTE (NULL si insuficiente historial global)
- `t₀`: fecha/hora actual del sistema

Definir:
```
threshold = 0.8          // Umbral temporal — porcentaje del ciclo que debe transcurrir
fallback_interval_global = 7     // Días por defecto cuando I_global(c) no está definido

days_since_last_sale_global(c) = 
    NULL                   SI d_last_global(c) == NULL
    (t₀.date - d_last_global(c).date).total_days() SINO

effective_interval_global(c) = fallback_interval_global           SI I_global(c) == NULL O I_global(c) <= 0
                     = I_global(c)                        SINO

exclude_if_global(c) = days_since_last_sale_global(c) < threshold × effective_interval_global(c)
```

### 4.2 Tabla Extendida de Ejemplos con el Algoritmo Aplicado (Multi-Vendedor)

| Cliente | Intervalo Global | Última Compra Global (hace) | Días desde última compra global | Umbral efectivo global | ¿Excluido GLOBALMENTE? |
|---------|------------------:|------------------------------|--------------------------------:|------------------------|-----------------------:|
| A       | 7 días            | 6 (por vendedor X)           | 5                               | 0.8 × 7 = 5.6          | **SÍ**                 |
| B       | 7 días            | 6 (por vendedor Y)           | 6                               | 0.8 × 7 = 5.6          | **NO**                 |
| C       | 14 días           | 3 por A, ayer por B          | 1 (globalmente última venta fue ayer) | 0.8 × 14 = 11.2      | **SÍ** (porque hizo 1 día) |
| D       | NULL              | — (nuevo cliente)            | —                               | N/A                    | **NO**                 |

### 4.3 Propósito extendido de diseño del umbral

El umbral de 0.8 (80%) es una **zona buffer multi-tenant**: el sistema espera que transcurra el 80% del ciclo esperado global antes de visitar al cliente. Esto:

1. Reduce visitas innecesarias en días intermedios
2. No excluye al cliente demasiado temprano (aún tiene probabilidad de comprar)  
3. Deja un margen del 20% para imprecisiones en la estimación del intervalo
4. **A nivel global:** Un vendedor A no puede visitar a un cliente que ya fue atendido ayer por el vendedor B

### 4.4 Sensibilidad extendida a cambios multi-tenant

- Si el umbral sube a 0.9: más clientes son excluidos globalmente (lista menor pero más selectiva)
- Si el umbral baja a 0.5: menos exclusiones globales (lista más amplia, más visitas potencialmente redundantes entre vendedores)

---

## A5. Estrategia B Extendida — Re-ordenamiento In-Memoria Multi-Tenant — Detalle de Implementación

### 5.1 Problema extendido que resuelve

La puntuación almacenada en SQLite (`puntuacion`) es estática: solo se actualiza cuando el usuario ejecuta `SyncType.rateClients`. Entre recálculos, la lista podría no reflejar prioridades actuales (ej: un cliente que compró ayer por cualquier vendedor ya no debería estar arriba). Además, con datos globales de múltiples vendedores, los scores frescos son más precisos.

### 5.2 Cómo funciona paso a paso extendido multi-tenant

```python
# Contexto del sistema MULTI-TENANT
cliente = {
    "puntuacion": 0.75,    # Score base almacenado en BD (incluye weekday boost global)
    "ciclo_score": 0.3,    # Componente de ciclo almacenado (global, estático)
    "weekday_score": 1.0,  # Boost semanal almacenado (puede ser obsoleto)
}

# Datos temporales calculados en este momento GLOBALMENTE:
lastSaleDatesGlobal = Map{cliente.id: DateTime(ayer)}   # Última venta de CUALQUIER vendedor

# ==========================================
# Paso 1: Descomponer el score almacenado para 
#         eliminar componentes que ya están ahí GLOBALMENTE
# ==========================================

# La puntuación guardada fue calculada como:
#   puntuacion_guardada = base_score + weekday_boost_global_al_momento

# El boost semanal se almacena como un multiplicador sobre la puntuación base global:
storedWeekdayBoost = 1.0 + (cliente.weekday_score × 0.15)
# Ejemplo: weekday_score = 1.0 → storedWeekdayBoost = 1.15

# Extraer el score base sin weekday boost:
scoreBaseSinWeekday = cliente.puntuacion / storedWeekdayBoost
# Ejemplo: 0.75 / 1.15 ≈ 0.652

# ==========================================
# Paso 2: Calcular ciclo_score en tiempo real GLOBALMENTE
# ==========================================

diasDesdeUltimaGlobal = (hoy - DateTime(ayer)).days = 1
intervaloPromedioGlobal = 7  # El cliente compra cada semana (calculado con datos globales)

desviacionCiclo_global = abs(diasDesdeUltimaGlobal - intervaloPromedioGlobal) / intervaloPromedioGlobal
                      = abs(1 - 7) / 7 = 6/7 ≈ 0.857

cicloFresco_global = max(0, 1 - desviacionCiclo_global)
                  = max(0, 0.143) = 0.143

# ==========================================
# Paso 3: Calcular weekday_score en tiempo real GLOBALMENTE
# ==========================================

# Cliente prefiere día jueves (dia_semana_preferido = 4) globalmente
# Hoy es miércoles (hoyDiaSemana = 3)
diff_global = abs(3 - 4) = 1 → weekday_score_fresco = 0.7

# ==========================================
# Paso 4: Reconstruir puntuación fresca GLOBALMENTE
# ==========================================

scoreBaseSinCicloGlobal = scoreBaseSinWeekday - (0.15 × cliente.ciclo_score)
                = 0.652 - (0.15 × 0.3) = 0.652 - 0.045 = 0.607

puntuacionFrescaGlobal = (scoreBaseSinCicloGlobal + 0.15 × cicloFresco_global) 
                        × weekday_score_fresco
                    = (0.607 + 0.15 × 0.143) × 0.7
                    = (0.607 + 0.021) × 0.7
                    = 0.628 × 0.7
                    = 0.440

# ==========================================
# Comparación con otro cliente en el mismo contexto multi-tenant
# ==========================================

# Otro cliente K con weekday_score almacenado = 0.7, ciclo_score = 0.5:
storedWeekdayBoost_K = 1.0 + (0.7 × 0.15) = 1.105
scoreBaseSinWeekday_K = 0.85 / 1.105 ≈ 0.769

diasDesdeUltimaGlobal_K = 4, intervalo_global_K = 7
desviacionCiclo_global_K = abs(4 - 7) / 7 = 3/7 ≈ 0.429
cicloFresco_global_K = max(0, 1 - 0.429) = 0.571

hoy es miércoles (3), K prefiere jueves globalmente → diff = 1 → weekday_fresco_K = 0.7

scoreBaseSinCiclo_K = 0.769 - (0.15 × 0.5) = 0.769 - 0.075 = 0.694
puntuacionFrescaGlobal_K = (0.694 + 0.15 × 0.571) × 0.7
                        = (0.694 + 0.086) × 0.7
                        = 0.780 × 0.7
                        = 0.546

# Resultado: Cliente C (0.440) < Cliente K (0.546) → K aparece primero
# Nota: el boost semanal de 0.7 se aplica a ambos, pero los componentes globales
# determinan la diferencia final


```

### 5.3 Complejidad extendida y rendimiento multi-tenant

- **Complejidad temporal:** O(n log n) por el sort final (n = candidatos filtrados globales)
- **Operaciones de aritmética pura** en cada cliente: ~5 operaciones por elemento
- **Sin I/O a disco**, sin llamadas a la API, sin escrituras a la base de datos
- **Escalable hasta miles de clientes globales** sin problemas

---

## A6. Estrategia A Extendida — Recálculo Completo Persistido Global — Detalle Matemático Multi-Tenant

### 6.1 Fórmulas detalladas extendidas multi-tenant

```python
# ==========================================
# kg_promedio_evento GLOBAL = kg_total / eventos (de TODOS los vendedores)
# ==========================================
# Nota: "eventos" incluye tanto ventas como rechazos/pendientes de CUALQUIER vendedor
  
# Si cliente tiene 10 ventas globales (45kg) y 3 rechazos globales:
#   eventos = 13 (de todos los vendedores combinados)
#   kg_promedio_evento = 45.0 / 13 ≈ 3.46

# ==========================================
# intervalo_promedio GLOBAL = media de diferencias entre compras consecutivas (CUALQUIER vendedor)
# ==========================================
# Solo usa ventas globales (no rechazos), ya que el "intervalo" es entre 
# oportunidades de compra, no entre cualquier interacción
  
# Ventas del cliente en orden cronológico (de TODOS los vendedores):
#   v1: 2024-01-05 (vendedor A, 3kg)
#   v2: 2024-01-18 (vendedor B, 7kg)  → intervalo global = 13 días
#   v3: 2024-02-09 (vendedor C, 5kg)  → intervalo global = 22 días  
#   v4: 2024-02-24 (vendedor A, 6kg)  → intervalo global = 15 días
#   v5: 2024-03-10 (vendedor B, 8kg)  → intervalo global = 14 días
  
# intervalos_globales = [13, 22, 15, 14]
# intervalo_promedio_global = media([13, 22, 15, 14]) = 64/4 = 16 días

# ==========================================
# kg_promedio_semana GLOBAL (rolling window)
# ==========================================
# Agrupar ventas por semana ISO de TODOS los vendedores:
  
# Semana 2024-W03: v1 (A, 3kg), v2 (B, 7kg) → total = 10kg global
# Semana 2024-W04: v3 (C, 5kg)              → total = 5kg global
# Semana 2024-W05: v4 (A, 6kg), v5 (B, 8kg)→ total = 14kg global
  
# semanasKg_global = {W03: 10, W04: 5, W05: 14}
# kg_promedio_semana_global = media([10, 5, 14]) = 29/3 ≈ 9.67

# ==========================================
# frecuencia_reparto GLOBAL (ventas por vuelta)
# ==========================================
# Si el cliente tiene ventas en los repartos de A=#1, B=#3, C=#5:
#   ventas_con_reparto_global = 4 (de las 5 ventas globales)
#   repartos_unicos_globales = {1, 3, 5} → 3 repartos de diferentes vendedores
#   frecuencia_reparto_global = 4/3 ≈ 1.33 ventas por ronda GLOBAL

# ==========================================
# ciclo_score GLOBAL — momento de compra óptima (global)
# ==========================================
# Hoy: 2024-03-20 (miércoles)
# Última venta global: v5, 2024-03-10 → daysSince = 10 días
# intervalo_promedio_global = 16 días
  
# desviacion_global = |10 - 16| / 16 = 6/16 = 0.375
# ciclo_score_global = max(0, 1 - 0.375) = 0.625

# Interpretación extendida: El cliente compra cada ~16 días globalmente y hace 
# 10 días que compró (por cualquier vendedor). Estamos a ~0.625 de la puntuación máxima.
# En un día perfecto, ciclo_score_global = 1.0.

# ==========================================
# weekday_score GLOBAL — boost por coincidencia de día (global)
# ==========================================
# Cliente prefiere días jueves y viernes globalmente:
#   frecuencias_dia_semana_global = {"4": 3, "5": 2}
#   dia_semana_preferido_global = 4 (jueves) ← el más frecuente GLOBALMENTE
  
# Hoy es miércoles → diff = |3 - 4| = 1 → weekday_score_fresco_global = 0.7

```

---

## A7. Controlador de Repartos Extendido — Flujo Multi-Tenant Completo

### 7.1 Máquina de Estados del DeliveryController Extendida

```
┌─────────────────────────────────────────────────────────────┐
│                    States Machine MULTI-TENANT               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│   [IDLE] ──startDelivery(N, vendorId)──► [ACTIVE]            │
│      ▲                              │                        │
│      │                 endDelivery() │                        │
│      │              (reset completo)  │                        │
│      │                              ▼                        │
│      │                        [PAUSED] ◄───────────────┘     │
│      │                  pause/pauseResume                     │
│      └───────────────────────────────────────────────────────┘│
│                                                               │
│   Transiciones especiales multi-tenant:                       │
│   • Abrir SectionDeliveryPage sin reparto activo:             │
│     → Si hay un número de reparto guardado en vendorId actual,  │
│       reanuda desde ahí                                        │
│     → Si no hay, inicia uno nuevo con el vendorId actual      │
└─────────────────────────────────────────────────────────────┘


```

### 7.2 Estado persistente extendido multi-tenant vs in-memory

| Estado | Dónde vive | ¿Se pierde al cerrar app? |
|--------|-----------|-------------------------|
| `numeroRepartoActual` + vendorId | In-memory (en el controller) | Sí, pero se restaura del singleton |
| `clientesContactados[]` | In-memory | No — se persiste en `DeliveryStateManager` |
| `clientesEstado[]` | In-memory | No — se persiste en `DeliveryStateManager` |
| `selectedClienteIndex` | In-memory | No — en el state manager |
| Estado del reparto (vendorId, totals) | SQLite (`persistent_delivery_states`) | **NO** — persistente por vendor_id |

### 7.3 Persistencia extendida del estado de reparto multi-tenant

```python
# Al iniciar un reparto:
# 1. Insertar en persistent_delivery_states con vendor_id:
INSERT INTO persistent_delivery_states (id, is_active, vendor_id, 
    elapsed_seconds, delivery_number, initial_boxes)
VALUES ('current', TRUE, $vendorIdActual, 0, N, cajas_iniciales ?? 0);

# 2. Al finalizar un reparto:
UPDATE persistent_delivery_states SET 
    is_active = FALSE, 
    elapsed_seconds = X,
    delivery_number = N,
    initial_boxes = cajas_iniciales;
-- Luego borrar el registro (o dejarlo como registro histórico)


```

---

## A8. Flujos de Errores Extendidos y Casos de Degeneración Multi-Tenant

### 8.1 ¿Qué pasa si Google Sheets está offline?

```python
try:
    await api.sheets.values.get(spreadsheetId, rango)
except Exception as e:
    # Captura timeout, connection refused, auth failed, etc.
    RETURN SyncResult(
        success: FALSE, 
        message: "No se pudo conectar con Google Sheets centralizado: ${e.message}"
    )

# La app continúa funcionando normalmente — todos los datos siguen locales


```

### 8.2 ¿Qué pasa si la tabla de clientes está vacía globalmente?

```python
clientes = await db.getAllClientes()

IF clientes.isEmpty entonces
    RETURN SyncResult.success("No hay clientes para puntuar (global).")
SINO
    // Procede con el cálculo normal


```

### 8.3 ¿Qué pasa si no se pueden calcular los intervalos globales (solo 1 venta total)?

```python
intervalos = []
FOR i EN range(1, len(ventas_ordenadas_global)) DO
    intervalos.add(diff)

IF intervalos.isEmpty entonces
    intervalo_promedio_global = NULL  # No se puede calcular con <2 ventas globales


```

### 8.4 ¿Qué pasa si el cliente tiene ventas pero sin delivery_number (ningún vendedor lo registró)?

```python
// Para frecuencia_reparto global:
ventas_con_reparto_global = [v for v in ventas IF v.delivery_number != NULL]

IF ventas_con_reparto_global.isEmpty entonces
    frecuencia_reparto_global = 0.0   # No hay datos de repartos globales para calcular


```

### 8.5 Caso extendido: Vendedor A no tiene ventas con el cliente, pero vendedor B SÍ

**Escenario multi-tenant:** El cliente ha comprado hace 3 días por el vendedor B pero no por el vendedor A.

```python
// PASO 1 del algoritmo de exclusión para el vendedor A:
ultimaVentaGlobal = lastSaleDates[cliente.id]  // ← Fecha de la venta de B (global)
diasDesdeUltima = 3  // Hace 3 días que compró por B

umbralExclusion = 0.8 × 7 = 5.6

SI 3 < 5.6 → VERDADERO → EXCLUIDO GLOBALMENTE para el vendedor A también!
```

**Interpretación extendida:** Aunque el vendedor A no vendió al cliente hace poco, 
el intervalo global (basado en la venta de B) indica que el cliente probablemente 
ya compró y no necesita producto nuevo. **Ningún vendedor debe visitarlo.**


### 8.6 Caso extendido: Dos vendedores quieren visitar al mismo cliente hoy

**Escenario:** El cliente compró hace 8 días (intervalo global = 7). Hoy es día 8:
- Vendedor A quiere visitar → ciclo global indica que está cerca del momento óptimo
- Vendedor B también quiere visitar → mismo problema

```python
// Para ambos vendedores:
diasDesdeUltimaGlobal = 8  // Hace 8 días (global)
intervaloGlobal = 7

umbralExclusion = 0.8 × 7 = 5.6
SI 8 < 5.6 → FALSO → NO excluidos por intervalo GLOBALMENTE

// Ambos pueden visitar al cliente (el intervalo ya pasó), pero si A vende hoy:
ventasDelDiaPorA = [v1]  // A vendió a este cliente hoy
```

**Resultado:** El vendedor B también puede visitar al cliente (pasó el umbral global), 
pero una vez que A lo atiende, la venta de A actualiza el intervalo global. 
El siguiente día el ciclo_score bajará y posiblemente ambos vendedores esperarán.


---

## A9. Consideraciones Técnicas Extendidas para Reimplementación Multi-Tenant (Lenguaje-Independiente)

### 9.1 Patrón Singleton extendido multi-tenant con Inicialización Lazy

Tanto `DatabaseService` como `GoogleSheetsService` usan el patrón singleton:
- Instancia única global (`_instance`)
- Creada la primera vez que se necesita
- Reutilizada en todas las llamadas subsiguientes
- La inicialización de Google Sheets (autenticación) es costosa — hacerla una sola vez

### 9.2 Patrón Fire-and-Forget extendido para actualizaciones asíncronas multi-tenant

La actualización de scores del cliente (`refreshSingleClientScore`) se ejecuta como:
```python
unawaited(refreshSingleClientScore(clientId))
```

Esto significa:
- **No espera** a que termine la actualización global
- **No maneja errores explícitamente** (si falla, simplemente ignora)
- **Permite la UI seguir respondiendo** mientras se actualiza en background
- **Es idempotente** — llamar varias veces es seguro

### 9.3 Manejo extendido de tipos JSON vs nativos multi-tenant

Algunos campos usan serialización JSON para almacenar estructuras complejas:
- `frecuencias_dia_semana`: `{0: 3, 2: 5}` en texto JSON (calculado globalmente)
- Esto permite guardar mapas/objetos en columnas simples sin schemas anidados

**Nota extendida:** Esto es una decisión de diseño práctica (evita migraciones complejas) pero introduce vulnerabilidad a errores de parseo. Siempre usar `try/catch` al deserializar, especialmente con datos globales que pueden provenir de múltiples fuentes.

### 9.4 Uso extendido de `limit(60)` en el pool candidato multi-tenant

El algoritmo solo considera los top 60 clientes por puntuación global. Esto significa:
- Clientes con puntuación < N°60 nunca son candidatos, incluso si cumplen todos los criterios temporales globales
- Es una optimización para no evaluar todos los clientes cada vez (globalmente)
- **Pendiente de validación:** ¿Es 60 un buen límite global? Con pocos clientes en la base, podría ser demasiado restrictivo; con miles, podría perder buenos clientes que están fuera del top 60

> **Actualización (implementación vigente):** desde `1c62312` el pool por puntuación ya no existe. `ClientRecommendationService.select` evalúa **todo el catálogo del vendedor** (sin `LIMIT`), sólo admite clientes con compras válidas propias y completa hasta 60 con cupos: 48 activos + hasta 9 seguimientos iniciales + 3 reactivaciones garantizadas + relleno con más reactivaciones por score. Si el catálogo no alcanza, la lista queda más corta. Ver `docs/SELECCION_REPRESENTATIVA_CLIENTES.md`.

---

## A10. Resumen Comparativo Extendido — Implementaciones Alternativas al Sistema Multi-Tenant Original

| Decisión | Implementado (Dart/Drift multi-tenant) | Alternativa equivalente |
|----------|----------------------------------------|-------------------------|
| ORM + código generado multi-tenant | Drift con wrapper vendor_id per query | TypeORM, Prisma con tenant context |
| Sincronización Sheets API v4 centralizada | googleapis v4 SDK | googleapis equivalentes por lenguaje |
| Autenticación Service Account centralizada | google-auth service account flow | google-auth equivalentes por lenguaje |
| Singleton de DB + per-vendedor | Factory pattern con instancia estática | Singleton pattern equivalente |
| Patrón singleton + lazy init multi-tenant | `DatabaseService._internal()` | Singleton con lazy initialization |
| Fire-and-forget async multi-tenant | `unawaited()` | `fireAndForget()`, `.andThenIgnore()` |
| Codegen desde schema multi-tenant | Drift code generation | Prisma generate, TypeORM decorators |
| Service Account auth centralizado | google-auth service account flow | google-auth equivalentes por lenguaje |
| Estado persistente en DB multi-tenant | SQLite + tabla `persistent_delivery_states` con vendor_id | Realm persistent state, Hive |

---

*Documento de implementación referencial extendido complementario. Proporciona pseudocódigo ejecutable para los algoritmos más complejos del sistema multi-tenant.*
