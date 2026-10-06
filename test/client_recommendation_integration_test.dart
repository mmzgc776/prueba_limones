import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_limones/data/database.dart';
import 'package:prueba_limones/services/client_recommendation_service.dart';
import 'package:prueba_limones/services/database_service.dart';
import 'package:prueba_limones/services/delivery_service.dart';
import 'package:prueba_limones/services/sync_service.dart';

void main() {
  test('Drift: catálogo completo, cupos, exclusiones y orden estable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 9, 17, 12);
    Future<void> addClient(int id, List<int> ages, {int seller = 1}) async {
      await db.insertCliente(
        id: id,
        nombre: 'Cliente $id',
        contacto: '',
        tipoNegocio: '',
        ciudad: '',
        domicilio: '',
        ubicacion: '',
        telefono: '',
        consumo: 0,
        ultimoContacto: now,
        horaInicio: 0,
        horaCierre: 24,
        dias: '',
        sellerId: seller,
        puntuacion: id <= 220 ? 999 : 0,
      );
      for (final age in ages) {
        await db.insertSale(
          date: now.subtract(Duration(days: age)),
          clientId: id,
          quantity: 10,
          price: 1,
          total: 10,
          sellerId: seller,
        );
      }
    }

    // 220 antiguos con puntuación guardada alta; 70 activos y 12 nuevos.
    for (var id = 1; id <= 220; id++) {
      await addClient(id, [314, 307, 300]);
    }
    for (var id = 221; id <= 290; id++) {
      await addClient(id, [35, 28, 21, 14, 7]);
    }
    for (var id = 291; id <= 302; id++) {
      await addClient(id, [12, 5]);
    }
    await addClient(303, [5], seller: 2);
    await addClient(304, []);
    for (final entry in {
      221: 'Rechazó',
      291: 'Encargó',
      1: 'Pendiente',
    }.entries) {
      await db.insertInteraccion(
        clientId: entry.key,
        result: entry.value,
        deliveryId: 99,
        timestamp: now,
        sellerId: 1,
      );
    }
    await db.insertSale(
      date: now,
      clientId: 222,
      quantity: 1,
      price: 1,
      total: 1,
      sellerId: 1,
      deliveryNumber: 99,
    );
    await db.insertInteraccion(
      clientId: 2,
      result: 'Rechazó',
      deliveryId: 98,
      timestamp: now.subtract(const Duration(days: 13)),
      sellerId: 1,
    );
    final clients = await db.select(db.clientes).get();
    final sales = await db.select(db.sales).get();
    final interactions = await db.select(db.interacciones).get();
    final result = ClientRecommendationService.select(
      clientes: clients,
      sales: sales,
      deliveries: [],
      interactions: interactions,
      now: now,
      sellerId: 1,
      excludeDeliveryNumber: 99,
    );
    expect(result, hasLength(60));
    final ids = result.map((r) => r.cliente.id).toList();
    expect(ids.toSet(), hasLength(60));
    for (final excluded in [1, 2, 221, 222, 291, 303, 304]) {
      expect(ids, isNot(contains(excluded)));
    }
    expect(result.where((r) => r.metrics.initialFollowUp), hasLength(9));
    expect(result.where((r) => r.metrics.reactivation), hasLength(3));
    expect(result.first.cliente.id, greaterThan(220));
    for (var i = 1; i < result.length; i++) {
      expect(
        result[i - 1].metrics.score,
        greaterThanOrEqualTo(result[i].metrics.score),
      );
    }
    final reversed = ClientRecommendationService.select(
      clientes: clients.reversed.toList(),
      sales: sales.reversed.toList(),
      deliveries: [],
      interactions: interactions,
      now: now,
      sellerId: 1,
      excludeDeliveryNumber: 99,
    );
    expect(reversed.map((r) => r.cliente.id), ids);
    // Los cupos de reactivación son garantía, no techo: si no hay activos
    // suficientes, los huecos se completan con más reactivaciones.
    final onlyOld = ClientRecommendationService.select(
      clientes: clients.where((c) => c.id <= 220).toList(),
      sales: sales,
      deliveries: [],
      interactions: interactions,
      now: now,
      sellerId: 1,
      excludeDeliveryNumber: 99,
    );
    expect(onlyOld, hasLength(60));
    expect(onlyOld.every((r) => r.metrics.reactivation), isTrue);
    // 44 activos semanales + 44 reactivaciones → lista completa de 60.
    final mixed = ClientRecommendationService.select(
      clientes: [
        ...clients.where((c) => c.id >= 223 && c.id <= 266),
        ...clients.where((c) => c.id >= 101 && c.id <= 144),
      ].toList(),
      sales: sales,
      deliveries: [],
      interactions: interactions,
      now: now,
      sellerId: 1,
      excludeDeliveryNumber: 99,
    );
    expect(mixed, hasLength(60));
    expect(mixed.where((r) => !r.metrics.reactivation), hasLength(44));
    expect(mixed.where((r) => r.metrics.reactivation), hasLength(16));
    expect(mixed.map((r) => r.cliente.id).toSet(), hasLength(60));
    // Sin compras válidas no se inventan visitas.
    final none = ClientRecommendationService.select(
      clientes: clients.where((c) => c.id == 304).toList(),
      sales: sales,
      deliveries: [],
      interactions: interactions,
      now: now,
      sellerId: 1,
      excludeDeliveryNumber: 99,
    );
    expect(none, isEmpty);
    final service = DatabaseService.forTesting(db);
    final deliveryService = DeliveryService(
      databaseService: service,
      clock: () => now,
    );
    final loaded = await deliveryService.loadClientes(
      excludeDeliveryNumber: 99,
    );
    expect(loaded.clientes.map((c) => c.id), ids);
    expect(loaded.motivos, result.map((r) => r.tags));

    final sync = SyncService(service, clock: () => now);
    await sync.refreshSingleClientScore(223);
    final individual = await service.getClienteById(223);
    expect(
      individual!.puntuacion,
      result.firstWhere((r) => r.cliente.id == 223).metrics.score,
    );
    expect((await sync.updateClientScores()).success, isTrue);
    final general = await service.getClienteById(223);
    expect(general, individual);
    // La nueva lista no debe cambiar después de persistir las mismas métricas.
    expect(
      (await deliveryService.loadClientes(
        excludeDeliveryNumber: 99,
      )).clientes.map((c) => c.id),
      ids,
    );
    // Vaciar ventas del cliente limpia las métricas, no conserva el volumen viejo.
    await db.customStatement('DELETE FROM sales WHERE client_id = 223');
    await sync.refreshSingleClientScore(223);
    final cleared = await service.getClienteById(223);
    expect(cleared!.puntuacion, 0);
    expect(cleared.kgTotal, 0);
    expect(cleared.eventos, 0);
    expect(cleared.intervaloPromedio, 0);
    expect(
      jsonEncode(result.map((r) => r.reason).toList()),
      contains('Seguimiento'),
    );
  });
}
