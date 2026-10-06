import 'dart:math' as math;

import '../data/database.dart';

/// Cálculo puro compartido por la lista y los recálculos persistidos.
class ClientPurchaseMetrics {
  final List<Sale> sales;
  final List<DateTime> purchaseDays;
  final Map<int, int> weekdayCounts;
  final double interval, confidence, ageDays, readiness, silenceFactor;
  final double recentEvents, recentKg, kgTotal, moda, maximo, kgSemana;
  final double ventasVuelta, ultimas10, weekdayScore;
  final int preferredDay;

  ClientPurchaseMetrics._({
    required this.sales,
    required this.purchaseDays,
    required this.weekdayCounts,
    required this.interval,
    required this.confidence,
    required this.ageDays,
    required this.readiness,
    required this.silenceFactor,
    required this.recentEvents,
    required this.recentKg,
    required this.kgTotal,
    required this.moda,
    required this.maximo,
    required this.kgSemana,
    required this.ventasVuelta,
    required this.ultimas10,
    required this.preferredDay,
    required this.weekdayScore,
  });

  static DateTime calendarDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  factory ClientPurchaseMetrics.calculate({
    required List<Sale> sales,
    required List<Delivery> deliveries,
    required DateTime now,
  }) {
    final valid =
        sales
            .where(
              (s) =>
                  !s.date.isAfter(now) && s.quantity.isFinite && s.quantity > 0,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final dailyKg = <DateTime, double>{};
    for (final sale in valid) {
      final day = calendarDay(sale.date);
      dailyKg[day] = (dailyKg[day] ?? 0) + sale.quantity;
    }
    final days = dailyKg.keys.toList()..sort();
    final today = calendarDay(now);
    final age = days.isEmpty
        ? double.infinity
        : today.difference(days.last).inDays.toDouble();
    final recentDays = days.skip(math.max(0, days.length - 10)).toList();
    final gaps = <double>[];
    for (var i = 1; i < recentDays.length; i++) {
      gaps.add(recentDays[i].difference(recentDays[i - 1]).inDays.toDouble());
    }
    var interval = 0.0;
    var confidence = 0.0;
    if (gaps.isNotEmpty) {
      final median = _median(gaps);
      final clean = gaps.where((g) => g <= 3 * median).toList();
      interval = clean.reduce((a, b) => a + b) / clean.length;
      // Las pausas descartadas sí reducen la confianza del patrón.
      final deviation =
          gaps.map((g) => (g - interval).abs()).reduce((a, b) => a + b) /
          gaps.length /
          interval;
      confidence = math.min(1.0, gaps.length / 4) / (1 + deviation);
    }
    final expected = interval > 0 ? interval : 7.0;
    final ratio = age / expected;
    final timing = ratio <= 1
        ? ratio.clamp(0.0, 1.0)
        : math.exp(-(ratio - 1) / 3);
    final readiness = days.isEmpty
        ? 0.0
        : (1 - confidence) * 0.6 + confidence * timing;
    final silenceStart = math.max(30.0, expected * 3);
    final silence = age <= silenceStart
        ? 1.0
        : math.exp(-(age - silenceStart) / math.max(30.0, expected * 2));
    final recent = dailyKg.entries
        .where((e) => today.difference(e.key).inDays < 90)
        .toList();
    var recentEvents = 0.0;
    var recentKg = 0.0;
    final weekdays = <int, int>{};
    for (final entry in recent) {
      final weight = math.exp(-today.difference(entry.key).inDays / 45);
      recentEvents += weight;
      recentKg += entry.value * weight;
      final weekday = entry.key.weekday - 1;
      weekdays[weekday] = (weekdays[weekday] ?? 0) + 1;
    }
    var preferred = 0;
    for (var day = 0; day < 7; day++) {
      if ((weekdays[day] ?? 0) > (weekdays[preferred] ?? 0)) preferred = day;
    }
    final distance = ((now.weekday - 1) - preferred).abs();
    final circularDistance = math.min(distance, 7 - distance);
    final weekdayScore = (weekdays[preferred] ?? 0) < 2
        ? 0.0
        : (circularDistance == 0
              ? 1.0
              : circularDistance == 1
              ? 0.7
              : circularDistance == 2
              ? 0.4
              : 0.0);
    final quantities = dailyKg.values.toList()..sort();
    final counts = <double, int>{};
    var moda = 0.0;
    for (final kg in quantities) {
      counts[kg] = (counts[kg] ?? 0) + 1;
      if (counts[kg]! > (counts[moda] ?? 0)) moda = kg;
    }
    final eligibleDeliveries =
        deliveries.where((d) => !d.date.isAfter(now)).toList()..sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          return byDate != 0
              ? byDate
              : b.deliveryNumber.compareTo(a.deliveryNumber);
        });
    final latest = eligibleDeliveries
        .take(10)
        .map((d) => d.deliveryNumber)
        .toSet();
    final known = eligibleDeliveries.map((d) => d.deliveryNumber).toSet();
    final purchased = valid
        .map((s) => s.deliveryNumber)
        .whereType<int>()
        .toSet();
    final total = quantities.fold(0.0, (sum, kg) => sum + kg);
    final weeks = days.isEmpty
        ? 1.0
        : ((today.difference(days.first).inDays + 1) / 7).clamp(1.0, 90 / 7);
    return ClientPurchaseMetrics._(
      sales: valid,
      purchaseDays: days,
      weekdayCounts: weekdays,
      interval: interval,
      confidence: confidence,
      ageDays: age,
      readiness: readiness,
      silenceFactor: silence,
      recentEvents: recentEvents,
      recentKg: recentKg,
      kgTotal: total,
      moda: moda,
      maximo: quantities.isEmpty ? 0 : quantities.last,
      kgSemana: recent.fold(0.0, (sum, e) => sum + e.value) / weeks,
      ventasVuelta: known.isEmpty
          ? 0
          : purchased.intersection(known).length / known.length,
      ultimas10: latest.isEmpty
          ? 0
          : purchased.intersection(latest).length / latest.length,
      preferredDay: preferred,
      weekdayScore: weekdayScore,
    );
  }

  bool get initialFollowUp =>
      purchaseDays.isNotEmpty && purchaseDays.length <= 2 && ageDays <= 30;
  bool get reactivation =>
      purchaseDays.isNotEmpty &&
      ageDays > math.max(30.0, (interval > 0 ? interval : 7.0) * 3);
  double get kgEvento =>
      purchaseDays.isEmpty ? 0 : kgTotal / purchaseDays.length;

  /// Kg habituales por día de compra: la moda si algún valor se repite;
  /// si todos son distintos la moda sería el mínimo, así que usa la mediana.
  double get typicalKg {
    if (purchaseDays.isEmpty) return 0;
    final dailyKg = <DateTime, double>{};
    for (final sale in sales) {
      final day = calendarDay(sale.date);
      dailyKg[day] = (dailyKg[day] ?? 0) + sale.quantity;
    }
    final repeats = dailyKg.values.where((kg) => kg == moda).length;
    return repeats > 1 ? moda : _median(dailyKg.values.toList());
  }

  /// Día predilecto (0 = lunes). Usa los últimos 90 días como `weekdayScore`;
  /// sin compras recientes (p. ej. reactivaciones) recurre a todo el historial.
  int? get displayPreferredDay {
    if (purchaseDays.isEmpty) return null;
    if (weekdayCounts.isNotEmpty) return preferredDay;
    final counts = <int, int>{};
    for (final day in purchaseDays) {
      counts[day.weekday - 1] = (counts[day.weekday - 1] ?? 0) + 1;
    }
    var preferred = 0;
    for (var day = 0; day < 7; day++) {
      if ((counts[day] ?? 0) > (counts[preferred] ?? 0)) preferred = day;
    }
    return preferred;
  }

  /// Escalas fijas: recalcular un cliente no cambia la escala del resto.
  /// Es una prioridad heurística, NO una probabilidad de venta.
  double get score {
    if (purchaseDays.isEmpty) return 0;
    final activity = recentEvents / (recentEvents + 3);
    final volume = recentKg / (recentKg + 100);
    final base = 0.45 * readiness + 0.35 * activity + 0.20 * volume;
    final expected = interval > 0 ? interval : 7.0;
    final earlyFactor =
        0.15 + 0.85 * (ageDays / (expected * 0.8)).clamp(0.0, 1.0);
    return base * earlyFactor * silenceFactor * (1 + 0.10 * weekdayScore);
  }
}

class ClientRecommendation {
  final Cliente cliente;
  final ClientPurchaseMetrics metrics;
  final DateTime? lastContact;
  const ClientRecommendation(this.cliente, this.metrics, this.lastContact);

  static const weekdayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  String get reason => metrics.reactivation
      ? 'Reactivación'
      : metrics.initialFollowUp
      ? 'Seguimiento'
      : metrics.confidence >= 0.5 && metrics.readiness >= 0.65
      ? 'Recompra'
      : 'Actividad';

  /// Etiquetas compactas para la lista: motivo, día predilecto y kg habituales.
  List<String> get tags {
    final day = metrics.displayPreferredDay;
    final kg = metrics.typicalKg;
    return [
      reason,
      if (day != null) weekdayNames[day],
      if (kg > 0)
        '${kg == kg.roundToDouble() ? kg.toInt() : kg.toStringAsFixed(1)}kg',
    ];
  }
}

class ClientRecommendationService {
  static const targetSize = 60;
  static const followUpSlots = 9;
  static const reactivationSlots = 3;
  static const reactivationCooldownDays = 14;

  static List<ClientRecommendation> select({
    required List<Cliente> clientes,
    required List<Sale> sales,
    required List<Delivery> deliveries,
    required List<Interaccione> interactions,
    required DateTime now,
    required int sellerId,
    int? excludeDeliveryNumber,
  }) {
    final ownSales = sales.where((s) => s.sellerId == sellerId).toList();
    final ownDeliveries = deliveries
        .where((d) => d.sellerId == sellerId)
        .toList();
    final excluded = <int>{};
    final contacts = <int, DateTime>{};
    for (final interaction in interactions.where(
      (i) => i.sellerId == sellerId,
    )) {
      if (excludeDeliveryNumber != null &&
          interaction.deliveryId == excludeDeliveryNumber) {
        excluded.add(interaction.clientId);
      }
      if (!interaction.timestamp.isAfter(now)) {
        final previous = contacts[interaction.clientId];
        if (previous == null || interaction.timestamp.isAfter(previous)) {
          contacts[interaction.clientId] = interaction.timestamp;
        }
      }
    }
    final byClient = <int, List<Sale>>{};
    for (final sale in ownSales) {
      byClient.putIfAbsent(sale.clientId, () => []).add(sale);
      if (excludeDeliveryNumber != null &&
          sale.deliveryNumber == excludeDeliveryNumber) {
        excluded.add(sale.clientId);
      }
    }
    final candidates = <ClientRecommendation>[];
    for (final client in clientes.where((c) => c.sellerId == sellerId)) {
      if (excluded.contains(client.id)) continue;
      final metrics = ClientPurchaseMetrics.calculate(
        sales: byClient[client.id] ?? [],
        deliveries: ownDeliveries,
        now: now,
      );
      if (metrics.purchaseDays.isEmpty) continue;
      final contact = contacts[client.id];
      if (metrics.reactivation &&
          contact != null &&
          ClientPurchaseMetrics.calendarDay(
                now,
              ).difference(ClientPurchaseMetrics.calendarDay(contact)).inDays <
              reactivationCooldownDays) {
        continue;
      }
      candidates.add(ClientRecommendation(client, metrics, contact));
    }
    int compare(ClientRecommendation a, ClientRecommendation b) {
      final score = b.metrics.score.compareTo(a.metrics.score);
      return score != 0 ? score : a.cliente.id.compareTo(b.cliente.id);
    }

    final active = candidates.where((c) => !c.metrics.reactivation).toList()
      ..sort(compare);
    final selected = active
        .take(targetSize - followUpSlots - reactivationSlots)
        .toList();
    final ids = selected.map((c) => c.cliente.id).toSet();
    void add(Iterable<ClientRecommendation> pool, int count) {
      for (final candidate in pool) {
        if (count <= 0 || selected.length >= targetSize) break;
        if (ids.add(candidate.cliente.id)) {
          selected.add(candidate);
          count--;
        }
      }
    }

    add(active.where((c) => c.metrics.initialFollowUp), followUpSlots);
    final recoveries = candidates.where((c) => c.metrics.reactivation).toList()
      ..sort((a, b) {
        // Contactar primero a quien lleva más tiempo sin intento real.
        final dateA = a.lastContact ?? a.metrics.purchaseDays.last;
        final dateB = b.lastContact ?? b.metrics.purchaseDays.last;
        final date = dateA.compareTo(dateB);
        return date != 0 ? date : compare(a, b);
      });
    add(recoveries, reactivationSlots);
    add(active, targetSize - selected.length);
    // Los cupos garantizan presencia, no son un techo: si los activos no
    // llenan la lista, los huecos se completan con más reactivaciones.
    add([...recoveries]..sort(compare), targetSize - selected.length);
    // Los cupos dan acceso, no prioridad artificial en el orden visible.
    selected.sort(compare);
    return selected;
  }
}
