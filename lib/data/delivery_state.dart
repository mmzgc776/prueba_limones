import 'delivery_session.dart';

/// Modelo para el estado persistente del delivery
class DeliveryPersistentState {
  final DateTime? startTime;
  final bool isPaused;
  final int elapsedSeconds;
  final bool isActive;
  final int? deliveryNumber;
  final int initialBoxes;

  DeliveryPersistentState({
    this.startTime,
    required this.isPaused,
    required this.elapsedSeconds,
    required this.isActive,
    this.deliveryNumber,
    this.initialBoxes = 0,
  });

  /// Crear desde Map (para deserialización)
  factory DeliveryPersistentState.fromMap(Map<String, dynamic> map) {
    return DeliveryPersistentState(
      startTime: map['startTime'] != null
          ? DateTime.parse(map['startTime'])
          : null,
      isPaused: map['isPaused'] ?? false,
      elapsedSeconds: map['elapsedSeconds'] ?? 0,
      isActive: map['isActive'] ?? false,
      deliveryNumber: map['deliveryNumber'],
      // DatabaseService usa la clave de la columna (`boxes`).
      initialBoxes: map['boxes'] ?? map['initialBoxes'] ?? 0,
    );
  }

  /// Convertir a Map (para serialización)
  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime?.toIso8601String(),
      'isPaused': isPaused,
      'elapsedSeconds': elapsedSeconds,
      'isActive': isActive,
      'deliveryNumber': deliveryNumber,
      'boxes': initialBoxes,
    };
  }
}

/// Estado del reparto en memoria compartido entre páginas. El tiempo vive sólo
/// en [session]; los flags se derivan de ella para no desincronizarse.
class DeliveryStateManager {
  static final DeliveryStateManager _instance =
      DeliveryStateManager._internal();

  factory DeliveryStateManager() {
    return _instance;
  }

  DeliveryStateManager._internal();

  DeliverySession? session;

  /// Vendedor dueño de [session]; al cambiar de usuario se vuelve a cargar.
  int? sessionSellerId;

  double? currentPrice;
  List<bool> clientesContactados = [];
  List<String> clientesEstado = [];
  int? selectedClienteIndex;

  bool get isDeliveryActive => session != null;
  bool get isDeliveryPaused => session?.isPaused ?? false;
  int? get currentDeliveryNumber => session?.deliveryNumber;
  int? get initialBoxes => session?.boxes;

  /// Cambia a otro reparto: las marcas de clientes no se heredan.
  void startSession(DeliverySession newSession, {required int sellerId}) {
    session = newSession;
    sessionSellerId = sellerId;
    clientesContactados = [];
    clientesEstado = [];
    selectedClienteIndex = null;
  }

  void endDelivery() {
    session = null;
    sessionSellerId = null;
    clientesContactados = [];
    clientesEstado = [];
    selectedClienteIndex = null;
  }

  int? getCurrentDeliveryNumber() {
    return session?.deliveryNumber;
  }

  void setCurrentPrice(double price) {
    currentPrice = price;
  }

  double? getCurrentPrice() {
    return currentPrice;
  }

  void updateClientesContactados(List<bool> contactados) {
    clientesContactados = List<bool>.from(contactados);
  }

  void updateClientesEstado(List<String> estado) {
    clientesEstado = List<String>.from(estado);
  }

  void updateSelectedClienteIndex(int? index) {
    selectedClienteIndex = index;
  }
}
