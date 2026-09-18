import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../data/database.dart';
import '../data/delivery_state.dart';
import '../pages/section_delivery/delivery_record.dart';
import 'database_service.dart';
import 'client_recommendation_service.dart';
import 'user_session_service.dart';

class DeliveryService {
  final DatabaseService _dbService;
  final DateTime Function() _clock;

  DeliveryService({DatabaseService? databaseService, DateTime Function()? clock})
      : _dbService = databaseService ?? DatabaseService(),
        _clock = clock ?? DateTime.now;

  Future<void> init() async {
    await _dbService.init();
  }

  static const int targetSize = ClientRecommendationService.targetSize;

  /// Evalúa todo el catálogo desde ventas reales, sin depender del score guardado.
  Future<({List<Cliente> clientes, List<bool> esRelleno,
      List<String> motivos})> loadClientes({int? excludeDeliveryNumber}) async {
    await init();
    final sellerId = UserSessionService().currentSellerId;
    final snapshot = await _dbService.getRecommendationSnapshot(sellerId);
    final recommendations = ClientRecommendationService.select(
      clientes: snapshot.clientes, sales: snapshot.sales,
      deliveries: snapshot.deliveries, interactions: snapshot.interactions,
      now: _clock(), sellerId: sellerId,
      excludeDeliveryNumber: excludeDeliveryNumber,
    );
    return (
      clientes: recommendations.map((r) => r.cliente).toList(),
      // Compatibilidad con consumidores anteriores; ya no existe relleno ciego.
      esRelleno: recommendations.map((r) =>
        r.metrics.initialFollowUp || r.metrics.reactivation).toList(),
      motivos: recommendations.map((r) => r.reason).toList(),
    );
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