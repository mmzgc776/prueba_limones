# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter app ("Limones el Patito") for 1-3 itinerant lemon sellers: timed delivery rounds, sales, client interactions, notes and expenses. Local-first storage with Drift (SQLite); manual sync with Google Sheets. Docs and UI strings are in Spanish.

**Documentation lives in `docs/` — start at `docs/README.md`.** Each doc there was verified against the code on 2026-09-29:

| Need | Read |
|---|---|
| Architecture, tables, sync mechanics, delivery state | `docs/ARQUITECTURA.md` |
| Client-list heuristic (formulas, quotas, tags) | `docs/SELECCION_CLIENTES.md` |
| Known bugs and prioritized work (IDs B/D/V/E/N) | `docs/PLAN_MEJORAS.md` |
| UX acceptance checklist (IDs U01…) | `docs/REQUISITOS_UX.md` |
| Confirmed future requirements | `docs/VISION.md` |

**Do not use `docs/archive/`** as a reference: it describes designs that were never built or were replaced.

### Documentation rules
- When a change alters something a `docs/` file describes (a constant, table, flow), update that doc **in the same commit**.
- When fixing an item from `PLAN_MEJORAS.md` or `REQUISITOS_UX.md`, flip its status (⬜ → ✅ + date) and update the plan's dashboard; don't delete it.
- `ARQUITECTURA` and `SELECCION_CLIENTES` describe only what the code does today. Wishes go to `VISION.md`, defects to `PLAN_MEJORAS.md`.
- If a requirement is unclear, ask the user instead of inventing it.

## Commands

```bash
flutter pub get
dart run build_runner build      # required after modifying lib/data/database.dart
dart run build_runner watch
flutter run                      # flutter run -d <device-id>, --release
flutter build apk --debug
flutter analyze
dart format .                    # `flutter format` no longer exists
flutter test                     # test/widget_test.dart fails (stale counter template); others should pass
flutter test test/client_recommendation_test.dart   # single file
```

## Architecture at a Glance

- `lib/data/database.dart`: Drift tables, **schemaVersion 19**. The 8 tables are `Sales`, `Deliveries`, `Clientes`, `Interacciones` (formerly `Contactos`), `Notas`, `Usuarios`, `Gastos` and `PersistentDeliveryStates`. `database.g.dart` is generated, so never edit it.
- `lib/services/`:
  - `database_service.dart`: CRUD, per-entity Sheets sync and the recommendation snapshot (~2100 lines).
  - `sync_service.dart`: `SyncType` has 9 values (`deliveries, sales, clients, notas, interacciones, expenses, usuarios, database, rateClients`). It also holds the sheet ranges and the score refresh.
  - `client_recommendation_service.dart`: pure, tested heuristic with an injectable clock. **This is the model to follow for new logic.**
  - `delivery_service.dart`, `google_sheets_service.dart`, `user_session_service.dart` (current seller), `sheets_row_utils.dart`, `sniim_scraper_service.dart` (market prices).
- `lib/controllers/delivery_controller.dart` + `lib/data/delivery_session.dart` (`DeliverySession`, pure) + `lib/data/delivery_state.dart` (`DeliveryStateManager` singleton): active-delivery state.
- `lib/pages/`: home is `MyHomePage` in `main.dart`, or `UserSelectionPage` when no session exists. Named routes: `/section1` (dead placeholder), `/ventas`, `/section_delivery`, `/nuevo_cliente`, `/editar_clientes`, `/synchronization`, `/logs`, `/gastos`; `/edit_sale` is resolved in `onGenerateRoute`. Delivery widgets live in `lib/pages/section_delivery/widgets/`.
- `lib/widgets/venta_form.dart`: `VentaForm` + `EditVentaForm`.
- `lib/theme/app_theme.dart`: light/dark Material 3 themes. `main.dart` holds `themeNotifier`, persisted in the `isDarkMode` pref.

## Pitfalls (verified 2026-09-29; details in `docs/PLAN_MEJORAS.md`)

- **Multi-seller scope:**
  - Data is **isolated per seller** (`seller_id`); this is a product decision.
  - New queries, deletes and sync code must filter by `UserSessionService().currentSellerId`.
  - Existing `deleteAll*` methods don't filter (D2, D3, D5).
  - The `Notas` and `Interacciones` sheets have no `seller_id` column (N1).
- **Migrations:** they use `if (from == N)` and are broken when versions are skipped (D1). New migrations should use `if (from <= N)`; fixing the old chain is tracked as D1.
- **Delivery time** comes only from `DeliverySession.elapsed(now)` (`accumulated + (now - runningSince)`). The singleton holds it, and every transition persists it to `PersistentDeliveryStates`. The controller's timer only repaints, so never add seconds by hand. Still pending: one app-wide controller instead of one per page, B8, B10 and the B11 confirmation (plan §1).
- **Delivery number** is a global PK but is computed per seller as `count + 1` (B8).
- **Sale + interaction:** use `AppDatabase.insertSaleWithInteraction` (atomic, tested) instead of separate inserts.
- **Client list** ignores the persisted `puntuacion`. It recomputes `ClientPurchaseMetrics` on every load, so change the heuristic in `client_recommendation_service.dart` and update `docs/SELECCION_CLIENTES.md`.
- **Deprecated API:** `withOpacity()` is deprecated in this Flutter version; use `.withValues(alpha: x)`. Prefer `colorScheme` tokens over hard-coded `Colors.*` so dark mode keeps working.

## Development Patterns

### Adding a new sync type
1. Add the value to `SyncType` and handle it in `syncData()` / `deleteData()` (`sync_service.dart`).
2. Define the sheet range and include a `seller_id` column.
3. Implement `syncXxxUnified()` in `database_service.dart`, pushing through `_pushSellerRows` so other sellers' rows are preserved.
4. Update the sync table in `docs/ARQUITECTURA.md`.

### Adding or changing a table
1. Edit `database.dart`, register the table in `@DriftDatabase(tables: [...])`, bump `schemaVersion` and add an `onUpgrade` step.
2. Run `dart run build_runner build`.
3. Add CRUD methods in `database_service.dart`, filtered by seller.
4. Update the data-model table in `docs/ARQUITECTURA.md`.

## Logging

`appLog(String)` (from `lib/pages/logs_page.dart`) appends to an in-memory buffer of the last 100 entries, which you can view at `/logs`.

## Credentials

The Google service-account key goes in `lib/services/credentials.json`.
- It is **git-ignored** and has never been committed.
- It is bundled as a Flutter asset, so it ships inside the app binary.
- The spreadsheet ID is hard-coded in `sync_service.dart` and duplicated in `user_selection_page.dart` (N5).
