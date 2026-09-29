# Plan de mejoras: bugs, usabilidad y refactorización

> **Origen:** revisión del 2026-09-28 (antes `REVISION_USABILIDAD_Y_BUGS_2026-09.md`), sobre `lib/` completo (≈13.4k líneas sin generados).
> **Última verificación contra el código:** 2026-09-29. Las referencias `archivo:línea` corresponden a esa fecha; pueden desfasarse unas líneas.
> **Mantenimiento:** al corregir un item, cambia su estado aquí en el mismo commit que el código (ver `docs/README.md`).

**Estados:** ⬜ pendiente · 🟡 parcial · ✅ resuelto · 🚫 descartado

## Tablero

| Área | Pendiente | Parcial | Resuelto |
|---|---|---|---|
| §1 Reparto activo (B1-B12) | 12 | 0 | 0 |
| §2 Datos, validación y estabilidad (D, V, E, N1-N7) | 27 | 1 (V6) | 0 |
| §4 Refactor (fases 0-5) | 5 | 0 | 1 (fase 5: docs) |
| §5 Mejoras de experiencia (#1-#13) | 13 | 0 | 0 |

Resuelto antes de esta revisión y por eso fuera de las tablas: la interacción al vender desde el FAB `$` (ticket archivado en `archive/tickets/`) y la heurística de selección (`SELECCION_CLIENTES.md`).

---

## 0. Resumen ejecutivo

- **El núcleo de la app, el reparto activo, tiene bugs de estado y de tiempo.** El cronómetro puede ir a 2x o 3x, retroceder, contar doble el tiempo en segundo plano, perderse si Android mata la app o pausarse sin que el usuario lo pida. El bug que viste en "estados y tiempo activo" es real, y no es uno solo: son al menos siete (ver §1).
- **Hay botones que destruyen datos a uno o dos toques**, sin confirmación y sin filtrar por vendedor: *Limpiar ventas*, *Eliminar repartos*, y *Cancelar* en el diálogo de sincronización, que lleva a un diálogo de *borrar datos locales*.
- **La multi-sesión (multi-vendedor) está a medias.** El número de reparto es clave primaria global, pero se calcula por vendedor. El segundo vendedor choca con los números del primero. Además las hojas de Notas e Interacciones no distinguen vendedor (N1).
- **Las migraciones de Drift están mal encadenadas** (`if (from == N)`): quien actualice saltándose versiones pierde migraciones.
- **Usabilidad con una mano**: las acciones importantes están arriba (AppBar) o al final de un scroll. Los botones de pausa y fin miden 120 px en el centro, justo donde el pulgar toca por accidente. Los flujos frecuentes (registrar interacción y venta) cuestan de 4 a 7 toques.
- **Hay partes bien hechas**: `ClientRecommendationService` es puro, testeable y tiene tests. Es el modelo a seguir para el resto.

---

## 1. Bugs del reparto activo (estado y tiempo). Prioridad máxima

Hoy el estado vive en **tres lugares** que se desincronizan:

1. `DeliveryController` (uno por cada página abierta).
2. El singleton `DeliveryStateManager` (en memoria).
3. La tabla `PersistentDeliveryStates`, que se escribe pero **nunca se lee**.

El reloj es un contador `_elapsedSeconds++` en un `Timer.periodic`. Casi todos los bugs vienen de esas dos decisiones.

| # | Bug | Dónde | Escenario que lo reproduce | Severidad | Estado |
|---|---|---|---|---|---|
| B1 | **Timers duplicados: el cronómetro acelera** | `delivery_controller.dart:113` (`_startTimer` no cancela el anterior) + `section_delivery_page.dart:114-124` | Reanudar un reparto desde *Detalle de reparto*, registrar una interacción "Rechazó" o "Pendiente". `_loadData()` vuelve a llamar a `resumeSpecificDelivery()`, que arranca **otro** `Timer.periodic`. Tras N interacciones el reloj corre a N+1 segundos por segundo. | **Crítica** | ⬜ |
| B2 | **El tiempo retrocede al registrar interacciones en un reparto reanudado** | `delivery_controller.dart:145-165` | En ese mismo `resumeSpecificDelivery`, `_elapsedSeconds` se recarga desde `deliveries.durationSeconds`, que sólo se guarda al **pausar**. Cada interacción regresa el reloj al último valor pausado. (*Corrección 2026-09-29:* no se pierde `clientesContactados`; el controller vuelve a empujar sus listas en `delivery_controller.dart:174-176`.) | **Crítica** | ⬜ |
| B3 | **Diálogo de cajas repetido** | `section_delivery_page.dart:108-121` | Reparto reanudado con 0 cajas: el diálogo "¿Con cuántas cajas…?" vuelve a salir tras cada interacción, porque el override no se persiste hasta la pausa. | Alta | ⬜ |
| B4 | **Tiempo en segundo plano contado doble** | `delivery_controller.dart:482-503` | En `paused` se anota `_backgroundTime`, pero el `Timer.periodic` sigue corriendo mientras el proceso vive (lo normal en Android durante minutos). En `resumed` se suma además `now - _backgroundTime`. Si el usuario cambia a WhatsApp 10 min, el reparto registra ~20 min. | **Crítica** | ⬜ |
| B5 | **El reparto se pierde si el SO mata la app** | `_loadPersistentState()` (`delivery_controller.dart:528`) **nunca se llama** | Se guarda estado en `PersistentDeliveryStates` pero jamás se restaura. Si Android mata la app o el usuario la cierra, el singleton vuelve a vacío: la app "olvida" que había un reparto y el siguiente *Iniciar* crea otro número. | **Crítica** | ⬜ |
| B6 | **Salir de la pantalla pausa el reparto** | `section_delivery_page.dart:254-259` (`onWillPop` → `pauseDelivery`) | Volver a Home para registrar un gasto o consultar una nota detiene el cronómetro sin avisar. El "tiempo activo" subreporta. Además, `fabs.dart:50,72` y `clientes_list.dart:69,106` **reanudan** en silencio al tocar un cliente o el `$`. El usuario no controla el estado. | Alta | ⬜ |
| B7 | **El controller nunca se hace `dispose()`** | `section_delivery_page.dart:240-245` | Se quita el observer pero no se llama `_controller.dispose()`. Cualquier timer vivo (B1) sigue ejecutándose y escribiendo en el singleton después de cerrar la página. | Media | ⬜ |
| B8 | **Número de reparto = `count + 1`** | `section_delivery_page.dart:368-369`, `delivery_controller.dart:45` | a) `getAllDeliveries()` filtra por vendedor, pero `deliveryNumber` es **PK global** (`database.dart:33`). El vendedor 2, con 3 repartos, inicia el #4, que ya existe del vendedor 1, y `insertDelivery` lanza UNIQUE. b) Si hay huecos (repartos borrados o sincronizados con saltos), `count+1` reutiliza un número existente y **fusiona** ventas de dos repartos. | **Crítica** (multi-vendedor) | ⬜ |
| B9 | **Si falla el cierre, el reparto queda zombie** | `delivery_controller.dart:255-281` | Si `_saveDeliveryRecord` lanza (p. ej. por B8), el `catch` llama a `_saveEmptyDeliveryRecord`, que vuelve a lanzar la misma excepción. Nunca se ejecuta `_resetDeliveryState`, la UI sigue en "reparto activo" y no hay mensaje al usuario. | Alta | ⬜ |
| B10 | **Cerrar un reparto reanudado sobrescribe datos históricos** | `delivery_controller.dart:264-269` | `endDelivery` guarda `date: DateTime.now()` y `remaining: 0.0`. Reanudar el reparto del lunes para añadir 5 min lo mueve al jueves y borra las cajas restantes. | Alta | ⬜ |
| B11 | **Reanudar un reparto viejo pisa el reparto activo** | `delivery_detail_view.dart:76-84` → `resumeSpecificDelivery` | Con el #7 activo, abrir el detalle del #5 y pulsar ▶ hace que `_stateManager.startDelivery(5)` reemplace el #7 sin preguntar. El tiempo del #7 desde la última pausa se pierde. | Alta | ⬜ |
| B12 | **La pantalla de "Progreso" no se refresca** | `delivery_progress_view.dart:29-79` | Sólo carga en `initState`. Con `TabBarView`, las ventas nuevas no aparecen hasta reconstruir la vista. También hace N+1 consultas (`getClienteById` en bucle). | Media | ⬜ |

### Corrección recomendada (una sola, que cubre B1-B7 y B11)

Reemplazar el contador por un **modelo de sesión basado en marcas de tiempo**, persistido en cada transición:

```dart
class DeliverySession {            // inmutable, se guarda en PersistentDeliveryStates
  final int deliveryNumber;
  final Duration accumulated;      // tiempo de tramos ya cerrados
  final DateTime? runningSince;    // null = pausado
  final int boxes;
  Duration elapsed(DateTime now) =>
      accumulated + (runningSince == null ? Duration.zero : now.difference(runningSince!));
}
```

- El `Timer.periodic` **sólo repinta**; nunca suma. Esto elimina B1, B2 y B4 por construcción.
- `start`, `pause`, `resume` y `end` escriben la sesión en DB antes de notificar.
- Al arrancar la app (`main()`) se lee la sesión, lo que resuelve B5.
- Un **único** controller de ámbito de app (no uno por página ni un singleton paralelo), para B6, B7 y B11.
- `resume(otherNumber)` con sesión activa debe preguntar: *"Hay un reparto en curso (#7). ¿Pausarlo y reanudar el #5?"*
- Número de reparto: `MAX(deliveryNumber)+1` **global**, o mejor PK compuesta `(seller_id, delivery_number)` o un UUID con número visible aparte. Requiere migración (v20), lo que resuelve B8.
- Inyectar un reloj (`DateTime Function() clock`, como ya hace `DeliveryService`) permite testear todo sin esperar segundos reales.

---

## 2. Otros bugs (fuera del reparto)

### Pérdida o corrupción de datos (alta)

| # | Bug | Dónde | Estado |
|---|---|---|---|
| D1 | Migraciones con `if (from == N)` en vez de `if (from <= N)`: actualizar de v16 a v19 sólo ejecuta 16→17. Hay que re-encadenar y agregar un test de migración con `drift_dev schema`. | `database.dart:148-267` | ⬜ |
| D2 | *Limpiar ventas*: botón rojo justo bajo *Guardar*, sin confirmación, y `deleteAllSales()` borra **todos los vendedores**. | `venta_form.dart:1020-1029`, `database_service.dart:275` | ⬜ |
| D3 | *Eliminar repartos*: al lado de *Mostrar repartos*, sin confirmación, borra todos los repartos de todos los vendedores. | `delivery_records_table.dart:42-48` → `delivery_controller.dart:441` → `delivery_service.dart:217` → `database_service.dart:436` | ⬜ |
| D4 | En el diálogo de sincronización, *Cancelar* devuelve `false` y `false` = "eliminar datos locales". *Corrección 2026-09-29:* no borra directo, abre un segundo diálogo de confirmación de borrado (`sync_action_button.dart:107-115`). Sigue siendo una trampa: el usuario que cancela termina frente a "¿borrar?". | `sync_dialogs.dart:19-21` + `sync_action_button.dart:78-115` | ⬜ |
| D5 | `deleteAll*` y "borrar y re-sincronizar" no filtran por `seller_id`, pero el pull sólo trae al vendedor actual. Se pierden datos no subidos de otros vendedores. Además el reset de BD y `clearDatabase` no incluyen `Gastos`. | `sync_service.dart:118-175` | ⬜ |
| D6 | `getSheetData` convierte errores de red en `[]`. Si la lectura falla y la escritura no, el PUSH puede reescribir la hoja sin las filas de otros vendedores (depende del momento exacto de la falla). | `google_sheets_service.dart:45-55` + `database_service.dart:881-917` | ⬜ |
| D7 | Una venta nueva "adopta" **todas** las notas del cliente con `ventaId == null`, incluidas las notas generales, que desaparecen de la ficha. Esa ruta tampoco filtra por vendedor. | `venta_form.dart:710` → `database_service.dart:1404-1410` | ⬜ |
| D8 | Editar una venta permite cambiar el cliente, pero `updateSale` no recibe `clientId`: el cambio se pierde sin aviso. | `venta_form.dart:236`, `database_service.dart:200-206` | ⬜ |
| N1 | *(Nuevo 2026-09-29)* Las hojas `Notas!A:E` e `Interacciones!A:E` **no tienen columna `seller_id`**. El PUSH reescribe la hoja completa con las filas locales del vendedor actual (borra las de los demás) y el PULL asigna todas las filas remotas al vendedor actual. Mismo problema de fondo que D5/D6, pero sin la protección de `_pushSellerRows`. | `database_service.dart` `_syncNotasData` (~1710-1765), `_syncInteraccionesData` (~2046-2105) | ⬜ |
| N2 | *(Nuevo, del ticket FAB)* Flujo *desde la lista*: elegir "Venta" en la hoja de interacción inserta la interacción **antes** de abrir el formulario. Si el usuario cancela, queda una interacción "Venta" sin venta. | `section_delivery_page.dart:197-201` | ⬜ |
| N3 | *(Nuevo, del ticket FAB)* En ese mismo flujo el cliente del formulario sigue editable: si se cambia, la interacción queda en el cliente original y la venta en otro. Además usa `insertSale` simple, no la transacción `insertSaleWithInteraction` que ya usa el FAB. | `venta_form.dart:~700-762` | ⬜ |

### Validación y entrada (media-alta)

| # | Bug | Dónde | Estado |
|---|---|---|---|
| V1 | Venta sin validación: campos vacíos o negativos se guardan como 0 kg / $0. Sin `selectedPrice` el precio es 0. `_persistSale` sólo valida que haya cliente. | `venta_form.dart:654-673` | ⬜ |
| V2 | El teclado de cantidad es `TextInputType.number`: en iOS no hay punto decimal, y la coma decimal parsea a 0. | `venta_form.dart:853` | ⬜ |
| V3 | Fecha de venta futura permitida (hasta 2101). La heurística ignora ventas con fecha futura y la hora se pierde. | `venta_form.dart:737-747` | ⬜ |
| V4 | Clientes: el validador acepta "2.5" (`num.tryParse`) pero se guarda con `int.tryParse`, que da 0. | `nuevo_cliente_page.dart:398-405` (parseo en `:222`, `:253`) | ⬜ |
| V5 | Al editar un cliente se guarda `ultimoContacto = now()` e ignora la fecha elegida. | `nuevo_cliente_page.dart:208-223` | ⬜ |
| V6 | Protección contra doble toque. **Parcial:** la venta nueva ya tiene `_isSaving` (`venta_form.dart:635-650`); faltan editar venta (`EditVentaForm._saveSale`, `venta_form.dart:211`), cliente y gasto. | varios | 🟡 |
| V7 | `currentSellerId` vale 1 cuando no hay sesión: se escriben datos como "Moy" sin avisar. | `user_session_service.dart:18` | ⬜ |

### Estabilidad (media)

| # | Bug | Dónde | Estado |
|---|---|---|---|
| E1 | Muchos `setState`, `ScaffoldMessenger` y `Navigator` después de `await` sin `mounted` (venta, edición de venta, notas, sync, clientes). Revisión por muestreo, no exhaustiva. | p. ej. `venta_form.dart:1023` | ⬜ |
| E2 | `GoogleSheetsService().init(context)` sin `await`: una sincronización rápida falla con "API not initialized". | `synchronization_page.dart:21` | ⬜ |
| E3 | `NotesContainer` sin `key`: al cambiar de cliente se ven las notas del anterior. | `editar_clientes_page.dart:354`, `venta_form.dart:466,976` | ⬜ |
| E4 | La fecha del gasto no se refresca en el diálogo (`fecha = picked` sin `setState`/`StatefulBuilder`). | `gastos_page.dart:103-111` | ⬜ |
| E5 | "Llamada" o "Mensaje" usa el número `3333333333` si el cliente no tiene teléfono: llama a un desconocido. Duplicado en `contacto_options_sheet.dart`. | `interaccion_options_sheet.dart:37,132` | ⬜ |
| E6 | `clientes.first` sobre una lista vacía lanza `StateError` (sólo cuando llega `preloadClientId`). | `editar_clientes_page.dart:60-63` | ⬜ |
| N4 | *(Nuevo)* `ClienteInfoCard` muestra `puntuacion` persistida, que ya no decide la lista y puede estar desactualizada: el usuario ve un número que no explica por qué el cliente está ahí. | `cliente_info_card.dart:112` | ⬜ |
| N5 | *(Nuevo)* El ID del spreadsheet está duplicado: además de `sync_service.dart:31` está en `user_selection_page.dart:59`. | — | ⬜ |
| N6 | *(Nuevo)* `DeliveryController.loadClientes` llama a `DeliveryService.loadClientes` sin `excludeDeliveryNumber`; quien sí lo pasa es la página. Dos caminos para lo mismo. | `delivery_controller.dart:421-423` | ⬜ |
| N7 | *(Nuevo)* `contacto_options_sheet.dart` y `contacto_section.dart` son código muerto (nadie los importa): copias de `interaccion_*` que quedaron del rename Contactos → Interacciones. | `lib/pages/section_delivery/widgets/` | ⬜ |

---

## 3. Usabilidad con una mano: diagnóstico

Zonas de pulgar (mano derecha, teléfono de 6"): **verde** el tercio inferior central, **amarillo** los laterales medios, **rojo** la AppBar y las esquinas superiores.

| Pantalla | Problema | Zona |
|---|---|---|
| Home (`main.dart:417-850`) | El botón **Reparto**, la acción del día, está *debajo* de la tarjeta de precios y del widget de notas: hay que hacer scroll para llegar. No se ve si hay un reparto en curso. | 🔴 |
| Home | *Cambiar usuario* y el tema están arriba a la derecha. El cambio de usuario no pide confirmación ni avisa si hay un reparto activo. | 🔴 |
| Reparto activo | ▶, ⏸ y ⏹ miden **120 px en el centro inferior**, justo encima de la lista. Es el lugar exacto donde el pulgar hace scroll, así que un toque accidental pausa el reparto. ⏹ está pegado a ▶. | 🟢 pero mal usado |
| Reparto activo | El cronómetro está en la AppBar (🔴), sin control. Los FABs `+` y `$` son `mini` (40 px) en esquinas inferiores y quedan tapados por los de 120 px. | 🟡 |
| Lista de clientes | Cada fila tiene 3 zonas táctiles: fila → hoja de interacción, 🔍 (24 px) → ficha, ✏️ (24 px) → editar. Los iconos miden 24 px, **menos que el mínimo de 48 dp** de `REQUISITOS_UX.md` U04. | 🟡 |
| Interacción | Tocar cliente → Llamada/Visita/Mensaje → (app externa) → segunda hoja con resultado: 3 o 4 toques más cambio de contexto. "Visita" espera al GPS de alta precisión antes de dejarte elegir el resultado. | — |
| Registrar venta | El buscador de cliente es un menú anclado arriba. *Guardar* está al final de un scroll largo, seguido de *Nuevo cliente* (no hace nada), *Ver ventas (debug)* y *Limpiar ventas*. Son 5-7 toques más scroll, frente al objetivo de ~30 s por venta (`REQUISITOS_UX.md` U06). | 🔴 |
| Clientes (nuevo o editar) | Guardar está en la AppBar o al final de un ListView con historial. | 🔴 |
| Gastos | Borrar sólo con pulsación larga, que nadie descubre. | — |
| Sincronización | Las acciones destructivas usan `TextButton` gris y el diálogo se cierra tocando fuera. | — |
| Pestañas "Repartos / Historial" | "Mostrar repartos", "Eliminar repartos" y "Debug Interacciones" son botones de desarrollo en la pantalla del vendedor. La tabla es un `DataTable` horizontal de 9 columnas, ilegible en vertical. | — |
| General | 48 colores fijos (`Colors.white`, `Colors.deepPurple`…) rompen el modo oscuro, por ejemplo la lista de clientes blanca sobre fondo oscuro (`clientes_list.dart:44`). El contraste no está pensado para usar la app bajo el sol. | — |

---

## 4. Evaluación de refactorización

### Diagnóstico

| Síntoma | Evidencia |
|---|---|
| God-service | `database_service.dart`: **2109 líneas** con CRUD, sync push/pull, snapshot de recomendaciones y estado persistente. |
| Formularios duplicados | `EditVentaForm` copia unas 480 líneas de `VentaForm`. `nuevo_cliente_page` y `editar_clientes_page` son ~85 % iguales y ya divergieron (GPS stub, `dispose`, notas). |
| Estado triplicado | Controller por página + singleton + tabla persistida, sin fuente de verdad (§1). |
| Lógica de negocio en la UI | Cálculo de precio y total en `venta_form`, precio sugerido en `main.dart:182-232`, numeración de repartos en la página. |
| Código muerto | `Section1Page` (con ruta), `_counter` y `_reparto*` en Home (`main.dart:98-104`), `TimerDisplay`, `saveInteraccionesToDatabase`, `onRegistrarVenta` "por compatibilidad" y `_registrarInteraccionVenta` (`section_delivery_page.dart:158-189`), `esRelleno` "por compatibilidad", `_notasFocusNode` desconectado, `contacto_options_sheet.dart` + `contacto_section.dart` (N7). |
| Documentación desalineada | ✅ *Resuelto 2026-09-29* con la consolidación de `docs/` (ver `docs/README.md`): CLAUDE.md y README corregidos (schema v19, `Interacciones`, pesos del score), specs obsoletas y backlog heurístico archivados, ticket del FAB cerrado. |
| Tests | `test/widget_test.dart` falla desde antes (busca un contador). Sólo la heurística tiene cobertura real. El controller de reparto, que es donde están los bugs, tiene cero tests. |

### Recomendación: refactor **incremental y dirigido**, no reescritura

| Fase | Qué | Ventaja | Riesgo | Estado |
|---|---|---|---|---|
| 0 | Arreglar `widget_test`, añadir tests de `DeliverySession` con reloj inyectable y un test de migraciones | Red de seguridad antes de mover nada | Bajo | ⬜ |
| 1 | `DeliverySession` + `DeliverySessionRepository` + un único `DeliveryController` global (con `ChangeNotifierProvider` o `ValueNotifier` en `main`). Eliminar `DeliveryStateManager`. | Resuelve el 80 % de los bugs críticos | Medio: toca la pantalla más usada | ⬜ |
| 2 | Partir `DatabaseService` en `SalesRepository`, `DeliveriesRepository`, `ClientsRepository`, `NotesRepository`, `ExpensesRepository` y un `SheetsSync` por entidad, con el filtro `sellerId` **obligatorio en el constructor** del repositorio | Elimina los `deleteAll*` globales por diseño y facilita tests | Medio: mucho código mecánico | ⬜ |
| 3 | Unificar `ClienteForm(mode: create/edit)` y `VentaForm(initial: Sale?)`, y sacar el cálculo de precio y total a un `SaleDraft` puro | -1000 líneas y fin de la divergencia | Bajo-medio | ⬜ |
| 4 | Borrar código muerto, mover lo de debug detrás de un "modo desarrollador" (7 toques en la versión, como Android) y pasar a `colorScheme` | Menos superficie y dark mode real | Bajo | ⬜ |
| 5 | Actualizar CLAUDE.md y README, archivar el backlog viejo en `docs/archive/` y cerrar el ticket del FAB | Los agentes y tú dejan de trabajar con información falsa | Nulo | ✅ 2026-09-29 |

**No recomiendo** cambiar de gestor de estado a Riverpod o Bloc ni reescribir la navegación ahora: el costo es alto y el problema no es el framework, es tener tres fuentes de verdad.

---

## 5. Mejoras propuestas, ordenadas por impacto en la experiencia

> Impacto = (frecuencia de uso × dolor actual × riesgo de perder datos). El esfuerzo va aparte (S/M/L). ➕ ventaja · ➖ desventaja. El estado va al final de cada título.

### 1. Reparto confiable: cronómetro por marcas de tiempo y sesión persistida (M) · ⬜
El reparto sobrevive a cerrar la app, a cambiar a WhatsApp y a Android matando el proceso. El tiempo es exacto, reanudar nunca pisa otro reparto y cerrar nunca cambia la fecha original (§1).
- ➕ Arregla la función central de la app y hace fiable el dato de "duración" para análisis.
- ➕ Con un reloj inyectable se vuelve testeable.
- ➖ Requiere migración (PK o número de reparto) y probar a mano los casos de ciclo de vida.
- ➖ Los repartos ya guardados con duraciones infladas no se pueden corregir retroactivamente.

### 2. Eliminar las trampas destructivas y el debug de la UI de producción (S) · ⬜
Quitar o ocultar *Limpiar ventas*, *Eliminar repartos*, *Debug Interacciones* y *Ver ventas (debug)*. Arreglar *Cancelar → borrar*. Toda eliminación masiva pide confirmación escribiendo "BORRAR", filtra por vendedor y usa un botón rojo.
- ➕ Esfuerzo mínimo con reducción máxima de riesgo.
- ➕ Pantallas más limpias.
- ➖ Pierdes atajos que usas al desarrollar, lo que se compensa con un modo desarrollador oculto.

### 3. "Modo reparto" pensado para el pulgar (M) · ⬜
Barra inferior fija de 64-72 dp con **[＋ Cliente] [$ Venta] [⏸ Pausa]**. El cronómetro pasa a un chip en la barra. *Terminar* se mueve a un menú o a una pulsación larga sobre ⏸ con confirmación. Se quitan los FABs de 120 px que tapan la lista.
- ➕ Todo al alcance del pulgar sin tapar contenido.
- ➕ Adiós a las pausas accidentales.
- ➕ Cumple `REQUISITOS_UX.md` U03 y U04.
- ➖ Cambia la memoria muscular del usuario actual.
- ➖ Hay que rediseñar `fabs.dart` y `_CustomFABLocation`.

### 4. Gestos de deslizamiento en la lista con "Deshacer" (M) · ⬜
Deslizar a la derecha registra *Visitado / Venta* (abre la venta rápida). Deslizar a la izquierda registra *No estaba / Rechazó*. Aparece un SnackBar con **Deshacer** 5 s antes de retirar al cliente de la lista. Llamar o mandar WhatsApp pasa a iconos dentro de la ficha.
- ➕ Una interacción baja de 3-4 toques a **1 gesto**: el objetivo de ~10 s por rechazo (`REQUISITOS_UX.md` U07).
- ➕ "Deshacer" evita el pánico al cometer errores.
- ➖ Los gestos se descubren poco, así que conviene un onboarding de una sola vez.
- ➖ Hay que diferir la inserción de la interacción hasta que expire el "Deshacer" (o borrarla al deshacer).

### 5. Venta rápida en hoja inferior y prellenada (M) · ⬜
Desde la lista, la ficha o el `$`, se abre un bottom sheet con el cliente ya elegido, los **kg habituales** (ya los calculas para las etiquetas), el precio del día y un teclado decimal. *Guardar* va fijo abajo y el total se calcula solo. La venta se valida (> 0, fecha ≤ hoy).
- ➕ La operación más frecuente pasa de 5-7 toques a 2 (ajustar kg y Guardar).
- ➕ Adiós a las ventas de $0.
- ➕ Se reutiliza `ClientPurchaseMetrics`.
- ➖ Hay que partir `venta_form.dart` (1034 líneas), lo que conviene hacer junto con la fase 3 del refactor.
- ➖ El caso de "cliente nuevo en la calle" necesita un atajo aparte.

### 6. Home orientado a la tarea del día (S-M) · ⬜
Arriba, una tarjeta **"Reparto #7 en curso · 01:23 · 14 visitados · Reanudar"** (o *Iniciar reparto* si no hay). Los botones principales van en la mitad inferior. El precio pasa a una tarjeta colapsable y las notas a un contador con enlace.
- ➕ Retomar el reparto toma 1 toque.
- ➕ El usuario siempre sabe en qué estado está.
- ➕ Se elimina el scroll para llegar a *Reparto*.
- ➖ La tarjeta de precios, que hoy es protagonista, pierde visibilidad; si se usa cada mañana, se puede mostrar expandida sólo antes del primer reparto del día.

### 7. Cierre de reparto con resumen y cajas restantes (S) · ⬜
Antes de confirmar se muestra: kg vendidos, total $, precio promedio, clientes visitados y ventas, duración, **cajas restantes** (campo; hoy `remaining` siempre es 0) y ventas sin asignar del día.
- ➕ Detecta errores antes de cerrar, por ejemplo una venta de $0 o una venta olvidada.
- ➕ Llena un dato (`remaining`) que hoy es basura.
- ➖ Suma un paso al cierre, aunque ocurre una vez al día.

### 8. Sincronización segura, visible y automática (M-L) · ⬜
Añadir un badge "3 cambios sin subir" en Home y sincronizar sola al terminar el reparto si hay red. Un error de lectura debe **abortar** el push en lugar de tratarse como hoja vacía. Los borrados deben filtrar por vendedor. Hace falta un progreso "X/Y" y un botón "Reintentar".
- ➕ Adiós al miedo a perder datos.
- ➕ Menos visitas a una pantalla técnica.
- ➕ Cumple `REQUISITOS_UX.md` U11.
- ➖ Requiere rastrear cambios pendientes (columna `dirty` o `updatedAt`, es decir, migración).
- ➖ La sincronización en segundo plano en Android/iOS tiene letra chica (WorkManager).

### 9. Lista de clientes accionable y con feedback visual (S-M) · ⬜
Filas con altura ≥ 56 dp y zonas táctiles de 48 dp. Al tocar la fila se abre la ficha expandida, con acciones Llamar, WhatsApp, Venta, Rechazó y Editar. Los contactados de la sesión se quedan visibles en verde o rojo en una sección "Hechos (5)" plegable, en vez de desaparecer. Arriba va un contador "Visitados 5/48".
- ➕ Sensación de progreso (motivación).
- ➕ Se puede corregir un error.
- ➕ Cumple `REQUISITOS_UX.md` U08 y U22 (colores por estado, progreso).
- ➖ Choca con el modelo actual, que recarga y excluye a los contactados. Hay que separar los "pendientes" (heurística) de los "hechos hoy" (sesión).

### 10. Formularios robustos: validación, anti doble toque, teclado correcto y "guardar abajo" (S) · ⬜
Esto aplica a venta, cliente y gasto: estado `_saving` que deshabilita el botón, teclado decimal, parseo de coma, mensajes en el campo con borde rojo (`REQUISITOS_UX.md` U13) y guardar fijo abajo.
- ➕ Se acaban los duplicados y los ceros silenciosos.
- ➕ Es barato.
- ➖ Es trabajo repetido en 4 formularios, salvo que se haga después de unificarlos (refactor fase 3).

### 11. Búsqueda de clientes a pantalla completa con recientes y cercanos (M) · ⬜
Un buscador en bottom sheet a pantalla completa, con el cursor ya en el campo. Debajo aparecen "Recientes" y, si hay GPS, "Cerca de ti" (ya guardas coordenadas al registrar visitas).
- ➕ Encontrar un cliente fuera de la lista toma 2 toques.
- ➕ Aprovecha datos que ya tienes.
- ➖ El GPS consume batería y pide permisos: debe ser opcional.
- ➖ Hay que indexar búsquedas con acentos.

### 12. Modo sol / tema consistente (S-M) · ⬜
Reemplazar los 48 colores fijos y los 12 `withOpacity` por `colorScheme`. Añadir una opción de alto contraste y texto grande para usar la app bajo el sol, y respetar `MediaQuery.textScaler`.
- ➕ Legible en la calle, que es donde se usa.
- ➕ El modo oscuro deja de verse roto.
- ➖ El trabajo es mecánico y disperso, sin impacto funcional directo.

### 13. Feedback háptico y estados vacíos explicados (S) · ⬜
Vibración corta al guardar una venta o una interacción. Si la lista está vacía, explicar el porqué ("Todos tus clientes compraron hace poco; el próximo toca el martes") con la opción *Mostrar todos* (`REQUISITOS_UX.md` U10). El error "Error al cargar datos: Exception…" debe traducirse a un mensaje humano.
- ➕ Confirma las acciones sin mirar la pantalla y reduce la confusión.
- ➖ Los mensajes "inteligentes" en estados vacíos dependen de exponer datos de la heurística a la UI.

---

## 6. Plan sugerido (primeras 3 iteraciones)

1. **Sprint "no perder datos"**: mejoras #2 y #10, el arreglo de migraciones (`from <= N`) y el filtrado por vendedor en borrados. *1-2 días.*
2. **Sprint "reparto confiable"**: mejora #1 más sus tests, número de reparto único (migración v20) y la mejora #7. *3-5 días.*
3. **Sprint "una mano"**: mejoras #3, #4, #5 y #6. *1-2 semanas.* Después: #8, #9, #11, #12 y #13.

✅ *Hecho 2026-09-29.* En paralelo, fase 5 del refactor: actualizar CLAUDE.md (schema v19, tablas `Usuarios`, `Gastos` y `PersistentDeliveryStates`), el README y archivar los documentos obsoletos.

---

## 7. Crítica mordaz (pero accionable)

Tu app tiene **un cronómetro que no sabe contar**. Suma segundos a mano en un `Timer`, además suma "el tiempo en segundo plano" y arranca otro timer cada vez que registras un rechazo. En un reparto reanudado, cuantos más clientes te rechazan, más rápido pasa el tiempo. Es poético, pero no es un KPI. **Acción:** una sola `DeliverySession` con `accumulated + (now - runningSince)`. El timer sólo repinta.

Guardas el estado del reparto en la base de datos con esmero… y **nunca lo lees**. Es un diario que nadie abre. **Acción:** léelo en `main()`, o borra esa tabla y deja de fingir que hay persistencia.

El reparto tiene **tres fuentes de verdad**: el controller, el singleton y la tabla. Cuando tres relojes marcan horas distintas, no tienes tres relojes, tienes ninguno. **Acción:** una fuente de verdad y el resto se deriva.

El botón **"Limpiar ventas"** vive a 8 px de **"Guardar"**, es rojo, no pregunta y borra las ventas de *todos* los vendedores. En sincronización, **"Cancelar" significa "¿Quieres borrar tus datos?"**. Es una app de ventas con botón de autodestrucción en la pantalla de ventas. **Acción:** hoy mismo, antes que cualquier otra mejora de esta lista.

El multi-vendedor es "multi" hasta que el segundo vendedor inicia su cuarto reparto y choca con el cuarto reparto del primero. La numeración `count + 1` es lo que usarías para numerar fotocopias, no para una clave primaria. **Acción:** PK compuesta o UUID, con migración v20.

Las migraciones se escribieron asumiendo que todo el mundo actualiza versión por versión, puntualmente, como buen ciudadano. Nadie hace eso. **Acción:** `if (from <= N)` y un test con `drift_dev schema dump`.

Escribiste una especificación de UX muy buena: botones de 48 dp, una mano, 30 s por venta, colores por estado, resumen antes de cerrar. Luego la app hizo lo contrario: botones de 120 px donde el pulgar hace scroll, iconos de 24 px, *Guardar* en la AppBar y la acción principal de Home debajo del pliegue. La especificación es aspiracional y el código es la verdad. **Acción:** convierte cada punto de la especificación en un checklist de aceptación y no des nada por terminado sin marcarlo. *(Hecho 2026-09-29: `REQUISITOS_UX.md`.)*

La documentación "de legado" se contradice a sí misma: schema v13 contra v19, "Contactos" que ya no existen, un umbral de 80 % que ya no se usa, un ticket "pendiente" ya resuelto y dos backlogs superados. Cada sesión de vibe-coding lee eso y construye sobre supuestos falsos, y así llegaste hasta aquí. **Acción:** si un documento describe algo que el código ya no hace, se actualiza o se archiva. Los documentos que sirven a los agentes también necesitan mantenimiento.

Lo bueno, para que no sea sólo fuego: `ClientRecommendationService` es puro, determinista, tiene reloj inyectable y tests. **Ya sabes hacerlo bien**. Aplica ese mismo patrón al reparto y la mitad de este documento se resuelve sola.
