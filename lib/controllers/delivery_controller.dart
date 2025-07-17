import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/delivery_state.dart';
import '../data/database.dart';
import '../pages/section_delivery/delivery_record.dart';
import '../services/delivery_service.dart';

class DeliveryController with ChangeNotifier {
  bool _started = false;
  bool _paused = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  List<bool> _clientesContactados = [];
  List<String> _clientesEstado = [];
  int? _selectedClienteIndex;
  List<DeliveryRecord> _deliveryRecords = [];
  final DeliveryService _deliveryService = DeliveryService();

  // Getters
  bool get started => _started;
  bool get paused => _paused;
  int get elapsedSeconds => _elapsedSeconds;
  List<bool> get clientesContactados => _clientesContactados;
  List<String> get clientesEstado => _clientesEstado;
  int? get selectedClienteIndex => _selectedClienteIndex;
  List<DeliveryRecord> get deliveryRecords => _deliveryRecords;
  String get formattedTime {
    final hours = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // Initialize controller with optional initial state parameters
  DeliveryController({
    bool started = false,
    bool paused = false,
    int elapsedSeconds = 0,
    List<bool> clientesContactados = const [],
    int? selectedClienteIndex,
  }) {
    // Load state from DeliveryStateManager if available
    final stateManager = DeliveryStateManager();
    _started = stateManager.isDeliveryActive
        ? stateManager.isDeliveryActive
        : started;
    _paused = stateManager.isDeliveryActive
        ? stateManager.isDeliveryPaused
        : paused;
    _elapsedSeconds = stateManager.isDeliveryActive
        ? stateManager.elapsedSeconds
        : elapsedSeconds;
    _clientesContactados =
        stateManager.isDeliveryActive &&
            stateManager.clientesContactados.isNotEmpty
        ? List<bool>.from(stateManager.clientesContactados)
        : List<bool>.from(clientesContactados);
    _clientesEstado =
        stateManager.isDeliveryActive && stateManager.clientesEstado.isNotEmpty
        ? List<String>.from(stateManager.clientesEstado)
        : [];
    _selectedClienteIndex = stateManager.isDeliveryActive
        ? stateManager.selectedClienteIndex
        : selectedClienteIndex;
    if (_started && !_paused) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      DeliveryStateManager().updateElapsedSeconds(_elapsedSeconds);
      notifyListeners();
    });
  }

  // Delivery control methods
  void startDelivery(int deliveryNumber) {
    _started = true;
    _paused = false;
    _elapsedSeconds = 0;
    final stateManager = DeliveryStateManager();
    stateManager.startDelivery(deliveryNumber);
    stateManager.updateClientesContactados(_clientesContactados);
    stateManager.updateClientesEstado(_clientesEstado);
    stateManager.updateSelectedClienteIndex(_selectedClienteIndex);
    _startTimer();
    notifyListeners();
  }

  void pauseDelivery() {
    _paused = true;
    final stateManager = DeliveryStateManager();
    stateManager.pauseDelivery();
    stateManager.updateElapsedSeconds(_elapsedSeconds);
    _timer?.cancel();
    notifyListeners();
  }

  void resumeDelivery() {
    _paused = false;
    final stateManager = DeliveryStateManager();
    stateManager.resumeDelivery();
    stateManager.updateElapsedSeconds(_elapsedSeconds);
    _startTimer();
    notifyListeners();
  }

  void endDelivery(List<Cliente> clientes) async {
    _started = false;
    _paused = false;
    final stateManager = DeliveryStateManager();
    
    // Get delivery number
    final deliveryNumber = stateManager.getCurrentDeliveryNumber() ?? 
        (_deliveryRecords.length + 1);
    
    // Calculate statistics from sales associated with this delivery
    double totalKilograms = 0.0;
    double totalAmount = 0.0;
    
    try {
      final sales = await _deliveryService.getSalesByDeliveryNumber(deliveryNumber);
      
      for (var sale in sales) {
        totalKilograms += sale.quantity;
        totalAmount += sale.total;
      }
      
      // Calculate average price per kilo
      double avgPricePerKilo = 0.0;
      if (totalKilograms > 0) {
        avgPricePerKilo = totalAmount / totalKilograms;
      }
      
      final record = DeliveryRecord(
        deliveryNumber: deliveryNumber,
        date: DateTime.now(),
        duration: Duration(seconds: _elapsedSeconds),
        avgPrice: avgPricePerKilo,
        kilograms: totalKilograms,
        boxes: 0, // Placeholder - can be calculated if needed
        remaining: 0.0, // Placeholder - can be calculated if needed
        seller: "Default Seller", // Placeholder - can be set based on user
        total: totalAmount,
      );
      
      _deliveryRecords.add(record);
      await _deliveryService.saveDeliveryToDatabase(record);
      await _deliveryService.saveContactResultsToDatabase(
        record.deliveryNumber,
        clientes,
        _clientesContactados,
        _clientesEstado,
      );
    } catch (e) {
      debugPrint('Error calculating delivery statistics: $e');
      
      // Fallback to empty record if there's an error
      final record = DeliveryRecord(
        deliveryNumber: deliveryNumber,
        date: DateTime.now(),
        duration: Duration(seconds: _elapsedSeconds),
        avgPrice: 0.0,
        kilograms: 0.0,
        boxes: 0,
        remaining: 0.0,
        seller: "Default Seller",
        total: 0.0,
      );
      
      _deliveryRecords.add(record);
      await _deliveryService.saveDeliveryToDatabase(record);
      await _deliveryService.saveContactResultsToDatabase(
        record.deliveryNumber,
        clientes,
        _clientesContactados,
        _clientesEstado,
      );
    }
    
    _elapsedSeconds = 0;
    _clientesContactados = List.generate(clientes.length, (_) => false);
    _clientesEstado = List.generate(clientes.length, (_) => '');
    _selectedClienteIndex = null;
    stateManager.endDelivery();
    _timer?.cancel();
    notifyListeners();
  }

  // Client interaction methods
  void selectCliente(int index) {
    _selectedClienteIndex = index;
    DeliveryStateManager().updateSelectedClienteIndex(index);
    notifyListeners();
  }

  void updateContactoStatus(int index, bool contactado, String estado) {
    _clientesContactados[index] = contactado;
    _clientesEstado[index] = estado;
    final stateManager = DeliveryStateManager();
    stateManager.updateClientesContactados(_clientesContactados);
    stateManager.updateClientesEstado(_clientesEstado);
    debugPrint(
      'Estado actualizado para cliente $index: $estado, Contactado: $contactado',
    );
    notifyListeners();
  }

  // Initialize client lists based on loaded clients
  void initializeClients(int length) {
    final stateManager = DeliveryStateManager();
    if (stateManager.clientesContactados.isEmpty ||
        stateManager.clientesContactados.length != length) {
      _clientesContactados = List.generate(length, (_) => false);
      stateManager.updateClientesContactados(_clientesContactados);
    } else {
      _clientesContactados = List<bool>.from(stateManager.clientesContactados);
    }
    if (stateManager.clientesEstado.isEmpty ||
        stateManager.clientesEstado.length != length) {
      _clientesEstado = List.generate(length, (_) => '');
      stateManager.updateClientesEstado(_clientesEstado);
    } else {
      _clientesEstado = List<String>.from(stateManager.clientesEstado);
    }
    notifyListeners();
  }

  // Load data from service
  Future<void> loadClientes() async {
    final clientes = await _deliveryService.loadClientes();
    initializeClients(clientes.length);
    notifyListeners();
  }

  Future<void> loadDeliveryRecords() async {
    _deliveryRecords = await _deliveryService.loadDeliveryRecords();
    notifyListeners();
  }

  Future<void> deleteDeliveryRecords() async {
    await _deliveryService.deleteDeliveryRecords();
    _deliveryRecords.clear();
    notifyListeners();
  }

  Future<void> debugContactos() async {
    final contactos = await _deliveryService.debugContactos();
    debugPrint('Últimos 10 registros de Contactos:');
    if (contactos.isEmpty) {
      debugPrint('No hay registros de contactos.');
    } else {
      for (var contacto in contactos) {
        debugPrint('ID: ${contacto.id}');
        debugPrint('Client ID: ${contacto.clientId}');
        debugPrint('Resultado: ${contacto.result}');
        debugPrint('Delivery ID: ${contacto.deliveryId}');
        debugPrint('---');
      }
    }
    debugPrint('Estado actual de clientesEstado:');
    for (int i = 0; i < _clientesEstado.length; i++) {
      if (_clientesEstado[i].isNotEmpty) {
        debugPrint(
          'Cliente index $i: ${_clientesEstado[i]} (Contactado: ${_clientesContactados[i]})',
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
