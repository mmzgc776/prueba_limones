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

  Future<List<List<Object?>>?> fetchClientData(
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
      return response.values;
    } catch (e) {
      print('Error fetching data from Google Sheets: $e');
      return null;
    }
  }

  Future<void> updateClientData(
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

  Future<List<List<Object?>>?> fetchDeliveryData(
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
      print('Raw delivery data from Google Sheets: ${response.values}');
      return response.values;
    } catch (e) {
      print('Error fetching delivery data from Google Sheets: $e');
      return null;
    }
  }

  Future<void> updateDeliveryData(
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
      print('Delivery data updated in Google Sheets: $data');
    } catch (e) {
      print('Error updating delivery data to Google Sheets: $e');
      throw Exception('Failed to update delivery data to Google Sheets: $e');
    }
  }

  Future<List<List<Object?>>?> fetchSalesData(
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
      print('Raw sales data from Google Sheets: ${response.values}');
      return response.values;
    } catch (e) {
      print('Error fetching sales data from Google Sheets: $e');
      return null;
    }
  }

  Future<void> updateSalesData(
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
      print('Sales data updated in Google Sheets: $data');
    } catch (e) {
      print('Error updating sales data to Google Sheets: $e');
      throw Exception('Failed to update sales data to Google Sheets: $e');
    }
  }
}
