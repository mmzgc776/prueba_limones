import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_limones/data/database.dart';
import 'package:prueba_limones/services/client_recommendation_service.dart';

final now = DateTime(2026, 9, 17, 12);
Sale sale(
  int client,
  int daysAgo, {
  int seller = 1,
  int? delivery,
  double kg = 10,
}) => Sale(
  id: client * 1000 + daysAgo,
  clientId: client,
  sellerId: seller,
  date: now.subtract(Duration(days: daysAgo)),
  quantity: kg,
  price: 10,
  total: kg * 10,
  deliveryNumber: delivery,
);
ClientPurchaseMetrics metrics(List<int> ages) =>
    ClientPurchaseMetrics.calculate(
      sales: ages.map((age) => sale(1, age)).toList(),
      deliveries: [],
      now: now,
    );

void main() {
  test('Dos ventas el mismo día cuentan como una oportunidad de recompra', () {
    final m = metrics([14, 7, 7]);
    expect(m.purchaseDays, hasLength(2));
    expect(m.interval, 7);
    expect(m.confidence, 0.25);
    expect(m.initialFollowUp, isTrue);
    expect(m.kgTotal, 30);
  });
  test('El cliente semanal sube antes de su recompra y no cae de golpe', () {
    final yesterday = metrics([29, 22, 15, 8, 1]);
    final soon = metrics([33, 26, 19, 12, 5]);
    final due = metrics([35, 28, 21, 14, 7]);
    final late = metrics([38, 31, 24, 17, 10]);
    expect(soon.score, greaterThan(yesterday.score));
    expect(due.readiness, 1);
    expect(late.readiness, greaterThan(0.8));
    expect(yesterday.score, greaterThan(0));
  });
  test('Un solo día de compra no inventa un patrón', () {
    final m = metrics([5]);
    expect(m.interval, 0);
    expect(m.confidence, 0);
    expect(m.score.isFinite, isTrue);
    expect(m.score, greaterThan(0));
  });
  test('Un ciclo largo no se considera inactivo por superar 60 días', () {
    expect(metrics([250, 190, 130, 70]).reactivation, isFalse);
    expect(metrics([250, 190, 130, 70]).silenceFactor, 1);
    expect(metrics([84, 77, 70]).reactivation, isTrue);
  });
  test('La irregularidad reduce la confianza', () {
    expect(
      metrics([45, 38, 31, 24, 7]).confidence,
      lessThan(metrics([35, 28, 21, 14, 7]).confidence),
    );
  });
  test('Sin ventas válidas se borran métricas; no usar datos futuros', () {
    final m = metrics([-1]);
    expect(m.purchaseDays, isEmpty);
    expect(m.score, 0);
    expect(m.kgTotal, 0);
    expect(m.kgSemana, 0);
  });
}
