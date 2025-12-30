import 'package:flutter/material.dart';

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
      initialBoxes: map['initialBoxes'] ?? 0,
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
      'initialBoxes': initialBoxes,
    };
  }
}

class DeliveryStateManager {
  static final DeliveryStateManager _instance =
      DeliveryStateManager._internal();

  factory DeliveryStateManager() {
    return _instance;
  }

  DeliveryStateManager._internal();

  int? currentDeliveryNumber;
  bool isDeliveryActive = false;
  bool isDeliveryPaused = false;
  double? currentPrice;
  int elapsedSeconds = 0;
  List<bool> clientesContactados = [];
  List<String> clientesEstado = [];
  int? selectedClienteIndex;
  int? initialBoxes;

  void startDelivery(int deliveryNumber, {int? boxes}) {
    currentDeliveryNumber = deliveryNumber;
    isDeliveryActive = true;
    isDeliveryPaused = false;
    elapsedSeconds = 0;
    clientesContactados = [];
    clientesEstado = [];
    selectedClienteIndex = null;
    initialBoxes = boxes;
  }

  void pauseDelivery() {
    isDeliveryPaused = true;
  }

  void resumeDelivery() {
    isDeliveryPaused = false;
  }

  void endDelivery() {
    currentDeliveryNumber = null;
    isDeliveryActive = false;
    isDeliveryPaused = false;
    elapsedSeconds = 0;
    clientesContactados = [];
    clientesEstado = [];
    selectedClienteIndex = null;
    initialBoxes = null;
  }

  int? getCurrentDeliveryNumber() {
    return isDeliveryActive ? currentDeliveryNumber : null;
  }

  void setCurrentPrice(double price) {
    currentPrice = price;
  }

  double? getCurrentPrice() {
    return currentPrice;
  }

  void updateElapsedSeconds(int seconds) {
    elapsedSeconds = seconds;
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
