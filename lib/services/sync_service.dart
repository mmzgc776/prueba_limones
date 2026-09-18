import 'package:flutter/material.dart';
import '../data/database.dart';
import '../services/database_service.dart';
import 'client_recommendation_service.dart';
import 'user_session_service.dart';

/// Tipos de sincronización disponibles
enum SyncType { deliveries, sales, clients, notas, interacciones, expenses, usuarios, database, rateClients }

/// Resultado de una operación de sincronización
class SyncResult {
  final bool success;
  final String message;
  final int itemsProcessed;

  const SyncResult({
    required this.success,
    required this.message,
    this.itemsProcessed = 0,
  });

  factory SyncResult.success(String message, [int items = 0]) =>
      SyncResult(success: true, message: message, itemsProcessed: items);

  factory SyncResult.error(String message) =>
      SyncResult(success: false, message: message);
}

/// Servicio centralizado para operaciones de sincronización
class SyncService {
  static const String _spreadsheetId =
      '1f72gI91Qvz9a2wcakgLLiCgPTzWHauYen5cD4kJL4ys';
  final DatabaseService _databaseService;

  final DateTime Function() _clock;

  SyncService(this._databaseService, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// Sincroniza datos según el tipo especificado
  Future<SyncResult> syncData(SyncType type, BuildContext context) async {
    try {
      await _databaseService.init();

      switch (type) {
        case SyncType.deliveries:
      await _databaseService.syncDeliveriesUnified(
        context: context,
        spreadsheetId: _spreadsheetId,
        range: 'Repartos!A:I',
      );
          return SyncResult.success('Repartos sincronizados exitosamente');

        case SyncType.sales:
      await _databaseService.syncSalesUnified(
        context: context,
        spreadsheetId: _spreadsheetId,
        range: 'Ventas!A:H',
      );
          return SyncResult.success('Ventas sincronizados exitosamente');

        case SyncType.clients:
      await _databaseService.syncClientesUnified(
        context: context,
        spreadsheetId: _spreadsheetId,
        range: 'Clientes!A:AC',
      );
          return SyncResult.success('Clientes sincronizados exitosamente');

        case SyncType.notas:
      await _databaseService.syncNotasUnified(
        context: context,
        spreadsheetId: _spreadsheetId,
        range: 'Notas!A:E',
      );
          return SyncResult.success('Notas sincronizadas exitosamente');

        case SyncType.interacciones:
      await _databaseService.syncInteraccionesUnified(
        context: context,
        spreadsheetId: _spreadsheetId,
        range: 'Interacciones!A:E',
      );
          return SyncResult.success('Interacciones sincronizadas exitosamente');

        case SyncType.expenses:
          await _databaseService.syncGastosUnified(
            context: context,
            spreadsheetId: _spreadsheetId,
            range: 'Gastos!A:F',
          );
          return SyncResult.success('Gastos sincronizados exitosamente');

        case SyncType.usuarios:
          await _databaseService.syncUsuariosUnified(
            context: context,
            spreadsheetId: _spreadsheetId,
            range: 'Usuarios!A:D',
          );
          return SyncResult.success('Usuarios sincronizados exitosamente');

        case SyncType.database:
          return SyncResult.error('Operación no válida para sincronización');

        case SyncType.rateClients:
          return await updateClientScores();
      }
    } catch (e) {
      return SyncResult.error('Error: ${e.toString()}');
    }
  }

  /// Elimina todos los datos de un tipo específico
  Future<SyncResult> deleteData(SyncType type, BuildContext context) async {
    try {
      await _databaseService.init();

      switch (type) {
        case SyncType.deliveries:
          await _databaseService.deleteAllDeliveries();
          return SyncResult.success('Repartos eliminados exitosamente');

        case SyncType.sales:
          await _databaseService.deleteAllSales();
          return SyncResult.success('Ventas eliminadas exitosamente');

        case SyncType.clients:
          await _databaseService.deleteAllClientes();
          return SyncResult.success('Clientes eliminados exitosamente');

        case SyncType.notas:
          await _databaseService.deleteAllNotas();
          return SyncResult.success('Notas eliminadas exitosamente');

        case SyncType.interacciones:
          await _databaseService.deleteAllInteracciones();
          return SyncResult.success('Interacciones eliminadas exitosamente');

        case SyncType.expenses:
          await _databaseService.deleteAllGastos();
          return SyncResult.success('Gastos eliminados exitosamente');

        case SyncType.usuarios:
          return SyncResult.error('Operación no válida para eliminación');

        case SyncType.database:
          await _databaseService.deleteAllSales();
          await _databaseService.deleteAllDeliveries();
          await _databaseService.deleteAllClientes();
          await _databaseService.deleteAllNotas();
          await _databaseService.deleteAllInteracciones();
          return SyncResult.success('Base de datos limpiada exitosamente');

        case SyncType.rateClients:
          return SyncResult.error('Operación no válida para eliminación');
      }
    } catch (e) {
      return SyncResult.error('Error: ${e.toString()}');
    }
  }

  /// Limpia toda la base de datos
  Future<SyncResult> clearDatabase() async {
    try {
      await _databaseService.init();
      await _databaseService.deleteAllSales();
      await _databaseService.deleteAllDeliveries();
      await _databaseService.deleteAllClientes();
      await _databaseService.deleteAllNotas();
      await _databaseService.deleteAllInteracciones();
      return SyncResult.success('Base de datos limpiada exitosamente');
    } catch (e) {
      return SyncResult.error('Error: ${e.toString()}');
    }
  }

  /// Ambas rutas usan exactamente las mismas métricas y escalas fijas.
  Future<void> _refreshScores(int sellerId, {int? clientId}) async {
    await _databaseService.init();
    final snapshot = await _databaseService.getRecommendationSnapshot(sellerId);
    final now = _clock();
    final grouped = <int, List<Sale>>{};
    for (final sale in snapshot.sales) {
      grouped.putIfAbsent(sale.clientId, () => []).add(sale);
    }
    for (final client in snapshot.clientes) {
      if (clientId != null && client.id != clientId) continue;
      final metrics = ClientPurchaseMetrics.calculate(
        sales: grouped[client.id] ?? [], deliveries: snapshot.deliveries, now: now);
      await _databaseService.saveRecommendationMetrics(client.id, sellerId, metrics);
    }
  }

  // Serializar recálculos evita que una tarea antigua sobrescriba una nueva.
  static Future<void> _scoreQueue = Future<void>.value();
  Future<void> _enqueueRefresh(int sellerId, {int? clientId}) {
    final task = _scoreQueue.then((_) => _refreshScores(sellerId, clientId: clientId));
    _scoreQueue = task.then<void>((_) {}, onError: (Object e, StackTrace st) {
      debugPrint('Error al recalcular puntuaciones: $e');
    });
    return task;
  }

  Future<SyncResult> updateClientScores() async {
    final sellerId = UserSessionService().currentSellerId;
    try {
      await _enqueueRefresh(sellerId);
      return SyncResult.success('Puntuaciones actualizadas con la heurística de recompra.');
    } catch (e) {
      return SyncResult.error('Error al puntuar clientes: $e');
    }
  }

  Future<void> refreshSingleClientScore(int clientId) async {
    final sellerId = UserSessionService().currentSellerId;
    try {
      await _enqueueRefresh(sellerId, clientId: clientId);
    } catch (e) {
      debugPrint('refreshSingleClientScore error for client $clientId: $e');
    }
  }
}
