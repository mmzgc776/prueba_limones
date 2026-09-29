> **ARCHIVADO (2026-09-29) — no usar como referencia.** Spec UX original, escrita sobre premisas descartadas (datos globales entre vendedores, login con PIN/JWT, lista de 15 clientes sin scroll). Sus requisitos vigentes se convirtieron en checklist con estado en `REQUISITOS_UX.md`.
> Documentación vigente: [`docs/README.md`](../README.md).

# Especificación Extendida de Experiencia de Usuario — Vendedores Itinerantes Multi-Tenant

Esta especificación describe **cómo interactúan múltiples vendedores con el sistema** durante sus jornadas diarias, los patrones de interfaz que usan, las transiciones de pantalla y la semántica de cada interacción táctil en un contexto multi-tenant. Está diseñada para ser implementable en cualquier framework móvil (React Native, Flutter, Swift, Kotlin, etc.).

---

## 1. Perfiles de Usuarios Extendidos — Organización Multi-Vendedor

### 1.1 ¿Quiénes usan el sistema?

| Rol | Descripción |
|-----|-------------|
| **Vendedor** | Recorre la ciudad visitando clientes y registrando ventas/interacciones en su dispositivo personal. Tiene una cuenta con PIN/contraseña. |
| **Administrador / Supervisor** | Gestiona vendedores, configura el sistema, ve datos consolidados en Google Sheets centralizado. Acceso limitado (no usa la app móvil). |

### 1.2 Requisitos no funcionales derivados del perfil multi-vendedor

| Requisito | Justificación Multi-Vendedor |
|-----------|----------------------------|
| **Offline-first per dispositivo** | Cada vendedor puede estar en zonas sin cobertura; su dispositivo funciona completamente offline con sus datos locales |
| **Respuesta instantánea** | Cada segundo cuenta; el sistema no puede bloquear la UI esperando a la BD local |
| **Interfaz grande y legible** | Se usa con una sola mano, posiblemente bajo el sol o con guantes |
| **Mínimo scroll** | La lista de clientes debe mostrar toda la información relevante sin hacer scroll |
| **Feedback inmediato** | Cada acción produce un resultado visible instantáneo (check verde, error rojo, etc.) |

---

## 2. Flujo del Día Extendido — Vista Completa Multi-Vendedor con Pantallas y Acciones

### 2.1 Secuencia Crítica de Interacción Extendida

```
[08:00] APP ARRANCA (DISPOSITIVO INDIVIDUAL)
         │
         ▼
┌───────────────────────────┐
│      PANTALLA DE INICIO   │  ← Section1Page (multi-tenant)
│                           │
│  "Siguiente reparto: #5"  │
│  [RESTART REPARTO #5]     │
│                           │
│  Precio sugerido: $X/kg   │
│  [CONFIGURAR PRECIO]      │
└───────────────────────────┘
         │
         ▼  TAP: "RESTART REPARTO #5"
[08:15] LISTA DE CLIENTES MULTI-TENANT
         │
         ▼  Se carga la lista inteligente (algoritmo de puntuación GLOBAL)
         → Los datos son globales pero solo se muestran para el vendor_id actual
         
┌───────────────────────────┐
│   REPARTO #5 — CLIENTES   │
│                           │
│  [CLIENTE A — $XX/kg]     │  ← Cliente con mayor score fresco GLOBAL
│  [CLIENTE B — $XX/kg]     │
│  ...                      │
│                           │
│  📊 PROGRESO              │
│  ┌─────────────────────┐ │
│  | 3/15 clientes       │ │
│  | Kg: 24.5            │ │
│  | $487                │ │
│  └─────────────────────┘ │
└───────────────────────────┘
         │
         ▼  TAP en cliente → detalle (datos globales pero filtrados por vendor_id)
[09:30] DETALLE CLIENTE MULTI-TENANT + VENTA
         │
         ▼  Registrar venta (vendor_id actual se asigna automáticamente)
┌───────────────────────────┐
│   REGISTRO DE VENTA        │
│                           │
│  Cliente: Juan Pérez       │
│                           │
│  Cantidad: [5] kg          │
│  Precio: [$20]             │
│  Total: [$100]             │
│                           │
│  Nota: (opcional)          │
│                           │
│         [GUARDAR VENTA]    │
└───────────────────────────┘
         │
         ▼  GUARDADA → vendor_id actual se registra en la venta + interacción
         → Regresa a lista (con feedback visual instantáneo)

... REPETIR para siguientes clientes ...

[17:30] FINALIZAR REPARTO MULTI-TENANT
         │
         ▼
┌───────────────────────────┐
│   RESUMEN DEL REPARTO      │
│                           │
│  Reparto #5 (Juan Pérez)   │
│  Duración: 2h 15min        │
│  Clientes contactados: 15  │
│  Kg vendidos: 48.3         │
│  Ventas totales: $967      │
│                           │
│  [CONFIRMAR FINALIZAR]     │
└───────────────────────────┘
         │
         ▼  CONFIRMADA → Reset completo, estado listo para siguiente reparto

[20:00] SINCRONIZACIÓN MULTI-TENANT CENTRALIZADA
         │
         ▼  Seleccionar tipo de datos (sus propios datos)
         │   [REPARTOS]  [VENTAS]    [CLIENTES]
         │
         ▼  Presionar botón sincronizar
┌───────────────────────────┐
│     PROGRESO SYNC          │
│                           │
│  Repartos: 15/15 ✓       │
│  Ventas: 87/87 ✓          │
│  Clientes: 42/42 ✓        │
│                           │
│  [VER SHEETS]             │
└───────────────────────────┘

```

---

## 3. Pantallas Individuales Extendidas — Multi-Tenant Contexto

### 3.1 Pantalla de Inicio (`Section1Page`) — Multi-Vendedor

**Propósito:** Configuración inicial y acceso rápido al inicio de un reparto, con contexto del vendedor autenticado.

#### Elementos visuales multi-tenant
| Zona | Contenido | Acción |
|------|-----------|--------|
| Header central | Texto con "Siguiente reparto: #N" + nombre del vendedor actual | Info contextual |
| Botón primario grande | "Reiniciar Reparto #N" (o "Nuevo Reparto") | Inicia el algoritmo de generación de lista |
| Campo editable secundario | "Precio sugerido: $XX/kg" (personalizable por vendedor) | Permite cambiar precio base del día |

#### Comportamiento multi-tenant extendido
- El número del próximo reparto se calcula automáticamente como `max(repartos existentes del mismo vendor_id) + 1`
- Si no hay repartos previos, comienza desde #1
- La pantalla de inicio **no requiere internet** para funcionar — todo el peso del algoritmo está localmente
- Cada vendedor personaliza su precio sugerido independientemente

### 3.2 Pantalla de Reparto Activo (`SectionDeliveryPage`) — Multi-Tenant Extendida

**Propósito:** Vista principal durante la jornada de reparto de un vendedor individual, con datos globales pero exclusión per-vendedor.

#### Estructura visual extendida multi-tenant
```
┌─────────────────────────────────────┐
│ [Pestaña: Clientes] [Pastaña: Progreso] │
├─────────────────────────────────────┤
│                                     │
│  ┌───────────────────────────────┐  │
│  │ Cliente seleccionado (card)   │  │
│  │ Nombre, tipo de negocio,      │  │
│  │ última compra GLOBAL          │  │
│  │ interacciones globales        │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ Lista de clientes:             │  │
│  │ [A] Cliente A                  │  │ 🔵 contacto pendiente (per vendor)
│  │ [✓] Cliente B                  │  │ 🟢 contactado por este vendedor hoy
│  │ [?] Cliente C                  │  │ 🔵 contacto pendiente
│  │ ...                            │  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│ [FAB: + VENTA] [FAB: NOTA]         │
└─────────────────────────────────────┘

Pestaña "Progreso" MULTI-TENANT:
┌─────────────────────────────────────┐
│ 📊 REPARTO #5 — JUAN PEREZ          │
│                                     │
│ Clientes visitados por mí: 3/15     │
│ Tiempo transcurrido: 1h 23min       │
│ Kg totales (mi reparto): 24.5       │
│ Ventas monetarias (mías): $487      │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ Historial de repartos mios  │    │
│ │ #1 | #2 | #3 ... #N         │    │
│ └─────────────────────────────┘    │
└─────────────────────────────────────┘

Nota: Los datos globales (puntuación, intervalo) se muestran, pero el progreso
y los totales son solo del reparto del vendedor actual.
```

#### Flujo extendido multi-tenant de interacción con un cliente

**TAP en un cliente → Abre detalle:**

1. Se muestra una card superior con información del cliente (nombre, tipo negocio, última compra GLOBAL)
2. Si el usuario TAP en la card → navegación a `NuevoClientePage` para editar
3. Si el usuario TAP botón "+" → abre formulario de venta (`venta_form.dart`)
4. **El vendor_id se asigna automáticamente al registro**

**Registro extendido multi-tenant:**
```python
# Cuando el vendedor guarda una venta:
await insertSale(
    vendorId: currentVendor.id,  // Asignación automática del vendedor actual
    date: now,
    clientId: selectedClient.id,
    quantity: inputQuantity,
    price: inputPrice,
    total: calculatedTotal,
)

# La interacción se registra con el vendor_id del vendedor actual:
await insertInteraccion(
    vendorId: currentVendor.id,  // ¿Quién la registró? El vendedor que está usando la app
    clientId: selectedClient.id,
    result: "Venta",
    deliveryId: currentDeliveryNumber,
)

# El score del cliente se recalcula con TODAS las ventas globales (no solo del vendor actual):
await refreshSingleClientScore(selectedClient.id)  // Globalmente
```

**El estado del cliente en la lista cambia instantáneamente:**
- Pendiente → azul (interés)
- Contactado → verde (éxito — contactado por ESTE vendedor hoy)
- Rechazó → rojo (excluido para este vendedor hoy)

#### Temporizador extendido multi-tenant

- Comienza automáticamente al iniciar el reparto del vendor actual
- Se muestra discretamente (no intrusivo) en la esquina superior
- Tiene botones de pausa/reanudar si el vendedor necesita un descanso breve
- El temporizador se guarda con vendor_id y puede reanudarse después de cerrar la app

### 3.3 Formulario Extendido de Venta Multi-Tenant (`venta_form.dart`)

**Propósito:** Registrar una venta individual con mínimo de campos, vinculada al vendedor actual automáticamente.

#### Campos extendidos del formulario multi-tenant
| Campo | Tipo | Obligatorio | Comportamiento Multi-Tenant |
|-------|------|-------------|---------------------------|
| Cliente | Selección previa | Sí | Pre-seleccionado desde la lista (filtrada globalmente) |
| Cantidad (kg) | Number input | Sí | Mínimo 0.1, máximo configurable |
| Precio por kg | Number input | No | Default = precio sugerido del día personalizable por vendedor |
| Total | Calculado automáticamente | No | `cantidad × precio` |
| Fecha | Auto-llenada | No | Siempre la fecha/hora actual |
| Nota | Texto opcional | No | Para observaciones adicionales |
| **Vendor ID** | Automático | Sí (implícito) | Se asigna al vendedor logueado automáticamente — no visible ni editable |

#### Comportamiento extendido de validación multi-tenant
- La venta no puede tener cantidad ≤ 0 (previene registro accidental)
- El total se recalcula en tiempo real al mover los inputs
- Si el precio está vacío, usa el precio sugerido del día como default
- El formulario **no requiere internet** para guardarse localmente
- Al guardar: vendor_id actual se registra automáticamente + interacción + score global

### 3.4 Pantalla Extendida de Edición Multi-Tenant (`editar_clientes_page.dart`)

**Propósito:** CRUD completo de clientes — crear nuevos o editar existentes, con contexto multi-vendedor.

#### Doble modo extendido: Crear / Editar
| Condición | Comportamiento |
|-----------|---------------|
| `nombreCliente` vacío + `cliente` nula | Modo CREACIÓN (nuevo cliente global) |
| `nombreCliente` con valor O `cliente` no nula | Modo EDICIÓN (pre-llena el form del cliente existente) |

#### Flujo extendido multi-tenant de creación
1. Formulario con todos los campos del cliente
2. Botón "Guardar Cliente" → persiste en SQLite con vendor_id actual como asignador
3. Si hay ubicación disponible, pide permiso para geolocalizar y guardar coordenadas GPS
4. Al guardar: genera nota automática (nota_id vinculada) + score global calculado

#### Flujo extendido multi-tenant de edición
1. Pre-llena todos los campos desde datos del cliente existente (globales)
2. Botón "Guardar Cambios" → actualiza registro en SQLite con vendor_id del editor
3. Muestra historial de ventas anteriores del cliente **de TODOS los vendedores** para referencia

### 3.5 Pantalla Extendida de Sincronización Multi-Tenant (`synchronization_page.dart`)

**Propósito:** Interfaz para enviar datos a Google Sheets centralizado (solo propios datos).

#### Elementos visuales extendidos multi-tenant
| Zona | Contenido | Acción |
|------|-----------|--------|
| Selector de tipo | Chips/botones: [Repartos] [Ventas] [Clientes] | Seleccionar qué sincronizar (propios datos) |
| Botón primario | "Sincronizar" | Ejecuta la operación per-vendedor |
| Feedback durante sync | Barra de progreso + conteo | Muestra avance: "X/Y registros sincronizados (vendedor: Juan)" |
| Resultado | Mensaje de éxito/error | Confirma completitud con vendor_id |

#### Comportamiento extendido multi-tenant
- El usuario selecciona primero qué tipo de dato sincronizar (no es automático)
- Se muestra un contador: "X/Y registros procesados del vendedor actual" durante la sincronización
- En caso de error: muestra el mensaje completo del error para depuración
- **Solo se sincronizan los datos del vendor_id actual** — no hay acceso a datos ajenos desde la UI
- Permite verificar el resultado en Google Sheets ("Ver Sheet")

### 3.6 Pantalla Extendida de Logs Multi-Tenant (`logs_page.dart`)

**Propósito:** Auditoría y depuración multi-tenant — ver qué operaciones ha realizado cada vendedor.

#### Contenido extendido multi-tenant
- Lista de eventos loggeados con vendor_id, timestamp y tipo
- Filtros por: fecha, tipo de operación, vendedor actual
- Categorías multi-tenant: login, venta, reparto, sincronización, error
- Formato extendido: `[HH:mm] [Juan Pérez] Tipo: Mensaje`

---

## 4. Patrones Extendidos de Interfaz Reutilizables (Widgets) Multi-Tenant

### 4.1 Cliente Info Card Extendida Multi-Tenant

Componente que muestra resumen de un cliente en el detalle superior, con contexto global.

**Contenido visual extendido:**
```
┌──────────────────────────┐
│  📍 Juan Pérez           │  ← Icono de ubicación + nombre
│  Restaurante "El Buen    │  ← Tipo de negocio (icono)
│  Comida                   │
│                           │
│  Última compra: 15.03     │  ← Fecha y cantidad GLOBAL (cualquier vendedor)
│  Interacciones totales:   │  ← Eventos globales de TODOS los vendedores
│    24 ventas, 3 rechazos  │
│                           │
│  Vendedor asignado: María │  ← El vendedor que "cuida" del cliente
└──────────────────────────┘
```

### 4.2 Bottom Sheet Extendida Multi-Tenant de Opciones de Interacción

Se abre desde el detalle del cliente multi-tenant. Contiene:
- Lista vertical de opciones con iconos y colores semánticos
- "Venta" → verde (primaria) — registra venta + vendor_id actual
- "Rechazó" → rojo (destructiva) — excluye solo para este vendedor hoy
- "Pendiente" → azul (información)
- "Encargó" → naranja

### 4.3 Formulario Extendido de Venta Reutilizable Multi-Tenant

Componente modular que se puede usar en:
1. El registro desde la lista de clientes (durante el reparto, vendor_id auto-asignado)
2. La pantalla dedicada de ventas (`ventas_page.dart`, vendor_id auto-asignado)

**Características extendidas:**
- Campos numéricos con teclado numérica nativa
- Cálculo automático del total
- Persistencia local inmediata sin requerir internet (con vendor_id)
- **Vendedor actual siempre se registra en la venta** — no editable manualmente

---

## 5. Semántica Visual Extendida por Estado Multi-Tenant

### 5.1 Sistema de colores extendido por estado multi-tenant

| Estado | Color | Uso Multi-Tenant |
|--------|-------|------------------|
| Éxito / Venta propia | Verde (#4CAF50) | Checkmarks, confirmaciones, cliente contactado exitosamente por ESTE vendedor |
| Éxito global (otros vendedores) | Azul claro (#64B5F6) | Cliente que compró hace poco por OTRO vendedor (info global) |
| Error / Rechazó propio | Rojo (#F44336) | Botones destructivos, exclusión temporal para este vendedor, errores de sync |
| Pendiente / Inactivo | Azul oscuro (#2196F3) | Clientes no visitados aún por ESTE vendedor |
| Primario (acción principal) | Morado (#9C27B0) | Botón de inicio de reparto, botón de venta |
| Secundario (info global) | Gris claro (#BDBDBD) | Datos globales de otros vendedores (no accionables) |

### 5.2 Feedback instantáneo extendido multi-tenant por acción

| Acción | Feedback esperado Multi-Tenant |
|--------|-------------------------------|
| Registrar venta (propio) | Check verde + vendor_id guardado + retorno inmediato a la lista |
| Rechazar cliente propio | X roja + cambio de estado en la lista (solo excluye para este vendedor hoy) |
| Sincronizar éxito | Check + conteo de registros procesados + "Datos de Juan Pérez sincronizados" |
| Error de sync | Mensaje descriptivo del error + opción de reintentar |
| Finalizar reparto propio | Resumen con totales (solo propios) antes de confirmar |

### 5.3 Indicadores visuales extendidos en la lista multi-tenant

Cada cliente en la lista muestra un **estado visual** que cambia según su interacción por el vendedor actual:

```
Cliente sin contacto hoy por mí:    [•] Cliente A          🔵 (pendiente — nadie lo visitó hoy)
Cliente contactado hoy por mí:      [✓] Cliente B          🟢 (éxito — yo lo atendí)
Cliente rechazó hoy por mí:         [✗] Cliente C          🔴 (rechazado — excluido para mí hoy)
Cliente compró ayer por otro vended.: [i] Cliente D       💠 (info global — otros vendedores vendieron)
```

---

## 6. Navegación Extendida Multi-Tenant y Transiciones

### 6.1 Mapa de navegación extendido multi-tenant completo

```
┌───────────────┐
│   Section1    │ ← Pantalla principal / home (contexto del vendedor)
│   (Inicio)    │
└──┬─────┬──────┘
   │     │
   ▼     ▼              ┌──────────────────┐
   /ventas             │  VentasPage      │
                        │ Formulario venta │
                        └──────────────────┘

┌───────────────┐
│   Reparto     │ ← Pantalla principal de reparto del vendedor actual
│   (Delivery)  │
└──┬─────┬──────┘
   ▼     ▼              ┌──────────────────┐
[Lista] [Detalle]       │ NuevoCliente    │
                        │ (Crear/Editar) │
                        └──────────────────┘

   ┌──────────────────┐
   │  Sincronización  │
   └──────────────────┘

   ┌──────────────────┐
   │     Logs          │
   └──────────────────┘
```

### 6.2 Transiciones extendidas multi-tenant específicas

| De → A | Tipo de transición | Notas Multi-Tenant |
|--------|-------------------|--------------------|
| Inicio → Reparto | Navegación directa | Se carga la lista automáticamente con vendor_id actual |
| Lista → Detalle cliente | Push navigation | Se mantiene stack para poder regresar |
| Detalle → Venta form | Modal / Bottom sheet | No requiere regresar al detalle; vendor_id auto-asignado |
| VentasPage → Form venta | Push navigation | Para ver historial de ventas globales del cliente |
| Login → Pantalla principal | Navegación directa | Genera token JWT con vendor_id y lo almacena en SQLite |

---

## 7. Patrones Extendidos Multi-Tenant — Cómo se usa el sistema realmente por vendedores

### 7.1 Flujo extendido típico durante un contacto con cliente (2-5 minutos) multi-tenant

```
Tiempo: 0s        TAP en cliente → abre detalle (0.5s)
                  Se muestra card con info del cliente GLOBALMENTE
                  Se ven sus datos históricos de todos los vendedores
                  Los datos globales se muestran pero no son accionables por otros vendedores

Tiempo: 3s        Botón interactuación → bottom sheet multi-tenant de opciones

Tiempo: 6s        Selecciona "Venta" → se abre form de venta
                  El vendor_id actual se asigna automáticamente (no visible)

Tiempo: 8-20s     Llena cantidad y precio (inputs numéricos rápidos)
                  Total calculado automáticamente
                  Posiblemente escribe nota rápida

Tiempo: 20-30s    TAP "Guardar Venta" → feedback instantáneo
                  vendor_id actual se registra en la venta + interacción
                  El score del cliente se recalcula GLOBALMENTE (fire-and-forget)
                  Regresa a lista con estado verde en el cliente

Tiempo total: ~30 segundos por cliente con venta exitosa
```

### 7.2 Flujo extendido cuando un cliente rechaza (1 minuto) multi-tenant

```
Tiempo: 0s        TAP en cliente → abre detalle
                  Datos globales visibles pero solo accionables para mi vendor_id
Tiempo: 5s        Botón interactuación → bottom sheet
                  Selecciona "Rechazó" → feedback rojo instantáneo
                  El cliente cambia de azul a rojo EN MI LISTA (solo excluyo para mí hoy)
                  Otros vendedores aún pueden visitar a este cliente en otro día

Tiempo total: ~10 segundos
```

### 7.3 Flujo extendido al finalizar el reparto multi-tenant

```
TAP botón finalizar → Resumen del día con totales PROPIOS (vendor_id actual)
                    → Confirmar → Estado reseteado
                    → Listo para siguiente reparto del mismo vendedor

// Nota: Al finalizar, se calculan los datos globales del cliente afectado
// (score global con todas las ventas de todos los vendedores).
```

---

## 8. Patrones Extendidos Multi-Tenant de Error y Recuperación

### 8.1 Sincronización fallida multi-tenant extendida

**Escenario:** El vendedor presiona "Sincronizar" pero no hay internet.

**Comportamiento esperado extended multi-tenant:**
1. Mostrar mensaje de error claro: "No se pudo conectar con Google Sheets centralizado (vendor: Juan Pérez)"
2. Ofrecer botón "Reintentar"
3. No perder datos locales — la app sigue funcionando offline con sus propios datos
4. Los datos del vendor_id actual se guardan en SQLite y se pueden sincronizar cuando haya conectividad
5. **No se envían datos de otros vendedores** — solo los del vendor_id autenticado

### 8.2 Reparto sin clientes disponibles globalmente extendido

**Escenario multi-tenant:** Todos los candidatos están excluidos globalmente por intervalo o ya atendidos hoy.

**Comportamiento esperado extended:**
1. Mostrar mensaje: "No hay más clientes para visitar hoy (ciclo global completo)"
2. Mencionar cuántos días faltan hasta que vuelvan a estar disponibles GLOBALMENTE
3. Ofrecer opción de forzar la visita de algún cliente (solo si el vendedor lo necesita)
4. **Importante:** El usuario debe saber que las exclusiones son globales, no solo per-vendedor

### 8.3 Venta con datos incompletos extendida multi-tenant

**Escenario:** El vendedor intenta guardar una venta sin cantidad válida.

**Comportamiento esperado extended:**
1. Mostrar error: "Cantidad mínima es 0.1 kg"
2. No permitir guardar la venta hasta que se complete el campo obligatorio
3. Mostrar feedback visual en el input con borde rojo
4. El vendor_id no se registra hasta que la validación pase

### 8.4 Cambio extendido de precio durante el reparto multi-tenant

**Escenario:** El vendedor cambia el precio sugerido a mitad del día.

**Comportamiento esperado extended:**
1. Actualizar el precio para **futuras** ventas registradas por este vendedor
2. No retroactivamente — las ventas ya guardadas mantienen su precio original y vendor_id original
3. Notificar visualmente: "Precio actualizado a $XX/kg (solo ventas futuras)"

### 8.5 Caso extendido multi-tenant: Vendedor cambia de ciudad (reubicación)

Si un vendedor se traslada a otra ciudad y necesita una base de datos nueva:

**Opción A — Reasignación simple:**
- El admin actualiza `ciudad_asignada` en la tabla `vendedores` con vendor_id
- El vendedor sigue usando el mismo dispositivo, pero ahora aparece en otra ciudad
- Los clientes existentes se reubican automáticamente (si se cambia su ciudad)

**Opción B — Base de datos limpia (para nuevo vendedor):**
- Crear nuevo registro en `vendedores` con ciudad diferente y vendor_id nuevo
- El admin puede hacer un "clon" del dispositivo (copiar la DB completa)
- O el vendedor empieza con base de datos vacía y agrega clientes manualmente

---

## 9. Patrones Extendidos Multi-Tenant de Diseño para Implementación Móvil

### 9.1 Patrones táctiles frecuentes extendidos multi-tenant en este sistema

| Acción | Patrón UX esperado Multi-Tenant |
|--------|--------------------------------|
| Seleccionar cliente → detalle | Tap en lista item → push nav (datos globales, acción local) |
| Registrar venta rápida | Bottom sheet con formulario pre-llenado + vendor_id auto-asignado |
| Cancelar acción destructiva | Confirmación antes de eliminar/borrar (con vendor_id check) |
| Sincronización larga | Barra de progreso + conteo + botón cancelar opcional |
| Navegación entre pantallas | Mantener stack para poder regresar (back button), vendor_id persiste en sesión |

### 9.2 Consideraciones extendidas multi-tenant de accesibilidad

- Todos los botones deben ser táctiles con área mínima de 48dp (Android) / 44pt (iOS)
- Contraste suficiente en colores sobre fondos
- Textos legibles a distancia (pantallas grandes, bajo sol)
- Feedback háptico opcional al guardar ventas

### 9.3 Consideraciones extendidas multi-tenant para uso con una mano

- Los botones principales deben estar accesibles desde el pulgar
- La lista de clientes debe tener items fácilmente tappable sin precisar pinching
- El formulario de venta no requiere scroll (diseño vertical compacto)
- **vendor_id se maneja automáticamente** — el vendedor nunca necesita saber su ID

---

## 10. Resumen Extendido Multi-Tenant — Decisiones Clave UX

| Decisión | Razón Multi-Vendedor | Alternativa rechazada multi-tenant |
|----------|---------------------|------------------------------------|
| **Lista inteligente global, no completa** | Reduce la carga cognitiva del vendedor; solo muestra lo relevante globalmente pero accionable localmente | Mostrar todos los clientes sin filtrar (sobrecarga de decisión) |
| **Registro rápido en campo** (~30s por cliente) multi-tenant | Maximizar tiempo de venta activo vs. tiempo administrativo; vendor_id auto-asignado | Formulario largo con muchas opciones y configuración manual del vendor |
| **Feedback instantáneo, no asincrónico multi-tenant** | El vendedor necesita saber que su acción se registró al instante (con su vendor_id) | Guardar "en background" sin confirmación visible y sin indicar qué vendor_id se usó |
| **Separación visual extendida entre estados propios y globales** | Escaneabilidad rápida en la lista; el vendedor sabe de un vistazo qué pasó con cada cliente y qué datos son sus vs. globales | Lista plana sin indicadores visuales |
| **Sincronización explícita multi-tenant, no automática global** | Permite al usuario elegir cuándo y qué sincronizar (sus propios datos); evita syncs innecesarios que podrían fallar offline | Sync automático en background de TODOS los vendedores (riesgo de fallos silenciosos y conflictos) |

---

## 11. Resumen Extendido — Decisiones de UX Clave Multi-Tenant

| Decisión | Razón Multi-Vendedor | Alternativa rechazada multi-tenant |
|----------|---------------------|------------------------------------|
| **Aislamiento visual vendor_id** en cada pantalla | Evita confusiones entre datos propios y globales; el vendedor siempre sabe qué es suyo | Mostrar todos los datos sin distinguir (riesgo de errores por mezcla) |
| **Vendor_id auto-asignado, nunca editable manualmente** | Prevención de errores: un vendedor no puede "falsificar" vendor_id para acceder a datos ajenos | Permitir que el usuario cambie manualmente su vendor_id en cada acción |
| **Logs consolidados pero separados per-vendedor** | Auditoría multi-tenant: el supervisor ve todo, el vendedor solo ve sus operaciones | Logs globales mezclados (confusión entre vendedores) o logs aislados sin consolidación (supervisor no puede ver panorama global) |

---

*Documento de experiencia de usuario extendida para soportar múltiples vendedores con aislamiento multi-tenant. Complementa la especificación técnica y de implementación referencial.*
