import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleSheetsService {
  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  static SheetsApi? _sheetsApi;

  factory GoogleSheetsService() {
    return _instance;
  }

  GoogleSheetsService._internal();

  bool _isInitialized = false;

  Future<void> init(BuildContext context) async {
    if (!_isInitialized) {
      // Load credentials from the JSON file
      final credentialsJson = await DefaultAssetBundle.of(
        context,
      ).loadString('lib/services/credentials.json');
      final credentialsMap = jsonDecode(credentialsJson);
      final credentials = ServiceAccountCredentials.fromJson(credentialsMap);

      final client = await clientViaServiceAccount(credentials, [
        SheetsApi.spreadsheetsScope,
      ]);

      _sheetsApi = SheetsApi(client);
      _isInitialized = true;
    }
  }

  /// Método genérico para obtener datos de una hoja
  Future<List<List<Object?>>> getSheetData(
    String spreadsheetId,
    String range,
  ) async {
    if (!_isInitialized || _sheetsApi == null) {
      throw Exception('Google Sheets API not initialized');
    }

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        range,
      );
      print('Raw data from Google Sheets: ${response.values}');
      return response.values ?? [];
    } catch (e) {
      print('Error fetching data from Google Sheets: $e');
      return [];
    }
  }

  /// Método genérico para actualizar datos en una hoja
  Future<void> updateSheetData(
    String spreadsheetId,
    String range,
    List<List<Object?>> data,
  ) async {
    if (!_isInitialized || _sheetsApi == null) {
      throw Exception('Google Sheets API not initialized');
    }

    try {
      final valueRange = ValueRange(values: data);
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
      print('Data updated in Google Sheets: $data');
    } catch (e) {
      print('Error updating data to Google Sheets: $e');
      throw Exception('Failed to update data to Google Sheets: $e');
    }
  }

  /// Obtiene datos de clientes (mantenido por compatibilidad)
  Future<List<List<Object?>>?> fetchClientData(
    String spreadsheetId,
    String range,
  ) async {
    return await getSheetData(spreadsheetId, range);
  }

  /// Actualiza datos de clientes (mantenido por compatibilidad)
  Future<void> updateClientData(
    String spreadsheetId,
    String range,
    List<List<Object?>> data,
  ) async {
    await updateSheetData(spreadsheetId, range, data);
  }

  /// Obtiene datos de repartos (mantenido por compatibilidad)
  Future<List<List<Object?>>?> fetchDeliveryData(
    String spreadsheetId,
    String range,
  ) async {
    return await getSheetData(spreadsheetId, range);
  }

  /// Actualiza datos de repartos (mantenido por compatibilidad)
  Future<void> updateDeliveryData(
    String spreadsheetId,
    String range,
    List<List<Object?>> data,
  ) async {
    await updateSheetData(spreadsheetId, range, data);
  }

  /// Obtiene datos de ventas (mantenido por compatibilidad)
  Future<List<List<Object?>>?> fetchSalesData(
    String spreadsheetId,
    String range,
  ) async {
    return await getSheetData(spreadsheetId, range);
  }

  /// Actualiza datos de ventas (mantenido por compatibilidad)
  Future<void> updateSalesData(
    String spreadsheetId,
    String range,
    List<List<Object?>> data,
  ) async {
    await updateSheetData(spreadsheetId, range, data);
  }
}
