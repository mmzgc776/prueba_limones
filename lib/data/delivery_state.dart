import 'package:flutter/material.dart';

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

  void startDelivery(int deliveryNumber) {
    currentDeliveryNumber = deliveryNumber;
    isDeliveryActive = true;
    isDeliveryPaused = false;
    elapsedSeconds = 0;
    clientesContactados = [];
    clientesEstado = [];
    selectedClienteIndex = null;
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
