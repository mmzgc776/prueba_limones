# Requisitos de experiencia de usuario (checklist de aceptación)

> **Tipo:** requisitos con estado · **Verificado contra el código:** 2026-09-29
> **Origen:** `archive/ESPECIFICACION_EXPERIENCIA_USUARIO.md`. De ahí se tomaron los requisitos que siguen vigentes con las decisiones actuales (datos aislados por vendedor, lista de hasta 60 clientes, vendedor elegido sin PIN). Los descartados están al final, con su motivo.
> **Regla:** una mejora de UX no está terminada hasta que su requisito pasa a ✅ aquí. Los IDs (U01…) se citan desde `PLAN_MEJORAS.md`.

**Estados:** ✅ cumplido · 🟡 parcial · ❌ no cumplido · ❔ sin verificar

## Contexto de uso

- **Usuario:** vendedor en la calle, con una sola mano, a veces bajo el sol, con cobertura intermitente y con prisa.
- **Administración:** la hace el dueño directamente en Google Sheets; no usa la app.

## Principios generales

| ID | Requisito | Estado | Evidencia / pendiente |
|---|---|---|---|
| U01 | Funciona completamente sin conexión; sincronizar es opcional | ✅ | Drift local; la sincronización es manual |
| U02 | La UI no se bloquea esperando a la base de datos | ❔ | No auditado |
| U03 | Uso con una mano: las acciones frecuentes quedan en el tercio inferior y no tapan contenido | ❌ | Home: *Reparto* bajo el pliegue. Reparto: FABs de 120 px sobre la lista. Guardar en la AppBar (`PLAN_MEJORAS.md` §3, mejoras #3 y #6) |
| U04 | Zonas táctiles ≥ 48 dp | 🟡 | Mini FABs de 40 dp; iconos 🔍 y ✏️ de la lista de ~24 dp (`clientes_list.dart:82,104`) |
| U05 | Cada acción produce un resultado visible inmediato (color, check, SnackBar) | 🟡 | Hay SnackBar al guardar la venta e iconos de estado; los clientes atendidos desaparecen en lugar de confirmarse |
| U06 | Registrar una venta toma ~30 s | 🟡 | 5-7 toques más scroll (mejora #5) |
| U07 | Registrar un rechazo o interacción toma ~10 s | ❌ | 3-4 toques más una app externa; "Visita" espera al GPS (mejora #4) |
| U24 | Feedback háptico al guardar una venta o una interacción | ❌ | No se usa en ningún lado (mejora #13) |
| U25 | Legible bajo el sol y respeta el tamaño de texto del sistema | ❌ | Hay 48 colores fijos que rompen el modo oscuro y no existe opción de alto contraste (mejora #12) |

## Home

| ID | Requisito | Estado | Evidencia / pendiente |
|---|---|---|---|
| U18 | Muestra el estado del reparto (en curso o siguiente número) con acceso directo de 1 toque | ❌ | Sólo hay un botón "Reparto" (`main.dart:726-731`) (mejora #6) |
| U19 | Muestra el nombre del vendedor activo | ✅ | `main.dart:342` |
| U20 | Precio sugerido del día, editable | 🟡 | Existe (`main.dart:534-697`), pero sólo en memoria: no se guarda por vendedor |

## Reparto activo

| ID | Requisito | Estado | Evidencia / pendiente |
|---|---|---|---|
| U17 | Cronómetro discreto, con pausa y reanudación, que sobrevive a salir de la app | 🟡 | Existe, pero el tiempo no es confiable y se pierde si el sistema mata la app (B1-B7, mejora #1) |
| U21 | Pestañas Clientes / Progreso | ✅ | `active_delivery_view.dart:72-80` |
| U08 | La lista distingue estados por color (pendiente, visitado, rechazó) y los atendidos siguen visibles | 🟡 | Los colores existen (`clientes_list.dart:94-100`), pero los atendidos salen de la lista al recargar (mejora #9) |
| U22 | Progreso de la sesión: "visitados X/N", kg, total | 🟡 | Muestra ventas, interacciones, total, kg y cajas; falta X/N y no se refresca (B12) |
| U26 | Cada cliente muestra por qué está en la lista (motivo, día, kg habituales) | ✅ | `ClientRecommendation.tags` (`SELECCION_CLIENTES.md`) |
| U27 | La ficha del cliente se abre con 1 toque y ofrece Llamar, WhatsApp, Venta, Rechazó y Editar | ❌ | Tocar la fila abre directo la hoja de interacción; no hay ficha (mejora #9) |
| U28 | Hoja de resultado con colores fijos: Venta verde, Rechazó rojo, Pendiente azul, Encargó naranja | ✅ | `interaccion_section.dart:24-43` |
| U10 | Lista vacía explicada ("todos compraron hace poco…") con acción *Mostrar todos* | ❌ | Hoy se muestra la lista vacía, sin mensaje (mejora #13) |
| U23 | Resumen antes de cerrar el reparto: kg, $, clientes, duración, cajas restantes y ventas sin asignar | ❌ | Sólo hay un diálogo de confirmación (`section_delivery_page.dart:380-393`) (mejora #7) |

## Venta

| ID | Requisito | Estado | Evidencia / pendiente |
|---|---|---|---|
| U14 | El cliente llega preseleccionado cuando la venta se abre desde la lista | 🟡 | Sí desde la lista; desde el FAB `$` hay que buscarlo (es intencional, ver `archive/tickets/`) |
| U13 | Validación en el campo: cantidad > 0, fecha ≤ hoy, precio vacío = precio del día, error con borde rojo | ❌ | V1, V2 y V3 (mejora #10) |
| U15 | Total calculado en vivo | ✅ | `_onFieldChanged` |
| U16 | El vendedor se asigna automáticamente | ✅ | `database_service.dart:142` |
| U29 | Cambiar el precio sólo afecta ventas futuras y se avisa al usuario | 🟡 | Sólo afecta ventas futuras por diseño; no hay aviso |
| U30 | La venta rápida se abre como hoja inferior, prellenada con los kg habituales y con *Guardar* fijo abajo | ❌ | Se abre como página completa (mejora #5) |
| U31 | No se duplican registros por doble toque | 🟡 | Venta nueva ✅; faltan editar venta, cliente y gasto (V6) |

## Clientes

| ID | Requisito | Estado | Evidencia / pendiente |
|---|---|---|---|
| U32 | Crear y editar clientes con captura de GPS | ✅ | `nuevo_cliente_page.dart:138-172` |
| U33 | La ficha muestra el historial de compras (del vendedor) | ✅ | `nuevo_cliente_page.dart:500` |

## Sincronización

| ID | Requisito | Estado | Evidencia / pendiente |
|---|---|---|---|
| U34 | Se puede sincronizar por tipo de dato | ✅ | `synchronization_page.dart:48-116` |
| U12 | Los errores de sincronización muestran el mensaje completo | ✅ | `sync_action_button.dart:103` |
| U11 | Progreso "X/Y", botón *Reintentar* e indicador de cambios sin subir | ❌ | Sólo hay un spinner (`sync_dialogs.dart:72`) (mejora #8) |
| U35 | Las acciones destructivas piden confirmación explícita y nunca se disparan con *Cancelar* | ❌ | D2, D3 y D4 (mejora #2) |

## Descartados (con motivo)

| Requisito original | Motivo |
|---|---|
| Ver historial, métricas y exclusiones **globales** de todos los vendedores; estado "vendido por otro vendedor" | Decisión 2026-09-29: los datos están aislados por vendedor, con una escala de 1 a 3 vendedores. Queda como posibilidad en `VISION.md`. |
| Login con PIN/contraseña y JWT | Se reemplaza por un **PIN local** futuro (`VISION.md`); no habrá JWT ni backend. |
| Lista de 15 clientes "sin scroll" | La lista es de hasta 60 clientes con scroll (decisión de la heurística actual). |
| Recalcular puntuaciones al terminar el reparto | Hoy se recalcula tras cada venta; la lista además recalcula en memoria en cada carga. |
| Vistas de administrador / supervisor en la app | La administración se hace en Google Sheets. |
| Reubicar vendedores por ciudad asignada (`vendedores.ciudad_asignada`) | No aplica a 1-3 vendedores. `Usuarios.ciudad` existe sólo como dato. |
| Logs con vendedor, categorías y filtros | Los logs son una herramienta de desarrollo; si se quieren, van con el "modo desarrollador" (refactor fase 4). |
