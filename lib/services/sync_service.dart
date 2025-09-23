import 'package:flutter/material.dart';
import '../data/database.dart';
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
            range: 'Repartos!A1:I',
          );
          return SyncResult.success('Repartos sincronizados exitosamente');

        case SyncType.sales:
          await _databaseService.syncSalesUnified(
            context: context,
            spreadsheetId: _spreadsheetId,
            range: 'Ventas!A1:H',
          );
          return SyncResult.success('Ventas sincronizados exitosamente');

        case SyncType.clients:
          await _databaseService.syncClientesUnified(
            context: context,
            spreadsheetId: _spreadsheetId,
            range: 'Clientes!A1:W',
          );
          return SyncResult.success('Clientes sincronizados exitosamente');

        case SyncType.expenses:
          return SyncResult.error('Sincronización de gastos no implementada');

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

      var clientes = await _databaseService.getAllClientes();
      if (clientes.isEmpty) {
        return SyncResult.success('No hay clientes para puntuar.');
      }

      final latestDeliveries = await _databaseService.getLatestDeliveryNumbers(
        10,
      );
      final highestDeliveryNumber =
          await _databaseService.getHighestDeliveryNumber() ?? 1;
      final DateTime? oldestDeliveryDate = await _databaseService
          .getOldestDeliveryDate();
      double weeksSinceFirstDelivery = 1.0;

      if (oldestDeliveryDate != null) {
        final now = DateTime.now();
        final differenceInDays = now.difference(oldestDeliveryDate).inDays;
        weeksSinceFirstDelivery = (differenceInDays / 7).clamp(
          1.0,
          double.infinity,
        );
      }

      int totalVentas = 0;
      for (final cliente in clientes) {
        final ventasCliente = await _databaseService.getVentasByClientId(
          cliente.id,
        );
        final numeroVentas = ventasCliente.length;
        totalVentas += numeroVentas;

        if (ventasCliente.isNotEmpty) {
          final double kgTotales = ventasCliente.fold(
            0.0,
            (sum, venta) => sum + venta.quantity,
          );
          await _databaseService.updateClienteKgTotal(cliente.id, kgTotales);

          final double maximo = ventasCliente
              .map((v) => v.quantity)
              .reduce((a, b) => a > b ? a : b);

          final counts = <double, int>{};
          for (var v in ventasCliente) {
            counts[v.quantity] = (counts[v.quantity] ?? 0) + 1;
          }
          final double moda = counts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;

          final double ventasEnUltimos10Repartos = ventasCliente
              .where(
                (v) =>
                    v.deliveryNumber != null &&
                    latestDeliveries.contains(v.deliveryNumber),
              )
              .length
              .toDouble();
          final double ultimas10 = ventasEnUltimos10Repartos / 10.0;

          final double ventasVuelta =
              (numeroVentas > 0 && highestDeliveryNumber > 0)
              ? numeroVentas.toDouble() / highestDeliveryNumber
              : 0.0;

          final double kgEvento = numeroVentas > 0
              ? kgTotales / numeroVentas
              : 0.0;

          await _databaseService.updateClientePuntuacion(
            clientId: cliente.id,
            moda: moda,
            maximo: maximo,
            ventasVuelta: ventasVuelta,
            ultimas10: ultimas10,
            kgEvento: kgEvento,
          );

          if (kgTotales > 0) {
            final double kgSemana = kgTotales / weeksSinceFirstDelivery;
            await _databaseService.updateClienteKgSemana(cliente.id, kgSemana);
          }
        }
        await _databaseService.updateClienteEventos(cliente.id, numeroVentas);
      }

      // Recargamos los clientes para tener los datos actualizados
      clientes = await _databaseService.getAllClientes();

      // Obtener los valores máximos para la normalización
      final maxEventos =
          (await _databaseService.getMaxEventos())?.toDouble() ?? 1.0;
      final maxModa = await _databaseService.getMaxModa() ?? 1.0;
      final maxKgEvento = await _databaseService.getMaxKgEvento() ?? 1.0;
      final maxKgTotal = await _databaseService.getMaxKgTotal() ?? 1.0;
      final maxMaximo = await _databaseService.getMaxMaximo() ?? 1.0;
      final maxKgSemana = await _databaseService.getMaxKgSemana() ?? 1.0;
      final maxVentasVuelta =
          await _databaseService.getMaxVentasVuelta() ?? 1.0;
      final maxUltimas10 = await _databaseService.getMaxUltimas10() ?? 1.0;

      for (final cliente in clientes) {
        // Normalización
        final cv = cliente.eventos / (maxEventos > 0 ? maxEventos : 1);
        final mc = cliente.moda / (maxModa > 0 ? maxModa : 1);
        final kv = cliente.kgEvento / (maxKgEvento > 0 ? maxKgEvento : 1);

        final co = 0.4 * cv + 0.4 * mc + 0.2 * kv;

        final tv = cliente.kgTotal / (maxKgTotal > 0 ? maxKgTotal : 1);
        final cm = cliente.maximo / (maxMaximo > 0 ? maxMaximo : 1);
        final ks = cliente.kgSemana / (maxKgSemana > 0 ? maxKgSemana : 1);

        final v = 0.4 * tv + 0.4 * cm + 0.2 * ks;

        final kr =
            cliente.ventasVuelta / (maxVentasVuelta > 0 ? maxVentasVuelta : 1);
        final c10 = cliente.ultimas10 / (maxUltimas10 > 0 ? maxUltimas10 : 1);

        final puntuacion = 0.35 * co + 0.35 * v + 0.1 * kr + 0.2 * c10;

        await _databaseService.updateClienteFinalScore(cliente.id, puntuacion);
      }

      return SyncResult.success(
        'Puntuaciones de ${clientes.length} clientes actualizadas exitosamente.',
        clientes.length,
      );
    } catch (e) {
      return SyncResult.error('Error al puntuar clientes: ${e.toString()}');
    }
  }
}
