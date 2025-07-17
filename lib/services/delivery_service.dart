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

  // Load all clients from the database
  Future<List<Cliente>> loadClientes() async {
    try {
      await init();
      return await _dbService.getAllClientes();
    } catch (e) {
      debugPrint('Error loading clientes from database: $e');
      throw Exception('Error al cargar los clientes');
    }
  }

  // Load delivery records from the database
  Future<List<DeliveryRecord>> loadDeliveryRecords() async {
    try {
      await init();
      final deliveries = await _dbService.getAllDeliveries();
      return deliveries
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
    } catch (e) {
      debugPrint('Error loading deliveries from database: $e');
      throw Exception('Error al cargar los registros de reparto');
    }
  }

  // Save a delivery record to the database
  Future<void> saveDeliveryToDatabase(DeliveryRecord record) async {
    try {
      await init();
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
    } catch (e) {
      debugPrint('Error saving delivery to database: $e');
      throw Exception('Error al guardar el reparto en la base de datos');
    }
  }

  // Save contact results to the database
  Future<void> saveContactResultsToDatabase(
    int deliveryId,
    List<Cliente> clientes,
    List<bool> contactados,
    List<String> estados,
  ) async {
    try {
      await init();
      debugPrint(
        'Guardando resultados de contacto para deliveryId: $deliveryId',
      );
      int savedCount = 0;
      for (int i = 0; i < clientes.length; i++) {
        // debugPrint(
        //   'Verificando cliente $i: Contactado: ${contactados[i]}, Estado: "${estados[i]}"',
        // );
        if (contactados[i] && estados[i].isNotEmpty) {
          debugPrint(
            'Guardando contacto: Cliente ID ${clientes[i].id}, Resultado: ${estados[i]}',
          );
          await _dbService.insertContacto(
            clientId: clientes[i].id,
            result: estados[i],
            deliveryId: deliveryId,
          );
          savedCount++;
        }
      }
      debugPrint('Total de contactos guardados: $savedCount');
    } catch (e) {
      debugPrint('Error saving contact results to database: $e');
      throw Exception('Error al guardar los resultados de contacto');
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

  // Debug contact records (fetch last 10)
  Future<List<Contacto>> debugContactos() async {
    try {
      await init();
      return await _dbService.getLast10Contactos();
    } catch (e) {
      debugPrint('Error fetching contact records: $e');
      throw Exception('Error al obtener los registros de contactos');
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
