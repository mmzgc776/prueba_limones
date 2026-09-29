# Arquitectura (estado actual)

> **Tipo:** referencia del estado actual · **Verificado contra el código:** 2026-09-29 (schema v19)
> Describe lo que el código **hace hoy**. Lo que se quiere y no existe va en `VISION.md`; los defectos conocidos, en `PLAN_MEJORAS.md`.

## Producto

App móvil para vendedores ambulantes de limones ("Limones el Patito"). Cada vendedor:

- recorre a sus clientes en **repartos** cronometrados;
- registra ventas, interacciones (Venta / Rechazó / Pendiente / Encargó), notas y gastos;
- recibe una **lista sugerida de clientes** por visitar (`SELECCION_CLIENTES.md`);
- sincroniza a mano con una hoja de Google Sheets compartida.

**Escala objetivo:** de 1 a 3 vendedores. No hay planes de flotilla.

## Stack

- **Plataforma:** Flutter, con Dart `^3.8.1`. Hay targets para Android, iOS, Web, Windows, Linux y macOS; el uso real es Android.
- **Datos:** Drift (SQLite), en un único archivo `app.sqlite` por dispositivo.
- **Sincronización:** Google Sheets API (`googleapis`) con cuenta de servicio.
- **Otras dependencias:** `shared_preferences` (sesión y tema), `geolocator` y `permission_handler` (GPS en visitas y clientes), `url_launcher` (llamada y WhatsApp), `dropdown_search`, y `http` + `html` (scraper de precios SNIIM).
- **Estado de la UI:** `setState`, el singleton `DeliveryStateManager` y un `ValueNotifier<ThemeMode>` global. No se usa Provider, Riverpod ni Bloc.

## Mapa de código

```
lib/
  main.dart                  MaterialApp, rutas, Home (MyHomePage): precio sugerido, notas, accesos
  controllers/
    delivery_controller.dart Cronómetro y ciclo de vida del reparto (uno por página)
  data/
    database.dart            Tablas Drift, migraciones, transacciones (p. ej. insertSaleWithInteraction)
    database.g.dart          Generado por build_runner. NO editar
    delivery_state.dart      Singleton DeliveryStateManager (estado del reparto en memoria)
  services/
    database_service.dart    CRUD + sync push/pull por entidad + snapshot de recomendaciones (~2100 líneas)
    sync_service.dart        Orquestador: SyncType, rangos de hojas, recálculo de métricas
    google_sheets_service.dart  Autenticación y lectura/escritura de rangos
    sheets_row_utils.dart    Utilidades puras de filas y encabezados multi-vendedor
    client_recommendation_service.dart  Heurística pura de la lista (tiene tests)
    delivery_service.dart    Carga de la lista del reparto y operaciones de repartos/interacciones
    user_session_service.dart   Vendedor actual (SharedPreferences)
    sniim_scraper_service.dart  Precios de mercado SNIIM para el precio sugerido
  pages/
    user_selection_page.dart Elegir vendedor (sin PIN); se muestra si no hay sesión
    section_delivery_page.dart  Pantalla del reparto (pestañas activas, historial, ventas sin asignar)
    section_delivery/widgets/   Lista de clientes, hojas de interacción, FABs, progreso, detalle, tabla
    ventas_page.dart, edit_sale_page.dart, nuevo_cliente_page.dart, editar_clientes_page.dart,
    gastos_page.dart, synchronization_page.dart, logs_page.dart, section1_page.dart (placeholder muerto)
  widgets/
    venta_form.dart          VentaForm + EditVentaForm (~1000 líneas)
    notes_container.dart, notes_overview_widget.dart, sync_action_button.dart, sync_dialogs.dart
  theme/app_theme.dart       AppTheme.light / AppTheme.dark (Material 3, semilla deepPurple)
```

### Rutas (`main.dart`)

- `home`: `MyHomePage` si hay sesión; si no, `UserSelectionPage`.
- Rutas con nombre: `/section1`, `/ventas`, `/section_delivery`, `/nuevo_cliente`, `/editar_clientes`, `/synchronization`, `/logs`, `/gastos`.
- `/edit_sale` se resuelve en `onGenerateRoute` (recibe el `saleId` como argumento).

## Modelo de datos (Drift, `schemaVersion = 19`)

| Tabla | PK | Contenido | `sellerId` |
|---|---|---|---|
| `Sales` | `id` | Venta: fecha, cliente, kg, precio, total, nota y `deliveryNumber` (nullable; sin FK) | obligatorio |
| `Deliveries` | `deliveryNumber` (**global**, ver B8) | Reparto: fecha, `durationSeconds`, precio promedio, kg, cajas, `remaining`, total | obligatorio |
| `Clientes` | `id` autoincremental | Datos de contacto, horario, días, GPS y métricas persistidas (`SELECCION_CLIENTES.md`) | default 1 |
| `Interacciones` | `id` | Resultado (`Venta`/`Rechazó`/`Pendiente`/`Encargó`), cliente, `deliveryId` (obligatorio) y timestamp. Antes se llamaba `Contactos` (se renombró en la migración 13→14) | default 1 |
| `Notas` | `id` | Texto y color; `clientId` obligatorio y `ventaId` opcional | default 1 |
| `Usuarios` | `id` | Vendedores: nombre, ciudad y activo | — |
| `Gastos` | `id` | Fecha, concepto, monto y categoría | obligatorio |
| `PersistentDeliveryStates` | `id` = `current_{sellerId}` | Estado del reparto en curso. Se escribe pero **nunca se lee** (B5) | implícito en el id |

- **Migraciones:** bloques `if (from == N)` para N = 11…18 en `database.dart`. Están mal encadenados: saltar versiones pierde migraciones (D1).
- **Tras modificar `database.dart`:** incrementar `schemaVersion`, agregar la migración y correr `dart run build_runner build`.

## Multi-vendedor

- **Decisión vigente (2026-09-29):** los datos están **aislados por vendedor**. Cada vendedor ve, calcula y sincroniza sólo sus filas (`seller_id`). No hay métricas ni exclusiones globales entre vendedores; si alguna vez se necesitan, el caso está en `VISION.md`.
- **Sesión:** `UserSessionService` guarda `current_seller_id` en SharedPreferences. La lista de vendedores sale de la hoja `Usuarios`, y se elige sin PIN.
  - Si no hay sesión, `currentSellerId` devuelve 1 (V7).
- **Un solo archivo SQLite por dispositivo:** pueden convivir varios vendedores en el mismo dispositivo, separados por la columna `seller_id`.
- **Choques conocidos:**
  - `Deliveries.deliveryNumber` es PK global, pero el siguiente número se calcula por vendedor (B8).
  - Los `deleteAll*` no filtran por vendedor (D2, D3, D5).
  - Las hojas de Notas e Interacciones no tienen `seller_id` (N1).

## Sincronización con Google Sheets

- **Hoja:** el spreadsheet `1f72gI91Qvz9a2wcakgLLiCgPTzWHauYen5cD4kJL4ys` está definido en `sync_service.dart:31` y **duplicado** en `user_selection_page.dart:59` (N5).
- **Autenticación:** cuenta de servicio en `lib/services/credentials.json`.
  - Está en `.gitignore` y nunca se ha commiteado, pero se empaqueta como asset en el binario.
  - La hoja debe compartirse con el email de la cuenta de servicio.
- **Disparo:** manual, desde `SynchronizationPage`. `SyncType` tiene 9 valores: `deliveries`, `sales`, `clients`, `notas`, `interacciones`, `expenses`, `usuarios`, `database` y `rateClients`.

| Hoja | Rango | Columna `seller_id` |
|---|---|---|
| Repartos | `Repartos!A:I` | H (índice 7) |
| Ventas | `Ventas!A:I` | I (8) |
| Clientes | `Clientes!A:AD` | AD (29) |
| Gastos | `Gastos!A:F` | B (1) |
| Notas | `Notas!A:E` | **no tiene** (N1) |
| Interacciones | `Interacciones!A:E` | **no tiene** (N1) |
| Usuarios | `Usuarios!A:D` | — |

**Algoritmo por entidad** (`database_service.dart`, `sync*Unified` → `_sync*Data`):

- **PULL:** si la tabla local está vacía y la hoja tiene datos, importa las filas del vendedor actual. Las filas sin `seller_id` se asumen del vendedor original (`kLegacySellerId`).
- **PUSH:** si la tabla local tiene datos, reescribe la hoja.
  - En Repartos, Ventas, Clientes y Gastos, `_pushSellerRows` conserva las filas de otros vendedores, escribe las propias y limpia las filas sobrantes.
  - En Notas e Interacciones sobrescribe todo.
- **No es un merge.** No hay rastreo de cambios, marcas de tiempo ni resolución de conflictos: gana el último que escribe.
- Si falla la lectura de la hoja, se trata como hoja vacía (D6).

**Recálculo de métricas:** `rateClients` recalcula las métricas de todo el catálogo del vendedor, y `refreshSingleClientScore` se dispara después de cada venta. Ambos detalles están en `SELECCION_CLIENTES.md`.

## Reparto activo

El estado del reparto vive en **tres lugares** que se desincronizan. Es la causa de B1-B11 (`PLAN_MEJORAS.md` §1):

1. `DeliveryController`: uno por página. El cronómetro es un `Timer.periodic` que suma `_elapsedSeconds++`.
2. `DeliveryStateManager`: un singleton en memoria con el número de reparto, las cajas, los clientes contactados y el precio sugerido.
3. `PersistentDeliveryStates`: se escribe y nunca se lee.

- **Ciclo:** iniciar (número = conteo de repartos del vendedor + 1, con diálogo de cajas) → pausar/reanudar → terminar. Al terminar se guarda `Deliveries` con `date = now` y `remaining = 0`.
- **Reanudar:** se puede reanudar un reparto pasado desde su detalle.
- **Salir de la pantalla pausa el reparto.**
- **Venta durante el reparto:**
  - **Desde el FAB `$`:** se abre `VentasPage(deliveryNumber)`. Al guardar se llama a `insertSaleWithInteraction`, que inserta la venta y la interacción `Venta` en una sola transacción.
  - **Desde la lista:** se toca un cliente, luego Llamada/Visita/Mensaje, luego el resultado. Si el resultado es "Venta", la interacción se inserta antes de abrir el formulario (N2 y N3).
- **Clientes ya atendidos:** cualquier interacción o venta los saca de la lista en la siguiente recarga.

## Otros módulos

- **Home:**
  - Precio sugerido: combina precios SNIIM y valores propios (`main.dart:182-232`), sólo en memoria.
  - Resumen de notas y accesos a las secciones.
  - Interruptor de tema claro/oscuro, persistido en `isDarkMode`.
- **Gastos:** alta, edición y borrado (por pulsación larga) por vendedor. Se sincroniza con la hoja `Gastos`.
- **Logs:** `LogManager` guarda en memoria las últimas 100 entradas (hora y mensaje). Se alimenta con `appLog()` y se consulta en `/logs`.

## Pruebas

| Archivo | Cubre |
|---|---|
| `client_recommendation_test.dart` | Heurística con reloj fijo |
| `client_recommendation_integration_test.dart` | Selección real con Drift en memoria (304 clientes) |
| `client_recommendation_widget_test.dart` | Etiquetas de motivo en la lista |
| `sale_interaction_test.dart` | `insertSaleWithInteraction`: atomicidad, vendedor, sin duplicados, rollback |
| `sheets_row_utils_test.dart` | Filas y encabezados multi-vendedor |
| `widget_test.dart` | **Falla**: es la plantilla del contador y la app no tiene contador |

Al 2026-09-29, los 24 tests de los cinco primeros archivos pasan y `widget_test.dart` falla. El controller del reparto, que concentra los bugs, no tiene pruebas.
