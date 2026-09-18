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
  IntColumn get sellerId => integer()(); // FK a tabla de usuarios

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
  IntColumn get sellerId => integer()(); // FK a tabla de usuarios (reemplaza seller TEXT)
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

  // Métricas de ciclo de compra
  RealColumn get intervaloPromedio => real().nullable().withDefault(const Constant(0.0))();
  IntColumn get diasDesdeUltimaVenta => integer().nullable().withDefault(const Constant(0))();
  RealColumn get cicloScore => real().nullable().withDefault(const Constant(0.0))();

  // Métricas de patrón semanal
  IntColumn get diaSemanaPreferido => integer().nullable().withDefault(const Constant(0))();
  TextColumn get frecuenciasDiaSemana => text().nullable().withDefault(const Constant('{}'))();
  RealColumn get weekdayScore => real().nullable().withDefault(const Constant(0.0))();

  IntColumn get sellerId => integer().withDefault(const Constant(1))(); // FK a tabla de usuarios
}

class Interacciones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer()(); // FK a tabla de clientes
  TextColumn get result =>
      text()(); // "Venta", "Rechazó", "Pendiente", "Encargó"
  IntColumn get deliveryId => integer()(); // FK a tabla de entregas
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get sellerId => integer().withDefault(const Constant(1))(); // FK a tabla de usuarios
}

class Notas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nota => text()(); // Nota obligatoria
  IntColumn get clientId => integer()(); // FK a tabla de clientes, obligatorio
  IntColumn get ventaId =>
      integer().nullable()(); // FK a tabla de ventas, opcional
  TextColumn get color => text()(); // Color de la etiqueta
  IntColumn get sellerId => integer().withDefault(const Constant(1))(); // FK a tabla de usuarios
}

class Usuarios extends Table {
  IntColumn get id => integer()();
  TextColumn get nombre => text()();
  TextColumn get ciudad => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Gastos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sellerId => integer()();
  DateTimeColumn get fecha => dateTime()();
  TextColumn get concepto => text()();
  RealColumn get monto => real()();
  TextColumn get categoria => text()();
}

class PersistentDeliveryStates extends Table {
  TextColumn get id => text()(); // Usaremos un ID compuesto 'current_{sellerId}'
  DateTimeColumn get startTime => dateTime().nullable()();
  BoolColumn get isPaused => boolean()();
  IntColumn get elapsedSeconds => integer()();
  BoolColumn get isActive => boolean()();
  IntColumn get deliveryNumber => integer().nullable()();
  IntColumn get boxes => integer().withDefault(const Constant(0))();

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
    Usuarios,
    Gastos,
    PersistentDeliveryStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 19;

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

      if (from == 16) {
        // Migration v16 -> v17: add boxes column to PersistentDeliveryStates
        await migrator.issueCustomQuery(
          "ALTER TABLE persistent_delivery_states ADD COLUMN boxes INTEGER NOT NULL DEFAULT 0;",
        );
      }

      if (from == 17) {
        // Migration v17 -> v18: add purchase cycle and weekday pattern columns
        // Note: Columns are nullable to handle backwards compatibility
        await migrator.issueCustomQuery(
          "ALTER TABLE clientes ADD COLUMN intervalo_promedio REAL DEFAULT 0.0;",
        );
        await migrator.issueCustomQuery(
          "ALTER TABLE clientes ADD COLUMN dias_desde_ultima_venta INTEGER DEFAULT 0;",
        );
        await migrator.issueCustomQuery(
          "ALTER TABLE clientes ADD COLUMN ciclo_score REAL DEFAULT 0.0;",
        );
        await migrator.issueCustomQuery(
          "ALTER TABLE clientes ADD COLUMN dia_semana_preferido INTEGER DEFAULT 0;",
        );
        await migrator.issueCustomQuery(
          "ALTER TABLE clientes ADD COLUMN frecuencias_dia_semana TEXT DEFAULT '{}';",
        );
        await migrator.issueCustomQuery(
          "ALTER TABLE clientes ADD COLUMN weekday_score REAL DEFAULT 0.0;",
        );
      }

      if (from == 18) {
        // Migration v18 -> v19: Multi-tenant support
        // 1) Create Usuarios table
        await migrator.createTable(usuarios);
        // 2) Create Gastos table
        await migrator.createTable(gastos);
        // 3) Agregar columna seller_id a tablas existentes
        await migrator.issueCustomQuery(
          "ALTER TABLE sales ADD COLUMN seller_id INTEGER NOT NULL DEFAULT 1;",
        );
        await migrator.issueCustomQuery(
          "ALTER TABLE clientes ADD COLUMN seller_id INTEGER NOT NULL DEFAULT 1;",
        );
        await migrator.issueCustomQuery(
          "ALTER TABLE interacciones ADD COLUMN seller_id INTEGER NOT NULL DEFAULT 1;",
        );
        await migrator.issueCustomQuery(
          "ALTER TABLE notas ADD COLUMN seller_id INTEGER NOT NULL DEFAULT 1;",
        );
        // 4) Migrar deliverie: reemplazar seller TEXT por seller_id INT
        await migrator.issueCustomQuery(
          "ALTER TABLE deliveries RENAME TO _deliveries_old_v18;",
        );
        await migrator.createTable(deliveries);
        await migrator.issueCustomQuery(
          'INSERT INTO deliveries (delivery_number, date, duration_seconds, avg_price, kilograms, boxes, remaining, seller_id, total) '
          "SELECT delivery_number, date, duration_seconds, avg_price, kilograms, boxes, remaining, CASE WHEN seller IN ('Moy', 'Default Seller') THEN 1 ELSE 2 END, total FROM _deliveries_old_v18;",
        );
        await migrator.issueCustomQuery('DROP TABLE _deliveries_old_v18;');
        // 5) Poblar usuarios
        await migrator.issueCustomQuery(
          "INSERT OR IGNORE INTO usuarios (id, nombre, activo) VALUES (1, 'Moy', 1);",
        );
        await migrator.issueCustomQuery(
          "INSERT OR IGNORE INTO usuarios (id, nombre, activo) VALUES (2, 'Manuel', 1);",
        );
        // 6) Migrar el estado persistente ID 'current' -> 'current_1'
        await migrator.issueCustomQuery(
          "UPDATE persistent_delivery_states SET id = 'current_1' WHERE id = 'current';",
        );
      }
    },
    onCreate: (migrator) async {
      await migrator.createAll();
      // Poblar usuarios por defecto en BD nueva
      await migrator.issueCustomQuery(
        "INSERT OR IGNORE INTO usuarios (id, nombre, activo) VALUES (1, 'Moy', 1);",
      );
      await migrator.issueCustomQuery(
        "INSERT OR IGNORE INTO usuarios (id, nombre, activo) VALUES (2, 'Manuel', 1);",
      );
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
    int? sellerId,
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
        sellerId: Value(sellerId ?? 1),
      ),
      mode: id != null ? InsertMode.replace : InsertMode.insert,
    );
  }

  /// Guarda una venta nueva y su interacción como una única operación.
  /// Las importaciones y ediciones siguen usando sus métodos independientes.
  Future<int> insertSaleWithInteraction({
    required DateTime date,
    required int clientId,
    required double quantity,
    required double price,
    required double total,
    required int sellerId,
    int? deliveryNumber,
  }) {
    return transaction(() async {
      final saleId = await insertSale(
        date: date,
        clientId: clientId,
        quantity: quantity,
        price: price,
        total: total,
        sellerId: sellerId,
        deliveryNumber: deliveryNumber,
      );
      if (deliveryNumber != null) {
        await insertInteraccion(
          clientId: clientId,
          result: 'Venta',
          deliveryId: deliveryNumber,
          sellerId: sellerId,
        );
      }
      await (update(notas)..where(
        (tbl) => tbl.clientId.equals(clientId) &
            tbl.sellerId.equals(sellerId) & tbl.ventaId.isNull(),
      )).write(NotasCompanion(ventaId: Value(saleId)));
      return saleId;
    });
  }


  Future<int> insertDelivery({
    required int deliveryNumber,
    required DateTime date,
    required int durationSeconds,
    required double avgPrice,
    required double kilograms,
    required int boxes,
    required double remaining,
    required int sellerId,
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
        sellerId: Value(sellerId),
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
    int? sellerId,
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
        sellerId: Value(sellerId ?? 1),
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
    int? sellerId,
  }) {
    return into(interacciones).insert(
      InteraccionesCompanion(
        clientId: Value(clientId),
        result: Value(result),
        deliveryId: Value(deliveryId),
        timestamp: Value(timestamp ?? DateTime.now()),
        sellerId: Value(sellerId ?? 1),
      ),
    );
  }

  Future<int> insertNota({
    required String nota,
    required int clientId,
    int? ventaId,
    required String color,
    int? sellerId,
  }) {
    return into(notas).insert(
      NotasCompanion(
        nota: Value(nota),
        clientId: Value(clientId),
        ventaId: Value(ventaId),
        color: Value(color),
        sellerId: Value(sellerId ?? 1),
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

  // ===== OPERACIONES DE USUARIOS =====

  Future<int> insertUsuario({
    required int id,
    required String nombre,
    String? ciudad,
    bool activo = true,
  }) {
    return into(usuarios).insert(
      UsuariosCompanion(
        id: Value(id),
        nombre: Value(nombre),
        ciudad: Value(ciudad),
        activo: Value(activo),
      ),
      mode: InsertMode.replace,
    );
  }

  Future<List<Usuario>> getAllUsuarios() {
    return (select(usuarios)..where((tbl) => tbl.activo.equals(true))).get();
  }

  Future<Usuario?> getUsuarioById(int id) {
    return (select(usuarios)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // ===== OPERACIONES DE GASTOS =====

  Future<int> insertGasto({
    int? id,
    required int sellerId,
    required DateTime fecha,
    required String concepto,
    required double monto,
    required String categoria,
  }) {
    return into(gastos).insert(
      GastosCompanion(
        id: id != null ? Value(id) : Value.absent(),
        sellerId: Value(sellerId),
        fecha: Value(fecha),
        concepto: Value(concepto),
        monto: Value(monto),
        categoria: Value(categoria),
      ),
      mode: id != null ? InsertMode.replace : InsertMode.insert,
    );
  }

  Future<List<Gasto>> getAllGastosBySeller(int sellerId) {
    return (select(gastos)..where((tbl) => tbl.sellerId.equals(sellerId))).get();
  }

  Future<List<Gasto>> getAllGastos() {
    return select(gastos).get();
  }

  Future<Gasto?> getGastoById(int id) {
    return (select(gastos)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> updateGasto({
    required int id,
    required DateTime fecha,
    required String concepto,
    required double monto,
    required String categoria,
  }) {
    return (update(gastos)..where((tbl) => tbl.id.equals(id))).write(
      GastosCompanion(
        fecha: Value(fecha),
        concepto: Value(concepto),
        monto: Value(monto),
        categoria: Value(categoria),
      ),
    );
  }

  Future<int> deleteGasto(int id) {
    return (delete(gastos)..where((tbl) => tbl.id.equals(id))).go();
  }
}