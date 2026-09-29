import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/delivery_session.dart';
import '../data/delivery_state.dart';
import '../data/database.dart';
import '../pages/section_delivery/delivery_record.dart';
import '../services/delivery_service.dart';
import '../services/user_session_service.dart';

/// Controlador principal para la gestión de repartos.
///
/// El tiempo sale de la [DeliverySession] guardada en [DeliveryStateManager]
/// (`accumulated + (now - runningSince)`); el timer sólo repinta. Cada
/// transición se persiste en `PersistentDeliveryStates` antes de notificar.
class DeliveryController with ChangeNotifier, WidgetsBindingObserver {
  Timer? _ticker;

  // Estado de clientes
  List<bool> _clientesContactados = [];
  List<String> _clientesEstado = [];
  int? _selectedClienteIndex;

  // Registros históricos
  List<DeliveryRecord> _deliveryRecords = [];

  // Servicios
  final DeliveryService _deliveryService;
  final DeliveryStateManager _stateManager;
  final DateTime Function() _clock;

  DeliverySession? get _session => _stateManager.session;

  // Getters
  bool get started => _session != null;
  bool get paused => _session?.isPaused ?? false;
  int get elapsedSeconds => _session?.elapsed(_clock()).inSeconds ?? 0;
  List<bool> get clientesContactados => _clientesContactados;
  List<String> get clientesEstado => _clientesEstado;
  int? get selectedClienteIndex => _selectedClienteIndex;
  List<DeliveryRecord> get deliveryRecords => _deliveryRecords;

  /// Devuelve el número de delivery actual (si hay uno activo) o un número
  /// calculado como siguiente disponible a partir de los registros guardados.
  int getCurrentDeliveryNumber() {
    return _stateManager.getCurrentDeliveryNumber() ??
        (_deliveryRecords.length + 1);
  }

  String get formattedTime {
    final elapsed = elapsedSeconds;
    final hours = (elapsed ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((elapsed % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  DeliveryController({
    DeliveryService? deliveryService,
    DeliveryStateManager? stateManager,
    DateTime Function()? clock,
  }) : _deliveryService = deliveryService ?? DeliveryService(),
       _stateManager = stateManager ?? DeliveryStateManager(),
       _clock = clock ?? DateTime.now {
    if (_stateManager.isDeliveryActive) {
      _clientesContactados = List<bool>.from(_stateManager.clientesContactados);
      _clientesEstado = List<String>.from(_stateManager.clientesEstado);
      _selectedClienteIndex = _stateManager.selectedClienteIndex;
    }
    _syncTicker();
  }

  /// El timer sólo repinta; nunca suma tiempo.
  void _syncTicker() {
    if (started && !paused) {
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
    } else {
      _stopTicker();
    }
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _persistSession() async {
    final session = _session;
    try {
      if (session == null) {
        await _deliveryService.clearPersistentDeliveryState();
      } else {
        await _deliveryService.savePersistentDeliveryState(
          session.toPersistentState(),
        );
      }
    } catch (e) {
      debugPrint('Error guardando la sesión de reparto: $e');
    }
  }

  /// Recupera la sesión guardada si la memoria está vacía (la app se cerró o
  /// el SO la mató) o si pertenece a otro vendedor.
  Future<void> restoreSession() async {
    final sellerId = UserSessionService().currentSellerId;
    if (_session != null && _stateManager.sessionSellerId == sellerId) return;

    final saved = await _deliveryService.loadPersistentDeliveryState();
    final restored = saved == null
        ? null
        : DeliverySession.fromPersistentState(saved);
    if (restored != null) {
      _stateManager.startSession(restored, sellerId: sellerId);
      debugPrint(
        'Sesión de reparto #${restored.deliveryNumber} restaurada: '
        '${restored.elapsed(_clock()).inSeconds} s',
      );
    } else if (_session != null) {
      _stateManager.endDelivery();
    }
    _syncTicker();
    notifyListeners();
  }

  void _pushClientStateToManager() {
    _stateManager.updateClientesContactados(_clientesContactados);
    _stateManager.updateClientesEstado(_clientesEstado);
    _stateManager.updateSelectedClienteIndex(_selectedClienteIndex);
  }

  /// Inicia un nuevo delivery
  Future<void> startDelivery(int deliveryNumber, {int boxes = 0}) async {
    _stateManager.startSession(
      DeliverySession.start(deliveryNumber, now: _clock(), boxes: boxes),
      sellerId: UserSessionService().currentSellerId,
    );
    _pushClientStateToManager();
    await _persistSession();
    _syncTicker();
    notifyListeners();
  }

  /// Reanuda un delivery específico
  /// Si se proporciona [boxesOverride], se usa ese valor en lugar del de la BD
  Future<void> resumeSpecificDelivery(
    int deliveryNumber, {
    int? boxesOverride,
  }) async {
    final current = _session;
    if (current != null && current.deliveryNumber == deliveryNumber) {
      // Ya es el reparto en curso: su tiempo está en la sesión, no en la BD.
      var updated = current.resume(_clock());
      if (boxesOverride != null) updated = updated.withBoxes(boxesOverride);
      if (updated != current) {
        _stateManager.session = updated;
        await _persistSession();
      }
      _syncTicker();
      notifyListeners();
      return;
    }

    if (current != null) {
      // Cerrar el tramo del reparto en curso antes de reemplazarlo, para no
      // perder su tiempo (B11; falta preguntar al usuario).
      await pauseDelivery();
    }

    var accumulated = Duration.zero;
    var boxes = boxesOverride ?? 0;
    try {
      final existingDelivery = await _deliveryService.getDeliveryByNumber(
        deliveryNumber,
      );
      if (existingDelivery != null) {
        accumulated = Duration(seconds: existingDelivery.durationSeconds);
        boxes = boxesOverride ?? existingDelivery.boxes;
      }
    } catch (e) {
      debugPrint('Error loading delivery time: $e');
    }
    debugPrint(
      'Resuming delivery #$deliveryNumber with accumulated time: '
      '${accumulated.inSeconds} seconds, boxes: $boxes',
    );

    _stateManager.startSession(
      DeliverySession.start(
        deliveryNumber,
        now: _clock(),
        accumulated: accumulated,
        boxes: boxes,
      ),
      sellerId: UserSessionService().currentSellerId,
    );
    _pushClientStateToManager();
    await _persistSession();
    _syncTicker();
    notifyListeners();
  }

  /// Pausa el delivery actual
  Future<void> pauseDelivery() async {
    final current = _session;
    if (current == null) return;
    final pausedSession = current.pause(_clock());
    _stateManager.session = pausedSession;
    _syncTicker();
    await _persistSession();

    try {
      await _saveCurrentDeliveryTime(pausedSession);
      debugPrint(
        'Saved delivery #${pausedSession.deliveryNumber} time on pause: '
        '${pausedSession.accumulated.inSeconds} seconds',
      );
    } catch (e) {
      debugPrint('Error saving delivery time on pause: $e');
    }

    notifyListeners();
  }

  /// Guarda el tiempo de la sesión en la fila de `Deliveries`
  Future<void> _saveCurrentDeliveryTime(DeliverySession session) async {
    final deliveryNumber = session.deliveryNumber;
    final existingDelivery = await _deliveryService.getDeliveryByNumber(
      deliveryNumber,
    );
    final stats = await _calculateDeliveryStats(deliveryNumber);
    final record = DeliveryRecord(
      deliveryNumber: deliveryNumber,
      date: existingDelivery?.date ?? _clock(),
      duration: session.elapsed(_clock()),
      avgPrice: stats.avgPricePerKilo,
      kilograms: stats.totalKilograms,
      boxes: existingDelivery != null && session.boxes <= 0
          ? existingDelivery.boxes
          : session.boxes,
      remaining: existingDelivery?.remaining ?? 0.0,
      sellerId: UserSessionService().currentSellerId,
      total: stats.totalAmount,
    );
    await _deliveryService.saveDeliveryToDatabase(record);
  }

  /// Reanuda el delivery pausado
  Future<void> resumeDelivery() async {
    final current = _session;
    if (current == null || !current.isPaused) return;
    _stateManager.session = current.resume(_clock());
    await _persistSession();
    _syncTicker();
    notifyListeners();
  }

  /// Finaliza el delivery actual y guarda los resultados
  Future<void> endDelivery(List<Cliente> clientes) async {
    final session = _session;
    final deliveryNumber =
        session?.deliveryNumber ?? (_deliveryRecords.length + 1);
    final duration = session?.elapsed(_clock()) ?? Duration.zero;
    final boxes = session?.boxes ?? 0;
    try {
      final stats = await _calculateDeliveryStats(deliveryNumber);

      final record = DeliveryRecord(
        deliveryNumber: deliveryNumber,
        date: _clock(),
        duration: duration,
        avgPrice: stats.avgPricePerKilo,
        kilograms: stats.totalKilograms,
        boxes: boxes,
        remaining: 0.0,
        sellerId: UserSessionService().currentSellerId,
        total: stats.totalAmount,
      );

      await _saveDeliveryRecord(record, clientes);
      _resetDeliveryState(clientes);
      await _persistSession(); // Sin sesión: limpia el estado persistente
    } catch (e) {
      debugPrint('Error al finalizar delivery: $e');
      await _saveEmptyDeliveryRecord(
        clientes,
        deliveryNumber: deliveryNumber,
        duration: duration,
        boxes: boxes,
      );
    }
  }

  /// Calcula las estadísticas del delivery
  Future<DeliveryStats> _calculateDeliveryStats(int deliveryNumber) async {
    final sales = await _deliveryService.getSalesByDeliveryNumber(
      deliveryNumber,
    );

    double totalKilograms = 0.0;
    double totalAmount = 0.0;

    for (var sale in sales) {
      totalKilograms += sale.quantity;
      totalAmount += sale.total;
    }

    final avgPricePerKilo = totalKilograms > 0
        ? totalAmount / totalKilograms
        : 0.0;

    return DeliveryStats(
      totalKilograms: totalKilograms,
      totalAmount: totalAmount,
      avgPricePerKilo: avgPricePerKilo,
    );
  }

  /// Guarda el registro del delivery
  Future<void> _saveDeliveryRecord(
    DeliveryRecord record,
    List<Cliente> clientes,
  ) async {
    _deliveryRecords.add(record);

    // Guardamos sólo el registro del delivery aquí. Las interacciones
    // se insertan inmediatamente cuando se capturan (insertInteraccionImmediate),
    // para evitar duplicados y permitir análisis en tiempo real.
    await _deliveryService.saveDeliveryToDatabase(record);
  }

  /// Guarda un registro vacío en caso de error
  Future<void> _saveEmptyDeliveryRecord(
    List<Cliente> clientes, {
    required int deliveryNumber,
    required Duration duration,
    required int boxes,
  }) async {
    final record = DeliveryRecord(
      deliveryNumber: deliveryNumber,
      date: _clock(),
      duration: duration,
      avgPrice: 0.0,
      kilograms: 0.0,
      boxes: boxes,
      remaining: 0.0,
      sellerId: UserSessionService().currentSellerId,
      total: 0.0,
    );

    await _saveDeliveryRecord(record, clientes);
  }

  /// Resetea el estado del delivery
  void _resetDeliveryState(List<Cliente> clientes) {
    _clientesContactados = List.generate(clientes.length, (_) => false);
    _clientesEstado = List.generate(clientes.length, (_) => '');
    _selectedClienteIndex = null;

    _stateManager.endDelivery();
    _stopTicker();
    notifyListeners();
  }

  /// Selecciona un cliente específico
  void selectCliente(int index) {
    _selectedClienteIndex = index;
    _stateManager.updateSelectedClienteIndex(index);
    notifyListeners();
  }

  /// Deselecciona el cliente actual (oculta la ficha de datos)
  void deselectCliente() {
    _selectedClienteIndex = null;
    _stateManager.updateSelectedClienteIndex(null);
    notifyListeners();
  }

  /// Actualiza el estado de contacto de un cliente
  void updateContactoStatus(int index, bool contactado, String estado) {
    if (index < 0 || index >= _clientesContactados.length) return;

    _clientesContactados[index] = contactado;
    _clientesEstado[index] = estado;

    _stateManager.updateClientesContactados(_clientesContactados);
    _stateManager.updateClientesEstado(_clientesEstado);

    debugPrint(
      'Estado actualizado para cliente $index: $estado, Contactado: $contactado',
    );
    notifyListeners();
  }

  /// Una lista regenerada contiene sólo clientes pendientes. Nunca restaurar
  /// marcas por índice: el mismo índice puede corresponder a otro cliente.
  void resetPendingClients(int length) {
    _clientesContactados = List<bool>.filled(length, false);
    _clientesEstado = List<String>.filled(length, '');
    _selectedClienteIndex = null;
    _stateManager.updateClientesContactados(_clientesContactados);
    _stateManager.updateClientesEstado(_clientesEstado);
    _stateManager.selectedClienteIndex = null;
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
      final result = await _deliveryService.loadClientes();
      initializeClients(result.clientes.length);
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

  /// Muestra información de debug sobre las interacciones
  Future<void> debugInteracciones() async {
    try {
      final interacciones = await _deliveryService.debugInteracciones();

      debugPrint('=== DEBUG INTERACCIONES ===');
      if (interacciones.isEmpty) {
        debugPrint('No hay registros de interacciones.');
      } else {
        for (var interaccion in interacciones.take(10)) {
          debugPrint(
            'ID: ${interaccion.id} | Client ID: ${interaccion.clientId} | Resultado: ${interaccion.result} | Delivery ID: ${interaccion.deliveryId}',
          );
        }
      }

      debugPrint('=== ESTADO CLIENTES ===');
      for (int i = 0; i < _clientesEstado.length; i++) {
        if (_clientesEstado[i].isNotEmpty) {
          debugPrint(
            'Cliente $i: ${_clientesEstado[i]} (Contactado: ${_clientesContactados[i]})',
          );
        }
      }
    } catch (e) {
      debugPrint('Error en debugInteracciones: $e');
    }
  }

  /// Maneja cambios en el ciclo de vida de la aplicación. No suma tiempo: la
  /// sesión ya sabe desde cuándo corre, aunque el SO mate el proceso.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopTicker();
      if (started) _persistSession();
    } else if (state == AppLifecycleState.resumed) {
      _syncTicker();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopTicker();
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
