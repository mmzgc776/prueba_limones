# Especificación Técnica — Sistema de Gestión para Vendedores Itinerantes Multi-Tenant

## Documento de Diseño Independiente del Lenguaje

Esta especificación describe el sistema sin referencias a Flutter, Dart ni Drift. Está pensada para ser implementada con cualquier stack (React Native / Swift / Kotlin / Python + WebView / .NET MAUI / etc.). Captura **qué** hace el sistema, **cómo** lo hace conceptualmente y **por qué** toma las decisiones que toma, no cómo se escribieron los bytes en memoria.

---

## 1. Propósito del Sistema

Un grupo de vendedores ambulantes de limones recorre la ciudad visitando clientes (tiendas, restaurantes, hogares) para vender su producto. El sistema les ayuda a:

- Decidir **quién visitar primero** durante cada ronda ("vuelta"), optimizando el tiempo y maximizando ventas
- Registrar en campo lo que ocurre con cada cliente (contacto, venta rechazada, pendiente, encargado)
- Sincronizar los datos diarios con una hoja de cálculo centralizada para análisis compartido

El valor central es el **algoritmo de generación de la lista de clientes por visitar**, no un simple registro pasivo.

## 2. Modelo Multi-Tenant — Arqitectura Centralizada

### 2.1 Principio Fundamental: Local Primero, Sincronización Selectiva con Agregación Central

```
┌─────────────────────────────────────────────────────┐
│              CAPA DE UI (Mobile)                     │
│   Pantallas táctiles, formularios, tablas            │
│                                                      │
│  ┌───────────┐  ┌──────────────┐                    │
│  │ Estado     │  │ Controller  │                    │
│  │ Reparto    │  │ de Repartos  │                    │
│  └─────┬─────┘  └──────┬───────┘                    │
│        │               │                             │
│  ┌─────▼───────────────▼──────────┐                  │
│  │    CAPA DE SERVICIOS            │                  │
│  │                                │                  │
│  │ ├─ SyncService (orquestador)   │                  │
│  │ ├─ DatabaseService (CRUD)      │                  │
│  │ └─ DeliveryService (lógica de  │                  │
│  │        generación de lista)    │                  │
│  └─────┬──────────────────────────┘                  │
│        │                                             │
│  ┌─────▼──────────────────────────┐                  │
│  │      CAPA DE DATOS              │                  │
│  │                                │                  │
│  │  SQLite (Drift ORM)             │                  │
│  │  ┌─────┬─────┬─────┬─────┐    │                  │
│  │  │Ventas│Reps.│Ctls. │Notas│   │                  │
│  │  └─────┴─────┴─────┴─────┘    │                  │
│  └────────────────────────────────┘                  │
│                                                      │
└──────────────────────────────────────────────────────┘
                  ↑↓ Sincronización periódica
         ═════════╧═══════════════════════
         Google Sheets (almacén centralizado)
```

### 2.2 Capas y sus responsabilidades

| Capa | Responsabilidad | ¿Puede cambiarse de stack? |
|------|-----------------|---------------------------|
| **UI** | Renderizar formularios, listas, botones táctiles; manejar navegación entre pantallas | Sí — React Native, Flutter Web, Swift, etc. |
| **Controller** | Coordinar la lógica del negocio del día a día (reparto activo), orquestar servicios | Sí — patrón MVC, Clean Architecture, BLoC, etc. |
| **Service** | Comunicación con base de datos y con Google Sheets; encapsula la complejidad de acceso a datos | Sí — cualquier ORM + cliente HTTP |
| **Datos (SQLite)** | Almacenamiento persistente local por vendedores (1 DB por vendedor), esquema relacional | Sí — SQLite directo, Realm, WaterDB, etc. |

### 2.3 Principio de Aislamiento por Vendedor (Tenant Isolation)

**Cada vendedor tiene su propia base de datos SQLite completa e independiente.** El aislamiento es obligatorio en cada nivel:

- **Lectura:** Todas las consultas SQL incluyen `WHERE vendedor_id = $vendorId_actual`
- **Escritura:** Cada INSERT/UPDATE registra el vendor_id correspondiente
- **Sincronización:** Cada vendedor envía solo sus datos al Google Sheets centralizado
- **Seguridad:** Ningún vendedor puede acceder a los datos de otro sin permisos de administrador

**Nota clave:** La relación es **venta-uno-a-cliente**, no venta-uno-a-reparto. Una venta puede tener un reparto asociado (cuando se registra en campo) o ninguno (si se anota manualmente desde el escritorio). El `numero_reparto` es opcional y sirve para reconstruir qué ventas componieron cada ronda.

## 3. Modelo de Datos — Esquema Relacional Multi-Tenant

### 3.1 Tablas Principales

#### Vendedores (Vendors) — Nuevo

Base de datos de usuarios del sistema. Cada vendedor tiene su propia cuenta con credenciales y token de sesión.

| Campo | Tipo | Semántica |
|-------|------|-----------|
| id | entero, autoincremental | Identificador único global del vendedor |
| nombre | texto | Nombre completo del vendedor (para identificación) |
| email | texto | Email de contacto (usado para OAuth si aplica) |
| password_hash | texto | Hash de la contraseña/PIN (bcrypt/argon2 — nunca texto plano) |
| telefono | texto | Teléfono de contacto del vendedor |
| ciudad_asignada | texto | Ciudad donde opera principalmente este vendedor |
| activo | booleano | ¿Puede iniciar repartos? (control desde admin) |

**Tabla de sesiones extendida:**
| Campo | Semántica |
|-------|-----------|
| id | "current" (fijo), FK → vendedores.id, timestamp de creación |
| is_paused | ¿Se pausó el temporizador? |
| elapsed_seconds | Duración acumulada del reparto actual |
| is_active | ¿Hay un reparto en curso? |
| delivery_number | Identificador del nuevo reparto actual (opcional hasta que se asigne) |
| initial_boxes | Número de cajas con las que arrancó el reparto |

#### Ventas (Sales) — Extendida con vendor_id

Registra cada transacción individual con un cliente. Ahora vinculada a quién vendió.

| Campo | Tipo | Semántica |
|-------|------|-----------|
| id | entero, autoincremental | Identificador único global de la venta |
| fecha | timestamp | Fecha/hora del momento de la venta |
| cliente_id | entero, FK → clientes.id | ¿A quién se le vendió? |
| cantidad_kg | decimal | Peso vendido en kilogramos |
| precio_unitario | decimal | Precio por kg |
| total_venta | decimal | `cantidad × precio` |
| nota_id | entero, nullable, FK → notas.id | Nota opcional anclada a la venta (para referencia rápida) |
| numero_reparto | entero, nullable | ¿En qué ronda del día ocurrió? Permite vincular ventas al contexto temporal de esa vuelta |
| **vendedor_id** | entero, FK → vendedores.id | **¿Quién vendió esto?** Aislamiento obligatorio en cada query |

### 3.2 Tablas Principales — Continúa

#### Repartos (Deliveries) — Extendida con vendor_id

Cada vez que un vendedor decide "salir a repartir" se crea un nuevo registro. Es un contenedor temporal de la jornada del vendedor.

| Campo | Tipo | Semántica |
|-------|------|-----------|
| numero_reparto | entero, autoincremental (por vendedor) | Identificador único de la ronda (1, 2, 3...) |
| fecha | timestamp | Cuándo empezó la ronda |
| duracion_segundos | entero | Tiempo total de la ronda en segundos |
| precio_promedio | decimal | Promedio ponderado de las ventas realizadas |
| kilos_totales | decimal | Suma de `cantidad_kg` de todas las ventas del reparto |
| cajas_usadas | entero | Cajas físicas utilizadas (para el vendedor) |
| kg_restante | decimal | ¿Cuánto producto queda? Se decrementa con cada venta |
| vendedor | texto | Nombre del vendedor que realiza la ronda |
| total_monetario | decimal | Suma de `total_venta` de todas las ventas |

**Nota sobre el autoincremental:** El campo `numero_reparto` es autoincremental **per-vendedor**, no global. Cada vendedor tiene sus propios números de reparto independientes (uno puede ir al #50 en su zona norte, otro también va al #50 en su zona sur).

#### Clientes (Clients) — Extendida con vendor_id y datos globales

El corazón del sistema de inteligencia. Cada cliente tiene datos demográficos **y** métricas calculadas. El `vendedor_id` indica la asignación primaria pero cualquier vendedor puede registrar ventas a este cliente.

| Campo | Tipo | Semántica |
|-------|------|-----------|
| id | entero, autoincremental | Identificador único global del cliente |
| nombre | texto | Nombre o razón social del cliente |
| contacto_principal | texto | Persona de contacto en el negocio |
| tipo_negocio | texto | Categoría (tienda, restaurante, panadería...) |
| ciudad | texto | Localidad donde opera este cliente |
| domicilio | texto | Dirección postal |
| ubicacion_gps | texto | Coordenadas GeoJSON/GeoHash |
| telefono | texto | Teléfono de contacto del cliente |
| consumo_estimado | entero | Último valor registrado de consumo (kg) |
| ultimo_contacto | timestamp | Fecha/hora del último contacto exitoso |
| hora_apertura | entero (0-24) | Hora aproximada de apertura |
| hora_cierre | entero (0-24) | Hora aproximada de cierre |
| dias_atencion | texto JSON array | Array `[0,1,3]` = lunes, martes, jueves (días de la semana, 0=domingo...6=sábado) |
| notas_id | entero, nullable, FK → notas.id | Nota principal del cliente |

**Métricas calculadas — son globales (todas las ventas de todos los vendedores):**

| Campo | Tipo | Semántica |
|-------|------|-----------|
| eventos | entero | Total de interacciones registradas por cualquier vendedor |
| kg_total | decimal | Suma histórica total de todas las ventas a este cliente (cualquier vendedor) |
| moda_kg | decimal | La cantidad más frecuente comprada globalmente |
| maximo_kg | decimal | Mayor compra individual en la historia (global) |
| ultimas10 | decimal | Promedio de participación en las últimas 10 rondas (global) |
| kg_promedio_evento | decimal | Kg promedio por visita entre todos los vendedores |
| kg_promedio_semana | decimal | Kg promedio vendido por semana (rolling window global) |
| frecuencia_reparto | decimal | Frecuencia estimada de compra por ronda (global) |
| puntuacion | decimal | Score compuesto que determina el ranking del cliente en la lista de visita |

**Campos de ciclo temporal — calculados globalmente:**

| Campo | Tipo | Semántica |
|-------|------|-----------|
| intervalo_promedio | decimal, nullable | Promedio de días entre compras consecutivas (global) |
| dias_desde_ultima_venta | entero, nullable | Días transcurridos desde la última venta real (cualquier vendedor) |
| ciclo_score | decimal, nullable | ¿Qué tan cerca estamos del momento óptimo de compra? |
| dia_semana_preferido | entero, nullable | Día de la semana en el que más compras hizo este cliente (global) |
| frecuencias_dia_semana | texto JSON | Mapa `{0: 3, 2: 5, 4: 1}` = vendió globalmente |

### 3.3 Tablas de Soporte — Extendidas con vendor_id

#### Interacciones (Contacts) — Extendida con vendor_id

Registro de cada encuentro con un cliente, independientemente de si hubo venta o no.

| Campo | Tipo | Semántica |
|-------|------|-----------|
| id | entero, autoincremental | Identificador único global |
| cliente_id | entero, FK → clientes.id | ¿A quién se le habló? |
| resultado | texto enumerado | "Venta" / "Rechazó" / "Pendiente" / "Encargó" |
| delivery_id | entero, nullable | Referencia a la ronda en que ocurrió la interacción |
| timestamp | timestamp | Hora exacta del encuentro |
| **vendedor_id** | entero, FK → vendedores.id | **¿Quién registró esta interacción?** Aislamiento obligatorio |

#### Notas (Notes) — Extendida con vendor_id

Sistema de notas independientes, vinculables a clientes o ventas.

| Campo | Tipo | Semántica |
|-------|------|-----------|
| id | entero, autoincremental | Identificador único |
| contenido | texto | Contenido de la nota (obligatorio) |
| cliente_id | entero, FK → clientes.id | Nota atada a un cliente |
| venta_id | entero, nullable, FK → ventas.id | Nota atada a una venta específica |
| color_etiqueta | texto | Color visual para categorizar notas |
| **vendedor_id** | entero, FK → vendedores.id | **¿Quién creó la nota?** Aislamiento obligatorio |

### 3.4 Relaciones y Cardinalidades Extendidas

```
Vendedores (N:1) ──► Clientes (1:1)        ← Un cliente puede tener múltiples vendedores asignados
Repartos de VendedorA (N:M) ──► Ventas de A — vinculo opcional por numero_reparto
Repartos de VendedorB (N:M) ──► Ventas de B
Interacciones de VendedorX (N:1) ──► Clientes
Notas de VendedorY (N:M) ──► Clientes, Ventas
```

**Vinculación de ventas con repartos:** No se usa un FK directo. Se asocia por el campo `numero_reparto` en la tabla de ventas. Esto permite:
- Registrar una venta sin saber qué ronda es (campo nullable)
- Volver a asignar ventas a rondas más tarde

## 4. Estado del Reparto Activo — Patrón Singleton Persistente Multi-Tenant

### 4.1 Concepto Extendido

El "estado del reparto" no vive en la memoria volátil de la UI. Se persiste en SQLite y puede recuperarse al reaperturar la app o cambiar de pantalla, manteniendo el contexto de la ronda activa sin perderse. Ahora cada vendedor tiene su propio estado persistente independiente.

**Tabla extendida `persistent_delivery_states`:**
| Campo | Semántica Extendida |
|-------|---------------------|
| id | "current" (fijo), vendor_id: FK → vendedores.id |
| hora_inicio | Cuándo arrancó el temporizador |
| is_paused | ¿El usuario pausó el temporizador? |
| segundos_transcurridos | Duración acumulada |
| is_active | ¿Hay un reparto en curso? |
| numero_reparto | Identificador del nuevo reparto actual (opcional hasta que se asigne) |
| cajas_iniciales | Número de cajas con las que arrancó |

### 4.2 Estado In-Memoria durante la sesión — Extendido

Paralelamente al persistido, existen en memoria listas temporales:
- `clientes_contactados`: booleano por índice — ¿se le habló a este cliente?
- `clientes_estado`: texto por índice — resultado del contacto ("Rechazó", "Pendiente") o vacío si no se contactó
- `cliente_seleccionado`: índice del cliente actualmente visible en detalle
- **`vendor_id_actual`**: Identificador del vendedor autenticado (contexto principal)

### 4.3 Transiciones de Estado Extendidas

```
[NO REPARTO] ──startDelivery(N, cajas?)──► [REPARTO ACTIVO]
                                                    │
                                          ┌─────────┤ pause/pauseResume
                                          │          ▼
                                          │      [REPARTO PAUSADO]
                                          │
                          endDelivery()  │
                              ▲           │
[NO REPARTO] ◄────────────────┘
```

**Al finalizar (endDelivery):** Se calcula automáticamente: duración total, kg totales, ventas totales. El estado se resetea completamente y el vendor_id del reparto queda registrado para auditoría centralizada.

## 5. Algoritmo de Generación de Lista — El Corazón del Sistema Extendido Multi-Tenant

Esta es la parte más compleja y valiosa del sistema. Determina **qué clientes visitar en qué orden** durante cada ronda. Ahora el algoritmo considera datos globales (todos los vendedores) pero aplica exclusiones per-vendedor.

### 5.1 Paso 1: Pool Candidato — Top N por Puntuación Global

```sql
SELECT * FROM clientes WHERE vendedor_id IS NULL OR vendedor_id = $vendorIdActual
ORDER BY puntuacion DESC
LIMIT 60
```

La puntuación (`puntuacion`) es un score compuesto que combina múltiples factores calculados globalmente (todas las ventas de todos los vendedores para cada cliente). Solo se recalcula cuando el usuario ejecuta manualmente o mediante la Estrategia A. Es **estática** entre recálculos — no cambia en tiempo real.

> **Nota (implementación vigente, `1c62312`):** el pool `LIMIT 60` por `puntuacion` ya no se usa. La lista vigente evalúa todo el catálogo del vendedor desde sus ventas reales con `ClientRecommendationService.select` (ver `docs/SELECCION_REPRESENTATIVA_CLIENTES.md`); este paso se conserva como referencia del diseño anterior.

### 5.2 Paso 2: Última Venta Real por Cliente (Tiempo de Ejecución — Global)

Para cada candidato, buscar su última venta registrada por CUALQUIER vendedor:

```sql
SELECT * FROM ventas WHERE cliente_id IN (lista_candidate_ids) ORDER BY fecha DESC LIMIT 1 per client
```

Resultado: `Mapa{cliente_id → fecha_ultima_venta}`. Esto se hace **al vuelo** en el momento de generar la lista, no se almacena. La clave aquí es que busca TODAS las ventas del cliente, sin filtrar por vendedor — esto permite calcular intervalos y puntuaciones globales precisas.

### 5.3 Paso 3: Exclusión Temporal Global por Intervalo

Para cada candidato que SÍ tuvo venta registrada (por cualquiera), calcular si debe excluirse del repartido actual:

```python
dias_desde_ultima_venta = hoy - fecha_ultima_venta (en días)  # GLOBAL
intervalo_cliente = intervalo_promedio calculado ?? 7.0 (fallback global)
umbral_exclusion = 0.8

EXCLUIR SI: dias_desde < (intervalo × umbral_exclusion)
```

**Interpretación:** No se visita a un cliente que compró hace poco. El sistema espera que el cliente necesite nuevo producto según su ritmo habitual de compra global. Si Juan vendió al cliente ayer y Carlos lo vende hoy, Carlos NO debería visitarlo (el intervalo ya pasó).

### 5.4 Paso 4: Exclusión por Reparto Actual — Per-Vendedor

Excluir clientes que ya se atendieron hoy o que rechazaron hoy **por el mismo vendedor**:

```sql
-- Ventas del día actual que ya están en una ronda DE ESTE VENDEDOR
SELECT DISTINCT cliente_id FROM ventas 
WHERE delivery_number = N_reparto_actual
  AND vendedor_id = $vendorIdActual

-- Clientes que rechazaron HOY (solo por este vendedor)
SELECT DISTINCT cliente_id FROM interacciones 
WHERE resultado = 'Rechazó' AND timestamp >= fecha_hoy
  AND vendedor_id = $vendorIdActual
```

**Nota:** Los rechazos de otros vendedores NO excluyen al cliente para el vendedor actual. Solo los rechazos del propio vendedor cuentan como exclusión temporal por reparto actual. Esto permite que diferentes vendedores visiten al mismo cliente en días distintos.

### 5.5 Paso 5: Filtrado Final Extendido

```python
todos_excluidos = set(excluidos_por_intervalo_global) | set(excluidos_actual_reparto_propio)
lista_final = [c for c in top60 if c.id not in todosExcluidos]
```

### 5.6 Estrategia B: Re-ordenamiento por Scores Frescos (Sin Persistencia, Global)

Una vez que la lista de clientes está filtrada, se le da un **re-ordenamiento inteligente en memoria**:

1. Calcular `ciclo_score` fresco para cada cliente:
   ```python
   ciclo_fresco = 1 - (|días_desde_ultima_venta_global - intervalo_promedio_global| / intervalo_promedio_global)
   # Rango [0, 1], 1 = exactamente en el momento ideal de compra (global)
   ```

2. Calcular `weekday_score` fresco:
   ```python
   if hoy_es_dia_preferido:        weekday = 1.0   # ×1.15 boost
   elif dif_1_dia:                 weekday = 0.7   # ×1.105 boost
   elif dif_2_dias:                weekday = 0.4   # ×1.06 boost
   else (3+ días):                 weekday = 0.0   # sin boost
   ```

3. Reconstruir puntuación aproximada:
   ```python
   base_sin_ciclo = puntuacion_global / storedWeekdayBoost - 0.15 * ciclo_score_guardado
   puntuacion_fresca = (base_sin_ciclo + 0.15 * ciclo_fresco) * weekday_boost
   ```

4. Ordenar la lista por `puntuacion_fresca` descendente.

**Ventaja de esta estrategia:** No hay escrituras a disco ni latencia en la API. Es puramente aritmética en memoria, O(n). Se ejecuta al final del `_loadData()` y reordena instantáneamente los clientes mostrados.

### 5.7 Estrategia A: Recálculo Completo Persistido Global (Fondo)

Después de registrar una venta en el formulario de venta (`venta_form.dart`), se dispara asíncronamente (fire-and-forget):

```dart
unawaited(_syncService.refreshSingleClientScore(clientId));
```

Esta función recalcula **toda** la suite de métricas del cliente afectado globalmente:
- `kg_total`, `moda_kg`, `maximo_kg`: sumas globales de TODAS las ventas a este cliente (cualquier vendedor)
- `intervalo_promedio`: promedio de días entre compras consecutivas (global, usando todas las ventas del cliente)
- `ultimas10`, `kg_promedio_evento`, `kg_promedio_semana`, `frecuencia_reparto`
- `puntuacion` final = fórmula compuesta completa

Y se persiste en SQLite. **No bloquea la UI ni el guardado de venta** — es fire-and-forget.

### 5.8 Diagrama del Algoritmo Completo Extendido

```
┌─────────────────────────────────────────────────┐
│  START DEL REPARTO (carga de clientes)           │
│                                                  │
│  Paso 1: SELECT TOP 60 por puntuacion DESC       │
│          → candidatos = {c1, c2, ..., c60}       │
│          (puntuación es GLOBAL — todos los vendedores) │
│                                                  │
│  Paso 2: Para cada candidato, buscar ultima      │
│         venta real (tiempo de ejecución)          │
│         → Map{id: DateTime}                      │
│         (BÚSQUEDA GLOBAL, sin filtro vendor_id)  │
│                                                  │
│  Paso 3: Filtro temporal por intervalo            │
│         Excluir si: dias_desde < umbral×intervalo │
│          → Set{excluidos_intervalo}              │
│                                                  │
│  Paso 4: Obtener ventas y rechazos del día       │
│         actuales DEL MISMO VENDEDOR (per-vendedor)│
│          → Set{excluidos_actual_reparto_propio}  │
│                                                  │
│  Paso 5: Intersección de exclusiones             │
│         lista_filtrada = candidatos - todos_excluidos │
│                                                  │
│  Paso 6 (B): Re-ordenar in-memory por scores     │
│          frescos (ciclo + weekday, GLOBAL)       │
│          → Lista final ordenada                   │
│                                                  │
└─────────────────────────────────────────────────┘

Después de registrar venta:
┌──────────────┐
│ Estrategia A │  ← Fire-and-forget, recalcula todo globalmente
│ refreshSingle│     pero no bloquea la UI ni el guardado
│ ClientScore  │
└──────────────┘
```

## 6. Sistema de Puntuación — Inteligencia Multi-Tenant Global

### 6.1 Fórmula Compuesta Extendida

La puntuación final se calcula como una suma ponderada de factores globales:

```
Puntuación = f(Consistencia global) + f(Volumen global) + f(Recencia global) + f(Ciclo temporal) + Boost_Semanal
```

Los pesos aproximados (basados en la implementación):
- **Factores de Consistencia** (~30% del score base): estabilidad y regularidad del cliente desde TODOS los vendedores
  - `eventos`: número total de interacciones registradas por cualquier vendedor
  - `moda_kg`: frecuencia de compra de un tamaño específico (patrón estable global)
  - `kg_promedio_evento`: promedio de kg por visita entre todos los vendedores

- **Factores de Volumen** (~30% del score base): magnitud del negocio con este cliente globalmente
  - `kg_total`: suma histórica total de TODAS las ventas a este cliente (cualquier vendedor)
  - `maximo_kg`: la compra más grande en toda la historia
  - `kg_promedio_semana`: consistencia volumétrica semanal (global rolling window)

- **Factores de Recencia** (~10% del score base): actividad reciente global
  - `ultimas10`: participación en las últimas 10 rondas de todos los vendedores combinadas

- **Factor de Ciclo** (~15% del score base): temporalidad
  - `ciclo_score`: distancia al momento óptimo de compra calculada con intervalos globales. Un cliente que compra cada 7 días y hoy es día 6 tiene un ciclo score alto → sube en el ranking

### 6.2 Boost Semanal Multiplicativo Extendido ( weekday_boost )

Independientemente del score base, si la fecha actual coincide con el patrón semanal global del cliente, se aplica un multiplicador:

| Días de diferencia desde el día preferido | Factor weekday | Multiplicador final sobre puntuación |
|-------------------------------------------|---------------|--------------------------------------|
| Coincide exactamente                      | 1.0           | × 1.15 (+15%)                        |
| 1 día antes/después                       | 0.7           | × 1.105 (+10.5%)                     |
| 2 días antes/después                      | 0.4           | × 1.06 (+6%)                         |
| 3+ días                                   | 0.0           | × 1.0 (sin cambio)                   |

**Lógica:** El vendedor prefiere visitar clientes en sus días preferidos porque es más probable que compren. Esto multiplica la puntuación base del cliente, elevándolo por encima de otros con score similar pero sin coincidencia semanal.

### 6.3 Cálculo del `intervalo_promedio` (Días entre Compras) — Global

Se calcula como el promedio de diferencias entre compras consecutivas **entre todos los vendedores**:

```python
ventas_ordenadas = ventas_del_cliente ordenadas por fecha ASC (de TODOS los vendedores)
diferencias = []
para i en range(1, len(ventas_ordenadas)):
    diff = (ventas[i].fecha - ventas[i-1].fecha).days  # Días entre compras consecutivas de cualquier vendedor
    diferencias.append(diff)

intervalo_promedio = media(diferencias)
```

Si el cliente tiene pocas ventas totales (<2), no se puede calcular un intervalo confiable y se marca como NULL (usando fallback de 7 días). Un cliente con una venta de Juan y otra de Carlos permite calcular intervalos globales.

### 6.4 Cálculo del `ciclo_score` — Global

```python
dias_desde = hoy - fecha_ultima_venta_global (en días)  # Última compra de CUALQUIER vendedor
intervalo = intervalo_promedio_global  # Promedio calculado con todas las ventas

si intervalo > 0:
    desviacion = |dias_desde - intervalo| / intervalo
    ciclo_score = max(0, 1 - desviacion)  # [0, 1]
else:
    ciclo_score = 0.0
```

Un `ciclo_score` de 1.0 significa que hoy es exactamente el día esperado para comprar según el historial global del cliente. De 0 significa que ni se acerca.

## 7. Sistema de Sincronización con Google Sheets Centralizado

### 7.1 Arquitectura Extendida: Almacén Agregado Multi-Tenant

```
┌──────────────┐    ┌─────────────────────────────────┐     ┌──────────────┐
│   Vendedor A │    │      GOOGLE SHEETS              │     │   ADMIN /    │
│  DB Local A  │    │                                  │     │   SUPERVISOR │
└──────┬───────┘    │                                   │     └──────────────┘
       │            │   Repartos!A:I                     │
       │  escritura  │   (agregados por vendor_id)        │     │             │
       │◄────────────│   Col A: vendor_id / nombre        │     │             │
       │            │   Col B-I: datos de repartos        │─────┼────────────┘
       │  lectura    └──────────────────────────────────┬──┘
               (agregaciones consolidadas)              │
                          ↑                             │
┌──────────────┐    ┌─────────────────────────────────┤│
│   Vendedor B │    │      GOOGLE SHEETS              ││
│  DB Local B  │    │                                  ││
└──────┬───────┘    │   Ventas!A:I                     ││
       │            │   (agregadas por vendor_id)       ││
       │  escritura  │   Col I: seller_id                ││
       │◄────────────│                                   ││
               (agregaciones consolidadas)              ││
                          ↑                             ││
┌──────────────┐    ┌─────────────────────────────────┤││
│   Vendedor C │    │      GOOGLE SHEETS              ├┼┘
│  DB Local C  │    │                                  ││
└──────┬───────┘    │   Clientes!A:AD                  ││
       │            │   (consolidado de todos los     ││
                ▲   vendedores para este cliente)      ││
               (agregaciones consolidadas)             ││
```

### 7.2 Hojas Extendidas de Google Sheets Centralizado

| Hoja | Rango | Contenido Extendido |
|------|-------|---------------------|
| Repartos | `Repartos!A:I` | Datos de entregas por vendedor (cada fila tiene vendor_id) |
| Ventas | `Ventas!A:I` | Registros de ventas detalladas con vendor_id como columna extra (`seller_id` en la columna I) |
| Clientes | `Clientes!A:AD` | Información de clientes con `seller_id` en la columna AD (los ids de cliente son locales a cada app, el par `seller_id + id` los identifica) |

### 7.3 Tipos Extendidos de Operación de Sincronización

```dart
enum SyncType { 
    deliveries,   // Sincronizar repartos del vendedor actual → hoja "Repartos" (per-vendedor)
    sales,        // Sincronizar ventas del vendedor actual → hoja "Ventas" (per-vendedor)
    clients,      // Sincronizar clientes → hoja "Clientes" (agregación de todos los vendedores)
    rateClients,  // Recalcular puntuaciones globales (no escribe a Sheets directamente)
}
```

### 7.4 Columna `vendor_id` en las hojas de Google Sheets Centralizado

Cada fila de sincronización debe incluir el vendor_id para permitir agregación posterior:

**Repartos por vendedor:**
| vendor_id | numero_reparto | fecha | duracion_seg | kilos_totales | total_usd | ciudad_asignada | vendedor_nombre |
|-----------|---------------|-------|-------------|---------------|-----------|-----------------|-----------------|
| A         | 3             | 2024-03-15 | 7200 | 25.0 | $500 | Norte | Juan Pérez |

**Ventas por vendedor:**
| vendor_id | numero_reparto | cliente_id | cantidad_kg | precio | total_venta | fecha | vendedor_nombre |
|-----------|---------------|------------|-------------|--------|-------------|-------|-----------------|
| A         | 3             | 1042       | 5.0 | $20 | $100 | 2024-03-15 | Juan Pérez |

**Clientes consolidados (global):**
| cliente_id | nombre | vendedores_asignados | kg_total_hist | total_eventos | ciudad | dia_preferido |
|------------|--------|----------------------|---------------|---------------|--------|---------------|
| 1042       | Juan Pérez | [A, C] | 156.3 | 28 | Sur | jueves |

### 7.5 Autenticación Extendida — Cuenta de Servicio con vendor_id

El sistema usa un **service account** de Google Cloud para autenticarse al spreadsheet centralizado:

1. El archivo `credentials.json` contiene la clave privada del service account
2. Se carga una vez al inicio (singleton `_sheetsApi`)
3. El scope requerido es `SheetsApi.spreadsheetsScope`
4. La hoja debe ser compartida con el email de la cuenta de servicio

**Ventaja:** No requiere que cada vendedor configure su propio Google Account. Solo se comparte el spreadsheet una vez con el service account y funciona para todos los vendedores. El vendor_id se maneja en la capa local (filtrado por query), no en Sheets.

### 7.6 Flujo Extendido de Sincronización

```
Usuario presiona "Sincronizar"
        │
    ┌───┴─────┐
    │  Qué tipo│ ← Selecciona: repartos, ventas, clientes (per-vendedor)
    └───┬─────┘
        ▼
  Leer de SQLite local (filtrado por vendor_id actual)
        │
        ▼
  Escribir al rango correspondiente en Google Sheets (con vendor_id en cada fila)
        │
        ▼
  Mostrar resultado: "X registros sincronizados (vendedor: Juan Pérez)"
```

## 8. Controlador de Repartos — Coordinación Extendida Multi-Tenant

### 8.1 Responsabilidad Extendida

El `DeliveryController` es el orquestador que:
- Decide qué lista de clientes mostrar (llama a `DeliveryService.loadClientes()`)
- Gestiona transiciones entre estados (iniciar/pausar/reanudar/terminar)
- Vincula ventas al número de reparto actual **y al vendor_id**
- Coordina la carga inicial del data (`_loadData()` con filtro global + exclusión per-vendedor)
- **Valida autenticación en cada operación crítica**

### 8.2 Flujo Extendido de Inicialización del Reparto Activo

```
Abrir SectionDeliveryPage
        │
        ▼
_loadData() se ejecuta (o al primer rechazo)
        │
        ├─ vendorIdActual = obtenerVendorDelToken()
        │
        ├─ currentDeliveryNumber = 
        │   started? controller.getCurrentDeliveryNumber(vendorIdActual)
        │            : widget.resumeDeliveryNumber(vendorIdActual)
        │
        ▼
DeliveryService.loadClientes(excludeDeliveryNumber=currentDeliveryNumber, vendorId=vendorIdActual)
        │
        ├── Paso 1: Top 60 clientes por puntuación GLOBAL (SQL con WHERE vendedor_id IS NULL OR = $vendorId)
        ├── Paso 2: Última venta real por cliente — GLOBAL (sin filtro de vendor_id en la búsqueda)
        ├── Paso 3: Excluir clientes cuyo intervalo no ha pasado (global, usa todas las ventas del cliente)
        ├── Paso 4: Excluir clientes atendidos O rechazos de HOY POR EL MISMO VENDEDOR
        └── Paso 5: Filtrar y devolver lista definitiva
        
Después del filtrado:
        │
        ▼
Estrategia B: _sortByFreshScore() re-ordena en memoria usando datos globales (ciclo + weekday)
```

### 8.3 Gestión Extendida de la Selección de Cliente

El sistema permite al vendedor seleccionar un cliente específico para ver su historial o información detallada:

1. El índice del cliente seleccionado se almacena en `selectedClienteIndex`
2. Se muestra un `cliente_info_card` con datos relevantes (nombre, última compra global, tipo de negocio)
3. Desde ahí se puede editar el cliente directamente (navegando a la pantalla de edición)

## 9. Lógica de Negocio Extendida — DeliveryService Multi-Tenant

### 9.1 Exclusión por Intervalo Global — Detalle Matemático Extendido

```python
umbral = 0.8                    # Constante mágica: ¿qué tan cerca del umbral estamos?
fallback_dias = 7.0             # Default para clientes sin intervalo calculado (global)

para cada candidato con fecha_ultima_venta_global:
    dias_desde = (hoy - fecha_ultima_venta).days
    
    if cliente.intervalo_promedio global es NULL o <= 0:
        intervalo_efectivo = fallback_dias  # 7 días por defecto global
    else:
        intervalo_efectivo = cliente.intervalo_promedio_global
    
    umbral_exclusion = umbral * intervalo_efectivo  # Ej: 0.8 × 7 = 5.6 días
    
    si dias_desde < umbral_exclusion:
        EXCLUIR este cliente para este vendedor

// Nota: la exclusión es GLOBAL por intervalo, pero PER-VEENDEDOR en el paso de exclusiones del reparto actual.
// Un cliente globalmente excluido está excluido para TODOS los vendedores (nadie debe visitarlo).
```

### 9.2 Cálculo Extendido de Puntuación — Detalle Multi-Tenant

La puntuación combina dimensiones complementarias con datos globales:

```
Puntuacion = 
    peso_consistencia * f(consistencia_factores_global) +
    peso_volumen * f(volumen_factores_global) +
    peso_recencia * f(recencia_factores_global) +
    peso_ciclo * f(ciclo_score_global) +
    boost_weekday
```

Los pesos aproximados:
- Los factores de ciclo y weekday contribuyen ~15% cada uno (como componente multiplicativo del score base)
- El resto se reparte entre consistencia global, volumen global y recencia global

### 9.3 Cálculo Extendido del `intervalo_promedio` — Global Rolling Window

```python
ventas_ordenadas = ventas_del_cliente ordenadas por fecha ASC (de TODOS los vendedores)
diferencias = []
para i en range(1, len(ventas_ordenadas)):
    diff = (ventas[i].fecha - ventas[i-1].fecha).days  # Días entre compras consecutivas de cualquier vendedor
    diferencias.append(diff)

intervalo_promedio_global = media(diferencias)
```

### 9.4 Cálculo Extendido de `frecuencia_reparto` — Global

```python
ventas_con_reparto_global = ventas_del_cliente donde delivery_number existe (de TODOS los vendedores)
repartos_unicos_globales = {v.delivery_number for v in ventas_con_reparto}
frecuencia_reparto_global = len(ventas_con_reparto_global) / len(repartos_unicos_globales)
```

## 10. Sistema Extendido de Logs — Auditoría Multi-Tenant

### 10.1 Extensión del Log por Vendedor y Fecha

| Campo | Semántica Extendida |
|-------|---------------------|
| timestamp | Hora exacta del log |
| vendor_id | ¿Quién generó este log? |
| tipo_operacion | "venta", "reparto_finalizado", "sincronizacion", "login" |
| mensaje | Descripción de la operación |

### 10.2 Logs Consolidados — Vista desde el Admin

El supervisor puede ver:
- Todos los logs consolidados por fecha y vendedor
- Total de repartos realizados por cada vendedor
- Ventas totales por vendedor
- Clientes activos que atendió cada vendedor

## 11. Flujo del Día Extendido — Perspectiva Multi-Vendedor

### 11.1 Día Típico del Vendedor Individual

```
┌──────────────────────────────────────────────────────┐
│                    FLUJO DEL DÍA (Vendedor A)        │
├──────────────────────────────────────────────────────┤
│                                                       │
│  08:00 - Arrancar app, iniciar sesión como "Juan"   │
│         → Generar token JWT con vendor_id=A          │
│         → Sincronizar datos pendientes (si es necesario) │
│                                                       │
│  08:15 - Iniciar reparto #5                          │
│         → Se cargan los clientes filtrados por el    │
│           algoritmo de puntuación GLOBAL + intervalo │
│         → Temporizador comienza automáticamente       │
│                                                       │
│  09:30 - Visitar cliente (desde lista inteligente)   │
│         → Marcar contacto, seleccionar resultado     │
│         → Si hay venta: registrar cantidad/precio    │
│           → Se genera interacción + nota automática  │
│         → El score del cliente se actualiza          │
│                                                       │
│  10:30 - Cliente rechaza                             │
│         → Marcar "Rechazó"                           │
│         → No aparece en listas futuras por hoy       │
│                                                       │
│  ... REPETIR con siguientes clientes ...              │
│                                                       │
│  17:30 - Finalizar reparto                           │
│         → Se guardan totales, duración, ventas       │
│         → Estado reseteado a "no reparto"            │
│                                                       │
│  20:00 - Sincronizar todo al Google Sheet central   │
│         → Sus propios datos agregados al sheet central │
│                                                       │
└──────────────────────────────────────────────────────┘

// Simultáneamente, el vendedor B en su zona sur tiene
// un flujo paralelo idéntico con vendor_id=B
```

### 11.2 Vista del Supervisor desde Google Sheets Centralizado

El supervisor ve:
- Datos consolidados por vendedor (totales, promedios, tendencias)
- Clientes que atienden múltiples vendedores
- Agenda central de repartos

## 12. Consideraciones Técnicas para Reimplementación Extendida Multi-Tenant

### 12.1 Dependencias Clave Extendidas (no específicas de plataforma)

| Funcionalidad | Alternativa genérica |
|--------------|---------------------|
| Base de datos SQLite con ORM multi-tenant | Prisma, TypeORM, SQLAlchemy, Realm, WaterDB |
| Google Sheets API v4 centralizado | googleapis SDK del lenguaje objetivo |
| Autenticación Service Account + JWT per-vendedor | google-auth-library equivalente |
| Geolocalización | platform specific APIs |
| Generación de código desde schema | tooling equivalente (drift codegen) |

### 12.2 Consideraciones Extendidas de Seguridad Multi-Tenant

- **`credentials.json`:** Contiene la clave privada del service account centralizado. Debe estar en `.gitignore`. En producción, rotar claves periódicamente y usar HTTPS para todas las comunicaciones con Google Sheets API.
- **Aislamiento vendor_id:** Cada query debe incluir `WHERE vendedor_id = $vendorIdActual` obligatoriamente — no confiar solo en el frontend.
- **Dato sensibles de clientes:** Los clientes tienen datos personales (teléfono, dirección). Cumplir con regulaciones locales de protección de datos aplicables y considerar cifrado adicional si los datos viajan entre dispositivos.

### 12.3 Consideraciones Extendidas de Escalabilidad Multi-Tenant

- SQLite local puede manejar miles de clientes por vendedor sin problemas
- El algoritmo de puntuación global es O(n log n) por el sort final — escala bien hasta ~10,000 clientes globales
- La sincronización con Google Sheets centralizado puede ser bottleneck si muchos vendedores escriben simultáneamente; considerar paginación o batch operations para rangos grandes
- Considerar colisiones de números de repartos entre vendedores: cada vendedor debe tener su propio autoincremental independiente, no global

### 12.4 Consideraciones Extendidas de Usabilidad en Campo Multi-Tenant

- La app debe funcionar bien **offline** — toda la lógica crítica está localmente
- Sincronización es opcional y asíncrona — no bloquea el trabajo del vendedor individual
- Los datos se cargan una vez al inicio del reparto, minimizando llamadas a BD durante el uso intensivo
- El login debe ser rápido (PIN numérico) para no frustrar al vendedor en campo

## 13. Resumen Extendido de Decisiones de Diseño Multi-Tenant

| Decisión | Razón Multi-Tenant | Alternativa rechazada |
|----------|-------------------|----------------------|
| **Local-first con SQLite per-vendedor** | Funciona offline; cada vendedor tiene su propia copia completa | Base de datos remota directa (requiere conectividad) |
| **Service Account centralizado vs OAuth interactivo per-vendedor** | Configuración única para toda la organización; sin fricción del usuario | OAuth 2.0 per-user (cada vendedor necesitaría configurar su cuenta) |
| **Ciclo temporal integrado en el ranking GLOBAL** | Maximiza ventas al visitar clientes en su momento óptimo de compra (con datos globales) | Lista puramente por recencia o volumen |
| **Exclusión basada en intervalo propio GLOBAL + per-vendedor en reparto** | Evita visitas redundantes; respeta el ritmo natural del cliente desde todas las fuentes | Solo exclusión per-vendedor sin considerar ventas ajenas |
| **Estrategia B (re-orden en memoria)** | O(n) aritmética pura, sin I/O ni latencia; datos globales reordenados localmente | Recalcular todo el score completo global para cada re-renderizado de pantalla |
| **Fire-and-forget para actualización global de scores** | No bloquea la UI ni el guardado de venta; respuesta instantánea al vendedor | Esperar a que termine toda la actualización global antes de mostrar el resultado |

## 14. Métricas y KPIs Calculados Extendidos por el Sistema Multi-Tenant

El sistema calcula automáticamente métricas globales:

| Métrica Global | Fórmula | Propósito |
|----------------|---------|-----------|
| **Eficiencia del reparto (global)** | `tiempo_total / clientes_contactados` (por vendedor) | Cuánto tiempo le toma atender cada cliente por vendedor |
| **Tasa de conversión global** | `ventas_exitosas / interacciones_totales × 100` (global) | Qué porcentaje de contactos resultan en venta a nivel organizacional |
| **Volumen total por ruta (agregado)** | Suma de kg vendidos por todos los vendedores del día | Productividad total de la organización |
| **Frecuencia promedio global de cliente** | Promedio de visitas por cliente entre todos los vendedores | ¿Qué tan frecuente compra cada cliente? |

## 15. Nota Final Extendida — Esencia del Sistema Multi-Tenant

Más allá de ser una app CRUD para registrar ventas, este sistema implementa un **algoritmo predictivo global de visitas** que aprende el comportamiento temporal de cada cliente:

- **Aprende cuándo** comprar (intervalo promedio + ciclo score calculados con TODAS las ventas de cualquier vendedor)
- **Aprende con qué frecuencia** compra en cada día de la semana (frecuencias semanal globales)  
- **Reordena dinámicamente** la lista de visita para visitar a los clientes que más probablemente compren hoy, y no repetir visitas innecesarias

Es un sistema que va mejorando su propia eficiencia con el tiempo: cada venta registrada por cualquier vendedor entrena al algoritmo global. El valor principal para cada vendedor no es "registrar qué pasó", sino **"recibir una lista optimizada de quién visitar y en qué orden"** basada en conocimiento colectivo de toda la organización.

---

*Documento de diseño independiente del stack tecnológico extendido para soportar múltiples vendedores con aislamiento multi-tenant.*
