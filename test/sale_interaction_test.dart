import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_limones/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> save({int clientId = 42, int? deliveryNumber = 7}) {
    return db.insertSaleWithInteraction(
      date: DateTime(2026, 9, 17),
      clientId: clientId,
      quantity: 2,
      price: 10,
      total: 20,
      sellerId: 2,
      deliveryNumber: deliveryNumber,
    );
  }

  test(
    'La venta por búsqueda registra al comprador y vendedor correctos',
    () async {
      final saleId = await save();
      final sales = await db.select(db.sales).get();
      final interactions = await db.select(db.interacciones).get();

      expect(sales.single.id, saleId);
      expect(interactions.single.clientId, sales.single.clientId);
      expect(interactions.single.clientId, 42);
      expect(interactions.single.deliveryId, 7);
      expect(interactions.single.sellerId, 2);
      expect(interactions.single.result, 'Venta');
    },
  );

  test('Sin reparto se guarda la venta sin interacción', () async {
    await save(deliveryNumber: null);
    expect(await db.select(db.sales).get(), hasLength(1));
    expect(await db.select(db.interacciones).get(), isEmpty);
  });

  test('Dos ventas al mismo cliente generan dos interacciones', () async {
    await save();
    await save();
    expect(await db.select(db.sales).get(), hasLength(2));
    expect(await db.select(db.interacciones).get(), hasLength(2));
  });

  test(
    'El insert usado por candidatos e importaciones no duplica interacciones',
    () async {
      await db.insertInteraccion(
        clientId: 42,
        result: 'Venta',
        deliveryId: 7,
        sellerId: 2,
      );
      await db.insertSale(
        date: DateTime(2026, 9, 17),
        clientId: 42,
        quantity: 2,
        price: 10,
        total: 20,
        deliveryNumber: 7,
        sellerId: 2,
      );
      expect(await db.select(db.interacciones).get(), hasLength(1));
    },
  );

  test('Si falla la interacción también se revierte la venta', () async {
    await db.customStatement('''
      CREATE TRIGGER fail_interaction BEFORE INSERT ON interacciones
      BEGIN SELECT RAISE(ABORT, 'error de prueba'); END;
    ''');
    await expectLater(save(), throwsA(isA<Exception>()));
    expect(await db.select(db.sales).get(), isEmpty);
    expect(await db.select(db.interacciones).get(), isEmpty);
  });
}
