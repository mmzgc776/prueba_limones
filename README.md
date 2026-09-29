# Limones el Patito: app para vendedor itinerante

App móvil en Flutter para que 1 a 3 vendedores ambulantes gestionen repartos, ventas, clientes, notas y gastos. Guarda todo localmente con Drift (SQLite), funciona sin conexión y sincroniza a mano con Google Sheets.

## Características

- **Repartos cronometrados**, con número, cajas, pausa y reanudación.
- **Lista sugerida de clientes** (hasta 60). Se recalcula en cada carga desde las ventas reales y muestra el motivo, el día preferido y los kg habituales, p. ej. `Recompra · Lunes · 20kg`.
- **Ventas e interacciones** (Venta / Rechazó / Pendiente / Encargó), vinculadas al reparto.
- **Clientes** con GPS, horario, historial y métricas calculadas.
- **Gastos** por vendedor.
- **Multi-vendedor**: se elige el vendedor al entrar y los datos quedan aislados por `seller_id`.
- **Sincronización con Google Sheets** por tipo de dato. Cada vendedor escribe sólo sus filas, salvo en Notas e Interacciones (bug conocido N1).
- **Precio sugerido** con referencia de precios SNIIM, más tema claro/oscuro.

## Documentación

Toda la documentación técnica y de producto está en [`docs/`](docs/README.md):

- [Arquitectura](docs/ARQUITECTURA.md): stack, mapa de código, modelo de datos (schema v19) y sincronización.
- [Selección de clientes](docs/SELECCION_CLIENTES.md): heurística de la lista del reparto.
- [Requisitos UX](docs/REQUISITOS_UX.md): checklist de aceptación con estado.
- [Plan de mejoras](docs/PLAN_MEJORAS.md): bugs conocidos y prioridades.
- [Visión](docs/VISION.md): lo que se quiere y todavía no existe.

## Instalación

**Requisitos:** Flutter con Dart `^3.8.1` y un proyecto de Google Cloud con la Google Sheets API habilitada.

```bash
flutter pub get
dart run build_runner build      # genera database.g.dart
flutter run
```

**Credenciales:**

1. Crea una service account y descarga su JSON en `lib/services/credentials.json`. Ese archivo está en `.gitignore`: nunca lo subas al repositorio.
2. Comparte la hoja de cálculo con el email de esa service account.
3. Si usas otra hoja, cambia el ID en **dos** lugares: `_spreadsheetId` en `lib/services/sync_service.dart` y `lib/pages/user_selection_page.dart` (ver `PLAN_MEJORAS.md` N5).

## Comandos

```bash
dart run build_runner build   # tras modificar lib/data/database.dart
dart run build_runner watch   # regeneración continua
flutter test
flutter analyze
dart format .
flutter build apk --debug
```

`test/widget_test.dart` falla desde antes: es la plantilla del contador, que la app no tiene.

## Licencia

Proyecto privado y confidencial.
