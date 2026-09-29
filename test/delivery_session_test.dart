import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_limones/controllers/delivery_controller.dart';
import 'package:prueba_limones/data/database.dart';
import 'package:prueba_limones/data/delivery_session.dart';
import 'package:prueba_limones/data/delivery_state.dart';
import 'package:prueba_limones/pages/section_delivery/delivery_record.dart';
import 'package:prueba_limones/services/delivery_service.dart';

/// DeliveryService en memoria: sin SQLite ni Sheets.
class _FakeDeliveryService extends DeliveryService {
  DeliveryPersistentState? persisted;
  final Map<int, DeliveryRecord> deliveries = {};

  @override
  Future<void> savePersistentDeliveryState(DeliveryPersistentState s) async =>
      persisted = s;

  @override
  Future<DeliveryPersistentState?> loadPersistentDeliveryState() async =>
      persisted;

  @override
  Future<void> clearPersistentDeliveryState() async => persisted = null;

  @override
  Future<Delivery?> getDeliveryByNumber(int deliveryNumber) async {
    final r = deliveries[deliveryNumber];
    if (r == null) return null;
    return Delivery(
      deliveryNumber: r.deliveryNumber,
      date: r.date,
      durationSeconds: r.duration.inSeconds,
      avgPrice: r.avgPrice,
      kilograms: r.kilograms,
      boxes: r.boxes,
      remaining: r.remaining,
      sellerId: r.sellerId,
      total: r.total,
    );
  }

  @override
  Future<List<Sale>> getSalesByDeliveryNumber(int deliveryNumber) async => [];

  @override
  Future<void> saveDeliveryToDatabase(DeliveryRecord record) async =>
      deliveries[record.deliveryNumber] = record;
}

void main() {
  final t0 = DateTime(2026, 9, 29, 9);

  group('DeliverySession', () {
    test('el tiempo es acumulado + tramo en curso', () {
      var s = DeliverySession.start(1, now: t0);
      expect(s.elapsed(t0.add(const Duration(minutes: 5))),
          const Duration(minutes: 5));

      s = s.pause(t0.add(const Duration(minutes: 5)));
      expect(s.isPaused, isTrue);
      // Pausado: el tiempo no avanza.
      expect(s.elapsed(t0.add(const Duration(hours: 1))),
          const Duration(minutes: 5));

      s = s.resume(t0.add(const Duration(hours: 1)));
      expect(s.elapsed(t0.add(const Duration(hours: 1, minutes: 2))),
          const Duration(minutes: 7));
    });

    test('pausar o reanudar dos veces no cambia nada', () {
      final s = DeliverySession.start(1, now: t0);
      expect(s.resume(t0.add(const Duration(minutes: 3))), s);
      final p = s.pause(t0.add(const Duration(minutes: 3)));
      expect(p.pause(t0.add(const Duration(minutes: 9))), p);
    });

    test('si el reloj retrocede no se resta tiempo', () {
      final s = DeliverySession.start(1,
          now: t0, accumulated: const Duration(minutes: 10));
      expect(s.elapsed(t0.subtract(const Duration(minutes: 30))),
          const Duration(minutes: 10));
    });

    test('ida y vuelta por PersistentDeliveryStates', () {
      final running = DeliverySession.start(7,
          now: t0, accumulated: const Duration(seconds: 90), boxes: 4);
      final paused = running.pause(t0.add(const Duration(seconds: 30)));
      for (final s in [running, paused]) {
        final map = s.toPersistentState().toMap();
        final back = DeliverySession.fromPersistentState(
            DeliveryPersistentState.fromMap(map));
        expect(back, s);
      }
      // La columna se llama `boxes`; antes se guardaba siempre 0.
      expect(running.toPersistentState().toMap()['boxes'], 4);
    });

    test('una fila inactiva no es una sesión', () {
      final state = DeliveryPersistentState(
          isPaused: false, elapsedSeconds: 0, isActive: false);
      expect(DeliverySession.fromPersistentState(state), isNull);
    });
  });

  group('DeliveryController', () {
    late DateTime now;
    late _FakeDeliveryService service;
    late DeliveryStateManager manager;
    late DeliveryController controller;

    DeliveryController build() => DeliveryController(
          deliveryService: service,
          stateManager: manager,
          clock: () => now,
        );

    setUp(() {
      now = t0;
      service = _FakeDeliveryService();
      manager = DeliveryStateManager()..endDelivery();
      controller = build();
    });

    tearDown(() {
      controller.dispose();
      manager.endDelivery();
    });

    test('B1/B2: reanudar varias veces el mismo reparto no acelera ni retrocede',
        () async {
      service.deliveries[5] = DeliveryRecord(
        deliveryNumber: 5,
        date: t0.subtract(const Duration(days: 3)),
        duration: const Duration(minutes: 20),
        avgPrice: 0,
        kilograms: 0,
        boxes: 2,
        remaining: 0,
        sellerId: 1,
        total: 0,
      );
      await controller.resumeSpecificDelivery(5);
      now = now.add(const Duration(minutes: 10));
      // Lo que hacía _loadData tras cada interacción.
      await controller.resumeSpecificDelivery(5);
      await controller.resumeSpecificDelivery(5);
      now = now.add(const Duration(minutes: 5));

      expect(controller.elapsedSeconds, const Duration(minutes: 35).inSeconds);
    });

    test('B4: el segundo plano no se cuenta doble', () async {
      await controller.startDelivery(1);
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 10));
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(controller.elapsedSeconds, const Duration(minutes: 10).inSeconds);
    });

    test('B5: la sesión persistida sobrevive a que el SO mate la app',
        () async {
      await controller.startDelivery(3, boxes: 6);
      now = now.add(const Duration(minutes: 4));
      await controller.pauseDelivery();
      now = now.add(const Duration(minutes: 1));
      await controller.resumeDelivery();

      // Proceso muerto: memoria vacía, sólo queda la tabla.
      controller.dispose();
      manager.endDelivery();
      now = now.add(const Duration(minutes: 30));
      controller = build();
      expect(controller.started, isFalse);

      await controller.restoreSession();
      expect(controller.started, isTrue);
      expect(controller.paused, isFalse);
      expect(controller.getCurrentDeliveryNumber(), 3);
      expect(manager.initialBoxes, 6);
      expect(controller.elapsedSeconds, const Duration(minutes: 34).inSeconds);
    });

    test('B6/B7: otra instancia del controller ve el mismo tiempo', () async {
      await controller.startDelivery(1);
      now = now.add(const Duration(minutes: 8));
      controller.dispose(); // salir de la página ya no pausa
      controller = build();
      expect(controller.paused, isFalse);
      expect(controller.elapsedSeconds, const Duration(minutes: 8).inSeconds);
    });

    test('B11: cambiar de reparto guarda el tiempo del que estaba activo',
        () async {
      await controller.startDelivery(7);
      now = now.add(const Duration(minutes: 12));
      await controller.resumeSpecificDelivery(5);

      expect(service.deliveries[7]!.duration, const Duration(minutes: 12));
      expect(controller.getCurrentDeliveryNumber(), 5);
      expect(controller.elapsedSeconds, 0);
    });

    test('terminar usa el tiempo de la sesión y limpia la persistencia',
        () async {
      await controller.startDelivery(2);
      now = now.add(const Duration(minutes: 3));
      await controller.pauseDelivery();
      now = now.add(const Duration(minutes: 50));
      await controller.resumeDelivery();
      now = now.add(const Duration(minutes: 2));
      await controller.endDelivery(const []);

      expect(service.deliveries[2]!.duration, const Duration(minutes: 5));
      expect(service.persisted, isNull);
      expect(controller.started, isFalse);
    });
  });
}
