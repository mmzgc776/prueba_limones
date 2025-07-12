import 'package:drift/drift.dart';

part 'database.g.dart';

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get clientId => integer()(); // FK a tabla de clientes
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  RealColumn get total => real()();
  IntColumn get notesId => integer().nullable()(); // FK a tabla de notas
  IntColumn get deliveryNumber =>
      integer().nullable()(); // FK a tabla de entregas
}

class Deliveries extends Table {
  IntColumn get deliveryNumber => integer().customConstraint('PRIMARY KEY')();
  DateTimeColumn get date => dateTime()();
  IntColumn get durationSeconds => integer()(); // Duration stored as seconds
  RealColumn get avgPrice => real()();
  RealColumn get kilograms => real()();
  IntColumn get boxes => integer()();
  RealColumn get remaining => real()();
  TextColumn get seller => text()();
  RealColumn get total => real()();
}

class Clientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get contacto => text()();
  TextColumn get tipoNegocio => text()();
  TextColumn get ciudad => text()();
  TextColumn get domicilio => text()();
  TextColumn get ubicacion => text()(); // Coordenada GPS as string
  TextColumn get telefono => text()();
  IntColumn get consumo => integer()();
  DateTimeColumn get ultimoContacto => dateTime()();
  IntColumn get horaInicio => integer()(); // 0-24 hour range
  IntColumn get horaCierre => integer()(); // 0-24 hour range
  IntColumn get notasId => integer().nullable()(); // FK to notas table
  TextColumn get dias => text()(); // DLMIJVS as string e.g., "0,1,2,3,4,5,6"
}

class Contactos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer()(); // FK a tabla de clientes
  TextColumn get result =>
      text()(); // "Venta", "Rechazó", "Pendiente", "Encargó"
  IntColumn get deliveryId => integer()(); // FK a tabla de entregas
}

// Aquí puedes agregar la tabla de notas después

@DriftDatabase(tables: [Sales, Deliveries, Clientes, Contactos])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from == 1) {
        await migrator.addColumn(sales, sales.deliveryNumber);
      }
      if (from < 5) {
        // Note: After making changes to the database schema, run `flutter pub run build_runner build` to regenerate the Drift code.
        // Create the Deliveries table if not exists for any version prior to 5.
        await migrator.createTable(deliveries);
      }
      if (from < 6) {
        // Create the Clientes table for versions prior to 6.
        await migrator.createTable(clientes);
      }
      if (from < 7) {
        // Instead of dropping the id column, we have set deliveryNumber as the primary key in the schema.
        // No action needed for existing id column; it will be ignored if it exists.
      }
      if (from < 8) {
        // Create the Contactos table for versions prior to 8.
        await migrator.createTable(contactos);
      }
    },
    onCreate: (migrator) async {
      await migrator.createAll();
    },
  );

  Future<int> insertSale({
    required DateTime date,
    required int clientId,
    required double quantity,
    required double price,
    required double total,
    int? notesId,
    int? deliveryNumber,
  }) {
    return into(sales).insert(
      SalesCompanion(
        date: Value(date),
        clientId: Value(clientId),
        quantity: Value(quantity),
        price: Value(price),
        total: Value(total),
        notesId: Value(notesId),
        deliveryNumber: Value(deliveryNumber),
      ),
    );
  }

  Future<int> insertDelivery({
    required int deliveryNumber,
    required DateTime date,
    required int durationSeconds,
    required double avgPrice,
    required double kilograms,
    required int boxes,
    required double remaining,
    required String seller,
    required double total,
  }) async {
    return into(deliveries).insert(
      DeliveriesCompanion(
        deliveryNumber: Value(deliveryNumber),
        date: Value(date),
        durationSeconds: Value(durationSeconds),
        avgPrice: Value(avgPrice),
        kilograms: Value(kilograms),
        boxes: Value(boxes),
        remaining: Value(remaining),
        seller: Value(seller),
        total: Value(total),
      ),
    );
  }

  Future<int> insertCliente({
    int? id,
    required String nombre,
    required String contacto,
    required String tipoNegocio,
    required String ciudad,
    required String domicilio,
    required String ubicacion,
    required String telefono,
    required int consumo,
    required DateTime ultimoContacto,
    required int horaInicio,
    required int horaCierre,
    int? notasId,
    required String dias,
  }) {
    return into(clientes).insert(
      ClientesCompanion(
        id: id != null ? Value(id) : Value.absent(),
        nombre: Value(nombre),
        contacto: Value(contacto),
        tipoNegocio: Value(tipoNegocio),
        ciudad: Value(ciudad),
        domicilio: Value(domicilio),
        ubicacion: Value(ubicacion),
        telefono: Value(telefono),
        consumo: Value(consumo),
        ultimoContacto: Value(ultimoContacto),
        horaInicio: Value(horaInicio),
        horaCierre: Value(horaCierre),
        notasId: Value(notasId),
        dias: Value(dias),
      ),
    );
  }

  Future<int> updateCliente({
    required int id,
    required String nombre,
    required String contacto,
    required String tipoNegocio,
    required String ciudad,
    required String domicilio,
    required String ubicacion,
    required String telefono,
    required int consumo,
    required DateTime ultimoContacto,
    required int horaInicio,
    required int horaCierre,
    required String dias,
  }) {
    return (update(clientes)..where((tbl) => tbl.id.equals(id))).write(
      ClientesCompanion(
        nombre: Value(nombre),
        contacto: Value(contacto),
        tipoNegocio: Value(tipoNegocio),
        ciudad: Value(ciudad),
        domicilio: Value(domicilio),
        ubicacion: Value(ubicacion),
        telefono: Value(telefono),
        consumo: Value(consumo),
        ultimoContacto: Value(ultimoContacto),
        horaInicio: Value(horaInicio),
        horaCierre: Value(horaCierre),
        dias: Value(dias),
      ),
    );
  }

  Future<int> insertContacto({
    required int clientId,
    required String result,
    required int deliveryId,
  }) {
    return into(contactos).insert(
      ContactosCompanion(
        clientId: Value(clientId),
        result: Value(result),
        deliveryId: Value(deliveryId),
      ),
    );
  }
}
