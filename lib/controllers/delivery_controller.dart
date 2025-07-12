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
    _started = started;
    _paused = paused;
    _elapsedSeconds = elapsedSeconds;
    _clientesContactados = List<bool>.from(clientesContactados);
    _selectedClienteIndex = selectedClienteIndex;
    if (_started && !_paused) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  // Delivery control methods
  void startDelivery(int deliveryNumber) {
    _started = true;
    _paused = false;
    _elapsedSeconds = 0;
    DeliveryStateManager().startDelivery(deliveryNumber);
    _startTimer();
    notifyListeners();
  }

  void pauseDelivery() {
    _paused = true;
    DeliveryStateManager().pauseDelivery();
    _timer?.cancel();
    notifyListeners();
  }

  void resumeDelivery() {
    _paused = false;
    DeliveryStateManager().resumeDelivery();
    _startTimer();
    notifyListeners();
  }

  void endDelivery(List<Cliente> clientes) {
    _started = false;
    _paused = false;
    final record = DeliveryRecord(
      deliveryNumber:
          DeliveryStateManager().getCurrentDeliveryNumber() ??
          (_deliveryRecords.length + 1),
      date: DateTime.now(),
      duration: Duration(seconds: _elapsedSeconds),
      avgPrice: 0.0, // Placeholder
      kilograms: 0.0, // Placeholder
      boxes: 0, // Placeholder
      remaining: 0.0, // Placeholder
      seller: "Default Seller", // Placeholder
      total: 0.0, // Placeholder
    );
    _deliveryRecords.add(record);
    _deliveryService.saveDeliveryToDatabase(record);
    _deliveryService.saveContactResultsToDatabase(
      record.deliveryNumber,
      clientes,
      _clientesContactados,
      _clientesEstado,
    );
    _elapsedSeconds = 0;
    _clientesContactados = List.generate(clientes.length, (_) => false);
    _clientesEstado = List.generate(clientes.length, (_) => '');
    _selectedClienteIndex = null;
    DeliveryStateManager().endDelivery();
    _timer?.cancel();
    notifyListeners();
  }

  // Client interaction methods
  void selectCliente(int index) {
    _selectedClienteIndex = index;
    notifyListeners();
  }

  void updateContactoStatus(int index, bool contactado, String estado) {
    _clientesContactados[index] = contactado;
    _clientesEstado[index] = estado;
    debugPrint(
      'Estado actualizado para cliente $index: $estado, Contactado: $contactado',
    );
    notifyListeners();
  }

  // Initialize client lists based on loaded clients
  void initializeClients(int length) {
    _clientesContactados = List.generate(length, (_) => false);
    _clientesEstado = List.generate(length, (_) => '');
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
