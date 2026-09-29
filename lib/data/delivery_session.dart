import 'delivery_state.dart';

/// Sesión de reparto basada en marcas de tiempo (plan §1).
///
/// El tiempo nunca se suma a mano: se calcula como
/// `accumulated + (now - runningSince)`. Así da igual cuántos timers repinten,
/// cuánto tiempo pase la app en segundo plano o si el SO mata el proceso.
/// Inmutable; cada transición devuelve una sesión nueva.
class DeliverySession {
  final int deliveryNumber;

  /// Tiempo de los tramos ya cerrados (pausados).
  final Duration accumulated;

  /// Inicio del tramo en curso; `null` = pausado.
  final DateTime? runningSince;

  final int boxes;

  const DeliverySession({
    required this.deliveryNumber,
    this.accumulated = Duration.zero,
    this.runningSince,
    this.boxes = 0,
  });

  /// Arranca (o retoma) un reparto corriendo desde [now].
  factory DeliverySession.start(
    int deliveryNumber, {
    required DateTime now,
    Duration accumulated = Duration.zero,
    int boxes = 0,
  }) {
    return DeliverySession(
      deliveryNumber: deliveryNumber,
      accumulated: accumulated,
      runningSince: now,
      boxes: boxes,
    );
  }

  bool get isPaused => runningSince == null;

  /// Tiempo activo total. Si el reloj del dispositivo retrocede, el tramo en
  /// curso cuenta como cero en lugar de restar.
  Duration elapsed(DateTime now) {
    final since = runningSince;
    if (since == null) return accumulated;
    final running = now.difference(since);
    return running.isNegative ? accumulated : accumulated + running;
  }

  DeliverySession pause(DateTime now) {
    if (isPaused) return this;
    return DeliverySession(
      deliveryNumber: deliveryNumber,
      accumulated: elapsed(now),
      boxes: boxes,
    );
  }

  DeliverySession resume(DateTime now) {
    if (!isPaused) return this;
    return DeliverySession(
      deliveryNumber: deliveryNumber,
      accumulated: accumulated,
      runningSince: now,
      boxes: boxes,
    );
  }

  DeliverySession withBoxes(int boxes) {
    return DeliverySession(
      deliveryNumber: deliveryNumber,
      accumulated: accumulated,
      runningSince: runningSince,
      boxes: boxes,
    );
  }

  /// Fila de `PersistentDeliveryStates`: `startTime` = [runningSince],
  /// `elapsedSeconds` = [accumulated].
  DeliveryPersistentState toPersistentState() {
    return DeliveryPersistentState(
      startTime: runningSince,
      isPaused: isPaused,
      elapsedSeconds: accumulated.inSeconds,
      isActive: true,
      deliveryNumber: deliveryNumber,
      initialBoxes: boxes,
    );
  }

  /// `null` si la fila no describe un reparto activo.
  static DeliverySession? fromPersistentState(DeliveryPersistentState state) {
    final number = state.deliveryNumber;
    if (!state.isActive || number == null) return null;
    return DeliverySession(
      deliveryNumber: number,
      accumulated: Duration(seconds: state.elapsedSeconds),
      runningSince: state.isPaused ? null : state.startTime,
      boxes: state.initialBoxes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeliverySession &&
      other.deliveryNumber == deliveryNumber &&
      other.accumulated == accumulated &&
      other.runningSince == runningSince &&
      other.boxes == boxes;

  @override
  int get hashCode =>
      Object.hash(deliveryNumber, accumulated, runningSince, boxes);
}
