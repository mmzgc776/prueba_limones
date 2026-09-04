import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../data/database.dart';
import '../data/delivery_state.dart';
import '../pages/section_delivery/delivery_record.dart';
import 'database_service.dart';
import 'user_session_service.dart';

class DeliveryService {
  final DatabaseService _dbService = DatabaseService();

  Future<void> init() async {
    await _dbService.init();
  }

  // Load clients for delivery, filtered by per-client interval heuristic
  Future<List<Cliente>> loadClientes({int? excludeDeliveryNumber}) async {
    try {
      await init();

      // Paso 1: Pool candidato — top 120 por puntuación
      final topClientesRaw = await _dbService.getTop30ClientesByPuntuacion();
      // Cambio B: Filtrar clientes con insuficiente historial (< 3 ventas)
      final topClientes = topClientesRaw.where((c) => c.eventos >= 3).toList();
      final candidateIds = topClientes.map((c) => c.id).toList();

      // Paso 2: Última fecha de venta real por cliente (tiempo de ejecución)
      final lastSaleDates = await _dbService.getLastSaleDatePerClient(
        candidateIds,
      );

      // Paso 3: Exclusión por intervalo propio del cliente
      // Se excluye si compró hace menos de (intervaloPromedio × umbral) días.
      // Fallback de 7 días para clientes sin intervaloPromedio definido.
      const double umbral = 0.8;
      const double fallbackDias = 7.0;
      final now = DateTime.now();

      final intervalExcluidos = topClientes
          .where((cliente) {
            final ultimaVenta = lastSaleDates[cliente.id];
            if (ultimaVenta == null) return false; // sin ventas → no excluir
            final diasDesde = now.difference(ultimaVenta).inDays;
            final intervalo =
                (cliente.intervaloPromedio != null &&
                    cliente.intervaloPromedio! > 0)
                ? cliente.intervaloPromedio!
                : fallbackDias;
            return diasDesde < (intervalo * umbral);
          })
          .map((c) => c.id)
          .toSet();

      // Paso 4: Exclusiones del reparto activo (ventas y rechazos de hoy)
      final Set<int> deliveryExcluidos = {};
      if (excludeDeliveryNumber != null) {
        final deliverySales = await _dbService.getSalesByDeliveryNumber(
          excludeDeliveryNumber,
        );
        deliveryExcluidos.addAll(deliverySales.map((s) => s.clientId));

        final rechazados =
            await _dbService.getRejectedClientIdsByDeliveryNumber(
          excludeDeliveryNumber,
        );
        deliveryExcluidos.addAll(rechazados);
      }

      // Paso 5: Filtrar y devolver
      final todosExcluidos = {...intervalExcluidos, ...deliveryExcluidos};
      final result = topClientes
          .where((c) => !todosExcluidos.contains(c.id))
          .toList();

      // Estrategia B: re-ordenar por scores frescos calculados en tiempo real
      _sortByFreshScore(result, lastSaleDates);
      // Cambio D: Limitar lista generada a 60 clientes
      if (result.length > 60) {
        result.removeRange(60, result.length);
      }
      return result;
    } catch (e) {
      debugPrint('Error loading clientes from database: $e');
      throw Exception('Error al cargar los clientes');
    }
  }

  /// Estrategia B: re-ordena los clientes usando cicloScore y weekdayScore
  /// calculados en tiempo real, sin escrituras a BD.
  void _sortByFreshScore(
    List<Cliente> clientes,
    Map<int, DateTime> lastSaleDates,
  ) {
    final now = DateTime.now();
    final todayWeekday = now.weekday - 1; // 0-6

    final scores = <int, double>{};
    for (final c in clientes) {
      // cicloScore fresco
      double freshCiclo = 0.0;
      final lastSale = lastSaleDates[c.id];
      final intervalo = c.intervaloPromedio ?? 0.0;
      if (intervalo > 0 && lastSale != null) {
        final diasDesde = now.difference(lastSale).inDays.toDouble();
        final deviation = (diasDesde - intervalo).abs() / intervalo;
        freshCiclo = (1.0 - deviation).clamp(0.0, 1.0);
      }

      // weekdayScore fresco
      double freshWeekday = 0.0;
      final preferredDay = c.diaSemanaPreferido ?? 0;
      if (c.frecuenciasDiaSemana != null &&
          c.frecuenciasDiaSemana!.isNotEmpty) {
        try {
          final freqs =
              json.decode(c.frecuenciasDiaSemana!) as Map<String, dynamic>;
          final count =
              (freqs[preferredDay.toString()] as num?)?.toInt() ?? 0;
          if (count >= 2) {
            final diff = (todayWeekday - preferredDay).abs();
            if (diff == 0) {
              freshWeekday = 1.0;
            } else if (diff == 1) {
              freshWeekday = 0.7;
            } else if (diff == 2) {
              freshWeekday = 0.4;
            }
          }
        } catch (_) {}
      }

      // Puntuación aproximada fresca:
      // Extrae el base score eliminando el weekday boost almacenado,
      // reemplaza el cicloScore almacenado por el fresco y aplica boost fresco.
      // Cambio A: peso de cicloScore reducido de 0.15 a 0.08
      final storedWeekdayBoost = 1.0 + ((c.weekdayScore ?? 0.0) * 0.15);
      final freshWeekdayBoost = 1.0 + (freshWeekday * 0.15);
      final baseWithoutCiclo =
          (c.puntuacion / (storedWeekdayBoost > 0 ? storedWeekdayBoost : 1.0)) -
          0.08 * (c.cicloScore ?? 0.0);

      // Cambio C: Penalización por silencio prolongado (> 120 días)
      double silenceFactor = 1.0;
      final lastSaleSilence = lastSaleDates[c.id];
      if (lastSaleSilence != null) {
        final diasDesde = now.difference(lastSaleSilence).inDays;
        const double maxSilenceDays = 120.0;
        if (diasDesde > maxSilenceDays) {
          silenceFactor =
              (1.0 - ((diasDesde - maxSilenceDays) / maxSilenceDays))
                  .clamp(0.0, 1.0);
        }
      }

      scores[c.id] =
          (baseWithoutCiclo + 0.08 * freshCiclo) * freshWeekdayBoost *
          silenceFactor;
    }

    clientes.sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));
  }

  // Get a specific delivery by number
  Future<Delivery?> getDeliveryByNumber(int deliveryNumber) async {
    try {
      await init();
      return await _dbService.getDeliveryByNumber(deliveryNumber);
    } catch (e) {
      // Drift can throw a FormatException when a column contains
      // an unexpected string (e.g. a timestamp in a numeric column).
      // In that case try to read the raw row and coerce values safely.
      if (e is FormatException) {
        debugPrint(
          'FormatException reading delivery #$deliveryNumber: $e. Attempting raw fallback.',
        );
        try {
          final raw = await _dbService.getDeliveryRawByNumber(deliveryNumber);
          if (raw == null) return null;

          final dn =
              int.tryParse(raw['delivery_number']?.toString() ?? '') ??
              deliveryNumber;
          final date =
              DateTime.tryParse(raw['date']?.toString() ?? '') ??
              DateTime.now();
          final durationSeconds =
              int.tryParse(raw['duration_seconds']?.toString() ?? '') ?? 0;
          final avgPrice =
              double.tryParse(raw['avg_price']?.toString() ?? '') ?? 0.0;
          final kilograms =
              double.tryParse(raw['kilograms']?.toString() ?? '') ?? 0.0;
          final boxes = int.tryParse(raw['boxes']?.toString() ?? '') ?? 0;
          final remaining =
              double.tryParse(raw['remaining']?.toString() ?? '') ?? 0.0;
          final sellerId = int.tryParse(raw['seller_id']?.toString() ?? '') ?? 1;
          final total = double.tryParse(raw['total']?.toString() ?? '') ?? 0.0;

          return Delivery(
            deliveryNumber: dn,
            date: date,
            durationSeconds: durationSeconds,
            avgPrice: avgPrice,
            kilograms: kilograms,
            boxes: boxes,
            remaining: remaining,
            sellerId: sellerId,
            total: total,
          );
        } catch (e2) {
          debugPrint('Raw fallback failed for delivery #$deliveryNumber: $e2');
          return null;
        }
      }

      debugPrint('Error getting delivery #$deliveryNumber: $e');
      return null;
    }
  }

  // Load delivery records from the database
  Future<List<DeliveryRecord>> loadDeliveryRecords() async {
    try {
      await init();
      final deliveries = await _dbService.getAllDeliveries();
      final deliveryRecords = deliveries
          .map(
            (delivery) => DeliveryRecord(
              deliveryNumber: delivery.deliveryNumber,
              date: delivery.date,
              duration: Duration(seconds: delivery.durationSeconds),
              avgPrice: delivery.avgPrice,
              kilograms: delivery.kilograms,
              boxes: delivery.boxes,
              remaining: delivery.remaining,
              sellerId: delivery.sellerId,
              total: delivery.total,
            ),
          )
          .toList();

      // Sort in descending order (most recent first)
      deliveryRecords.sort(
        (a, b) => b.deliveryNumber.compareTo(a.deliveryNumber),
      );

      return deliveryRecords;
    } catch (e) {
      debugPrint('Error loading deliveries from database: $e');
      throw Exception('Error al cargar los registros de reparto');
    }
  }

  // Save a delivery record to the database (insert or update if exists)
  Future<void> saveDeliveryToDatabase(DeliveryRecord record) async {
    try {
      await init();

      // Verificar si el delivery ya existe
      final existingDelivery = await _dbService.getDeliveryByNumber(
        record.deliveryNumber,
      );

      if (existingDelivery != null) {
        // Si existe, actualizar
        debugPrint('Actualizando delivery existente #${record.deliveryNumber}');
        await _dbService.updateDelivery(
          deliveryNumber: record.deliveryNumber,
          date: record.date,
          durationSeconds: record.duration.inSeconds,
          avgPrice: record.avgPrice,
          kilograms: record.kilograms,
          boxes: record.boxes,
          remaining: record.remaining,
          sellerId: UserSessionService().currentSellerId,
          total: record.total,
        );
      } else {
        // Si no existe, insertar
        debugPrint('Insertando nuevo delivery #${record.deliveryNumber}');
        await _dbService.insertDelivery(
          deliveryNumber: record.deliveryNumber,
          date: record.date,
          durationSeconds: record.duration.inSeconds,
          avgPrice: record.avgPrice,
          kilograms: record.kilograms,
          boxes: record.boxes,
          remaining: record.remaining,
          sellerId: UserSessionService().currentSellerId,
          total: record.total,
        );
      }
    } catch (e) {
      debugPrint('Error saving delivery to database: $e');
      throw Exception('Error al guardar el reparto en la base de datos');
    }
  }

  // Save interaction results to the database
  Future<void> saveInteraccionesToDatabase(
    int deliveryId,
    List<Cliente> clientes,
    List<bool> contactados,
    List<String> estados,
  ) async {
    try {
      await init();
      debugPrint(
        'Guardando resultados de interacciones para deliveryId: $deliveryId',
      );
      int savedCount = 0;
      for (int i = 0; i < clientes.length; i++) {
        // debugPrint(
        //   'Verificando cliente $i: Contactado: ${contactados[i]}, Estado: "${estados[i]}"',
        // );
        if (contactados[i] && estados[i].isNotEmpty) {
          debugPrint(
            'Guardando interacción: Cliente ID ${clientes[i].id}, Resultado: ${estados[i]}',
          );
          await _dbService.insertInteraccion(
            clientId: clientes[i].id,
            result: estados[i],
            deliveryId: deliveryId,
          );
          savedCount++;
        }
      }
      debugPrint('Total de interacciones guardadas: $savedCount');
    } catch (e) {
      debugPrint('Error saving interaction results to database: $e');
      throw Exception('Error al guardar los resultados de interacción');
    }
  }

  // Delete all delivery records from the database
  Future<void> deleteDeliveryRecords() async {
    try {
      await init();
      await _dbService.deleteAllDeliveries();
    } catch (e) {
      debugPrint('Error deleting deliveries from database: $e');
      throw Exception('Error al eliminar los registros de reparto');
    }
  }

  // Debug interaction records (fetch last 10)
  Future<List<Interaccione>> debugInteracciones() async {
    try {
      await init();
      return await _dbService.getLast10Interacciones();
    } catch (e) {
      debugPrint('Error fetching interaction records: $e');
      throw Exception('Error al obtener los registros de interacciones');
    }
  }

  /// Inserta una interacción individualmente (usa DatabaseService)
  Future<void> insertInteraccionImmediate({
    required int deliveryId,
    required int clientId,
    required String result,
    DateTime? timestamp,
  }) async {
    try {
      await init();
      await _dbService.insertInteraccion(
        clientId: clientId,
        result: result,
        deliveryId: deliveryId,
        timestamp: timestamp ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error inserting interaccion immediate: $e');
      throw Exception('Error al insertar interacción');
    }
  }

  // Get sales by delivery number
  Future<List<Sale>> getSalesByDeliveryNumber(int deliveryNumber) async {
    try {
      await init();
      return await _dbService.getSalesByDeliveryNumber(deliveryNumber);
    } catch (e) {
      debugPrint('Error fetching sales by delivery number: $e');
      throw Exception('Error al obtener las ventas del reparto');
    }
  }

  // Get current location with permission handling
  Future<Position> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permiso de localización denegado');
          throw Exception('Permiso de localización denegado');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permiso de localización denegado permanentemente');
        throw Exception('Permiso de localización denegado permanentemente');
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint(
        'Localización obtenida: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      debugPrint('Error al obtener la localización: $e');
      throw Exception('Error al obtener la localización');
    }
  }

  /// Guarda el estado persistente del delivery
  Future<void> savePersistentDeliveryState(
    DeliveryPersistentState state,
  ) async {
    try {
      await init();
      final stateMap = state.toMap();
      stateMap['id'] = UserSessionService().persistentStateId;
      await _dbService.savePersistentDeliveryState(stateMap);
      debugPrint(
        'Estado persistente guardado: ${state.isActive ? 'Activo' : 'Inactivo'}',
      );
    } catch (e) {
      debugPrint('Error saving persistent delivery state: $e');
      throw Exception('Error al guardar el estado persistente del delivery');
    }
  }

  /// Carga el estado persistente del delivery
  Future<DeliveryPersistentState?> loadPersistentDeliveryState() async {
    try {
      await init();
      final stateMap = await _dbService.loadPersistentDeliveryState();
      if (stateMap != null) {
        return DeliveryPersistentState.fromMap(stateMap);
      }
      return null;
    } catch (e) {
      debugPrint('Error loading persistent delivery state: $e');
      return null;
    }
  }

  /// Elimina el estado persistente del delivery
  Future<void> clearPersistentDeliveryState() async {
    try {
      await init();
      await _dbService.clearPersistentDeliveryState();
      debugPrint('Estado persistente eliminado');
    } catch (e) {
      debugPrint('Error clearing persistent delivery state: $e');
      throw Exception('Error al eliminar el estado persistente del delivery');
    }
  }
}