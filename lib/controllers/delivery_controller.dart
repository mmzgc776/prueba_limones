import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/delivery_state.dart';
import '../data/database.dart';
import '../pages/section_delivery/delivery_record.dart';
import '../services/delivery_service.dart';

/// Controlador principal para la gestión de repartos
/// Maneja el estado del delivery, temporizador y estadísticas
class DeliveryController with ChangeNotifier {
  // Estado del delivery
  bool _started = false;
  bool _paused = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  
  // Estado de clientes
  List<bool> _clientesContactados = [];
  List<String> _clientesEstado = [];
  int? _selectedClienteIndex;
  
  // Registros históricos
  List<DeliveryRecord> _deliveryRecords = [];
  
  // Servicios
  final DeliveryService _deliveryService = DeliveryService();
  final DeliveryStateManager _stateManager = DeliveryStateManager();

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

  // Constructor
  DeliveryController({
    bool started = false,
    bool paused = false,
    int elapsedSeconds = 0,
    List<bool> clientesContactados = const [],
    int? selectedClienteIndex,
  }) {
    _loadInitialState(started, paused, elapsedSeconds, clientesContactados, selectedClienteIndex);
  }

  /// Carga el estado inicial desde el DeliveryStateManager
  void _loadInitialState(bool started, bool paused, int elapsedSeconds, 
      List<bool> clientesContactados, int? selectedClienteIndex) {
    
    _started = _stateManager.isDeliveryActive ? _stateManager.isDeliveryActive : started;
    _paused = _stateManager.isDeliveryActive ? _stateManager.isDeliveryPaused : paused;
    _elapsedSeconds = _stateManager.isDeliveryActive ? _stateManager.elapsedSeconds : elapsedSeconds;
    
    _clientesContactados = _stateManager.isDeliveryActive && _stateManager.clientesContactados.isNotEmpty
        ? List<bool>.from(_stateManager.clientesContactados)
        : List<bool>.from(clientesContactados);
        
    _clientesEstado = _stateManager.isDeliveryActive && _stateManager.clientesEstado.isNotEmpty
        ? List<String>.from(_stateManager.clientesEstado)
        : [];
        
    _selectedClienteIndex = _stateManager.isDeliveryActive ? _stateManager.selectedClienteIndex : selectedClienteIndex;
    
    if (_started && !_paused) {
      _startTimer();
    }
  }

  /// Inicia el temporizador del delivery
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      _stateManager.updateElapsedSeconds(_elapsedSeconds);
      notifyListeners();
    });
  }

  /// Detiene el temporizador
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Inicia un nuevo delivery
  void startDelivery(int deliveryNumber) {
    _started = true;
    _paused = false;
    _elapsedSeconds = 0;
    
    _stateManager.startDelivery(deliveryNumber);
    _stateManager.updateClientesContactados(_clientesContactados);
    _stateManager.updateClientesEstado(_clientesEstado);
    _stateManager.updateSelectedClienteIndex(_selectedClienteIndex);
    
    _startTimer();
    notifyListeners();
  }

  /// Pausa el delivery actual
  void pauseDelivery() {
    _paused = true;
    _stateManager.pauseDelivery();
    _stateManager.updateElapsedSeconds(_elapsedSeconds);
    _stopTimer();
    notifyListeners();
  }

  /// Reanuda el delivery pausado
  void resumeDelivery() {
    _paused = false;
    _stateManager.resumeDelivery();
    _stateManager.updateElapsedSeconds(_elapsedSeconds);
    _startTimer();
    notifyListeners();
  }

  /// Finaliza el delivery actual y guarda los resultados
  Future<void> endDelivery(List<Cliente> clientes) async {
    try {
      final deliveryNumber = _stateManager.getCurrentDeliveryNumber() ?? (_deliveryRecords.length + 1);
      final stats = await _calculateDeliveryStats(deliveryNumber);
      
      final record = DeliveryRecord(
        deliveryNumber: deliveryNumber,
        date: DateTime.now(),
        duration: Duration(seconds: _elapsedSeconds),
        avgPrice: stats.avgPricePerKilo,
        kilograms: stats.totalKilograms,
        boxes: 0,
        remaining: 0.0,
        seller: "Default Seller",
        total: stats.totalAmount,
      );
      
      await _saveDeliveryRecord(record, clientes);
      _resetDeliveryState(clientes);
      
    } catch (e) {
      debugPrint('Error al finalizar delivery: $e');
      await _saveEmptyDeliveryRecord(clientes);
    }
  }

  /// Calcula las estadísticas del delivery
  Future<DeliveryStats> _calculateDeliveryStats(int deliveryNumber) async {
    final sales = await _deliveryService.getSalesByDeliveryNumber(deliveryNumber);
    
    double totalKilograms = 0.0;
    double totalAmount = 0.0;
    
    for (var sale in sales) {
      totalKilograms += sale.quantity;
      totalAmount += sale.total;
    }
    
    final avgPricePerKilo = totalKilograms > 0 ? totalAmount / totalKilograms : 0.0;
    
    return DeliveryStats(
      totalKilograms: totalKilograms,
      totalAmount: totalAmount,
      avgPricePerKilo: avgPricePerKilo,
    );
  }

  /// Guarda el registro del delivery
  Future<void> _saveDeliveryRecord(DeliveryRecord record, List<Cliente> clientes) async {
    _deliveryRecords.add(record);
    
    await Future.wait([
      _deliveryService.saveDeliveryToDatabase(record),
      _deliveryService.saveContactResultsToDatabase(
        record.deliveryNumber,
        clientes,
        _clientesContactados,
        _clientesEstado,
      ),
    ]);
  }

  /// Guarda un registro vacío en caso de error
  Future<void> _saveEmptyDeliveryRecord(List<Cliente> clientes) async {
    final deliveryNumber = _stateManager.getCurrentDeliveryNumber() ?? (_deliveryRecords.length + 1);
    
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
    
    await _saveDeliveryRecord(record, clientes);
  }

  /// Resetea el estado del delivery
  void _resetDeliveryState(List<Cliente> clientes) {
    _started = false;
    _paused = false;
    _elapsedSeconds = 0;
    _clientesContactados = List.generate(clientes.length, (_) => false);
    _clientesEstado = List.generate(clientes.length, (_) => '');
    _selectedClienteIndex = null;
    
    _stateManager.endDelivery();
    _stopTimer();
    notifyListeners();
  }

  /// Selecciona un cliente específico
  void selectCliente(int index) {
    _selectedClienteIndex = index;
    _stateManager.updateSelectedClienteIndex(index);
    notifyListeners();
  }

  /// Actualiza el estado de contacto de un cliente
  void updateContactoStatus(int index, bool contactado, String estado) {
    if (index < 0 || index >= _clientesContactados.length) return;
    
    _clientesContactados[index] = contactado;
    _clientesEstado[index] = estado;
    
    _stateManager.updateClientesContactados(_clientesContactados);
    _stateManager.updateClientesEstado(_clientesEstado);
    
    debugPrint('Estado actualizado para cliente $index: $estado, Contactado: $contactado');
    notifyListeners();
  }

  /// Inicializa las listas de clientes
  void initializeClients(int length) {
    if (_stateManager.clientesContactados.isEmpty || 
        _stateManager.clientesContactados.length != length) {
      _clientesContactados = List.generate(length, (_) => false);
      _stateManager.updateClientesContactados(_clientesContactados);
    } else {
      _clientesContactados = List<bool>.from(_stateManager.clientesContactados);
    }
    
    if (_stateManager.clientesEstado.isEmpty || 
        _stateManager.clientesEstado.length != length) {
      _clientesEstado = List.generate(length, (_) => '');
      _stateManager.updateClientesEstado(_clientesEstado);
    } else {
      _clientesEstado = List<String>.from(_stateManager.clientesEstado);
    }
    
    notifyListeners();
  }

  /// Carga la lista de clientes
  Future<void> loadClientes() async {
    try {
      final clientes = await _deliveryService.loadClientes();
      initializeClients(clientes.length);
    } catch (e) {
      debugPrint('Error al cargar clientes: $e');
    }
  }

  /// Carga los registros de delivery
  Future<void> loadDeliveryRecords() async {
    try {
      _deliveryRecords = await _deliveryService.loadDeliveryRecords();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar registros de delivery: $e');
    }
  }

  /// Elimina todos los registros de delivery
  Future<void> deleteDeliveryRecords() async {
    try {
      await _deliveryService.deleteDeliveryRecords();
      _deliveryRecords.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al eliminar registros de delivery: $e');
    }
  }

  /// Muestra información de debug sobre los contactos
  Future<void> debugContactos() async {
    try {
      final contactos = await _deliveryService.debugContactos();
      
      debugPrint('=== DEBUG CONTACTOS ===');
      if (contactos.isEmpty) {
        debugPrint('No hay registros de contactos.');
      } else {
        for (var contacto in contactos.take(10)) {
          debugPrint('ID: ${contacto.id} | Client ID: ${contacto.clientId} | Resultado: ${contacto.result} | Delivery ID: ${contacto.deliveryId}');
        }
      }
      
      debugPrint('=== ESTADO CLIENTES ===');
      for (int i = 0; i < _clientesEstado.length; i++) {
        if (_clientesEstado[i].isNotEmpty) {
          debugPrint('Cliente $i: ${_clientesEstado[i]} (Contactado: ${_clientesContactados[i]})');
        }
      }
    } catch (e) {
      debugPrint('Error en debugContactos: $e');
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

/// Clase auxiliar para encapsular estadísticas de delivery
class DeliveryStats {
  final double totalKilograms;
  final double totalAmount;
  final double avgPricePerKilo;

  DeliveryStats({
    required this.totalKilograms,
    required this.totalAmount,
    required this.avgPricePerKilo,
  });
}
