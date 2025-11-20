import 'package:drift/drift.dart';

part 'database.g.dart';

class Sales extends Table {
  IntColumn get id => integer()();
  DateTimeColumn get date => dateTime()();
  IntColumn get clientId => integer()(); // FK a tabla de clientes
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  RealColumn get total => real()();
  IntColumn get notesId => integer().nullable()(); // FK a tabla de notas
  IntColumn get deliveryNumber =>
      integer().nullable()(); // FK a tabla de entregas

  @override
  Set<Column> get primaryKey => {id};
}

class Deliveries extends Table {
  IntColumn get deliveryNumber => integer()();
  DateTimeColumn get date => dateTime()();
  IntColumn get durationSeconds => integer()(); // Duration stored as seconds
  RealColumn get avgPrice => real()();
  RealColumn get kilograms => real()();
  IntColumn get boxes => integer()();
  RealColumn get remaining => real()();
  TextColumn get seller => text()();
  RealColumn get total => real()();

  @override
  Set<Column> get primaryKey => {deliveryNumber};
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

  // Nuevas columnas agregadas
  IntColumn get eventos => integer().withDefault(const Constant(0))();
  RealColumn get kgTotal => real().withDefault(const Constant(0.0))();
  RealColumn get moda => real().withDefault(const Constant(0.0))();
  RealColumn get maximo => real().withDefault(const Constant(0.0))();
  RealColumn get ultimas10 => real().withDefault(const Constant(0.0))();
  RealColumn get kgEvento => real().withDefault(const Constant(0.0))();
  RealColumn get kgSemana => real().withDefault(const Constant(0.0))();
  RealColumn get ventasVuelta => real().withDefault(const Constant(0.0))();
  RealColumn get puntuacion => real().withDefault(const Constant(0.0))();
}

class Interacciones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer()(); // FK a tabla de clientes
  TextColumn get result =>
      text()(); // "Venta", "Rechazó", "Pendiente", "Encargó"
  IntColumn get deliveryId => integer()(); // FK a tabla de entregas
  DateTimeColumn get timestamp => dateTime()();
}

class Notas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nota => text()(); // Nota obligatoria
  IntColumn get clientId => integer()(); // FK a tabla de clientes, obligatorio
  IntColumn get ventaId =>
      integer().nullable()(); // FK a tabla de ventas, opcional
  TextColumn get color => text()(); // Color de la etiqueta
}

class PersistentDeliveryStates extends Table {
  TextColumn get id => text()(); // Usaremos un ID fijo como 'current'
  DateTimeColumn get startTime => dateTime().nullable()();
  BoolColumn get isPaused => boolean()();
  IntColumn get elapsedSeconds => integer()();
  BoolColumn get isActive => boolean()();
  IntColumn get deliveryNumber => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Sales,
    Deliveries,
    Clientes,
    Interacciones,
    Notas,
    PersistentDeliveryStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 11) {
        // For simplicity, we'll just create everything if coming from an old version.
        await migrator.createAll();
        return;
      }

      if (from == 11) {
        // Migration from v11 to v12: change `ventasVuelta` from INTEGER to REAL.
        await migrator.issueCustomQuery(
          'ALTER TABLE clientes RENAME TO _clientes_old_v11;',
        );
        await migrator.createTable(clientes);
        await migrator.issueCustomQuery(
          'INSERT INTO clientes (id, nombre, contacto, tipo_negocio, ciudad, domicilio, ubicacion, telefono, consumo, ultimo_contacto, hora_inicio, hora_cierre, notas_id, dias, eventos, kg_total, moda, maximo, ultimas10, kg_evento, kg_semana, puntuacion) '
          'SELECT id, nombre, contacto, tipo_negocio, ciudad, domicilio, ubicacion, telefono, consumo, ultimo_contacto, hora_inicio, hora_cierre, notas_id, dias, eventos, kg_total, moda, maximo, ultimas10, kg_evento, kg_semana, puntuacion FROM _clientes_old_v11;',
        );
        await migrator.issueCustomQuery('DROP TABLE _clientes_old_v11;');
      }

      if (from == 12) {
        // Migration from v12 to v13: add Notas table
        await migrator.createTable(notas);
      }

      if (from == 13) {
        // Migration from v13 to v14: rename Contactos to Interacciones
        await migrator.issueCustomQuery(
          'ALTER TABLE contactos RENAME TO interacciones;',
        );
      }
      if (from == 14) {
        // Migration v14 -> v15: add timestamp column to interacciones
        // SQLite does not allow non-constant expressions as DEFAULT values
        // in ALTER TABLE. We add the column (nullable), then populate it
        // for existing rows with the current datetime.
        await migrator.issueCustomQuery(
          "ALTER TABLE interacciones ADD COLUMN timestamp TEXT;",
        );
        await migrator.issueCustomQuery(
          "UPDATE interacciones SET timestamp = strftime('%Y-%m-%dT%H:%M:%f','now') WHERE timestamp IS NULL;",
        );
      }

      if (from == 15) {
        // Migration v15 -> v16: add PersistentDeliveryStates table
        await migrator.createTable(persistentDeliveryStates);
      }
    },
    onCreate: (migrator) async {
      await migrator.createAll();
    },
  );

  Future<int> insertSale({
    int? id,
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
        id: id != null ? Value(id) : Value.absent(),
        date: Value(date),
        clientId: Value(clientId),
        quantity: Value(quantity),
        price: Value(price),
        total: Value(total),
        notesId: Value(notesId),
        deliveryNumber: Value(deliveryNumber),
      ),
      mode: id != null ? InsertMode.replace : InsertMode.insert,
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
    int? eventos,
    double? kgTotal,
    double? moda,
    double? maximo,
    double? ultimas10,
    double? kgEvento,
    double? kgSemana,
    double? ventasVuelta,
    double? puntuacion,
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
        eventos: eventos != null ? Value(eventos) : Value.absent(),
        kgTotal: kgTotal != null ? Value(kgTotal) : Value.absent(),
        moda: moda != null ? Value(moda) : Value.absent(),
        maximo: maximo != null ? Value(maximo) : Value.absent(),
        ultimas10: ultimas10 != null ? Value(ultimas10) : Value.absent(),
        kgEvento: kgEvento != null ? Value(kgEvento) : Value.absent(),
        kgSemana: kgSemana != null ? Value(kgSemana) : Value.absent(),
        ventasVuelta: ventasVuelta != null
            ? Value(ventasVuelta)
            : Value.absent(),
        puntuacion: puntuacion != null ? Value(puntuacion) : Value.absent(),
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
    int? eventos,
    double? kgTotal,
    double? moda,
    double? maximo,
    double? ultimas10,
    double? kgEvento,
    double? kgSemana,
    double? ventasVuelta,
    double? puntuacion,
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
        eventos: eventos != null ? Value(eventos) : Value.absent(),
        kgTotal: kgTotal != null ? Value(kgTotal) : Value.absent(),
        moda: moda != null ? Value(moda) : Value.absent(),
        maximo: maximo != null ? Value(maximo) : Value.absent(),
        ultimas10: ultimas10 != null ? Value(ultimas10) : Value.absent(),
        kgEvento: kgEvento != null ? Value(kgEvento) : Value.absent(),
        kgSemana: kgSemana != null ? Value(kgSemana) : Value.absent(),
        ventasVuelta: ventasVuelta != null
            ? Value(ventasVuelta)
            : Value.absent(),
        puntuacion: puntuacion != null ? Value(puntuacion) : Value.absent(),
      ),
    );
  }

  Future<int> insertInteraccion({
    required int clientId,
    required String result,
    required int deliveryId,
    DateTime? timestamp,
  }) {
    return into(interacciones).insert(
      InteraccionesCompanion(
        clientId: Value(clientId),
        result: Value(result),
        deliveryId: Value(deliveryId),
        timestamp: Value(timestamp ?? DateTime.now()),
      ),
    );
  }

  Future<int> insertNota({
    required String nota,
    required int clientId,
    int? ventaId,
    required String color,
  }) {
    return into(notas).insert(
      NotasCompanion(
        nota: Value(nota),
        clientId: Value(clientId),
        ventaId: Value(ventaId),
        color: Value(color),
      ),
    );
  }

  Future<List<Nota>> getNotasByClientId(int clientId) {
    return (select(notas)..where((tbl) => tbl.clientId.equals(clientId))).get();
  }

  Future<List<Nota>> getNotasByVentaId(int ventaId) {
    return (select(notas)..where((tbl) => tbl.ventaId.equals(ventaId))).get();
  }

  Future<int> deleteNota(int id) {
    return (delete(notas)..where((tbl) => tbl.id.equals(id))).go();
  }
}
