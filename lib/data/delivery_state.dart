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

  void startDelivery(int deliveryNumber) {
    currentDeliveryNumber = deliveryNumber;
    isDeliveryActive = true;
    isDeliveryPaused = false;
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
  }

  int? getCurrentDeliveryNumber() {
    return isDeliveryActive ? currentDeliveryNumber : null;
  }
}
