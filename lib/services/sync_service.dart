import 'dart:convert';

import 'package:flutter/material.dart';
import '../data/database.dart';
import '../services/database_service.dart';

/// Tipos de sincronización disponibles
enum SyncType { deliveries, sales, clients, notas, interacciones, expenses, database, rateClients }

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

        case SyncType.notas:
          await _databaseService.deleteAllNotas();
          return SyncResult.success('Notas eliminadas exitosamente');

        case SyncType.interacciones:
          await _databaseService.deleteAllInteracciones();
          return SyncResult.success('Interacciones eliminadas exitosamente');

        case SyncType.expenses:
          return SyncResult.error('Eliminación de gastos no implementada');

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

          // ===== NUEVO: Análisis de Ciclo de Compra =====
          double intervaloPromedio = 0.0;
          int diasDesdeUltimaVenta = 0;
          double cicloScore = 0.0;

          if (ventasCliente.length >= 2) {
            // Ordenar ventas por fecha
            final salesDates = ventasCliente.map((v) => v.date).toList()..sort();

            // IMPORTANTE: Solo usar las últimas 10 ventas para calcular intervalo
            // Esto hace que el sistema se adapte a cambios recientes en comportamiento
            final recentSales = salesDates.length > 10
                ? salesDates.sublist(salesDates.length - 10)
                : salesDates;

            // Calcular intervalos entre compras consecutivas
            List<int> intervals = [];
            for (int i = 1; i < recentSales.length; i++) {
              int daysBetween = recentSales[i].difference(recentSales[i - 1]).inDays;
              if (daysBetween > 0) intervals.add(daysBetween);
            }

            // Intervalo promedio (excluye gaps ≥ 3× el promedio bruto)
            if (intervals.isNotEmpty) {
              intervaloPromedio = _calcIntervaloPromedio(
                intervals.map((i) => i.toDouble()).toList(),
              );
            }

            // Días desde última venta (usar todas las ventas para esto)
            final now = DateTime.now();
            final lastSaleDate = salesDates.last;
            diasDesdeUltimaVenta = now.difference(lastSaleDate).inDays;

            // Score de ciclo: qué tan cerca estamos del intervalo esperado
            // Si el cliente compra cada 14 días y han pasado ~14 días: score alto
            // Si han pasado 5 o 25 días: score bajo
            if (intervaloPromedio > 0) {
              final deviation = (diasDesdeUltimaVenta - intervaloPromedio).abs() / intervaloPromedio;
              cicloScore = (1.0 - deviation).clamp(0.0, 1.0);
            }
          }

          // ===== NUEVO: Análisis de Patrón Semanal =====
          int diaSemanaPreferido = 0;
          String frecuenciasDiaSemana = '{}';
          double weekdayScore = 0.0;

          if (ventasCliente.isNotEmpty) {
            // Contar compras por día de semana (0=Lunes, 6=Domingo)
            final weekdayCounts = <int, int>{};
            for (var venta in ventasCliente) {
              // DateTime.weekday es 1-7 (1=Lunes), convertir a 0-6
              final weekday = venta.date.weekday - 1;
              weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
            }

            // Encontrar día más común
            int maxCount = 0;
            weekdayCounts.forEach((weekday, count) {
              if (count > maxCount) {
                maxCount = count;
                diaSemanaPreferido = weekday;
              }
            });

            // Guardar como JSON para sync con Google Sheets
            // Convertir claves int a String para asegurar JSON válido
            final weekdayCountsStr = weekdayCounts.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            frecuenciasDiaSemana = json.encode(weekdayCountsStr);

            // Calcular score basado en qué día es hoy
            // Solo aplicar si hay patrón claro (al menos 2 compras en ese día)
            if (maxCount >= 2) {
              final today = DateTime.now().weekday - 1; // 0-6
              final daysDiff = (today - diaSemanaPreferido).abs();

              // Score decreciente LINEAL según distancia al día preferido
              if (daysDiff == 0) {
                weekdayScore = 1.0;  // Hoy es el día preferido
              } else if (daysDiff == 1) {
                weekdayScore = 0.7;  // 1 día de diferencia
              } else if (daysDiff == 2) {
                weekdayScore = 0.4;  // 2 días de diferencia
              }
              // 3+ días = 0.0 (sin boost)
            }
          }

          // Guardar métricas de ciclo
          await _databaseService.updateClienteCicloMetrics(
            clientId: cliente.id,
            intervaloPromedio: intervaloPromedio,
            diasDesdeUltimaVenta: diasDesdeUltimaVenta,
            cicloScore: cicloScore,
          );

          // Guardar métricas de día de semana
          await _databaseService.updateClienteWeekdayMetrics(
            clientId: cliente.id,
            diaSemanaPreferido: diaSemanaPreferido,
            frecuenciasDiaSemana: frecuenciasDiaSemana,
            weekdayScore: weekdayScore,
          );
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
      final maxCicloScore = await _databaseService.getMaxCicloScore() ?? 1.0;

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
        final cs = (cliente.cicloScore ?? 0.0) / (maxCicloScore > 0 ? maxCicloScore : 1);

        // ===== FÓRMULA ACTUALIZADA =====
        // Pesos ajustados para incluir ciclo de compra:
        // - Consistencia: 30% (reducido de 35%)
        // - Volumen: 30% (reducido de 35%)
        // - Frecuencia: 10% (sin cambio)
        // - Recencia: 15% (reducido de 20%)
        // - Ciclo: 15% (nuevo)
        final baseScore = 0.30 * co + 0.30 * v + 0.10 * kr + 0.15 * c10 + 0.15 * cs;

        // Aplicar boost multiplicativo por día de semana
        // Boost máximo: 15% (multiplicador 1.15)
        // weekdayScore ya está en rango [0-1], usar 0.0 si es null
        final weekdayBoost = 1.0 + ((cliente.weekdayScore ?? 0.0) * 0.15);
        final puntuacion = baseScore * weekdayBoost;

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

  /// Recalcula y persiste la puntuación de un único cliente.
  /// Diseñado para llamarse de forma unawaited tras registrar una venta.
  Future<void> refreshSingleClientScore(int clientId) async {
    try {
      await _databaseService.init();

      final cliente = await _databaseService.getClienteById(clientId);
      if (cliente == null) return;

      final ventasCliente =
          await _databaseService.getVentasByClientId(clientId);
      final numeroVentas = ventasCliente.length;

      if (ventasCliente.isNotEmpty) {
        final double kgTotales = ventasCliente.fold(
          0.0,
          (sum, v) => sum + v.quantity,
        );
        await _databaseService.updateClienteKgTotal(clientId, kgTotales);

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

        final allDeliveries = await _databaseService.getAllDeliveries();
        final latestDeliveries = (allDeliveries
              ..sort((a, b) => b.date.compareTo(a.date)))
            .take(10)
            .map((d) => d.deliveryNumber)
            .toSet();
        final highestDeliveryNumber = allDeliveries.isEmpty
            ? 1
            : allDeliveries
                .map((d) => d.deliveryNumber)
                .reduce((a, b) => a > b ? a : b);

        final ventasEnUltimos10 = ventasCliente
            .where(
              (v) =>
                  v.deliveryNumber != null &&
                  latestDeliveries.contains(v.deliveryNumber),
            )
            .length
            .toDouble();
        final double ultimas10 = ventasEnUltimos10 / 10.0;

        final double ventasVuelta = highestDeliveryNumber > 0
            ? numeroVentas.toDouble() / highestDeliveryNumber
            : 0.0;

        final double kgEvento = kgTotales / numeroVentas;

        await _databaseService.updateClientePuntuacion(
          clientId: clientId,
          moda: moda,
          maximo: maximo,
          ventasVuelta: ventasVuelta,
          ultimas10: ultimas10,
          kgEvento: kgEvento,
        );

        // kgSemana
        final salesDatesAll = ventasCliente.map((v) => v.date).toList()..sort();
        if (salesDatesAll.length >= 2) {
          final weeksSinceFirst =
              DateTime.now().difference(salesDatesAll.first).inDays / 7.0;
          if (weeksSinceFirst > 0) {
            await _databaseService.updateClienteKgSemana(
              clientId,
              kgTotales / weeksSinceFirst,
            );
          }
        }

        // ── Ciclo de compra ────────────────────────────────────────────────
        double intervaloPromedio = 0.0;
        int diasDesdeUltimaVenta = 0;
        double cicloScore = 0.0;

        if (ventasCliente.length >= 2) {
          final salesDatesAll =
              ventasCliente.map((v) => v.date).toList()..sort();
          final recentDates = salesDatesAll.length > 10
              ? salesDatesAll.sublist(salesDatesAll.length - 10)
              : salesDatesAll;
          final intervals = <double>[];
          for (int i = 1; i < recentDates.length; i++) {
            intervals.add(
              recentDates[i].difference(recentDates[i - 1]).inDays.toDouble(),
            );
          }
          if (intervals.isNotEmpty) {
            intervaloPromedio = _calcIntervaloPromedio(intervals);
          }
          final salesAll = ventasCliente.map((v) => v.date).toList()..sort();
          diasDesdeUltimaVenta =
              DateTime.now().difference(salesAll.last).inDays;
          if (intervaloPromedio > 0) {
            final deviation =
                (diasDesdeUltimaVenta - intervaloPromedio).abs() /
                intervaloPromedio;
            cicloScore = (1.0 - deviation).clamp(0.0, 1.0);
          }
        }
        await _databaseService.updateClienteCicloMetrics(
          clientId: clientId,
          intervaloPromedio: intervaloPromedio,
          diasDesdeUltimaVenta: diasDesdeUltimaVenta,
          cicloScore: cicloScore,
        );

        // ── Patrón semanal ────────────────────────────────────────────────
        int diaSemanaPreferido = 0;
        String frecuenciasDiaSemana = '{}';
        double weekdayScore = 0.0;

        final weekdayCounts = <int, int>{};
        for (var v in ventasCliente) {
          final wd = v.date.weekday - 1;
          weekdayCounts[wd] = (weekdayCounts[wd] ?? 0) + 1;
        }
        int maxCount = 0;
        weekdayCounts.forEach((wd, count) {
          if (count > maxCount) {
            maxCount = count;
            diaSemanaPreferido = wd;
          }
        });
        final weekdayCountsStr = weekdayCounts.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        frecuenciasDiaSemana = json.encode(weekdayCountsStr);
        if (maxCount >= 2) {
          final today = DateTime.now().weekday - 1;
          final diff = (today - diaSemanaPreferido).abs();
          if (diff == 0) {
            weekdayScore = 1.0;
          } else if (diff == 1) {
            weekdayScore = 0.7;
          } else if (diff == 2) {
            weekdayScore = 0.4;
          }
        }
        await _databaseService.updateClienteWeekdayMetrics(
          clientId: clientId,
          diaSemanaPreferido: diaSemanaPreferido,
          frecuenciasDiaSemana: frecuenciasDiaSemana,
          weekdayScore: weekdayScore,
        );
      }

      await _databaseService.updateClienteEventos(clientId, numeroVentas);

      // ── Puntuación final (normalizada contra el resto de la BD) ──────────
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
      final maxCicloScore = await _databaseService.getMaxCicloScore() ?? 1.0;

      // Recargar cliente con métricas actualizadas
      final updated = await _databaseService.getClienteById(clientId);
      if (updated == null) return;

      final co =
          0.4 * (updated.eventos / (maxEventos > 0 ? maxEventos : 1)) +
          0.4 * (updated.moda / (maxModa > 0 ? maxModa : 1)) +
          0.2 * (updated.kgEvento / (maxKgEvento > 0 ? maxKgEvento : 1));

      final v =
          0.4 * (updated.kgTotal / (maxKgTotal > 0 ? maxKgTotal : 1)) +
          0.4 * (updated.maximo / (maxMaximo > 0 ? maxMaximo : 1)) +
          0.2 * (updated.kgSemana / (maxKgSemana > 0 ? maxKgSemana : 1));

      final kr =
          updated.ventasVuelta / (maxVentasVuelta > 0 ? maxVentasVuelta : 1);
      final c10 =
          updated.ultimas10 / (maxUltimas10 > 0 ? maxUltimas10 : 1);
      final cs =
          (updated.cicloScore ?? 0.0) /
          (maxCicloScore > 0 ? maxCicloScore : 1);

      final baseScore =
          0.30 * co + 0.30 * v + 0.10 * kr + 0.15 * c10 + 0.15 * cs;
      final weekdayBoost = 1.0 + ((updated.weekdayScore ?? 0.0) * 0.15);
      final puntuacion = baseScore * weekdayBoost;

      await _databaseService.updateClienteFinalScore(clientId, puntuacion);
    } catch (e) {
      debugPrint('refreshSingleClientScore error for client $clientId: $e');
    }
  }

  /// Calcula el intervalo promedio descartando gaps atípicos (pausas estacionales).
  /// Usa la mediana como umbral base (inmune a outliers) para evitar que un gap
  /// grande infle el propio umbral que debería filtrarlo.
  /// Un intervalo se descarta si supera 3× la mediana del lote.
  static double _calcIntervaloPromedio(List<double> intervals) {
    if (intervals.isEmpty) return 0.0;
    final sorted = [...intervals]..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2.0;
    final clean = intervals.where((i) => i <= median * 3.0).toList();
    if (clean.isEmpty) return median;
    return clean.reduce((a, b) => a + b) / clean.length;
  }
}
