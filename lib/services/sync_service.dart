import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Tipos de sincronización disponibles
enum SyncType { deliveries, sales, clients, expenses, database, rateClients }

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

  SyncService(this._databaseService);

  /// Sincroniza datos según el tipo especificado
  Future<SyncResult> syncData(SyncType type, BuildContext context) async {
    try {
      await _databaseService.init();

      switch (type) {
        case SyncType.deliveries:
          await _databaseService.syncDeliveriesUnified(
            context: context,
            spreadsheetId: _spreadsheetId,
            range: 'Repartos!A1:I300',
          );
          return SyncResult.success('Repartos sincronizados exitosamente');

        case SyncType.sales:
          await _databaseService.syncSalesUnified(
            context: context,
            spreadsheetId: _spreadsheetId,
            range: 'Ventas!A1:H300',
          );
          return SyncResult.success('Ventas sincronizadas exitosamente');

        case SyncType.clients:
          await _databaseService.syncClientesUnified(
            context: context,
            spreadsheetId: _spreadsheetId,
            range: 'Clientes!A1:W300',
          );
          return SyncResult.success('Clientes sincronizados exitosamente');

        case SyncType.expenses:
          return SyncResult.error('Sincronización de gastos no implementada');

        case SyncType.database:
          return SyncResult.error('Operación no válida para sincronización');

        case SyncType.rateClients:
          return SyncResult.error('Operación no válida para sincronización');
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

        case SyncType.expenses:
          return SyncResult.error('Eliminación de gastos no implementada');

        case SyncType.database:
          await _databaseService.deleteAllSales();
          await _databaseService.deleteAllDeliveries();
          await _databaseService.deleteAllClientes();
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
      return SyncResult.success('Base de datos limpiada exitosamente');
    } catch (e) {
      return SyncResult.error('Error: ${e.toString()}');
    }
  }

  /// Actualiza las puntuaciones de los clientes
  Future<SyncResult> updateClientScores() async {
    try {
      await _databaseService.init();

      final clientes = await _databaseService.getAllClientes();
      int totalVentas = 0;

      for (final cliente in clientes) {
        final ventasCliente = await _databaseService.getVentasByClientId(
          cliente.id,
        );
        final numeroVentas = ventasCliente.length;
        totalVentas += numeroVentas;

        await _databaseService.updateClienteEventos(cliente.id, numeroVentas);
      }

      return SyncResult.success('Puntuaciones actualizadas', totalVentas);
    } catch (e) {
      return SyncResult.error('Error: ${e.toString()}');
    }
  }
}
