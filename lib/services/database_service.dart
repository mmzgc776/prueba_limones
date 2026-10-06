import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/database.dart';
import 'client_recommendation_service.dart';
import 'google_sheets_service.dart';
import 'sheets_row_utils.dart';
import 'user_session_service.dart';

/// Servicio principal para operaciones de base de datos
/// Maneja todas las operaciones CRUD y sincronización con Google Sheets
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  AppDatabase? _db;

  /// Conexión aislada para pruebas; no sustituye el singleton de producción.
  @visibleForTesting
  DatabaseService.forTesting(AppDatabase database)
      : _db = database, _isInitialized = true;

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

  /// Snapshot consistente y acotado al vendedor capturado al iniciar la carga.
  Future<({List<Cliente> clientes, List<Sale> sales,
      List<Delivery> deliveries, List<Interaccione> interactions})>
      getRecommendationSnapshot(int sellerId) async {
    _ensureInitialized();
    return _db!.transaction(() async {
      final clientes = await (_db!.select(_db!.clientes)
        ..where((t) => t.sellerId.equals(sellerId))).get();
      final sales = await (_db!.select(_db!.sales)
        ..where((t) => t.sellerId.equals(sellerId))).get();
      final deliveries = await (_db!.select(_db!.deliveries)
        ..where((t) => t.sellerId.equals(sellerId))).get();
      final interactions = await (_db!.select(_db!.interacciones)
        ..where((t) => t.sellerId.equals(sellerId))).get();
      return (clientes: clientes, sales: sales,
          deliveries: deliveries, interactions: interactions);
    });
  }

  /// Una escritura por cliente, incluidas métricas cero tras borrar ventas.
  Future<void> saveRecommendationMetrics(int clientId, int sellerId,
      ClientPurchaseMetrics metrics) async {
    _ensureInitialized();
    await (_db!.update(_db!.clientes)..where((t) =>
        t.id.equals(clientId) & t.sellerId.equals(sellerId))).write(
      ClientesCompanion(
        eventos: Value(metrics.sales.length),
        kgTotal: Value(metrics.kgTotal), moda: Value(metrics.moda),
        maximo: Value(metrics.maximo), kgEvento: Value(metrics.kgEvento),
        kgSemana: Value(metrics.kgSemana), ventasVuelta: Value(metrics.ventasVuelta),
        ultimas10: Value(metrics.ultimas10), puntuacion: Value(metrics.score),
        intervaloPromedio: Value(metrics.interval),
        diasDesdeUltimaVenta: Value(metrics.ageDays.isFinite ? metrics.ageDays.toInt() : 0),
        cicloScore: Value(metrics.readiness),
        diaSemanaPreferido: Value(metrics.preferredDay),
        frecuenciasDiaSemana: Value(jsonEncode(metrics.weekdayCounts.map(
          (key, value) => MapEntry(key.toString(), value)))),
        weekdayScore: Value(metrics.weekdayScore),
      ),
    );
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
    int? sellerId,
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
      sellerId: sellerId ?? UserSessionService().currentSellerId,
    );
  }

  /// Guarda la venta por búsqueda y su interacción de forma atómica.
  Future<int> insertSaleWithInteraction({
    required DateTime date,
    required int clientId,
    required double quantity,
    required double price,
    required double total,
    int? deliveryNumber,
  }) async {
    _ensureInitialized();
    return _db!.insertSaleWithInteraction(
      date: date,
      clientId: clientId,
      quantity: quantity,
      price: price,
      total: total,
      deliveryNumber: deliveryNumber,
      sellerId: UserSessionService().currentSellerId,
    );
  }


  /// Obtiene todas las ventas del usuario actual
  Future<List<Sale>> getAllSales() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(
      _db!.sales,
    )..where((tbl) => tbl.sellerId.equals(sellerId))).get();
  }

  /// Obtiene ventas sin asignar a un delivery
  Future<List<Sale>> getUnassignedSales() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.sales)..where(
          (tbl) => tbl.deliveryNumber.isNull() & tbl.sellerId.equals(sellerId),
        ))
        .get();
  }

  /// Obtiene ventas por número de delivery
  Future<List<Sale>> getSalesByDeliveryNumber(int deliveryNumber) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.sales)..where(
          (tbl) =>
              tbl.deliveryNumber.equals(deliveryNumber) &
              tbl.sellerId.equals(sellerId),
        ))
        .get();
  }

  /// Obtiene ventas por ID de cliente
  Future<List<Sale>> getVentasByClientId(int clientId) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.sales)..where(
          (tbl) =>
              tbl.clientId.equals(clientId) & tbl.sellerId.equals(sellerId),
        ))
        .get();
  }

  /// Obtiene una venta específica por ID
  Future<Sale?> getSaleById(int saleId) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.sales)..where(
          (tbl) => tbl.id.equals(saleId) & tbl.sellerId.equals(sellerId),
        ))
        .getSingleOrNull();
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

  /// Desasigna una venta de su delivery (pone deliveryNumber en null)
  Future<int> unassignSaleFromDelivery(int saleId) async {
    _ensureInitialized();

    // Primero obtener la venta para saber de qué delivery desasignarla
    final sale = await (_db!.select(
      _db!.sales,
    )..where((tbl) => tbl.id.equals(saleId))).getSingleOrNull();

    if (sale == null) {
      throw Exception('Venta no encontrada');
    }

    final previousDeliveryNumber = sale.deliveryNumber;

    // Desasignar la venta (poner deliveryNumber en null)
    final result =
        await (_db!.update(_db!.sales)..where((tbl) => tbl.id.equals(saleId)))
            .write(SalesCompanion(deliveryNumber: Value(null)));

    // Recalcular las estadísticas del delivery del cual se desasignó
    if (previousDeliveryNumber != null) {
      await recalculateDeliveryStats(previousDeliveryNumber);
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
    required int sellerId,
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
      sellerId: sellerId,
      total: total,
    );
  }

  /// Obtiene todos los deliveries del usuario actual
  Future<List<Delivery>> getAllDeliveries() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(
      _db!.deliveries,
    )..where((tbl) => tbl.sellerId.equals(sellerId))).get();
  }

  /// Obtiene los números de los últimos X deliveries
  Future<List<int>> getLatestDeliveryNumbers(int limit) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final query = _db!.select(_db!.deliveries)
      ..where((tbl) => tbl.sellerId.equals(sellerId))
      ..orderBy([(d) => OrderingTerm.desc(d.deliveryNumber)])
      ..limit(limit);

    final result = await query.get();
    return result.map((d) => d.deliveryNumber).toList();
  }

  /// Obtiene los números de los últimos X deliveries ordenados por fecha
  Future<List<int>> getLatestDeliveryNumbersByDate(int limit) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final query = _db!.select(_db!.deliveries)
      ..where((tbl) => tbl.sellerId.equals(sellerId))
      ..orderBy([(d) => OrderingTerm.desc(d.date)])
      ..limit(limit);

    final result = await query.get();
    return result.map((d) => d.deliveryNumber).toList();
  }

  /// Obtiene la fecha del delivery más antiguo
  Future<DateTime?> getOldestDeliveryDate() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final query = _db!.select(_db!.deliveries)
      ..where((tbl) => tbl.sellerId.equals(sellerId))
      ..orderBy([(d) => OrderingTerm.asc(d.date)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result?.date;
  }

  /// Obtiene el número de delivery más alto
  Future<int?> getHighestDeliveryNumber() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final query = _db!.select(_db!.deliveries)
      ..where((tbl) => tbl.sellerId.equals(sellerId))
      ..orderBy([(d) => OrderingTerm.desc(d.deliveryNumber)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result?.deliveryNumber;
  }

  /// Obtiene un delivery específico por número
  Future<Delivery?> getDeliveryByNumber(int deliveryNumber) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.deliveries)..where(
          (tbl) =>
              tbl.deliveryNumber.equals(deliveryNumber) &
              tbl.sellerId.equals(sellerId),
        ))
        .getSingleOrNull();
  }

  /// Devuelve la fila cruda de un delivery (sin mapeo de Drift).
  /// Útil como fallback cuando el mapeo generado por Drift falla
  /// por datos corruptos (por ejemplo, una cadena en una columna numérica).
  Future<Map<String, dynamic>?> getDeliveryRawByNumber(
    int deliveryNumber,
  ) async {
    _ensureInitialized();
    final query = await _db!
        .customSelect(
          'SELECT * FROM deliveries WHERE delivery_number = ? LIMIT 1',
          variables: [Variable.withInt(deliveryNumber)],
        )
        .getSingleOrNull();

    return query?.data;
  }

  /// Intenta corregir filas corruptas en la tabla `deliveries` donde
  /// `duration_seconds` contiene texto/timestamps (p. ej. '2025-...').
  /// Establece duration_seconds = 0 para las filas que aparentan contener
  /// un timestamp (contienen 'T' o '-'), o cuyo tipo SQLite es TEXT.
  // NOTE: fixCorruptDeliveryDurations was a temporary helper to repair
  // corrupted rows where `duration_seconds` contained timestamp strings.
  // It has been removed now that the data appears clean in production.

  /// Actualiza un delivery existente
  Future<int> updateDelivery({
    required int deliveryNumber,
    required DateTime date,
    required int durationSeconds,
    required double avgPrice,
    required double kilograms,
    required int boxes,
    required double remaining,
    required int sellerId,
    required double total,
  }) async {
    _ensureInitialized();
    return await (_db!.update(
      _db!.deliveries,
    )..where((tbl) => tbl.deliveryNumber.equals(deliveryNumber))).write(
      DeliveriesCompanion(
        date: Value(date),
        durationSeconds: Value(durationSeconds),
        avgPrice: Value(avgPrice),
        kilograms: Value(kilograms),
        boxes: Value(boxes),
        remaining: Value(remaining),
        sellerId: Value(sellerId),
        total: Value(total),
      ),
    );
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
      sellerId: UserSessionService().currentSellerId,
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

  /// Obtiene todos los clientes del usuario actual
  Future<List<Cliente>> getAllClientes() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(
      _db!.clientes,
    )..where((tbl) => tbl.sellerId.equals(sellerId))).get();
  }

  /// Obtiene un cliente por ID
  Future<Cliente?> getClienteById(int id) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.clientes)
          ..where((tbl) => tbl.id.equals(id) & tbl.sellerId.equals(sellerId)))
        .getSingleOrNull();
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

  /// Actualiza el campo kgSemana de un cliente
  Future<void> updateClienteKgSemana(int clientId, double kgSemana) async {
    _ensureInitialized();
    await (_db!.update(_db!.clientes)..where((tbl) => tbl.id.equals(clientId)))
        .write(ClientesCompanion(kgSemana: Value(kgSemana)));
  }

  /// Elimina todos los clientes
  Future<void> deleteAllClientes() async {
    _ensureInitialized();
    await _db!.delete(_db!.clientes).go();
  }

  /// Actualiza el campo puntuacion final de un cliente
  Future<void> updateClienteFinalScore(int clientId, double score) async {
    _ensureInitialized();
    await (_db!.update(_db!.clientes)..where((tbl) => tbl.id.equals(clientId)))
        .write(ClientesCompanion(puntuacion: Value(score)));
  }

  /// Actualiza las métricas de ciclo de compra de un cliente
  Future<void> updateClienteCicloMetrics({
    required int clientId,
    required double intervaloPromedio,
    required int diasDesdeUltimaVenta,
    required double cicloScore,
  }) async {
    _ensureInitialized();
    await (_db!.update(
      _db!.clientes,
    )..where((tbl) => tbl.id.equals(clientId))).write(
      ClientesCompanion(
        intervaloPromedio: Value(intervaloPromedio),
        diasDesdeUltimaVenta: Value(diasDesdeUltimaVenta),
        cicloScore: Value(cicloScore),
      ),
    );
  }

  /// Actualiza las métricas de patrón semanal de un cliente
  Future<void> updateClienteWeekdayMetrics({
    required int clientId,
    required int diaSemanaPreferido,
    required String frecuenciasDiaSemana,
    required double weekdayScore,
  }) async {
    _ensureInitialized();
    await (_db!.update(
      _db!.clientes,
    )..where((tbl) => tbl.id.equals(clientId))).write(
      ClientesCompanion(
        diaSemanaPreferido: Value(diaSemanaPreferido),
        frecuenciasDiaSemana: Value(frecuenciasDiaSemana),
        weekdayScore: Value(weekdayScore),
      ),
    );
  }

  // Métodos para obtener los valores máximos para la normalización
  Future<int?> getMaxEventos() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxEventos = _db!.clientes.eventos.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxEventos])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query.map((row) => row.read(maxEventos)).getSingleOrNull();
  }

  Future<double?> getMaxKgTotal() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxKgTotal = _db!.clientes.kgTotal.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxKgTotal])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query.map((row) => row.read(maxKgTotal)).getSingleOrNull();
  }

  Future<double?> getMaxModa() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxModa = _db!.clientes.moda.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxModa])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query.map((row) => row.read(maxModa)).getSingleOrNull();
  }

  Future<double?> getMaxMaximo() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxMaximo = _db!.clientes.maximo.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxMaximo])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query.map((row) => row.read(maxMaximo)).getSingleOrNull();
  }

  Future<double?> getMaxUltimas10() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxUltimas10 = _db!.clientes.ultimas10.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxUltimas10])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query.map((row) => row.read(maxUltimas10)).getSingleOrNull();
  }

  Future<double?> getMaxKgEvento() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxKgEvento = _db!.clientes.kgEvento.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxKgEvento])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query.map((row) => row.read(maxKgEvento)).getSingleOrNull();
  }

  Future<double?> getMaxKgSemana() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxKgSemana = _db!.clientes.kgSemana.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxKgSemana])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query.map((row) => row.read(maxKgSemana)).getSingleOrNull();
  }

  Future<double?> getMaxVentasVuelta() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxVentasVuelta = _db!.clientes.ventasVuelta.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxVentasVuelta])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query
        .map((row) => row.read(maxVentasVuelta))
        .getSingleOrNull();
  }

  Future<double?> getMaxCicloScore() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxCicloScore = _db!.clientes.cicloScore.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxCicloScore])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query.map((row) => row.read(maxCicloScore)).getSingleOrNull();
  }

  Future<double?> getMaxIntervaloPromedio() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final maxIntervalo = _db!.clientes.intervaloPromedio.max();
    final query = _db!.selectOnly(_db!.clientes)
      ..addColumns([maxIntervalo])
      ..where(_db!.clientes.sellerId.equals(sellerId));
    return await query.map((row) => row.read(maxIntervalo)).getSingleOrNull();
  }

  // ===== SINCRONIZACIÓN CON GOOGLE SHEETS =====

  // Índice (0-based) de la columna `seller_id` en cada hoja.
  static const int _salesSellerColumn = 8;
  static const int _deliveriesSellerColumn = 7;
  static const int _clientesSellerColumn = 29;
  static const int _gastosSellerColumn = 1;

  // Encabezados por defecto: se usan para completar la fila 1 cuando la hoja
  // está vacía o tiene celdas sin nombre, y así el PUSH no la sobrescribe.
  static const List<String> _salesHeader = [
    'id',
    'date',
    'clientId',
    'quantity',
    'price',
    'total',
    'notesId',
    'deliveryNumber',
    'seller_id',
  ];
  static const List<String> _deliveriesHeader = [
    'deliveryNumber',
    'date',
    'durationSeconds',
    'avgPrice',
    'kilograms',
    'boxes',
    'remaining',
    'seller_id',
    'total',
  ];
  static const List<String> _clientesHeader = [
    'ID',
    'Nombre',
    'Contacto',
    'TipoNegocio',
    'Ciudad',
    'Domicilio',
    'Ubicacion',
    'Telefono',
    'Consumo',
    'UltimoContacto',
    'HoraInicio',
    'HoraCierre',
    'NotasId',
    'Dias',
    'Eventos',
    'KgTotal',
    'Moda',
    'Maximo',
    'Ultimas10',
    'KgEvento',
    'KgSemana',
    'VentasVuelta',
    'Puntuacion',
    'intervaloPromedio',
    'diasDesdeUltimaVenta',
    'cicloScore',
    'diaSemanaPreferido',
    'frecuenciasDiaSemana',
    'weekdayScore',
    'seller_id',
  ];
  static const List<String> _gastosHeader = [
    'id',
    'seller_id',
    'fecha',
    'concepto',
    'monto',
    'categoria',
  ];

  /// `true` si la fila de la hoja pertenece al vendedor actual. Las filas sin
  /// `seller_id` (legacy) pertenecen al vendedor original ([kLegacySellerId]).
  bool _rowBelongsToCurrentSeller(List<Object?> row, int sellerColumnIndex) =>
      (sellerIdOfRow(row, sellerColumnIndex) ?? kLegacySellerId) ==
      UserSessionService().currentSellerId;

  /// PUSH multi-vendedor: escribe el encabezado y las filas del vendedor
  /// actual **conservando** las filas de los demás vendedores, y limpia las
  /// filas sobrantes si el bloque nuevo quedó más corto que la hoja previa.
  Future<void> _pushSellerRows({
    required GoogleSheetsService googleSheetsService,
    required String spreadsheetId,
    required String range,
    required List<List<Object?>> sheetData,
    required List<String> headerDefaults,
    required int sellerColumnIndex,
    required List<List<Object?>> localRows,
  }) async {
    final updatedData = <List<Object?>>[
      normalizedHeaderRow(
        sheetData.isNotEmpty ? sheetData.first : null,
        defaults: headerDefaults,
      ),
      ...rowsOwnedByOtherSellers(
        sheetData: sheetData,
        sellerColumnIndex: sellerColumnIndex,
        sellerId: UserSessionService().currentSellerId,
      ),
      ...localRows,
    ];

    await googleSheetsService.updateSheetData(
      spreadsheetId,
      range,
      updatedData,
    );

    final trailing = trailingRowsRange(
      range,
      previousRows: sheetData.length,
      newRows: updatedData.length,
    );
    if (trailing != null) {
      await googleSheetsService.clearSheetData(spreadsheetId, trailing);
    }
  }

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
        // Solo importar filas del usuario actual
        if (!_rowBelongsToCurrentSeller(row, _deliveriesSellerColumn)) {
          continue;
        }
        try {
          final delivery = DeliveriesCompanion(
            deliveryNumber: Value(int.parse(row[0].toString())),
            date: Value(DateTime.tryParse(row[1].toString()) ?? DateTime.now()),
            durationSeconds: Value(int.tryParse(row[2].toString()) ?? 0),
            avgPrice: Value(double.tryParse(row[3].toString()) ?? 0.0),
            kilograms: Value(double.tryParse(row[4].toString()) ?? 0.0),
            boxes: Value(int.tryParse(row[5].toString()) ?? 0),
            remaining: Value(double.tryParse(row[6].toString()) ?? 0.0),
            sellerId: Value(
              sellerIdOfRow(row, _deliveriesSellerColumn) ?? kLegacySellerId,
            ),
            total: Value(double.tryParse(row[8].toString()) ?? 0.0),
          );
          await _db!.into(_db!.deliveries).insertOnConflictUpdate(delivery);
        } catch (e) {
          print('Error procesando fila de reparto: $row, error: $e');
        }
      }
    } else if (localDeliveries.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final localRows = <List<Object?>>[];
      for (var delivery in localDeliveries) {
        localRows.add([
          delivery.deliveryNumber,
          delivery.date.toString(),
          delivery.durationSeconds,
          delivery.avgPrice,
          delivery.kilograms,
          delivery.boxes,
          delivery.remaining,
          delivery.sellerId,
          delivery.total,
        ]);
      }

      await _pushSellerRows(
        googleSheetsService: googleSheetsService,
        spreadsheetId: spreadsheetId,
        range: range,
        sheetData: sheetData,
        headerDefaults: _deliveriesHeader,
        sellerColumnIndex: _deliveriesSellerColumn,
        localRows: localRows,
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
        // Las filas legacy traen 8 columnas (sin `seller_id`).
        if (row.isEmpty || row.length < 8 || row[0] == null) continue;
        // Solo importar filas del usuario actual
        if (!_rowBelongsToCurrentSeller(row, _salesSellerColumn)) continue;
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
            sellerId: Value(
              sellerIdOfRow(row, _salesSellerColumn) ?? kLegacySellerId,
            ),
          );
          await _db!.into(_db!.sales).insertOnConflictUpdate(sale);
        } catch (e) {
          print('Error procesando fila de venta: $row, error: $e');
        }
      }
    } else if (localSales.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final localRows = <List<Object?>>[];
      for (var sale in localSales) {
        localRows.add([
          sale.id,
          sale.date.toString(),
          sale.clientId,
          sale.quantity,
          sale.price,
          sale.total,
          sale.notesId ?? '',
          sale.deliveryNumber ?? '',
          sale.sellerId,
        ]);
      }

      await _pushSellerRows(
        googleSheetsService: googleSheetsService,
        spreadsheetId: spreadsheetId,
        range: range,
        sheetData: sheetData,
        headerDefaults: _salesHeader,
        sellerColumnIndex: _salesSellerColumn,
        localRows: localRows,
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
        // Aceptar filas de 23 columnas (antiguo), 29 (sin seller_id) o 30
        // (actual). Los clientes se identifican por (seller_id, id), así que
        // las filas de otro vendedor colisionarían con los ids locales.
        if (row.isEmpty || row.length < 23 || row[0] == null) continue;
        if (!_rowBelongsToCurrentSeller(row, _clientesSellerColumn)) continue;
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
            // Nuevas columnas (si existen en el sheet)
            intervaloPromedio: row.length > 23
                ? Value(double.tryParse(row[23].toString()) ?? 0.0)
                : Value.absent(),
            diasDesdeUltimaVenta: row.length > 24
                ? Value(int.tryParse(row[24].toString()) ?? 0)
                : Value.absent(),
            cicloScore: row.length > 25
                ? Value(double.tryParse(row[25].toString()) ?? 0.0)
                : Value.absent(),
            diaSemanaPreferido: row.length > 26
                ? Value(int.tryParse(row[26].toString()) ?? 0)
                : Value.absent(),
            frecuenciasDiaSemana: row.length > 27
                ? Value(row[27].toString())
                : Value.absent(),
            weekdayScore: row.length > 28
                ? Value(double.tryParse(row[28].toString()) ?? 0.0)
                : Value.absent(),
            sellerId: Value(
              sellerIdOfRow(row, _clientesSellerColumn) ?? kLegacySellerId,
            ),
          );
          await _db!.into(_db!.clientes).insertOnConflictUpdate(cliente);
        } catch (e) {
          print('Error procesando fila de cliente: $row, error: $e');
        }
      }
    } else if (localClientes.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final localRows = <List<Object?>>[];
      for (var cliente in localClientes) {
        localRows.add([
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
          // Nuevas columnas de ciclo de compra y patrón semanal
          cliente.intervaloPromedio ?? 0.0,
          cliente.diasDesdeUltimaVenta ?? 0,
          cliente.cicloScore ?? 0.0,
          cliente.diaSemanaPreferido ?? 0,
          cliente.frecuenciasDiaSemana ?? '{}',
          cliente.weekdayScore ?? 0.0,
          // Columna AD: dueño del cliente (evita colisiones de ids entre
          // vendedores, porque cada app numera sus clientes desde cero).
          cliente.sellerId,
        ]);
      }

      await _pushSellerRows(
        googleSheetsService: googleSheetsService,
        spreadsheetId: spreadsheetId,
        range: range,
        sheetData: sheetData,
        headerDefaults: _clientesHeader,
        sellerColumnIndex: _clientesSellerColumn,
        localRows: localRows,
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

  // (removed unused helper _countNonEmptyFields)

  /// Inserta un registro de interacción
  Future<int> insertInteraccion({
    required int clientId,
    required String result,
    required int deliveryId,
    DateTime? timestamp,
  }) async {
    _ensureInitialized();
    return await _db!.insertInteraccion(
      clientId: clientId,
      result: result,
      deliveryId: deliveryId,
      timestamp: timestamp,
      sellerId: UserSessionService().currentSellerId,
    );
  }

  /// Obtiene los últimos 10 registros de interacción del usuario actual
  Future<List<Interaccione>> getLast10Interacciones() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.interacciones)
          ..where((tbl) => tbl.sellerId.equals(sellerId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)])
          ..limit(10))
        .get();
  }

  /// Obtiene todas las interacciones de un delivery específico
  Future<List<Interaccione>> getInteraccionesByDeliveryNumber(
    int deliveryNumber,
  ) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.interacciones)
          ..where(
            (tbl) =>
                tbl.deliveryId.equals(deliveryNumber) &
                tbl.sellerId.equals(sellerId),
          ))
        .get();
  }

  /// Obtiene los IDs de los clientes que rechazaron en un delivery específico
  Future<List<int>> getRejectedClientIdsByDeliveryNumber(
    int deliveryNumber,
  ) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final query = _db!.select(_db!.interacciones)
      ..where(
        (tbl) =>
            tbl.deliveryId.equals(deliveryNumber) &
            tbl.result.equals('Rechazó') &
            tbl.sellerId.equals(sellerId),
      );
    final result = await query.get();
    return result.map((interaccion) => interaccion.clientId).toList();
  }

  /// Obtiene los IDs de los clientes de las últimas 20 ventas
  Future<List<int>> getLast10SalesClientIds() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    final query = _db!.select(_db!.sales)
      ..where((tbl) => tbl.sellerId.equals(sellerId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)])
      ..limit(20);
    final result = await query.get();
    return result.map((sale) => sale.clientId).toList();
  }

  /// Devuelve un mapa clientId → fecha de la venta más reciente,
  /// para los IDs proporcionados. Solo incluye clientes con al menos una venta.
  Future<Map<int, DateTime>> getLastSaleDatePerClient(
    List<int> clientIds,
  ) async {
    _ensureInitialized();
    if (clientIds.isEmpty) return {};
    final sellerId = UserSessionService().currentSellerId;
    final query = _db!.select(_db!.sales)
      ..where(
        (tbl) =>
            tbl.clientId.isIn(clientIds) & tbl.sellerId.equals(sellerId),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);
    final sales = await query.get();
    final Map<int, DateTime> result = {};
    for (final sale in sales) {
      // Al estar ordenado DESC, el primer hit por cliente es el más reciente.
      result.putIfAbsent(sale.clientId, () => sale.date);
    }
    return result;
  }

  // ===== OPERACIONES DE NOTAS =====

  /// Inserta una nueva nota
  Future<int> insertNota({
    required String nota,
    required int clientId,
    int? ventaId,
    required String color,
  }) async {
    _ensureInitialized();
    return await _db!.insertNota(
      nota: nota,
      clientId: clientId,
      ventaId: ventaId,
      color: color,
      sellerId: UserSessionService().currentSellerId,
    );
  }

  /// Obtiene todas las notas de un cliente
  Future<List<Nota>> getNotasByClientId(int clientId) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.notas)
          ..where(
            (tbl) =>
                tbl.clientId.equals(clientId) & tbl.sellerId.equals(sellerId),
          ))
        .get();
  }

  /// Obtiene todas las notas de una venta
  Future<List<Nota>> getNotasByVentaId(int ventaId) async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(_db!.notas)
          ..where(
            (tbl) => tbl.ventaId.equals(ventaId) & tbl.sellerId.equals(sellerId),
          ))
        .get();
  }

  /// Elimina una nota por ID
  Future<int> deleteNota(int id) async {
    _ensureInitialized();
    return await _db!.deleteNota(id);
  }

  /// Actualiza el ventaId de las notas de un cliente que no tienen ventaId asignado
  Future<int> updateNotasVentaId(int clientId, int ventaId) async {
    _ensureInitialized();
    return await (_db!.update(
          _db!.notas,
        )..where((tbl) => tbl.clientId.equals(clientId) & tbl.ventaId.isNull()))
        .write(NotasCompanion(ventaId: Value(ventaId)));
  }

  /// Obtiene todas las notas con información del cliente asociado
  Future<List<Map<String, dynamic>>> getAllNotasWithClientInfo() async {
    _ensureInitialized();

    // Obtener todas las notas
    final notas = await _db!.select(_db!.notas).get();

    // Para cada nota, obtener el cliente asociado y datos de la venta si existe
    final result = <Map<String, dynamic>>[];
    for (final nota in notas) {
      final cliente = await getClienteById(nota.clientId);
      if (cliente != null) {
        final map = <String, dynamic>{
          'nota': nota,
          'clientName': cliente.nombre,
          'cliente': cliente,
        };

        // Si la nota tiene una venta asociada, obtener sus datos
        if (nota.ventaId != null && nota.ventaId! > 0) {
          try {
            // Usar get() + limit(1) en lugar de getSingleOrNull() para evitar
            // excepciones si hay datos duplicados o corruptos
            final ventas = await (_db!.select(_db!.sales)
                  ..where((tbl) => tbl.id.equals(nota.ventaId!))
                  ..limit(1))
                .get();
            if (ventas.isNotEmpty) {
              final venta = ventas.first;
              map['venta'] = venta;
              map['ventaTotal'] = venta.total;
              map['ventaDate'] = venta.date;
              map['ventaQuantity'] = venta.quantity;
              map['deliveryNumber'] = venta.deliveryNumber;
            } else {
              debugPrint('Nota ${nota.id}: ventaId ${nota.ventaId} no encontrada en BD local');
            }
          } catch (e) {
            debugPrint('Error al obtener venta ${nota.ventaId} para nota ${nota.id}: $e');
          }
        }

        result.add(map);
      }
    }

    return result;
  }

  /// Obtiene todas las notas del usuario actual
  Future<List<Nota>> getAllNotas() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(
      _db!.notas,
    )..where((tbl) => tbl.sellerId.equals(sellerId))).get();
  }

  /// Elimina todas las notas
  Future<void> deleteAllNotas() async {
    _ensureInitialized();
    await _db!.delete(_db!.notas).go();
  }

  /// Elimina todas las interacciones
  Future<void> deleteAllInteracciones() async {
    _ensureInitialized();
    await _db!.delete(_db!.interacciones).go();
  }

  /// Obtiene todas las interacciones del usuario actual
  Future<List<Interaccione>> getAllInteracciones() async {
    _ensureInitialized();
    final sellerId = UserSessionService().currentSellerId;
    return await (_db!.select(
      _db!.interacciones,
    )..where((tbl) => tbl.sellerId.equals(sellerId))).get();
  }

  /// Obtiene el historial de ventas e interacciones de los últimos N repartos
  /// Devuelve una lista de mapas con información combinada
  /// Los repartos se ordenan por fecha (más recientes primero)
  Future<List<Map<String, dynamic>>> getHistoryForLastDeliveries(
    int deliveryCount,
  ) async {
    _ensureInitialized();

    // Obtener los números de los últimos N repartos ordenados por fecha
    final deliveryNumbers = await getLatestDeliveryNumbersByDate(deliveryCount);

    if (deliveryNumbers.isEmpty) {
      return [];
    }

    final history = <Map<String, dynamic>>[];

    // Para cada reparto, obtener sus ventas e interacciones
    for (final deliveryNumber in deliveryNumbers) {
      // Obtener el delivery completo para tener la fecha
      final delivery = await getDeliveryByNumber(deliveryNumber);
      if (delivery == null) continue;

      // Obtener ventas de este reparto
      final sales = await getSalesByDeliveryNumber(deliveryNumber);
      for (final sale in sales) {
        final cliente = await getClienteById(sale.clientId);
        if (cliente != null) {
          history.add({
            'type': 'sale',
            'saleId': sale.id,
            'deliveryNumber': deliveryNumber,
            'deliveryDate': delivery.date,
            'clientId': cliente.id,
            'clientName': cliente.nombre,
            'contactName': cliente.contacto,
            'businessName': cliente.tipoNegocio,
            'quantity': sale.quantity,
            'timestamp': sale.date,
          });
        }
      }

      // Obtener interacciones de este reparto
      final interacciones = await getInteraccionesByDeliveryNumber(
        deliveryNumber,
      );
      for (final interaccion in interacciones) {
        // Omitir interacciones de tipo "Venta" porque ya están en las ventas
        if (interaccion.result == 'Venta') {
          continue;
        }

        final cliente = await getClienteById(interaccion.clientId);
        if (cliente != null) {
          history.add({
            'type': 'interaction',
            'deliveryNumber': deliveryNumber,
            'deliveryDate': delivery.date,
            'clientId': cliente.id,
            'clientName': cliente.nombre,
            'contactName': cliente.contacto,
            'businessName': cliente.tipoNegocio,
            'interactionType': interaccion.result,
            'timestamp': interaccion.timestamp,
          });
        }
      }
    }

    // Ordenar por fecha descendente (más reciente primero)
    history.sort(
      (a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
    );

    return history;
  }

  /// Obtiene el historial de ventas e interacciones de un cliente específico
  /// Devuelve una lista de mapas con información combinada
  Future<List<Map<String, dynamic>>> getHistoryForClient(int clientId) async {
    _ensureInitialized();

    final history = <Map<String, dynamic>>[];
    final cliente = await getClienteById(clientId);

    if (cliente == null) {
      return [];
    }

    // Obtener todas las ventas del cliente
    final sales = await getVentasByClientId(clientId);
    for (final sale in sales) {
      if (sale.deliveryNumber != null) {
        final delivery = await getDeliveryByNumber(sale.deliveryNumber!);
        history.add({
          'type': 'sale',
          'saleId': sale.id,
          'deliveryNumber': sale.deliveryNumber,
          'deliveryDate': delivery?.date ?? sale.date,
          'clientId': cliente.id,
          'clientName': cliente.nombre,
          'contactName': cliente.contacto,
          'businessName': cliente.tipoNegocio,
          'quantity': sale.quantity,
          'timestamp': sale.date,
        });
      }
    }

    // Obtener todas las interacciones del cliente
    final allInteracciones = await getAllInteracciones();
    final clientInteracciones = allInteracciones
        .where((interaccion) => interaccion.clientId == clientId)
        .toList();

    for (final interaccion in clientInteracciones) {
      // Omitir interacciones de tipo "Venta" porque ya están en las ventas
      if (interaccion.result == 'Venta') {
        continue;
      }

      final delivery = await getDeliveryByNumber(interaccion.deliveryId);
      history.add({
        'type': 'interaction',
        'deliveryNumber': interaccion.deliveryId,
        'deliveryDate': delivery?.date ?? interaccion.timestamp,
        'clientId': cliente.id,
        'clientName': cliente.nombre,
        'contactName': cliente.contacto,
        'businessName': cliente.tipoNegocio,
        'interactionType': interaccion.result,
        'timestamp': interaccion.timestamp,
      });
    }

    // Ordenar por fecha descendente (más reciente primero)
    history.sort(
      (a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
    );

    return history;
  }

  /// Guarda el estado persistente del delivery
  Future<void> savePersistentDeliveryState(
    Map<String, dynamic> stateMap,
  ) async {
    _ensureInitialized();
    final companion = PersistentDeliveryStatesCompanion(
      id: Value(stateMap['id'] as String),
      startTime: Value(
        stateMap['startTime'] != null
            ? DateTime.parse(stateMap['startTime'])
            : null,
      ),
      isPaused: Value(stateMap['isPaused'] as bool),
      elapsedSeconds: Value(stateMap['elapsedSeconds'] as int),
      isActive: Value(stateMap['isActive'] as bool),
      deliveryNumber: Value(stateMap['deliveryNumber']),
      boxes: Value(stateMap['boxes'] as int? ?? 0),
    );
    await _db!
        .into(_db!.persistentDeliveryStates)
        .insertOnConflictUpdate(companion);
  }

  /// Carga el estado persistente del delivery
  Future<Map<String, dynamic>?> loadPersistentDeliveryState() async {
    _ensureInitialized();
    final stateId = UserSessionService().persistentStateId;
    final result = await (_db!.select(
      _db!.persistentDeliveryStates,
    )..where((tbl) => tbl.id.equals(stateId))).getSingleOrNull();
    if (result != null) {
      return {
        'id': result.id,
        'startTime': result.startTime?.toIso8601String(),
        'isPaused': result.isPaused,
        'elapsedSeconds': result.elapsedSeconds,
        'isActive': result.isActive,
        'deliveryNumber': result.deliveryNumber,
        'boxes': result.boxes,
      };
    }
    return null;
  }

  /// Elimina el estado persistente del delivery
  Future<void> clearPersistentDeliveryState() async {
    _ensureInitialized();
    final stateId = UserSessionService().persistentStateId;
    await (_db!.delete(
      _db!.persistentDeliveryStates,
    )..where((tbl) => tbl.id.equals(stateId))).go();
  }

  /// Sincroniza notas con Google Sheets
  Future<void> syncNotasUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    _ensureInitialized();
    final googleSheetsService = GoogleSheetsService();

    try {
      final localNotas = await getAllNotas();
      final sheetData = await googleSheetsService.getSheetData(
        spreadsheetId,
        range,
      );

      await _syncNotasData(localNotas, sheetData, spreadsheetId, range);
    } catch (e) {
      throw Exception('Error al sincronizar notas: $e');
    }
  }

  /// Método privado para sincronizar datos de notas
  Future<void> _syncNotasData(
    List<Nota> localNotas,
    List<List<Object?>> sheetData,
    String spreadsheetId,
    String range,
  ) async {
    final googleSheetsService = GoogleSheetsService();

    if (localNotas.isEmpty && sheetData.length > 1) {
      // PULL: La base de datos local está vacía, pero la remota tiene datos
      final sellerId = UserSessionService().currentSellerId;
      final dataRows = sheetData.skip(1);
      for (final row in dataRows) {
        if (row.isEmpty || row.length < 5 || row[0] == null) continue;
        try {
          final nota = NotasCompanion(
            id: Value(int.parse(row[0].toString())),
            nota: Value(row[1].toString()),
            clientId: Value(int.parse(row[2].toString())),
            ventaId: Value(int.tryParse(row[3].toString())),
            color: Value(row[4].toString()),
            sellerId: Value(sellerId),
          );
          await _db!.into(_db!.notas).insertOnConflictUpdate(nota);
        } catch (e) {
          print('Error procesando fila de nota: $row, error: $e');
        }
      }
    } else if (localNotas.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final updatedData = <List<Object?>>[];
      if (sheetData.isNotEmpty) {
        updatedData.add(sheetData[0]); // Conservar cabeceras existentes
      } else {
        // Si no hay cabeceras, agregar las cabeceras por defecto
        updatedData.add(['id', 'nota', 'client_id', 'venta_id', 'color']);
      }

      for (var nota in localNotas) {
        updatedData.add([
          nota.id,
          nota.nota,
          nota.clientId,
          nota.ventaId ?? '',
          nota.color,
        ]);
      }

      await googleSheetsService.updateSheetData(
        spreadsheetId,
        range,
        updatedData,
      );
    }
  }

  /// Sincroniza interacciones con Google Sheets
  Future<void> syncInteraccionesUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    _ensureInitialized();
    final googleSheetsService = GoogleSheetsService();

    try {
      final localInteracciones = await getAllInteracciones();
      final sheetData = await googleSheetsService.getSheetData(
        spreadsheetId,
        range,
      );

      await _syncInteraccionesData(
        localInteracciones,
        sheetData,
        spreadsheetId,
        range,
      );
    } catch (e) {
      throw Exception('Error al sincronizar interacciones: $e');
    }
  }

  // ===== OPERACIONES DE USUARIOS =====

  /// Obtiene todos los usuarios activos
  Future<List<Usuario>> getAllUsuarios() async {
    _ensureInitialized();
    return await _db!.getAllUsuarios();
  }

  /// Obtiene un usuario por ID
  Future<Usuario?> getUsuarioById(int id) async {
    _ensureInitialized();
    return await _db!.getUsuarioById(id);
  }

  /// Inserta o actualiza un usuario
  Future<int> insertUsuario({
    required int id,
    required String nombre,
    String? ciudad,
    bool activo = true,
  }) async {
    _ensureInitialized();
    return await _db!.insertUsuario(
      id: id,
      nombre: nombre,
      ciudad: ciudad,
      activo: activo,
    );
  }

  // ===== OPERACIONES DE GASTOS =====

  /// Inserta un nuevo gasto
  Future<int> insertGasto({
    int? id,
    required DateTime fecha,
    required String concepto,
    required double monto,
    required String categoria,
  }) async {
    _ensureInitialized();
    return await _db!.insertGasto(
      id: id,
      sellerId: UserSessionService().currentSellerId,
      fecha: fecha,
      concepto: concepto,
      monto: monto,
      categoria: categoria,
    );
  }

  /// Obtiene todos los gastos del usuario actual
  Future<List<Gasto>> getAllGastos() async {
    _ensureInitialized();
    return await _db!.getAllGastosBySeller(
      UserSessionService().currentSellerId,
    );
  }

  /// Obtiene un gasto por ID
  Future<Gasto?> getGastoById(int id) async {
    _ensureInitialized();
    return await _db!.getGastoById(id);
  }

  /// Actualiza un gasto existente
  Future<int> updateGasto({
    required int id,
    required DateTime fecha,
    required String concepto,
    required double monto,
    required String categoria,
  }) async {
    _ensureInitialized();
    return await _db!.updateGasto(
      id: id,
      fecha: fecha,
      concepto: concepto,
      monto: monto,
      categoria: categoria,
    );
  }

  /// Elimina un gasto por ID
  Future<int> deleteGasto(int id) async {
    _ensureInitialized();
    return await _db!.deleteGasto(id);
  }

  /// Elimina todos los gastos
  Future<void> deleteAllGastos() async {
    _ensureInitialized();
    await _db!.delete(_db!.gastos).go();
  }

  /// Sincroniza gastos con Google Sheets
  Future<void> syncGastosUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    _ensureInitialized();
    final googleSheetsService = GoogleSheetsService();

    try {
      final localGastos = await getAllGastos();
      final sheetData = await googleSheetsService.getSheetData(
        spreadsheetId,
        range,
      );

      await _syncGastosData(localGastos, sheetData, spreadsheetId, range);
    } catch (e) {
      throw Exception('Error al sincronizar gastos: $e');
    }
  }

  /// Método privado para sincronizar datos de gastos
  Future<void> _syncGastosData(
    List<Gasto> localGastos,
    List<List<Object?>> sheetData,
    String spreadsheetId,
    String range,
  ) async {
    final googleSheetsService = GoogleSheetsService();

    if (localGastos.isEmpty && sheetData.length > 1) {
      // PULL: La base de datos local está vacía, pero la remota tiene datos
      final dataRows = sheetData.skip(1);
      for (final row in dataRows) {
        if (row.isEmpty || row.length < 6 || row[0] == null) continue;
        // Solo importar filas del usuario actual
        if (!_rowBelongsToCurrentSeller(row, _gastosSellerColumn)) continue;
        try {
          final gasto = GastosCompanion(
            id: Value(int.parse(row[0].toString())),
            sellerId: Value(
              sellerIdOfRow(row, _gastosSellerColumn) ?? kLegacySellerId,
            ),
            fecha: Value(DateTime.tryParse(row[2].toString()) ?? DateTime.now()),
            concepto: Value(row[3].toString()),
            monto: Value(double.tryParse(row[4].toString()) ?? 0.0),
            categoria: Value(row[5].toString()),
          );
          await _db!.into(_db!.gastos).insertOnConflictUpdate(gasto);
        } catch (e) {
          print('Error procesando fila de gasto: $row, error: $e');
        }
      }
    } else if (localGastos.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final localRows = <List<Object?>>[];
      for (var gasto in localGastos) {
        localRows.add([
          gasto.id,
          gasto.sellerId,
          gasto.fecha.toString(),
          gasto.concepto,
          gasto.monto,
          gasto.categoria,
        ]);
      }

      await _pushSellerRows(
        googleSheetsService: googleSheetsService,
        spreadsheetId: spreadsheetId,
        range: range,
        sheetData: sheetData,
        headerDefaults: _gastosHeader,
        sellerColumnIndex: _gastosSellerColumn,
        localRows: localRows,
      );
    }
  }

  /// Sincroniza usuarios con Google Sheets
  Future<void> syncUsuariosUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    _ensureInitialized();
    final googleSheetsService = GoogleSheetsService();

    try {
      final localUsuarios = await getAllUsuarios();
      final sheetData = await googleSheetsService.getSheetData(
        spreadsheetId,
        range,
      );

      await _syncUsuariosData(localUsuarios, sheetData, spreadsheetId, range);
    } catch (e) {
      throw Exception('Error al sincronizar usuarios: $e');
    }
  }

  /// Método privado para sincronizar datos de usuarios
  Future<void> _syncUsuariosData(
    List<Usuario> localUsuarios,
    List<List<Object?>> sheetData,
    String spreadsheetId,
    String range,
  ) async {
    final googleSheetsService = GoogleSheetsService();

    if (localUsuarios.isEmpty && sheetData.length > 1) {
      // PULL: La base de datos local está vacía, pero la remota tiene datos
      final dataRows = sheetData.skip(1);
      for (final row in dataRows) {
        if (row.isEmpty || row.length < 4 || row[0] == null) continue;
        try {
          final usuario = UsuariosCompanion(
            id: Value(int.parse(row[0].toString())),
            nombre: Value(row[1].toString()),
            ciudad: Value(row[2].toString().isEmpty ? null : row[2].toString()),
            activo: Value(row[3].toString().toLowerCase() == 'true'),
          );
          await _db!.into(_db!.usuarios).insertOnConflictUpdate(usuario);
        } catch (e) {
          print('Error procesando fila de usuario: $row, error: $e');
        }
      }
    } else if (localUsuarios.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final updatedData = <List<Object?>>[];
      if (sheetData.isNotEmpty) {
        updatedData.add(sheetData[0]); // Conservar cabeceras existentes
      } else {
        updatedData.add(['id', 'nombre', 'ciudad', 'activo']);
      }

      for (var usuario in localUsuarios) {
        updatedData.add([
          usuario.id,
          usuario.nombre,
          usuario.ciudad ?? '',
          usuario.activo,
        ]);
      }

      await googleSheetsService.updateSheetData(
        spreadsheetId,
        range,
        updatedData,
      );
    }
  }

  /// Método privado para sincronizar datos de interacciones
  Future<void> _syncInteraccionesData(
    List<Interaccione> localInteracciones,
    List<List<Object?>> sheetData,
    String spreadsheetId,
    String range,
  ) async {
    final googleSheetsService = GoogleSheetsService();

    if (localInteracciones.isEmpty && sheetData.length > 1) {
      // PULL: La base de datos local está vacía, pero la remota tiene datos
      final dataRows = sheetData.skip(1);
      for (final row in dataRows) {
        if (row.isEmpty || row.length < 5 || row[0] == null) continue;
        try {
          final interaccion = InteraccionesCompanion(
            id: Value(int.parse(row[0].toString())),
            clientId: Value(int.parse(row[1].toString())),
            result: Value(row[2].toString()),
            deliveryId: Value(int.parse(row[3].toString())),
            timestamp: Value(
              DateTime.tryParse(row[4].toString()) ?? DateTime.now(),
            ),
          );
          await _db!
              .into(_db!.interacciones)
              .insertOnConflictUpdate(interaccion);
        } catch (e) {
          print('Error procesando fila de interacción: $row, error: $e');
        }
      }
    } else if (localInteracciones.isNotEmpty) {
      // PUSH: La base de datos local tiene datos, se envían a la remota
      final updatedData = <List<Object?>>[];
      if (sheetData.isNotEmpty) {
        updatedData.add(sheetData[0]); // Conservar cabeceras existentes
      } else {
        // Si no hay cabeceras, agregar las cabeceras por defecto
        updatedData.add([
          'id',
          'client_id',
          'result',
          'delivery_id',
          'timestamp',
        ]);
      }

      for (var interaccion in localInteracciones) {
        updatedData.add([
          interaccion.id,
          interaccion.clientId,
          interaccion.result,
          interaccion.deliveryId,
          interaccion.timestamp.toString(),
        ]);
      }

      await googleSheetsService.updateSheetData(
        spreadsheetId,
        range,
        updatedData,
      );
    }
  }
}
