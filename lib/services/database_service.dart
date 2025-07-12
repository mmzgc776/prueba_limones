import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/database.dart';
import 'google_sheets_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static AppDatabase? _db;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  Future<void> init() async {
    if (!_isInitialized) {
      if (_initializationFuture == null) {
        _initializationFuture = _initializeDatabase();
      }
      await _initializationFuture;
    }
  }

  Future<void> _initializeDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'app.sqlite'));
    _db = AppDatabase(NativeDatabase(dbFile));
    _isInitialized = true;
  }

  Future<int> insertSale({
    required DateTime date,
    required int clientId,
    required double quantity,
    required double price,
    required double total,
    int? notesId,
    int? deliveryNumber,
  }) async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    return await _db!.insertSale(
      date: date,
      clientId: clientId,
      quantity: quantity,
      price: price,
      total: total,
      notesId: notesId,
      deliveryNumber: deliveryNumber,
    );
  }

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
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
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

  Future<List<Sale>> getAllSales() async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    return await _db!.select(_db!.sales).get();
  }

  Future<List<Delivery>> getAllDeliveries() async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    return await _db!.select(_db!.deliveries).get();
  }

  Future<void> deleteAllSales() async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    await _db!.delete(_db!.sales).go();
  }

  Future<void> deleteAllDeliveries() async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    await _db!.delete(_db!.deliveries).go();
  }

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
  }) async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
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
    );
  }

  Future<List<Cliente>> getAllClientes() async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    return await _db!.select(_db!.clientes).get();
  }

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
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    return await _db!.updateCliente(
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
      dias: dias,
    );
  }

  Future<void> deleteAllClientes() async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    await _db!.delete(_db!.clientes).go();
  }

  Future<int> insertContacto({
    required int clientId,
    required String result,
    required int deliveryId,
  }) async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    return await _db!.insertContacto(
      clientId: clientId,
      result: result,
      deliveryId: deliveryId,
    );
  }

  Future<List<Contacto>> getLast10Contactos() async {
    if (!_isInitialized || _db == null)
      throw Exception('Database not initialized');
    return await (_db!.select(_db!.contactos)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(10))
        .get();
  }

  Future<void> syncClientesFromGoogleSheets({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    if (!_isInitialized || _db == null) {
      throw Exception('Database not initialized');
    }

    final googleSheetsService = GoogleSheetsService();
    await googleSheetsService.init(context);
    final clientData = await googleSheetsService.fetchClientData(
      spreadsheetId,
      range,
    );

    if (clientData != null && clientData.isNotEmpty) {
      print('Processing client data from Google Sheets: $clientData');
      // Get local clients for comparison
      final localClientes = await getAllClientes();
      final localClientMap = <int, Cliente>{};
      for (var cliente in localClientes) {
        localClientMap[cliente.id] = cliente;
      }

      // Assuming the first row is headers, skip it
      for (var i = 1; i < clientData.length; i++) {
        final row = clientData[i];
        print('Processing row $i: $row');
        // Map the data from Google Sheets to Cliente fields
        try {
          final sheetId = row.length > 0 && row[0].toString().isNotEmpty
              ? int.tryParse(row[0].toString())
              : null;
          final sheetUltimoContacto = row.length > 9
              ? DateTime.tryParse(row[9].toString())
              : null;

          if (sheetId != null && localClientMap.containsKey(sheetId)) {
            // Client exists locally, compare "Ultimo contacto"
            final localCliente = localClientMap[sheetId]!;
            final localUltimoContacto = localCliente.ultimoContacto;

            if (sheetUltimoContacto != null) {
              if (sheetUltimoContacto.isAfter(localUltimoContacto)) {
                // Sheets data is more recent, update local
                await updateCliente(
                  id: sheetId,
                  nombre: row.length > 1 ? row[1].toString() : 'Sin Nombre',
                  contacto: row.length > 2 ? row[2].toString() : 'Sin Contacto',
                  tipoNegocio: row.length > 3 ? row[3].toString() : 'Sin Tipo',
                  ciudad: row.length > 4 ? row[4].toString() : 'Sin Ciudad',
                  domicilio: row.length > 5
                      ? row[5].toString()
                      : 'Sin Domicilio',
                  ubicacion: row.length > 6
                      ? row[6].toString()
                      : 'Sin Ubicación',
                  telefono: row.length > 7 ? row[7].toString() : 'Sin Teléfono',
                  consumo: row.length > 8
                      ? int.tryParse(row[8].toString()) ?? 0
                      : 0,
                  ultimoContacto: sheetUltimoContacto,
                  horaInicio: row.length > 10
                      ? int.tryParse(row[10].toString()) ?? 0
                      : 0,
                  horaCierre: row.length > 11
                      ? int.tryParse(row[11].toString()) ?? 0
                      : 0,
                  dias: row.length > 13 ? row[13].toString() : 'Sin Días',
                );
                print(
                  'Updated local client ID $sheetId from Sheets (more recent).',
                );
              } else if (localUltimoContacto.isAfter(sheetUltimoContacto)) {
                // Local data is more recent, do nothing in this direction
                print(
                  'Local client ID $sheetId is more recent, no update from Sheets.',
                );
              } else {
                // Dates are equal, no update needed
                print(
                  'Client ID $sheetId has equal Ultimo contacto, no update needed.',
                );
              }
            }
          } else {
            // New client from Sheets, insert into local database
            await insertCliente(
              id: sheetId,
              nombre: row.length > 1 ? row[1].toString() : 'Sin Nombre',
              contacto: row.length > 2 ? row[2].toString() : 'Sin Contacto',
              tipoNegocio: row.length > 3 ? row[3].toString() : 'Sin Tipo',
              ciudad: row.length > 4 ? row[4].toString() : 'Sin Ciudad',
              domicilio: row.length > 5 ? row[5].toString() : 'Sin Domicilio',
              ubicacion: row.length > 6 ? row[6].toString() : 'Sin Ubicación',
              telefono: row.length > 7 ? row[7].toString() : 'Sin Teléfono',
              consumo: row.length > 8
                  ? int.tryParse(row[8].toString()) ?? 0
                  : 0,
              ultimoContacto: row.length > 9
                  ? DateTime.tryParse(row[9].toString()) ?? DateTime.now()
                  : DateTime.now(),
              horaInicio: row.length > 10
                  ? int.tryParse(row[10].toString()) ?? 0
                  : 0,
              horaCierre: row.length > 11
                  ? int.tryParse(row[11].toString()) ?? 0
                  : 0,
              notasId: row.length > 12 && row[12].toString().isNotEmpty
                  ? int.tryParse(row[12].toString())
                  : null,
              dias: row.length > 13 ? row[13].toString() : 'Sin Días',
            );
            print('Inserted new client ID $sheetId from Sheets.');
          }
        } catch (e) {
          print('Error processing client from row $i: $e');
        }
      }
    }
  }

  Future<void> syncClientesToGoogleSheets({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    if (!_isInitialized || _db == null) {
      throw Exception('Database not initialized');
    }

    final googleSheetsService = GoogleSheetsService();
    await googleSheetsService.init(context);

    // Fetch local clients
    final localClientes = await getAllClientes();
    // Fetch current data from Google Sheets for comparison
    final sheetsData = await googleSheetsService.fetchClientData(
      spreadsheetId,
      range,
    );

    if (sheetsData == null || sheetsData.isEmpty) {
      throw Exception('Failed to fetch data from Google Sheets for comparison');
    }

    // Prepare data for updating Google Sheets
    final updatedData = <List<Object?>>[];
    // Keep the header row
    updatedData.add(sheetsData[0]);

    // Map local clients to a list for easier lookup
    final localClientMap = <int, Cliente>{};
    for (var cliente in localClientes) {
      localClientMap[cliente.id] = cliente;
    }

    // Process Google Sheets data starting from row 1 (after header)
    for (var i = 1; i < sheetsData.length; i++) {
      final sheetRow = sheetsData[i];
      final sheetId = sheetRow.length > 0
          ? int.tryParse(sheetRow[0].toString())
          : null;
      final sheetUltimoContacto = sheetRow.length > 9
          ? DateTime.tryParse(sheetRow[9].toString())
          : null;

      if (sheetId != null && localClientMap.containsKey(sheetId)) {
        final localCliente = localClientMap[sheetId]!;
        final localUltimoContacto = localCliente.ultimoContacto;

        // Compare "Ultimo contacto" to decide which data to keep
        if (sheetUltimoContacto != null &&
            localUltimoContacto.isAfter(sheetUltimoContacto)) {
          // Local data is newer, update Sheets with local data
          updatedData.add(_clienteToRow(localCliente));
          print(
            'Updating Sheets with local client ID $sheetId (local more recent).',
          );
        } else if (sheetUltimoContacto != null &&
            sheetUltimoContacto.isAfter(localUltimoContacto)) {
          // Sheet data is newer, update local database
          await updateCliente(
            id: sheetId,
            nombre: sheetRow.length > 1 ? sheetRow[1].toString() : 'Sin Nombre',
            contacto: sheetRow.length > 2
                ? sheetRow[2].toString()
                : 'Sin Contacto',
            tipoNegocio: sheetRow.length > 3
                ? sheetRow[3].toString()
                : 'Sin Tipo',
            ciudad: sheetRow.length > 4 ? sheetRow[4].toString() : 'Sin Ciudad',
            domicilio: sheetRow.length > 5
                ? sheetRow[5].toString()
                : 'Sin Domicilio',
            ubicacion: sheetRow.length > 6
                ? sheetRow[6].toString()
                : 'Sin Ubicación',
            telefono: sheetRow.length > 7
                ? sheetRow[7].toString()
                : 'Sin Teléfono',
            consumo: sheetRow.length > 8
                ? int.tryParse(sheetRow[8].toString()) ?? 0
                : 0,
            ultimoContacto: sheetUltimoContacto,
            horaInicio: sheetRow.length > 10
                ? int.tryParse(sheetRow[10].toString()) ?? 0
                : 0,
            horaCierre: sheetRow.length > 11
                ? int.tryParse(sheetRow[11].toString()) ?? 0
                : 0,
            dias: sheetRow.length > 13 ? sheetRow[13].toString() : 'Sin Días',
          );
          updatedData.add(sheetRow);
          print(
            'Updated local client ID $sheetId from Sheets (Sheets more recent).',
          );
        } else {
          // Same timestamp, no update needed
          updatedData.add(sheetRow);
          print(
            'Client ID $sheetId has equal Ultimo contacto, no update needed.',
          );
        }
      } else {
        // No matching local client or empty ID, keep sheet data
        updatedData.add(sheetRow);
      }
    }

    // Add any local clients that are not in Google Sheets
    for (var cliente in localClientes) {
      if (!sheetsData.any(
        (row) =>
            row.length > 0 && int.tryParse(row[0].toString()) == cliente.id,
      )) {
        updatedData.add(_clienteToRow(cliente));
        print('Added new local client ID ${cliente.id} to Sheets.');
      }
    }

    // Update Google Sheets with the merged data
    await googleSheetsService.updateClientData(
      spreadsheetId,
      range,
      updatedData,
    );
  }

  Future<void> syncDeliveriesUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    if (!_isInitialized || _db == null) {
      throw Exception('Database not initialized');
    }

    final googleSheetsService = GoogleSheetsService();
    await googleSheetsService.init(context);

    // Fetch local deliveries
    final localDeliveries = await getAllDeliveries();
    // Fetch current data from Google Sheets for comparison
    final sheetsData = await googleSheetsService.fetchDeliveryData(
      spreadsheetId,
      range,
    );

    if (sheetsData == null || sheetsData.isEmpty) {
      throw Exception('Failed to fetch data from Google Sheets for comparison');
    }

    // Prepare data for updating Google Sheets
    final updatedData = <List<Object?>>[];
    // Keep the header row
    updatedData.add(sheetsData[0]);

    // Map local deliveries to a list for easier lookup
    final localDeliveryMap = <int, Delivery>{};
    for (var delivery in localDeliveries) {
      localDeliveryMap[delivery.deliveryNumber] = delivery;
    }

    // Map sheets data to a list for easier lookup
    final sheetsDeliveryMap = <int, List<Object?>>{};
    for (var i = 1; i < sheetsData.length; i++) {
      final row = sheetsData[i];
      final sheetDeliveryNumber = row.length > 0 && row[0].toString().isNotEmpty
          ? int.tryParse(row[0].toString())
          : null;
      if (sheetDeliveryNumber != null) {
        sheetsDeliveryMap[sheetDeliveryNumber] = row;
      }
    }

    // Process Google Sheets data for updates to local database
    for (var i = 1; i < sheetsData.length; i++) {
      final sheetRow = sheetsData[i];
      final sheetDeliveryNumber =
          sheetRow.length > 0 && sheetRow[0].toString().isNotEmpty
          ? int.tryParse(sheetRow[0].toString())
          : null;
      final sheetDate = sheetRow.length > 1
          ? DateTime.tryParse(sheetRow[1].toString())
          : null;

      if (sheetDeliveryNumber != null) {
        if (localDeliveryMap.containsKey(sheetDeliveryNumber)) {
          final localDelivery = localDeliveryMap[sheetDeliveryNumber]!;
          final localDate = localDelivery.date;

          if (sheetDate != null) {
            print('Comparing Date for delivery number $sheetDeliveryNumber:');
            print('Sheets Date: $sheetDate');
            print('Local Date: $localDate');
            if (sheetDate.isAfter(localDate)) {
              // Sheets data is more recent, update local
              // Insert updated delivery record from Sheets
              await insertDelivery(
                deliveryNumber: sheetDeliveryNumber,
                date: sheetDate,
                durationSeconds: sheetRow.length > 2
                    ? int.tryParse(sheetRow[2].toString()) ?? 0
                    : 0,
                avgPrice: sheetRow.length > 3
                    ? double.tryParse(sheetRow[3].toString()) ?? 0.0
                    : 0.0,
                kilograms: sheetRow.length > 4
                    ? double.tryParse(sheetRow[4].toString()) ?? 0.0
                    : 0.0,
                boxes: sheetRow.length > 5
                    ? int.tryParse(sheetRow[5].toString()) ?? 0
                    : 0,
                remaining: sheetRow.length > 6
                    ? double.tryParse(sheetRow[6].toString()) ?? 0.0
                    : 0.0,
                seller: sheetRow.length > 7
                    ? sheetRow[7].toString()
                    : 'Sin Vendedor',
                total: sheetRow.length > 8
                    ? double.tryParse(sheetRow[8].toString()) ?? 0.0
                    : 0.0,
              );
              print(
                'Updated local delivery number $sheetDeliveryNumber from Sheets (Sheets more recent: $sheetDate vs $localDate).',
              );
            } else {
              print(
                'No update to local delivery number $sheetDeliveryNumber (Local not older: $localDate vs $sheetDate).',
              );
            }
          } else {
            print(
              'Sheets Date is null for delivery number $sheetDeliveryNumber, skipping comparison.',
            );
          }
          // Keep the row as is for now, will be updated in the next step if local is more recent
          updatedData.add(sheetRow);
        } else {
          // New delivery from Sheets, insert into local database
          await insertDelivery(
            deliveryNumber: sheetDeliveryNumber,
            date: sheetDate ?? DateTime.now(),
            durationSeconds: sheetRow.length > 2
                ? int.tryParse(sheetRow[2].toString()) ?? 0
                : 0,
            avgPrice: sheetRow.length > 3
                ? double.tryParse(sheetRow[3].toString()) ?? 0.0
                : 0.0,
            kilograms: sheetRow.length > 4
                ? double.tryParse(sheetRow[4].toString()) ?? 0.0
                : 0.0,
            boxes: sheetRow.length > 5
                ? int.tryParse(sheetRow[5].toString()) ?? 0
                : 0,
            remaining: sheetRow.length > 6
                ? double.tryParse(sheetRow[6].toString()) ?? 0.0
                : 0.0,
            seller: sheetRow.length > 7
                ? sheetRow[7].toString()
                : 'Sin Vendedor',
            total: sheetRow.length > 8
                ? double.tryParse(sheetRow[8].toString()) ?? 0.0
                : 0.0,
          );
          print(
            'Inserted new delivery number $sheetDeliveryNumber from Sheets.',
          );
          updatedData.add(sheetRow);
        }
      } else {
        // No delivery number or empty, keep sheet data as is
        updatedData.add(sheetRow);
      }
    }

    // Process local data to update Sheets if local is more recent or new
    for (var delivery in localDeliveries) {
      if (sheetsDeliveryMap.containsKey(delivery.deliveryNumber)) {
        final sheetRow = sheetsDeliveryMap[delivery.deliveryNumber]!;
        final sheetDate = sheetRow.length > 1
            ? DateTime.tryParse(sheetRow[1].toString())
            : null;
        final localDate = delivery.date;

        if (sheetDate != null && localDate.isAfter(sheetDate)) {
          // Local data is more recent, update Sheets
          for (var i = 1; i < updatedData.length; i++) {
            final row = updatedData[i];
            final rowDeliveryNumber =
                row.length > 0 && row[0].toString().isNotEmpty
                ? int.tryParse(row[0].toString())
                : null;
            if (rowDeliveryNumber == delivery.deliveryNumber) {
              updatedData[i] = _deliveryToRow(delivery);
              print(
                'Updated Sheets with local delivery number ${delivery.deliveryNumber} (local more recent: $localDate vs $sheetDate).',
              );
              break;
            }
          }
        } else {
          print(
            'No update to Sheets for delivery number ${delivery.deliveryNumber} (Sheets not older: ${sheetDate ?? "null"} vs $localDate).',
          );
        }
      } else {
        // New local delivery, add to Sheets
        updatedData.add(_deliveryToRow(delivery));
        print(
          'Added new local delivery number ${delivery.deliveryNumber} to Sheets.',
        );
      }
    }

    // Update Google Sheets with the merged data
    await googleSheetsService.updateDeliveryData(
      spreadsheetId,
      range,
      updatedData,
    );
  }

  List<Object?> _deliveryToRow(Delivery delivery) {
    return [
      delivery.deliveryNumber,
      delivery.date.toString(),
      delivery.durationSeconds,
      delivery.avgPrice,
      delivery.kilograms,
      delivery.boxes,
      delivery.remaining,
      delivery.seller,
      delivery.total,
    ];
  }

  Future<void> syncSalesUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    if (!_isInitialized || _db == null) {
      throw Exception('Database not initialized');
    }

    final googleSheetsService = GoogleSheetsService();
    await googleSheetsService.init(context);

    // Fetch local sales
    final localSales = await getAllSales();
    // Fetch current data from Google Sheets for comparison
    final sheetsData = await googleSheetsService.fetchSalesData(
      spreadsheetId,
      range,
    );

    if (sheetsData == null || sheetsData.isEmpty) {
      throw Exception(
        'Failed to fetch sales data from Google Sheets for comparison',
      );
    }

    // Prepare data for updating Google Sheets
    final updatedData = <List<Object?>>[];
    // Keep the header row
    updatedData.add(sheetsData[0]);

    // Map local sales to a list for easier lookup
    final localSalesMap = <int, Sale>{};
    for (var sale in localSales) {
      localSalesMap[sale.id] = sale;
    }

    // Map sheets data to a list for easier lookup
    final sheetsSalesMap = <int, List<Object?>>{};
    for (var i = 1; i < sheetsData.length; i++) {
      final row = sheetsData[i];
      final sheetId = row.length > 0 && row[0].toString().isNotEmpty
          ? int.tryParse(row[0].toString())
          : null;
      if (sheetId != null) {
        sheetsSalesMap[sheetId] = row;
      }
    }

    // Process Google Sheets data for updates to local database
    for (var i = 1; i < sheetsData.length; i++) {
      final sheetRow = sheetsData[i];
      final sheetId = sheetRow.length > 0 && sheetRow[0].toString().isNotEmpty
          ? int.tryParse(sheetRow[0].toString())
          : null;
      final sheetDate = sheetRow.length > 1
          ? DateTime.tryParse(sheetRow[1].toString())
          : null;

      if (sheetId != null) {
        if (localSalesMap.containsKey(sheetId)) {
          final localSale = localSalesMap[sheetId]!;
          final localDate = localSale.date;

          if (sheetDate != null) {
            print('Comparing Date for sale ID $sheetId:');
            print('Sheets Date: $sheetDate');
            print('Local Date: $localDate');
            if (sheetDate.isAfter(localDate)) {
              // Sheets data is more recent, update local
              await insertSale(
                date: sheetDate,
                clientId: sheetRow.length > 2
                    ? int.tryParse(sheetRow[2].toString()) ?? 0
                    : 0,
                quantity: sheetRow.length > 3
                    ? double.tryParse(sheetRow[3].toString()) ?? 0.0
                    : 0.0,
                price: sheetRow.length > 4
                    ? double.tryParse(sheetRow[4].toString()) ?? 0.0
                    : 0.0,
                total: sheetRow.length > 5
                    ? double.tryParse(sheetRow[5].toString()) ?? 0.0
                    : 0.0,
                notesId:
                    sheetRow.length > 6 && sheetRow[6].toString().isNotEmpty
                    ? int.tryParse(sheetRow[6].toString())
                    : null,
                deliveryNumber:
                    sheetRow.length > 7 && sheetRow[7].toString().isNotEmpty
                    ? int.tryParse(sheetRow[7].toString())
                    : null,
              );
              print(
                'Updated local sale ID $sheetId from Sheets (Sheets more recent: $sheetDate vs $localDate).',
              );
            } else {
              print(
                'No update to local sale ID $sheetId (Local not older: $localDate vs $sheetDate).',
              );
            }
          } else {
            print(
              'Sheets Date is null for sale ID $sheetId, skipping comparison.',
            );
          }
          // Keep the row as is for now, will be updated in the next step if local is more recent
          updatedData.add(sheetRow);
        } else {
          // New sale from Sheets, insert into local database
          await insertSale(
            date: sheetDate ?? DateTime.now(),
            clientId: sheetRow.length > 2
                ? int.tryParse(sheetRow[2].toString()) ?? 0
                : 0,
            quantity: sheetRow.length > 3
                ? double.tryParse(sheetRow[3].toString()) ?? 0.0
                : 0.0,
            price: sheetRow.length > 4
                ? double.tryParse(sheetRow[4].toString()) ?? 0.0
                : 0.0,
            total: sheetRow.length > 5
                ? double.tryParse(sheetRow[5].toString()) ?? 0.0
                : 0.0,
            notesId: sheetRow.length > 6 && sheetRow[6].toString().isNotEmpty
                ? int.tryParse(sheetRow[6].toString())
                : null,
            deliveryNumber:
                sheetRow.length > 7 && sheetRow[7].toString().isNotEmpty
                ? int.tryParse(sheetRow[7].toString())
                : null,
          );
          print('Inserted new sale ID $sheetId from Sheets.');
          updatedData.add(sheetRow);
        }
      } else {
        // No ID or empty ID, keep sheet data as is
        updatedData.add(sheetRow);
      }
    }

    // Process local data to update Sheets if local is more recent or new
    for (var sale in localSales) {
      if (sheetsSalesMap.containsKey(sale.id)) {
        final sheetRow = sheetsSalesMap[sale.id]!;
        final sheetDate = sheetRow.length > 1
            ? DateTime.tryParse(sheetRow[1].toString())
            : null;
        final localDate = sale.date;

        if (sheetDate != null && localDate.isAfter(sheetDate)) {
          // Local data is more recent, update Sheets
          for (var i = 1; i < updatedData.length; i++) {
            final row = updatedData[i];
            final rowId = row.length > 0 && row[0].toString().isNotEmpty
                ? int.tryParse(row[0].toString())
                : null;
            if (rowId == sale.id) {
              updatedData[i] = _saleToRow(sale);
              print(
                'Updated Sheets with local sale ID ${sale.id} (local more recent: $localDate vs $sheetDate).',
              );
              break;
            }
          }
        } else {
          print(
            'No update to Sheets for sale ID ${sale.id} (Sheets not older: ${sheetDate ?? "null"} vs $localDate).',
          );
        }
      } else {
        // New local sale, add to Sheets
        updatedData.add(_saleToRow(sale));
        print('Added new local sale ID ${sale.id} to Sheets.');
      }
    }

    // Update Google Sheets with the merged data
    await googleSheetsService.updateSalesData(
      spreadsheetId,
      range,
      updatedData,
    );
  }

  List<Object?> _saleToRow(Sale sale) {
    return [
      sale.id,
      sale.date.toString(),
      sale.clientId,
      sale.quantity,
      sale.price,
      sale.total,
      sale.notesId ?? '',
      sale.deliveryNumber ?? '',
    ];
  }

  Future<void> syncClientesUnified({
    required BuildContext context,
    required String spreadsheetId,
    required String range,
  }) async {
    if (!_isInitialized || _db == null) {
      throw Exception('Database not initialized');
    }

    final googleSheetsService = GoogleSheetsService();
    await googleSheetsService.init(context);

    // Fetch local clients
    final localClientes = await getAllClientes();
    // Fetch current data from Google Sheets for comparison
    final sheetsData = await googleSheetsService.fetchClientData(
      spreadsheetId,
      range,
    );

    if (sheetsData == null || sheetsData.isEmpty) {
      throw Exception('Failed to fetch data from Google Sheets for comparison');
    }

    // Prepare data for updating Google Sheets
    final updatedData = <List<Object?>>[];
    // Keep the header row
    updatedData.add(sheetsData[0]);

    // Map local clients to a list for easier lookup
    final localClientMap = <int, Cliente>{};
    for (var cliente in localClientes) {
      if (cliente.id != null) {
        localClientMap[cliente.id!] = cliente;
      }
    }

    // Map sheets data to a list for easier lookup
    final sheetsClientMap = <int, List<Object?>>{};
    for (var i = 1; i < sheetsData.length; i++) {
      final row = sheetsData[i];
      final sheetId = row.length > 0 && row[0].toString().isNotEmpty
          ? int.tryParse(row[0].toString())
          : null;
      if (sheetId != null) {
        sheetsClientMap[sheetId] = row;
      }
    }

    // Process Google Sheets data for updates to local database
    for (var i = 1; i < sheetsData.length; i++) {
      final sheetRow = sheetsData[i];
      final sheetId = sheetRow.length > 0 && sheetRow[0].toString().isNotEmpty
          ? int.tryParse(sheetRow[0].toString())
          : null;
      final sheetUltimoContacto = sheetRow.length > 9
          ? DateTime.tryParse(sheetRow[9].toString())
          : null;

      if (sheetId != null) {
        if (localClientMap.containsKey(sheetId)) {
          final localCliente = localClientMap[sheetId]!;
          final localUltimoContacto = localCliente.ultimoContacto;

          if (sheetUltimoContacto != null) {
            print('Comparing Ultimo contacto for client ID $sheetId:');
            print('Sheets Ultimo contacto: $sheetUltimoContacto');
            print('Local Ultimo contacto: $localUltimoContacto');
            if (sheetUltimoContacto.isAfter(localUltimoContacto)) {
              // Sheets data is more recent, update local
              await updateCliente(
                id: sheetId,
                nombre: sheetRow.length > 1
                    ? sheetRow[1].toString()
                    : 'Sin Nombre',
                contacto: sheetRow.length > 2
                    ? sheetRow[2].toString()
                    : 'Sin Contacto',
                tipoNegocio: sheetRow.length > 3
                    ? sheetRow[3].toString()
                    : 'Sin Tipo',
                ciudad: sheetRow.length > 4
                    ? sheetRow[4].toString()
                    : 'Sin Ciudad',
                domicilio: sheetRow.length > 5
                    ? sheetRow[5].toString()
                    : 'Sin Domicilio',
                ubicacion: sheetRow.length > 6
                    ? sheetRow[6].toString()
                    : 'Sin Ubicación',
                telefono: sheetRow.length > 7
                    ? sheetRow[7].toString()
                    : 'Sin Teléfono',
                consumo: sheetRow.length > 8
                    ? int.tryParse(sheetRow[8].toString()) ?? 0
                    : 0,
                ultimoContacto: sheetUltimoContacto,
                horaInicio: sheetRow.length > 10
                    ? int.tryParse(sheetRow[10].toString()) ?? 0
                    : 0,
                horaCierre: sheetRow.length > 11
                    ? int.tryParse(sheetRow[11].toString()) ?? 0
                    : 0,
                dias: sheetRow.length > 13
                    ? sheetRow[13].toString()
                    : 'Sin Días',
              );
              print(
                'Updated local client ID $sheetId from Sheets (Sheets more recent: $sheetUltimoContacto vs $localUltimoContacto).',
              );
            } else {
              print(
                'No update to local client ID $sheetId (Local not older: $localUltimoContacto vs $sheetUltimoContacto).',
              );
            }
          } else {
            print(
              'Sheets Ultimo contacto is null for client ID $sheetId, skipping comparison.',
            );
          }
          // Keep the row as is for now, will be updated in the next step if local is more recent
          updatedData.add(sheetRow);
        } else {
          // New client from Sheets, insert into local database
          await insertCliente(
            id: sheetId,
            nombre: sheetRow.length > 1 ? sheetRow[1].toString() : 'Sin Nombre',
            contacto: sheetRow.length > 2
                ? sheetRow[2].toString()
                : 'Sin Contacto',
            tipoNegocio: sheetRow.length > 3
                ? sheetRow[3].toString()
                : 'Sin Tipo',
            ciudad: sheetRow.length > 4 ? sheetRow[4].toString() : 'Sin Ciudad',
            domicilio: sheetRow.length > 5
                ? sheetRow[5].toString()
                : 'Sin Domicilio',
            ubicacion: sheetRow.length > 6
                ? sheetRow[6].toString()
                : 'Sin Ubicación',
            telefono: sheetRow.length > 7
                ? sheetRow[7].toString()
                : 'Sin Teléfono',
            consumo: sheetRow.length > 8
                ? int.tryParse(sheetRow[8].toString()) ?? 0
                : 0,
            ultimoContacto: sheetRow.length > 9
                ? DateTime.tryParse(sheetRow[9].toString()) ?? DateTime.now()
                : DateTime.now(),
            horaInicio: sheetRow.length > 10
                ? int.tryParse(sheetRow[10].toString()) ?? 0
                : 0,
            horaCierre: sheetRow.length > 11
                ? int.tryParse(sheetRow[11].toString()) ?? 0
                : 0,
            notasId: sheetRow.length > 12 && sheetRow[12].toString().isNotEmpty
                ? int.tryParse(sheetRow[12].toString())
                : null,
            dias: sheetRow.length > 13 ? sheetRow[13].toString() : 'Sin Días',
          );
          print('Inserted new client ID $sheetId from Sheets.');
          updatedData.add(sheetRow);
        }
      } else {
        // No ID or empty ID, keep sheet data as is
        updatedData.add(sheetRow);
      }
    }

    // Process local data to update Sheets if local is more recent or new
    for (var cliente in localClientes) {
      if (cliente.id != null) {
        if (sheetsClientMap.containsKey(cliente.id)) {
          final sheetRow = sheetsClientMap[cliente.id]!;
          final sheetUltimoContacto = sheetRow.length > 9
              ? DateTime.tryParse(sheetRow[9].toString())
              : null;
          final localUltimoContacto = cliente.ultimoContacto;

          if (sheetUltimoContacto != null &&
              localUltimoContacto.isAfter(sheetUltimoContacto)) {
            // Local data is more recent, update Sheets
            // Find the index in updatedData to replace
            for (var i = 1; i < updatedData.length; i++) {
              final row = updatedData[i];
              final rowId = row.length > 0 && row[0].toString().isNotEmpty
                  ? int.tryParse(row[0].toString())
                  : null;
              if (rowId == cliente.id) {
                updatedData[i] = _clienteToRow(cliente);
                print(
                  'Updated Sheets with local client ID ${cliente.id} (local more recent: $localUltimoContacto vs $sheetUltimoContacto).',
                );
                break;
              }
            }
          } else {
            print(
              'No update to Sheets for client ID ${cliente.id} (Sheets not older: ${sheetUltimoContacto ?? "null"} vs $localUltimoContacto).',
            );
          }
        } else {
          // New local client, add to Sheets
          updatedData.add(_clienteToRow(cliente));
          print('Added new local client ID ${cliente.id} to Sheets.');
        }
      }
    }

    // Update Google Sheets with the merged data
    await googleSheetsService.updateClientData(
      spreadsheetId,
      range,
      updatedData,
    );
  }

  List<Object?> _clienteToRow(Cliente cliente) {
    return [
      cliente.id,
      cliente.nombre,
      cliente.contacto,
      cliente.tipoNegocio,
      cliente.ciudad,
      cliente.domicilio,
      cliente.ubicacion,
      cliente.telefono,
      cliente.consumo,
      cliente.ultimoContacto
          .toString(), // Use a readable format for Google Sheets
      cliente.horaInicio,
      cliente.horaCierre,
      cliente.notasId ?? '',
      cliente.dias,
    ];
  }

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

  Future<void> close() async {
    if (_isInitialized && _db != null) {
      await _db!.close();
      _db = null;
      _isInitialized = false;
    }
  }
}
