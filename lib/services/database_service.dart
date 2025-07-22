import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/database.dart';
import 'google_sheets_service.dart';
import '../pages/logs_page.dart';

/// Servicio principal para operaciones de base de datos
/// Maneja todas las operaciones CRUD y sincronización con Google Sheets
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static AppDatabase? _db;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  /// Inicializa la base de datos
  Future<void> init() async {
    if (!_isInitialized) {
      _initializationFuture ??= _initializeDatabase();
      await _initializationFuture;
    }
  }

  /// Inicializa la conexión con la base de datos
  Future<void> _initializeDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'app.sqlite'));
    _db = AppDatabase(NativeDatabase(dbFile));
    _isInitialized = true;
  }

  /// Verifica si la base de datos está inicializada
  void _ensureInitialized() {
    if (!_isInitialized || _db == null) {
      throw Exception('Database not initialized');
    }
  }

  // ===== OPERACIONES DE VENTAS =====

  /// Inserta una nueva venta
  Future<int> insertSale({
    int? id,
    required DateTime date,
    required int clientId,
    required double quantity,
    required double price,
    required double total,
    int? notesId,
    int? deliveryNumber,
  }) async {
    _ensureInitialized();
    return await _db!.insertSale(
      id: id,
      date: date,
      clientId: clientId,
      quantity: quantity,
      price: price,
      total: total,
      notesId: notesId,
      deliveryNumber: deliveryNumber,
    );
  }

  /// Obtiene todas las ventas
  Future<List<Sale>> getAllSales() async {
    _ensureInitialized();
    return await _db!.select(_db!.sales).get();
  }

  /// Obtiene ventas sin asignar a un delivery
  Future<List<Sale>> getUnassignedSales() async {
    _ensureInitialized();
    return await (_db!.select(
      _db!.sales,
    )..where((tbl) => tbl.deliveryNumber.isNull())).get();
  }

  /// Obtiene ventas por número de delivery
  Future<List<Sale>> getSalesByDeliveryNumber(int deliveryNumber) async {
    _ensureInitialized();
    return await (_db!.select(
      _db!.sales,
    )..where((tbl) => tbl.deliveryNumber.equals(deliveryNumber))).get();
  }

  /// Obtiene ventas por ID de cliente
  Future<List<Sale>> getVentasByClientId(int clientId) async {
    _ensureInitialized();
    return await (_db!.select(
      _db!.sales,
    )..where((tbl) => tbl.clientId.equals(clientId))).get();
  }

  /// Actualiza una venta existente
  Future<int> updateSale({
    required int id,
    required double quantity,
    required double price,
    required double total,
    required DateTime date,
  }) async {
    _ensureInitialized();

    final sale = await (_db!.select(
      _db!.sales,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

    final result =
        await (_db!.update(
          _db!.sales,
        )..where((tbl) => tbl.id.equals(id))).write(
          SalesCompanion(
            quantity: Value(quantity),
            price: Value(price),
            total: Value(total),
            date: Value(date),
          ),
        );

    if (sale != null && sale.deliveryNumber != null) {
      await recalculateDeliveryStats(sale.deliveryNumber!);
    }

    return result;
  }

  /// Elimina una venta específica
  Future<void> deleteSale(int id) async {
    _ensureInitialized();

    final sale = await (_db!.select(
      _db!.sales,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    await (_db!.delete(_db!.sales)..where((tbl) => tbl.id.equals(id))).go();

    if (sale != null && sale.deliveryNumber != null) {
      await recalculateDeliveryStats(sale.deliveryNumber!);
    }
  }

  /// Elimina todas las ventas
  Future<void> deleteAllSales() async {
    _ensureInitialized();
    await _db!.delete(_db!.sales).go();
  }

  // ===== OPERACIONES DE DELIVERIES =====

  /// Inserta un nuevo registro de delivery
  Future<int> insertDelivery({
    required int deliveryNumber,
    required DateTime date,
    required int durationSeconds,
    required double avgPrice,
    required double kilograms,
    required int boxes,
    required double remaining,
    required String seller,
    required double total,
  }) async {
    _ensureInitialized();
    return await _db!.insertDelivery(
      deliveryNumber: deliveryNumber,
      date: date,
      durationSeconds: durationSeconds,
      avgPrice: avgPrice,
      kilograms: kilograms,
      boxes: boxes,
      remaining: remaining,
      seller: seller,
      total: total,
    );
  }

  /// Obtiene todos los deliveries
  Future<List<Delivery>> getAllDeliveries() async {
    _ensureInitialized();
    return await _db!.select(_db!.deliveries).get();
  }

  /// Obtiene los números de los últimos X deliveries
  Future<List<int>> getLatestDeliveryNumbers(int limit) async {
    _ensureInitialized();
    final query = _db!.select(_db!.deliveries)
      ..orderBy([(d) => OrderingTerm.desc(d.deliveryNumber)])
      ..limit(limit);

    final result = await query.get();
    return result.map((d) => d.deliveryNumber).toList();
  }

  /// Elimina todos los deliveries
  Future<void> deleteAllDeliveries() async {
    _ensureInitialized();
    await _db!.delete(_db!.deliveries).go();
  }

  /// Recalcula las estadísticas de un delivery
  Future<void> recalculateDeliveryStats(int deliveryNumber) async {
    _ensureInitialized();

    final sales = await getSalesByDeliveryNumber(deliveryNumber);

    double totalKilograms = 0.0;
    double totalAmount = 0.0;

    for (var sale in sales) {
      totalKilograms += sale.quantity;
      totalAmount += sale.total;
    }

    final avgPricePerKilo = totalKilograms > 0
        ? totalAmount / totalKilograms
        : 0.0;

    await (_db!.update(
      _db!.deliveries,
    )..where((tbl) => tbl.deliveryNumber.equals(deliveryNumber))).write(
      DeliveriesCompanion(
        kilograms: Value(totalKilograms),
        total: Value(totalAmount),
        avgPrice: Value(avgPricePerKilo),
      ),
    );
  }

  /// Asigna ventas a un delivery específico
  Future<int> assignSalesToDelivery({
    required List<int> saleIds,
    required int deliveryNumber,
  }) async {
    _ensureInitialized();

    int updatedCount = 0;
    for (int saleId in saleIds) {
      updatedCount +=
          await (_db!.update(_db!.sales)..where((tbl) => tbl.id.equals(saleId)))
              .write(SalesCompanion(deliveryNumber: Value(deliveryNumber)));
    }

    await recalculateDeliveryStats(deliveryNumber);
    return updatedCount;
  }

  // ===== OPERACIONES DE CLIENTES =====

  /// Inserta un nuevo cliente
  Future<int> insertCliente({
    int? id,
    required String nombre,
    required String contacto,
    required String tipoNegocio,
    required String ciudad,
    required String domicilio,
    required String ubicacion,
    required String telefono,
    required int consumo,
    required DateTime ultimoContacto,
    required int horaInicio,
    required int horaCierre,
    int? notasId,
    required String dias,
    int eventos = 0,
    double kgTotal = 0.0,
    double moda = 0.0,
    double maximo = 0.0,
    double ultimas10 = 0.0,
    double kgEvento = 0.0,
    double kgSemana = 0.0,
    double ventasVuelta = 0.0,
    double puntuacion = 0.0,
  }) async {
    _ensureInitialized();
    return await _db!.insertCliente(
      id: id,
      nombre: nombre,
      contacto: contacto,
      tipoNegocio: tipoNegocio,
      ciudad: ciudad,
      domicilio: domicilio,
      ubicacion: ubicacion,
      telefono: telefono,
      consumo: consumo,
      ultimoContacto: ultimoContacto,
      horaInicio: horaInicio,
      horaCierre: horaCierre,
      notasId: notasId,
      dias: dias,
      eventos: eventos,
      kgTotal: kgTotal,
      moda: moda,
      maximo: maximo,
      ultimas10: ultimas10,
      kgEvento: kgEvento,
      kgSemana: kgSemana,
      ventasVuelta: ventasVuelta,
      puntuacion: puntuacion,
    );
  }

  /// Actualiza un cliente existente
  Future<int> updateCliente({
    required int id,
    required String nombre,
    required String contacto,
    required String tipoNegocio,
    required String ciudad,
    required String domicilio,
    required String ubicacion,
    required String telefono,
    required int consumo,
    required DateTime ultimoContacto,
    required int horaInicio,
    required int horaCierre,
    required String dias,
  }) async {
    _ensureInitialized();

    return await (_db!.update(
      _db!.clientes,
    )..where((tbl) => tbl.id.equals(id))).write(
      ClientesCompanion(
        nombre: Value(nombre),
        contacto: Value(contacto),
        tipoNegocio: Value(tipoNegocio),
        ciudad: Value(ciudad),
        domicilio: Value(domicilio),
        ubicacion: Value(ubicacion),
        telefono: Value(telefono),
        consumo: Value(consumo),
        ultimoContacto: Value(ultimoContacto),
        horaInicio: Value(horaInicio),
        horaCierre: Value(horaCierre),
        dias: Value(dias),
      ),
    );
  }

  /// Obtiene todos los clientes
  Future<List<Cliente>> getAllClientes() async {
    _ensureInitialized();
    return await _db!.select(_db!.clientes).get();
  }

  /// Obtiene un cliente por ID
  Future<Cliente?> getClienteById(int id) async {
    _ensureInitialized();
    return await (_db!.select(
      _db!.clientes,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Actualiza el campo eventos de un cliente
  Future<void> updateClienteEventos(int clientId, int eventos) async {
    _ensureInitialized();
    await (_db!.update(_db!.clientes)..where((tbl) => tbl.id.equals(clientId)))
        .write(ClientesCompanion(eventos: Value(eventos)));
  }

  /// Actualiza el campo kgTotal de un cliente
  Future<void> updateClienteKgTotal(int clientId, double kgTotal) async {
    _ensureInitialized();
    await (_db!.update(_db!.clientes)..where((tbl) => tbl.id.equals(clientId)))
        .write(ClientesCompanion(kgTotal: Value(kgTotal)));
  }

  /// Actualiza los campos de puntuación de un cliente
  Future<void> updateClientePuntuacion({
    required int clientId,
    required double moda,
    required double maximo,
    required double ventasVuelta,
    required double ultimas10,
    required double kgEvento,
  }) async {
    _ensureInitialized();
    await (_db!.update(
      _db!.clientes,
    )..where((tbl) => tbl.id.equals(clientId))).write(
      ClientesCompanion(
        moda: Value(moda),
        maximo: Value(maximo),
        ventasVuelta: Value(ventasVuelta),
        ultimas10: Value(ultimas10),
        kgEvento: Value(kgEvento),
      ),
    );
  }

  /// Elimina todos los clientes
  Future<void> deleteAllClientes() async {
    _ensureInitialized();
    await _db!.delete(_db!.clientes).go();
  }

  // ===== SINCRONIZACIÓN CON GOOGLE SHEETS =====

  /// Sincroniza repartos con Google Sheets
  Future<void> syncDeliveriesUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    _ensureInitialized();
    final googleSheetsService = GoogleSheetsService();

    try {
      final localDeliveries = await getAllDeliveries();
      final sheetData = await googleSheetsService.getSheetData(
        spreadsheetId,
        range,
      );

      await _syncDeliveriesData(
        localDeliveries,
        sheetData,
        spreadsheetId,
        range,
      );
    } catch (e) {
      throw Exception('Error al sincronizar repartos: $e');
    }
  }

  /// Sincroniza ventas con Google Sheets
  Future<void> syncSalesUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    _ensureInitialized();
    final googleSheetsService = GoogleSheetsService();

    try {
      final localSales = await getAllSales();
      final sheetData = await googleSheetsService.getSheetData(
        spreadsheetId,
        range,
      );

      await _syncSalesData(localSales, sheetData, spreadsheetId, range);
    } catch (e) {
      throw Exception('Error al sincronizar ventas: $e');
    }
  }

  /// Sincroniza clientes con Google Sheets
  Future<void> syncClientesUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    _ensureInitialized();
    final googleSheetsService = GoogleSheetsService();

    try {
      final localClientes = await getAllClientes();
      final sheetData = await googleSheetsService.getSheetData(
        spreadsheetId,
        range,
      );

      await _syncClientesData(localClientes, sheetData, spreadsheetId, range);
    } catch (e) {
      throw Exception('Error al sincronizar clientes: $e');
    }
  }

  /// Método privado para sincronizar datos de repartos
  Future<void> _syncDeliveriesData(
    List<Delivery> localDeliveries,
    List<List<Object?>> sheetData,
    String spreadsheetId,
    String range,
  ) async {
    final googleSheetsService = GoogleSheetsService();

    if (localDeliveries.isEmpty && sheetData.length > 1) {
      // PULL: La base de datos local está vacía, pero la remota tiene datos
      final dataRows = sheetData.skip(1);
      for (final row in dataRows) {
        if (row.isEmpty || row.length < 9 || row[0] == null) continue;
        try {
          final delivery = DeliveriesCompanion(
            deliveryNumber: Value(int.parse(row[0].toString())),
            date: Value(DateTime.tryParse(row[1].toString()) ?? DateTime.now()),
            durationSeconds: Value(int.tryParse(row[2].toString()) ?? 0),
            avgPrice: Value(double.tryParse(row[3].toString()) ?? 0.0),
            kilograms: Value(double.tryParse(row[4].toString()) ?? 0.0),
            boxes: Value(int.tryParse(row[5].toString()) ?? 0),
            remaining: Value(double.tryParse(row[6].toString()) ?? 0.0),
            seller: Value(row[7].toString()),
            total: Value(double.tryParse(row[8].toString()) ?? 0.0),
          );
          await _db!.into(_db!.deliveries).insertOnConflictUpdate(delivery);
        } catch (e) {
          print('Error procesando fila de reparto: $row, error: $e');
        }
      }
    } else if (localDeliveries.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final updatedData = <List<Object?>>[];
      if (sheetData.isNotEmpty) {
        updatedData.add(sheetData[0]); // Conservar cabeceras existentes
      }

      for (var delivery in localDeliveries) {
        updatedData.add([
          delivery.deliveryNumber,
          delivery.date.toString(),
          delivery.durationSeconds,
          delivery.avgPrice,
          delivery.kilograms,
          delivery.boxes,
          delivery.remaining,
          delivery.seller,
          delivery.total,
        ]);
      }

      await googleSheetsService.updateSheetData(
        spreadsheetId,
        range,
        updatedData,
      );
    }
  }

  /// Método privado para sincronizar datos de ventas
  Future<void> _syncSalesData(
    List<Sale> localSales,
    List<List<Object?>> sheetData,
    String spreadsheetId,
    String range,
  ) async {
    final googleSheetsService = GoogleSheetsService();

    if (localSales.isEmpty && sheetData.length > 1) {
      // PULL: La base de datos local está vacía, pero la remota tiene datos
      final dataRows = sheetData.skip(1);
      for (final row in dataRows) {
        if (row.isEmpty || row.length < 8 || row[0] == null) continue;
        try {
          final sale = SalesCompanion(
            id: Value(int.parse(row[0].toString())),
            date: Value(DateTime.tryParse(row[1].toString()) ?? DateTime.now()),
            clientId: Value(int.parse(row[2].toString())),
            quantity: Value(double.parse(row[3].toString())),
            price: Value(double.parse(row[4].toString())),
            total: Value(double.parse(row[5].toString())),
            notesId: Value(int.tryParse(row[6].toString())),
            deliveryNumber: Value(int.tryParse(row[7].toString())),
          );
          await _db!.into(_db!.sales).insertOnConflictUpdate(sale);
        } catch (e) {
          print('Error procesando fila de venta: $row, error: $e');
        }
      }
    } else if (localSales.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final updatedData = <List<Object?>>[];
      if (sheetData.isNotEmpty) {
        updatedData.add(sheetData[0]); // Conservar cabeceras existentes
      }

      for (var sale in localSales) {
        updatedData.add([
          sale.id,
          sale.date.toString(),
          sale.clientId,
          sale.quantity,
          sale.price,
          sale.total,
          sale.notesId ?? '',
          sale.deliveryNumber ?? '',
        ]);
      }

      await googleSheetsService.updateSheetData(
        spreadsheetId,
        range,
        updatedData,
      );
    }
  }

  /// Método privado para sincronizar datos de clientes
  Future<void> _syncClientesData(
    List<Cliente> localClientes,
    List<List<Object?>> sheetData,
    String spreadsheetId,
    String range,
  ) async {
    final googleSheetsService = GoogleSheetsService();

    if (localClientes.isEmpty && sheetData.length > 1) {
      // PULL: La base de datos local está vacía, pero la remota tiene datos
      final dataRows = sheetData.skip(1);
      for (final row in dataRows) {
        if (row.isEmpty || row.length < 23 || row[0] == null) continue;
        try {
          final cliente = ClientesCompanion(
            id: Value(int.parse(row[0].toString())),
            nombre: Value(row[1].toString()),
            contacto: Value(row[2].toString()),
            tipoNegocio: Value(row[3].toString()),
            ciudad: Value(row[4].toString()),
            domicilio: Value(row[5].toString()),
            ubicacion: Value(row[6].toString()),
            telefono: Value(row[7].toString()),
            consumo: Value(int.tryParse(row[8].toString()) ?? 0),
            ultimoContacto: Value(
              DateTime.tryParse(row[9].toString()) ?? DateTime.now(),
            ),
            horaInicio: Value(int.tryParse(row[10].toString()) ?? 0),
            horaCierre: Value(int.tryParse(row[11].toString()) ?? 0),
            notasId: Value(int.tryParse(row[12].toString())),
            dias: Value(row[13].toString()),
            eventos: Value(int.tryParse(row[14].toString()) ?? 0),
            kgTotal: Value(double.tryParse(row[15].toString()) ?? 0.0),
            moda: Value(double.tryParse(row[16].toString()) ?? 0.0),
            maximo: Value(double.tryParse(row[17].toString()) ?? 0.0),
            ultimas10: Value(double.tryParse(row[18].toString()) ?? 0.0),
            kgEvento: Value(double.tryParse(row[19].toString()) ?? 0.0),
            kgSemana: Value(double.tryParse(row[20].toString()) ?? 0.0),
            ventasVuelta: Value(double.tryParse(row[21].toString()) ?? 0.0),
            puntuacion: Value(double.tryParse(row[22].toString()) ?? 0.0),
          );
          await _db!.into(_db!.clientes).insertOnConflictUpdate(cliente);
        } catch (e) {
          print('Error procesando fila de cliente: $row, error: $e');
        }
      }
    } else if (localClientes.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final updatedData = <List<Object?>>[];
      if (sheetData.isNotEmpty) {
        updatedData.add(sheetData[0]); // Conservar cabeceras existentes
      }

      for (var cliente in localClientes) {
        updatedData.add([
          cliente.id,
          cliente.nombre,
          cliente.contacto,
          cliente.tipoNegocio,
          cliente.ciudad,
          cliente.domicilio,
          cliente.ubicacion,
          cliente.telefono,
          cliente.consumo,
          cliente.ultimoContacto.toString(),
          cliente.horaInicio,
          cliente.horaCierre,
          cliente.notasId ?? '',
          cliente.dias,
          cliente.eventos,
          cliente.kgTotal,
          cliente.moda,
          cliente.maximo,
          cliente.ultimas10,
          cliente.kgEvento,
          cliente.kgSemana,
          cliente.ventasVuelta,
          cliente.puntuacion,
        ]);
      }

      await googleSheetsService.updateSheetData(
        spreadsheetId,
        range,
        updatedData,
      );
    }
  }

  // ===== UTILIDADES =====

  /// Cierra la conexión con la base de datos
  Future<void> close() async {
    if (_isInitialized && _db != null) {
      await _db!.close();
      _db = null;
      _isInitialized = false;
    }
  }

  /// Cuenta campos no vacíos en una fila
  int _countNonEmptyFields(List<Object?> row) {
    return row
        .where(
          (field) =>
              field != null &&
              field.toString().isNotEmpty &&
              field.toString() != '0',
        )
        .length;
  }

  /// Inserta un registro de contacto
  Future<int> insertContacto({
    required int clientId,
    required String result,
    required int deliveryId,
  }) async {
    _ensureInitialized();
    return await _db!.insertContacto(
      clientId: clientId,
      result: result,
      deliveryId: deliveryId,
    );
  }

  /// Obtiene los últimos 10 registros de contacto
  Future<List<Contacto>> getLast10Contactos() async {
    _ensureInitialized();
    // Si no existe en AppDatabase, implementa aquí la consulta
    return await (_db!.select(_db!.contactos)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)])
          ..limit(10))
        .get();
  }
}
