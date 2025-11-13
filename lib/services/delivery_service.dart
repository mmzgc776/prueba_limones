import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../data/database.dart';
import '../pages/section_delivery/delivery_record.dart';
import 'database_service.dart';

class DeliveryService {
  final DatabaseService _dbService = DatabaseService();

  Future<void> init() async {
    await _dbService.init();
  }

  // Load clients for delivery, filtered by heuristic and excluding recent sales
  Future<List<Cliente>> loadClientes({int? excludeDeliveryNumber}) async {
    try {
      await init();
      // Obtener los IDs de los clientes de las últimas 10 ventas
      final lastSalesClientIds = await _dbService.getLast10SalesClientIds();

      // Si se especifica un deliveryNumber, obtener también los clientes de ese reparto
      List<int> excludedClientIds = List.from(lastSalesClientIds);
      if (excludeDeliveryNumber != null) {
        final deliverySales = await _dbService.getSalesByDeliveryNumber(
          excludeDeliveryNumber,
        );
        final deliveryClientIds = deliverySales
            .map((sale) => sale.clientId)
            .toList();
        excludedClientIds.addAll(deliveryClientIds);
      }

      // Obtener los 30 clientes con mayor puntuación
      final topClientes = await _dbService.getTop30ClientesByPuntuacion();
      // Filtrar los clientes, excluyendo aquellos en las últimas ventas y del reparto especificado
      final filteredClientes = topClientes
          .where((cliente) => !excludedClientIds.contains(cliente.id))
          .toList();
      return filteredClientes;
    } catch (e) {
      debugPrint('Error loading clientes from database: $e');
      throw Exception('Error al cargar los clientes');
    }
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
          final seller = raw['seller']?.toString() ?? '';
          final total = double.tryParse(raw['total']?.toString() ?? '') ?? 0.0;

          return Delivery(
            deliveryNumber: dn,
            date: date,
            durationSeconds: durationSeconds,
            avgPrice: avgPrice,
            kilograms: kilograms,
            boxes: boxes,
            remaining: remaining,
            seller: seller,
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
              seller: delivery.seller,
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
          seller: record.seller,
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
          seller: record.seller,
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
}
