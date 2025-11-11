// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<int> clientId = GeneratedColumn<int>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesIdMeta = const VerificationMeta(
    'notesId',
  );
  @override
  late final GeneratedColumn<int> notesId = GeneratedColumn<int>(
    'notes_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deliveryNumberMeta = const VerificationMeta(
    'deliveryNumber',
  );
  @override
  late final GeneratedColumn<int> deliveryNumber = GeneratedColumn<int>(
    'delivery_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    clientId,
    quantity,
    price,
    total,
    notesId,
    deliveryNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('notes_id')) {
      context.handle(
        _notesIdMeta,
        notesId.isAcceptableOrUnknown(data['notes_id']!, _notesIdMeta),
      );
    }
    if (data.containsKey('delivery_number')) {
      context.handle(
        _deliveryNumberMeta,
        deliveryNumber.isAcceptableOrUnknown(
          data['delivery_number']!,
          _deliveryNumberMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
      notesId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notes_id'],
      ),
      deliveryNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delivery_number'],
      ),
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class Sale extends DataClass implements Insertable<Sale> {
  final int id;
  final DateTime date;
  final int clientId;
  final double quantity;
  final double price;
  final double total;
  final int? notesId;
  final int? deliveryNumber;
  const Sale({
    required this.id,
    required this.date,
    required this.clientId,
    required this.quantity,
    required this.price,
    required this.total,
    this.notesId,
    this.deliveryNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['client_id'] = Variable<int>(clientId);
    map['quantity'] = Variable<double>(quantity);
    map['price'] = Variable<double>(price);
    map['total'] = Variable<double>(total);
    if (!nullToAbsent || notesId != null) {
      map['notes_id'] = Variable<int>(notesId);
    }
    if (!nullToAbsent || deliveryNumber != null) {
      map['delivery_number'] = Variable<int>(deliveryNumber);
    }
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      date: Value(date),
      clientId: Value(clientId),
      quantity: Value(quantity),
      price: Value(price),
      total: Value(total),
      notesId: notesId == null && nullToAbsent
          ? const Value.absent()
          : Value(notesId),
      deliveryNumber: deliveryNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveryNumber),
    );
  }

  factory Sale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      clientId: serializer.fromJson<int>(json['clientId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      price: serializer.fromJson<double>(json['price']),
      total: serializer.fromJson<double>(json['total']),
      notesId: serializer.fromJson<int?>(json['notesId']),
      deliveryNumber: serializer.fromJson<int?>(json['deliveryNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'clientId': serializer.toJson<int>(clientId),
      'quantity': serializer.toJson<double>(quantity),
      'price': serializer.toJson<double>(price),
      'total': serializer.toJson<double>(total),
      'notesId': serializer.toJson<int?>(notesId),
      'deliveryNumber': serializer.toJson<int?>(deliveryNumber),
    };
  }

  Sale copyWith({
    int? id,
    DateTime? date,
    int? clientId,
    double? quantity,
    double? price,
    double? total,
    Value<int?> notesId = const Value.absent(),
    Value<int?> deliveryNumber = const Value.absent(),
  }) => Sale(
    id: id ?? this.id,
    date: date ?? this.date,
    clientId: clientId ?? this.clientId,
    quantity: quantity ?? this.quantity,
    price: price ?? this.price,
    total: total ?? this.total,
    notesId: notesId.present ? notesId.value : this.notesId,
    deliveryNumber: deliveryNumber.present
        ? deliveryNumber.value
        : this.deliveryNumber,
  );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      price: data.price.present ? data.price.value : this.price,
      total: data.total.present ? data.total.value : this.total,
      notesId: data.notesId.present ? data.notesId.value : this.notesId,
      deliveryNumber: data.deliveryNumber.present
          ? data.deliveryNumber.value
          : this.deliveryNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('clientId: $clientId, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('total: $total, ')
          ..write('notesId: $notesId, ')
          ..write('deliveryNumber: $deliveryNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    clientId,
    quantity,
    price,
    total,
    notesId,
    deliveryNumber,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.id == this.id &&
          other.date == this.date &&
          other.clientId == this.clientId &&
          other.quantity == this.quantity &&
          other.price == this.price &&
          other.total == this.total &&
          other.notesId == this.notesId &&
          other.deliveryNumber == this.deliveryNumber);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<int> clientId;
  final Value<double> quantity;
  final Value<double> price;
  final Value<double> total;
  final Value<int?> notesId;
  final Value<int?> deliveryNumber;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.clientId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.price = const Value.absent(),
    this.total = const Value.absent(),
    this.notesId = const Value.absent(),
    this.deliveryNumber = const Value.absent(),
  });
  SalesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required int clientId,
    required double quantity,
    required double price,
    required double total,
    this.notesId = const Value.absent(),
    this.deliveryNumber = const Value.absent(),
  }) : date = Value(date),
       clientId = Value(clientId),
       quantity = Value(quantity),
       price = Value(price),
       total = Value(total);
  static Insertable<Sale> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? clientId,
    Expression<double>? quantity,
    Expression<double>? price,
    Expression<double>? total,
    Expression<int>? notesId,
    Expression<int>? deliveryNumber,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (clientId != null) 'client_id': clientId,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
      if (total != null) 'total': total,
      if (notesId != null) 'notes_id': notesId,
      if (deliveryNumber != null) 'delivery_number': deliveryNumber,
    });
  }

  SalesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<int>? clientId,
    Value<double>? quantity,
    Value<double>? price,
    Value<double>? total,
    Value<int?>? notesId,
    Value<int?>? deliveryNumber,
  }) {
    return SalesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      clientId: clientId ?? this.clientId,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      total: total ?? this.total,
      notesId: notesId ?? this.notesId,
      deliveryNumber: deliveryNumber ?? this.deliveryNumber,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (notesId.present) {
      map['notes_id'] = Variable<int>(notesId.value);
    }
    if (deliveryNumber.present) {
      map['delivery_number'] = Variable<int>(deliveryNumber.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('clientId: $clientId, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('total: $total, ')
          ..write('notesId: $notesId, ')
          ..write('deliveryNumber: $deliveryNumber')
          ..write(')'))
        .toString();
  }
}

class $DeliveriesTable extends Deliveries
    with TableInfo<$DeliveriesTable, Delivery> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeliveriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deliveryNumberMeta = const VerificationMeta(
    'deliveryNumber',
  );
  @override
  late final GeneratedColumn<int> deliveryNumber = GeneratedColumn<int>(
    'delivery_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avgPriceMeta = const VerificationMeta(
    'avgPrice',
  );
  @override
  late final GeneratedColumn<double> avgPrice = GeneratedColumn<double>(
    'avg_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kilogramsMeta = const VerificationMeta(
    'kilograms',
  );
  @override
  late final GeneratedColumn<double> kilograms = GeneratedColumn<double>(
    'kilograms',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boxesMeta = const VerificationMeta('boxes');
  @override
  late final GeneratedColumn<int> boxes = GeneratedColumn<int>(
    'boxes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingMeta = const VerificationMeta(
    'remaining',
  );
  @override
  late final GeneratedColumn<double> remaining = GeneratedColumn<double>(
    'remaining',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sellerMeta = const VerificationMeta('seller');
  @override
  late final GeneratedColumn<String> seller = GeneratedColumn<String>(
    'seller',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deliveryNumber,
    date,
    durationSeconds,
    avgPrice,
    kilograms,
    boxes,
    remaining,
    seller,
    total,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deliveries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Delivery> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('delivery_number')) {
      context.handle(
        _deliveryNumberMeta,
        deliveryNumber.isAcceptableOrUnknown(
          data['delivery_number']!,
          _deliveryNumberMeta,
        ),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('avg_price')) {
      context.handle(
        _avgPriceMeta,
        avgPrice.isAcceptableOrUnknown(data['avg_price']!, _avgPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_avgPriceMeta);
    }
    if (data.containsKey('kilograms')) {
      context.handle(
        _kilogramsMeta,
        kilograms.isAcceptableOrUnknown(data['kilograms']!, _kilogramsMeta),
      );
    } else if (isInserting) {
      context.missing(_kilogramsMeta);
    }
    if (data.containsKey('boxes')) {
      context.handle(
        _boxesMeta,
        boxes.isAcceptableOrUnknown(data['boxes']!, _boxesMeta),
      );
    } else if (isInserting) {
      context.missing(_boxesMeta);
    }
    if (data.containsKey('remaining')) {
      context.handle(
        _remainingMeta,
        remaining.isAcceptableOrUnknown(data['remaining']!, _remainingMeta),
      );
    } else if (isInserting) {
      context.missing(_remainingMeta);
    }
    if (data.containsKey('seller')) {
      context.handle(
        _sellerMeta,
        seller.isAcceptableOrUnknown(data['seller']!, _sellerMeta),
      );
    } else if (isInserting) {
      context.missing(_sellerMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deliveryNumber};
  @override
  Delivery map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Delivery(
      deliveryNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delivery_number'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      avgPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_price'],
      )!,
      kilograms: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kilograms'],
      )!,
      boxes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}boxes'],
      )!,
      remaining: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}remaining'],
      )!,
      seller: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seller'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
    );
  }

  @override
  $DeliveriesTable createAlias(String alias) {
    return $DeliveriesTable(attachedDatabase, alias);
  }
}

class Delivery extends DataClass implements Insertable<Delivery> {
  final int deliveryNumber;
  final DateTime date;
  final int durationSeconds;
  final double avgPrice;
  final double kilograms;
  final int boxes;
  final double remaining;
  final String seller;
  final double total;
  const Delivery({
    required this.deliveryNumber,
    required this.date,
    required this.durationSeconds,
    required this.avgPrice,
    required this.kilograms,
    required this.boxes,
    required this.remaining,
    required this.seller,
    required this.total,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['delivery_number'] = Variable<int>(deliveryNumber);
    map['date'] = Variable<DateTime>(date);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['avg_price'] = Variable<double>(avgPrice);
    map['kilograms'] = Variable<double>(kilograms);
    map['boxes'] = Variable<int>(boxes);
    map['remaining'] = Variable<double>(remaining);
    map['seller'] = Variable<String>(seller);
    map['total'] = Variable<double>(total);
    return map;
  }

  DeliveriesCompanion toCompanion(bool nullToAbsent) {
    return DeliveriesCompanion(
      deliveryNumber: Value(deliveryNumber),
      date: Value(date),
      durationSeconds: Value(durationSeconds),
      avgPrice: Value(avgPrice),
      kilograms: Value(kilograms),
      boxes: Value(boxes),
      remaining: Value(remaining),
      seller: Value(seller),
      total: Value(total),
    );
  }

  factory Delivery.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Delivery(
      deliveryNumber: serializer.fromJson<int>(json['deliveryNumber']),
      date: serializer.fromJson<DateTime>(json['date']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      avgPrice: serializer.fromJson<double>(json['avgPrice']),
      kilograms: serializer.fromJson<double>(json['kilograms']),
      boxes: serializer.fromJson<int>(json['boxes']),
      remaining: serializer.fromJson<double>(json['remaining']),
      seller: serializer.fromJson<String>(json['seller']),
      total: serializer.fromJson<double>(json['total']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deliveryNumber': serializer.toJson<int>(deliveryNumber),
      'date': serializer.toJson<DateTime>(date),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'avgPrice': serializer.toJson<double>(avgPrice),
      'kilograms': serializer.toJson<double>(kilograms),
      'boxes': serializer.toJson<int>(boxes),
      'remaining': serializer.toJson<double>(remaining),
      'seller': serializer.toJson<String>(seller),
      'total': serializer.toJson<double>(total),
    };
  }

  Delivery copyWith({
    int? deliveryNumber,
    DateTime? date,
    int? durationSeconds,
    double? avgPrice,
    double? kilograms,
    int? boxes,
    double? remaining,
    String? seller,
    double? total,
  }) => Delivery(
    deliveryNumber: deliveryNumber ?? this.deliveryNumber,
    date: date ?? this.date,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    avgPrice: avgPrice ?? this.avgPrice,
    kilograms: kilograms ?? this.kilograms,
    boxes: boxes ?? this.boxes,
    remaining: remaining ?? this.remaining,
    seller: seller ?? this.seller,
    total: total ?? this.total,
  );
  Delivery copyWithCompanion(DeliveriesCompanion data) {
    return Delivery(
      deliveryNumber: data.deliveryNumber.present
          ? data.deliveryNumber.value
          : this.deliveryNumber,
      date: data.date.present ? data.date.value : this.date,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      avgPrice: data.avgPrice.present ? data.avgPrice.value : this.avgPrice,
      kilograms: data.kilograms.present ? data.kilograms.value : this.kilograms,
      boxes: data.boxes.present ? data.boxes.value : this.boxes,
      remaining: data.remaining.present ? data.remaining.value : this.remaining,
      seller: data.seller.present ? data.seller.value : this.seller,
      total: data.total.present ? data.total.value : this.total,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Delivery(')
          ..write('deliveryNumber: $deliveryNumber, ')
          ..write('date: $date, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('avgPrice: $avgPrice, ')
          ..write('kilograms: $kilograms, ')
          ..write('boxes: $boxes, ')
          ..write('remaining: $remaining, ')
          ..write('seller: $seller, ')
          ..write('total: $total')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deliveryNumber,
    date,
    durationSeconds,
    avgPrice,
    kilograms,
    boxes,
    remaining,
    seller,
    total,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Delivery &&
          other.deliveryNumber == this.deliveryNumber &&
          other.date == this.date &&
          other.durationSeconds == this.durationSeconds &&
          other.avgPrice == this.avgPrice &&
          other.kilograms == this.kilograms &&
          other.boxes == this.boxes &&
          other.remaining == this.remaining &&
          other.seller == this.seller &&
          other.total == this.total);
}

class DeliveriesCompanion extends UpdateCompanion<Delivery> {
  final Value<int> deliveryNumber;
  final Value<DateTime> date;
  final Value<int> durationSeconds;
  final Value<double> avgPrice;
  final Value<double> kilograms;
  final Value<int> boxes;
  final Value<double> remaining;
  final Value<String> seller;
  final Value<double> total;
  const DeliveriesCompanion({
    this.deliveryNumber = const Value.absent(),
    this.date = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.avgPrice = const Value.absent(),
    this.kilograms = const Value.absent(),
    this.boxes = const Value.absent(),
    this.remaining = const Value.absent(),
    this.seller = const Value.absent(),
    this.total = const Value.absent(),
  });
  DeliveriesCompanion.insert({
    this.deliveryNumber = const Value.absent(),
    required DateTime date,
    required int durationSeconds,
    required double avgPrice,
    required double kilograms,
    required int boxes,
    required double remaining,
    required String seller,
    required double total,
  }) : date = Value(date),
       durationSeconds = Value(durationSeconds),
       avgPrice = Value(avgPrice),
       kilograms = Value(kilograms),
       boxes = Value(boxes),
       remaining = Value(remaining),
       seller = Value(seller),
       total = Value(total);
  static Insertable<Delivery> custom({
    Expression<int>? deliveryNumber,
    Expression<DateTime>? date,
    Expression<int>? durationSeconds,
    Expression<double>? avgPrice,
    Expression<double>? kilograms,
    Expression<int>? boxes,
    Expression<double>? remaining,
    Expression<String>? seller,
    Expression<double>? total,
  }) {
    return RawValuesInsertable({
      if (deliveryNumber != null) 'delivery_number': deliveryNumber,
      if (date != null) 'date': date,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (avgPrice != null) 'avg_price': avgPrice,
      if (kilograms != null) 'kilograms': kilograms,
      if (boxes != null) 'boxes': boxes,
      if (remaining != null) 'remaining': remaining,
      if (seller != null) 'seller': seller,
      if (total != null) 'total': total,
    });
  }

  DeliveriesCompanion copyWith({
    Value<int>? deliveryNumber,
    Value<DateTime>? date,
    Value<int>? durationSeconds,
    Value<double>? avgPrice,
    Value<double>? kilograms,
    Value<int>? boxes,
    Value<double>? remaining,
    Value<String>? seller,
    Value<double>? total,
  }) {
    return DeliveriesCompanion(
      deliveryNumber: deliveryNumber ?? this.deliveryNumber,
      date: date ?? this.date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      avgPrice: avgPrice ?? this.avgPrice,
      kilograms: kilograms ?? this.kilograms,
      boxes: boxes ?? this.boxes,
      remaining: remaining ?? this.remaining,
      seller: seller ?? this.seller,
      total: total ?? this.total,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deliveryNumber.present) {
      map['delivery_number'] = Variable<int>(deliveryNumber.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (avgPrice.present) {
      map['avg_price'] = Variable<double>(avgPrice.value);
    }
    if (kilograms.present) {
      map['kilograms'] = Variable<double>(kilograms.value);
    }
    if (boxes.present) {
      map['boxes'] = Variable<int>(boxes.value);
    }
    if (remaining.present) {
      map['remaining'] = Variable<double>(remaining.value);
    }
    if (seller.present) {
      map['seller'] = Variable<String>(seller.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeliveriesCompanion(')
          ..write('deliveryNumber: $deliveryNumber, ')
          ..write('date: $date, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('avgPrice: $avgPrice, ')
          ..write('kilograms: $kilograms, ')
          ..write('boxes: $boxes, ')
          ..write('remaining: $remaining, ')
          ..write('seller: $seller, ')
          ..write('total: $total')
          ..write(')'))
        .toString();
  }
}

class $ClientesTable extends Clientes with TableInfo<$ClientesTable, Cliente> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactoMeta = const VerificationMeta(
    'contacto',
  );
  @override
  late final GeneratedColumn<String> contacto = GeneratedColumn<String>(
    'contacto',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoNegocioMeta = const VerificationMeta(
    'tipoNegocio',
  );
  @override
  late final GeneratedColumn<String> tipoNegocio = GeneratedColumn<String>(
    'tipo_negocio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ciudadMeta = const VerificationMeta('ciudad');
  @override
  late final GeneratedColumn<String> ciudad = GeneratedColumn<String>(
    'ciudad',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _domicilioMeta = const VerificationMeta(
    'domicilio',
  );
  @override
  late final GeneratedColumn<String> domicilio = GeneratedColumn<String>(
    'domicilio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ubicacionMeta = const VerificationMeta(
    'ubicacion',
  );
  @override
  late final GeneratedColumn<String> ubicacion = GeneratedColumn<String>(
    'ubicacion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _telefonoMeta = const VerificationMeta(
    'telefono',
  );
  @override
  late final GeneratedColumn<String> telefono = GeneratedColumn<String>(
    'telefono',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _consumoMeta = const VerificationMeta(
    'consumo',
  );
  @override
  late final GeneratedColumn<int> consumo = GeneratedColumn<int>(
    'consumo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ultimoContactoMeta = const VerificationMeta(
    'ultimoContacto',
  );
  @override
  late final GeneratedColumn<DateTime> ultimoContacto =
      GeneratedColumn<DateTime>(
        'ultimo_contacto',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _horaInicioMeta = const VerificationMeta(
    'horaInicio',
  );
  @override
  late final GeneratedColumn<int> horaInicio = GeneratedColumn<int>(
    'hora_inicio',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _horaCierreMeta = const VerificationMeta(
    'horaCierre',
  );
  @override
  late final GeneratedColumn<int> horaCierre = GeneratedColumn<int>(
    'hora_cierre',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notasIdMeta = const VerificationMeta(
    'notasId',
  );
  @override
  late final GeneratedColumn<int> notasId = GeneratedColumn<int>(
    'notas_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diasMeta = const VerificationMeta('dias');
  @override
  late final GeneratedColumn<String> dias = GeneratedColumn<String>(
    'dias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventosMeta = const VerificationMeta(
    'eventos',
  );
  @override
  late final GeneratedColumn<int> eventos = GeneratedColumn<int>(
    'eventos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _kgTotalMeta = const VerificationMeta(
    'kgTotal',
  );
  @override
  late final GeneratedColumn<double> kgTotal = GeneratedColumn<double>(
    'kg_total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _modaMeta = const VerificationMeta('moda');
  @override
  late final GeneratedColumn<double> moda = GeneratedColumn<double>(
    'moda',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _maximoMeta = const VerificationMeta('maximo');
  @override
  late final GeneratedColumn<double> maximo = GeneratedColumn<double>(
    'maximo',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _ultimas10Meta = const VerificationMeta(
    'ultimas10',
  );
  @override
  late final GeneratedColumn<double> ultimas10 = GeneratedColumn<double>(
    'ultimas10',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _kgEventoMeta = const VerificationMeta(
    'kgEvento',
  );
  @override
  late final GeneratedColumn<double> kgEvento = GeneratedColumn<double>(
    'kg_evento',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _kgSemanaMeta = const VerificationMeta(
    'kgSemana',
  );
  @override
  late final GeneratedColumn<double> kgSemana = GeneratedColumn<double>(
    'kg_semana',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _ventasVueltaMeta = const VerificationMeta(
    'ventasVuelta',
  );
  @override
  late final GeneratedColumn<double> ventasVuelta = GeneratedColumn<double>(
    'ventas_vuelta',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _puntuacionMeta = const VerificationMeta(
    'puntuacion',
  );
  @override
  late final GeneratedColumn<double> puntuacion = GeneratedColumn<double>(
    'puntuacion',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nombre,
    contacto,
    tipoNegocio,
    ciudad,
    domicilio,
    ubicacion,
    telefono,
    consumo,
    ultimoContacto,
    horaInicio,
    horaCierre,
    notasId,
    dias,
    eventos,
    kgTotal,
    moda,
    maximo,
    ultimas10,
    kgEvento,
    kgSemana,
    ventasVuelta,
    puntuacion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clientes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cliente> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('contacto')) {
      context.handle(
        _contactoMeta,
        contacto.isAcceptableOrUnknown(data['contacto']!, _contactoMeta),
      );
    } else if (isInserting) {
      context.missing(_contactoMeta);
    }
    if (data.containsKey('tipo_negocio')) {
      context.handle(
        _tipoNegocioMeta,
        tipoNegocio.isAcceptableOrUnknown(
          data['tipo_negocio']!,
          _tipoNegocioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tipoNegocioMeta);
    }
    if (data.containsKey('ciudad')) {
      context.handle(
        _ciudadMeta,
        ciudad.isAcceptableOrUnknown(data['ciudad']!, _ciudadMeta),
      );
    } else if (isInserting) {
      context.missing(_ciudadMeta);
    }
    if (data.containsKey('domicilio')) {
      context.handle(
        _domicilioMeta,
        domicilio.isAcceptableOrUnknown(data['domicilio']!, _domicilioMeta),
      );
    } else if (isInserting) {
      context.missing(_domicilioMeta);
    }
    if (data.containsKey('ubicacion')) {
      context.handle(
        _ubicacionMeta,
        ubicacion.isAcceptableOrUnknown(data['ubicacion']!, _ubicacionMeta),
      );
    } else if (isInserting) {
      context.missing(_ubicacionMeta);
    }
    if (data.containsKey('telefono')) {
      context.handle(
        _telefonoMeta,
        telefono.isAcceptableOrUnknown(data['telefono']!, _telefonoMeta),
      );
    } else if (isInserting) {
      context.missing(_telefonoMeta);
    }
    if (data.containsKey('consumo')) {
      context.handle(
        _consumoMeta,
        consumo.isAcceptableOrUnknown(data['consumo']!, _consumoMeta),
      );
    } else if (isInserting) {
      context.missing(_consumoMeta);
    }
    if (data.containsKey('ultimo_contacto')) {
      context.handle(
        _ultimoContactoMeta,
        ultimoContacto.isAcceptableOrUnknown(
          data['ultimo_contacto']!,
          _ultimoContactoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ultimoContactoMeta);
    }
    if (data.containsKey('hora_inicio')) {
      context.handle(
        _horaInicioMeta,
        horaInicio.isAcceptableOrUnknown(data['hora_inicio']!, _horaInicioMeta),
      );
    } else if (isInserting) {
      context.missing(_horaInicioMeta);
    }
    if (data.containsKey('hora_cierre')) {
      context.handle(
        _horaCierreMeta,
        horaCierre.isAcceptableOrUnknown(data['hora_cierre']!, _horaCierreMeta),
      );
    } else if (isInserting) {
      context.missing(_horaCierreMeta);
    }
    if (data.containsKey('notas_id')) {
      context.handle(
        _notasIdMeta,
        notasId.isAcceptableOrUnknown(data['notas_id']!, _notasIdMeta),
      );
    }
    if (data.containsKey('dias')) {
      context.handle(
        _diasMeta,
        dias.isAcceptableOrUnknown(data['dias']!, _diasMeta),
      );
    } else if (isInserting) {
      context.missing(_diasMeta);
    }
    if (data.containsKey('eventos')) {
      context.handle(
        _eventosMeta,
        eventos.isAcceptableOrUnknown(data['eventos']!, _eventosMeta),
      );
    }
    if (data.containsKey('kg_total')) {
      context.handle(
        _kgTotalMeta,
        kgTotal.isAcceptableOrUnknown(data['kg_total']!, _kgTotalMeta),
      );
    }
    if (data.containsKey('moda')) {
      context.handle(
        _modaMeta,
        moda.isAcceptableOrUnknown(data['moda']!, _modaMeta),
      );
    }
    if (data.containsKey('maximo')) {
      context.handle(
        _maximoMeta,
        maximo.isAcceptableOrUnknown(data['maximo']!, _maximoMeta),
      );
    }
    if (data.containsKey('ultimas10')) {
      context.handle(
        _ultimas10Meta,
        ultimas10.isAcceptableOrUnknown(data['ultimas10']!, _ultimas10Meta),
      );
    }
    if (data.containsKey('kg_evento')) {
      context.handle(
        _kgEventoMeta,
        kgEvento.isAcceptableOrUnknown(data['kg_evento']!, _kgEventoMeta),
      );
    }
    if (data.containsKey('kg_semana')) {
      context.handle(
        _kgSemanaMeta,
        kgSemana.isAcceptableOrUnknown(data['kg_semana']!, _kgSemanaMeta),
      );
    }
    if (data.containsKey('ventas_vuelta')) {
      context.handle(
        _ventasVueltaMeta,
        ventasVuelta.isAcceptableOrUnknown(
          data['ventas_vuelta']!,
          _ventasVueltaMeta,
        ),
      );
    }
    if (data.containsKey('puntuacion')) {
      context.handle(
        _puntuacionMeta,
        puntuacion.isAcceptableOrUnknown(data['puntuacion']!, _puntuacionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cliente map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cliente(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      contacto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contacto'],
      )!,
      tipoNegocio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_negocio'],
      )!,
      ciudad: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ciudad'],
      )!,
      domicilio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domicilio'],
      )!,
      ubicacion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ubicacion'],
      )!,
      telefono: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}telefono'],
      )!,
      consumo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consumo'],
      )!,
      ultimoContacto: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ultimo_contacto'],
      )!,
      horaInicio: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hora_inicio'],
      )!,
      horaCierre: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hora_cierre'],
      )!,
      notasId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notas_id'],
      ),
      dias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dias'],
      )!,
      eventos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}eventos'],
      )!,
      kgTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kg_total'],
      )!,
      moda: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}moda'],
      )!,
      maximo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}maximo'],
      )!,
      ultimas10: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ultimas10'],
      )!,
      kgEvento: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kg_evento'],
      )!,
      kgSemana: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kg_semana'],
      )!,
      ventasVuelta: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ventas_vuelta'],
      )!,
      puntuacion: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}puntuacion'],
      )!,
    );
  }

  @override
  $ClientesTable createAlias(String alias) {
    return $ClientesTable(attachedDatabase, alias);
  }
}

class Cliente extends DataClass implements Insertable<Cliente> {
  final int id;
  final String nombre;
  final String contacto;
  final String tipoNegocio;
  final String ciudad;
  final String domicilio;
  final String ubicacion;
  final String telefono;
  final int consumo;
  final DateTime ultimoContacto;
  final int horaInicio;
  final int horaCierre;
  final int? notasId;
  final String dias;
  final int eventos;
  final double kgTotal;
  final double moda;
  final double maximo;
  final double ultimas10;
  final double kgEvento;
  final double kgSemana;
  final double ventasVuelta;
  final double puntuacion;
  const Cliente({
    required this.id,
    required this.nombre,
    required this.contacto,
    required this.tipoNegocio,
    required this.ciudad,
    required this.domicilio,
    required this.ubicacion,
    required this.telefono,
    required this.consumo,
    required this.ultimoContacto,
    required this.horaInicio,
    required this.horaCierre,
    this.notasId,
    required this.dias,
    required this.eventos,
    required this.kgTotal,
    required this.moda,
    required this.maximo,
    required this.ultimas10,
    required this.kgEvento,
    required this.kgSemana,
    required this.ventasVuelta,
    required this.puntuacion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nombre'] = Variable<String>(nombre);
    map['contacto'] = Variable<String>(contacto);
    map['tipo_negocio'] = Variable<String>(tipoNegocio);
    map['ciudad'] = Variable<String>(ciudad);
    map['domicilio'] = Variable<String>(domicilio);
    map['ubicacion'] = Variable<String>(ubicacion);
    map['telefono'] = Variable<String>(telefono);
    map['consumo'] = Variable<int>(consumo);
    map['ultimo_contacto'] = Variable<DateTime>(ultimoContacto);
    map['hora_inicio'] = Variable<int>(horaInicio);
    map['hora_cierre'] = Variable<int>(horaCierre);
    if (!nullToAbsent || notasId != null) {
      map['notas_id'] = Variable<int>(notasId);
    }
    map['dias'] = Variable<String>(dias);
    map['eventos'] = Variable<int>(eventos);
    map['kg_total'] = Variable<double>(kgTotal);
    map['moda'] = Variable<double>(moda);
    map['maximo'] = Variable<double>(maximo);
    map['ultimas10'] = Variable<double>(ultimas10);
    map['kg_evento'] = Variable<double>(kgEvento);
    map['kg_semana'] = Variable<double>(kgSemana);
    map['ventas_vuelta'] = Variable<double>(ventasVuelta);
    map['puntuacion'] = Variable<double>(puntuacion);
    return map;
  }

  ClientesCompanion toCompanion(bool nullToAbsent) {
    return ClientesCompanion(
      id: Value(id),
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
      notasId: notasId == null && nullToAbsent
          ? const Value.absent()
          : Value(notasId),
      dias: Value(dias),
      eventos: Value(eventos),
      kgTotal: Value(kgTotal),
      moda: Value(moda),
      maximo: Value(maximo),
      ultimas10: Value(ultimas10),
      kgEvento: Value(kgEvento),
      kgSemana: Value(kgSemana),
      ventasVuelta: Value(ventasVuelta),
      puntuacion: Value(puntuacion),
    );
  }

  factory Cliente.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cliente(
      id: serializer.fromJson<int>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      contacto: serializer.fromJson<String>(json['contacto']),
      tipoNegocio: serializer.fromJson<String>(json['tipoNegocio']),
      ciudad: serializer.fromJson<String>(json['ciudad']),
      domicilio: serializer.fromJson<String>(json['domicilio']),
      ubicacion: serializer.fromJson<String>(json['ubicacion']),
      telefono: serializer.fromJson<String>(json['telefono']),
      consumo: serializer.fromJson<int>(json['consumo']),
      ultimoContacto: serializer.fromJson<DateTime>(json['ultimoContacto']),
      horaInicio: serializer.fromJson<int>(json['horaInicio']),
      horaCierre: serializer.fromJson<int>(json['horaCierre']),
      notasId: serializer.fromJson<int?>(json['notasId']),
      dias: serializer.fromJson<String>(json['dias']),
      eventos: serializer.fromJson<int>(json['eventos']),
      kgTotal: serializer.fromJson<double>(json['kgTotal']),
      moda: serializer.fromJson<double>(json['moda']),
      maximo: serializer.fromJson<double>(json['maximo']),
      ultimas10: serializer.fromJson<double>(json['ultimas10']),
      kgEvento: serializer.fromJson<double>(json['kgEvento']),
      kgSemana: serializer.fromJson<double>(json['kgSemana']),
      ventasVuelta: serializer.fromJson<double>(json['ventasVuelta']),
      puntuacion: serializer.fromJson<double>(json['puntuacion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nombre': serializer.toJson<String>(nombre),
      'contacto': serializer.toJson<String>(contacto),
      'tipoNegocio': serializer.toJson<String>(tipoNegocio),
      'ciudad': serializer.toJson<String>(ciudad),
      'domicilio': serializer.toJson<String>(domicilio),
      'ubicacion': serializer.toJson<String>(ubicacion),
      'telefono': serializer.toJson<String>(telefono),
      'consumo': serializer.toJson<int>(consumo),
      'ultimoContacto': serializer.toJson<DateTime>(ultimoContacto),
      'horaInicio': serializer.toJson<int>(horaInicio),
      'horaCierre': serializer.toJson<int>(horaCierre),
      'notasId': serializer.toJson<int?>(notasId),
      'dias': serializer.toJson<String>(dias),
      'eventos': serializer.toJson<int>(eventos),
      'kgTotal': serializer.toJson<double>(kgTotal),
      'moda': serializer.toJson<double>(moda),
      'maximo': serializer.toJson<double>(maximo),
      'ultimas10': serializer.toJson<double>(ultimas10),
      'kgEvento': serializer.toJson<double>(kgEvento),
      'kgSemana': serializer.toJson<double>(kgSemana),
      'ventasVuelta': serializer.toJson<double>(ventasVuelta),
      'puntuacion': serializer.toJson<double>(puntuacion),
    };
  }

  Cliente copyWith({
    int? id,
    String? nombre,
    String? contacto,
    String? tipoNegocio,
    String? ciudad,
    String? domicilio,
    String? ubicacion,
    String? telefono,
    int? consumo,
    DateTime? ultimoContacto,
    int? horaInicio,
    int? horaCierre,
    Value<int?> notasId = const Value.absent(),
    String? dias,
    int? eventos,
    double? kgTotal,
    double? moda,
    double? maximo,
    double? ultimas10,
    double? kgEvento,
    double? kgSemana,
    double? ventasVuelta,
    double? puntuacion,
  }) => Cliente(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    contacto: contacto ?? this.contacto,
    tipoNegocio: tipoNegocio ?? this.tipoNegocio,
    ciudad: ciudad ?? this.ciudad,
    domicilio: domicilio ?? this.domicilio,
    ubicacion: ubicacion ?? this.ubicacion,
    telefono: telefono ?? this.telefono,
    consumo: consumo ?? this.consumo,
    ultimoContacto: ultimoContacto ?? this.ultimoContacto,
    horaInicio: horaInicio ?? this.horaInicio,
    horaCierre: horaCierre ?? this.horaCierre,
    notasId: notasId.present ? notasId.value : this.notasId,
    dias: dias ?? this.dias,
    eventos: eventos ?? this.eventos,
    kgTotal: kgTotal ?? this.kgTotal,
    moda: moda ?? this.moda,
    maximo: maximo ?? this.maximo,
    ultimas10: ultimas10 ?? this.ultimas10,
    kgEvento: kgEvento ?? this.kgEvento,
    kgSemana: kgSemana ?? this.kgSemana,
    ventasVuelta: ventasVuelta ?? this.ventasVuelta,
    puntuacion: puntuacion ?? this.puntuacion,
  );
  Cliente copyWithCompanion(ClientesCompanion data) {
    return Cliente(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      contacto: data.contacto.present ? data.contacto.value : this.contacto,
      tipoNegocio: data.tipoNegocio.present
          ? data.tipoNegocio.value
          : this.tipoNegocio,
      ciudad: data.ciudad.present ? data.ciudad.value : this.ciudad,
      domicilio: data.domicilio.present ? data.domicilio.value : this.domicilio,
      ubicacion: data.ubicacion.present ? data.ubicacion.value : this.ubicacion,
      telefono: data.telefono.present ? data.telefono.value : this.telefono,
      consumo: data.consumo.present ? data.consumo.value : this.consumo,
      ultimoContacto: data.ultimoContacto.present
          ? data.ultimoContacto.value
          : this.ultimoContacto,
      horaInicio: data.horaInicio.present
          ? data.horaInicio.value
          : this.horaInicio,
      horaCierre: data.horaCierre.present
          ? data.horaCierre.value
          : this.horaCierre,
      notasId: data.notasId.present ? data.notasId.value : this.notasId,
      dias: data.dias.present ? data.dias.value : this.dias,
      eventos: data.eventos.present ? data.eventos.value : this.eventos,
      kgTotal: data.kgTotal.present ? data.kgTotal.value : this.kgTotal,
      moda: data.moda.present ? data.moda.value : this.moda,
      maximo: data.maximo.present ? data.maximo.value : this.maximo,
      ultimas10: data.ultimas10.present ? data.ultimas10.value : this.ultimas10,
      kgEvento: data.kgEvento.present ? data.kgEvento.value : this.kgEvento,
      kgSemana: data.kgSemana.present ? data.kgSemana.value : this.kgSemana,
      ventasVuelta: data.ventasVuelta.present
          ? data.ventasVuelta.value
          : this.ventasVuelta,
      puntuacion: data.puntuacion.present
          ? data.puntuacion.value
          : this.puntuacion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cliente(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('contacto: $contacto, ')
          ..write('tipoNegocio: $tipoNegocio, ')
          ..write('ciudad: $ciudad, ')
          ..write('domicilio: $domicilio, ')
          ..write('ubicacion: $ubicacion, ')
          ..write('telefono: $telefono, ')
          ..write('consumo: $consumo, ')
          ..write('ultimoContacto: $ultimoContacto, ')
          ..write('horaInicio: $horaInicio, ')
          ..write('horaCierre: $horaCierre, ')
          ..write('notasId: $notasId, ')
          ..write('dias: $dias, ')
          ..write('eventos: $eventos, ')
          ..write('kgTotal: $kgTotal, ')
          ..write('moda: $moda, ')
          ..write('maximo: $maximo, ')
          ..write('ultimas10: $ultimas10, ')
          ..write('kgEvento: $kgEvento, ')
          ..write('kgSemana: $kgSemana, ')
          ..write('ventasVuelta: $ventasVuelta, ')
          ..write('puntuacion: $puntuacion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    nombre,
    contacto,
    tipoNegocio,
    ciudad,
    domicilio,
    ubicacion,
    telefono,
    consumo,
    ultimoContacto,
    horaInicio,
    horaCierre,
    notasId,
    dias,
    eventos,
    kgTotal,
    moda,
    maximo,
    ultimas10,
    kgEvento,
    kgSemana,
    ventasVuelta,
    puntuacion,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cliente &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.contacto == this.contacto &&
          other.tipoNegocio == this.tipoNegocio &&
          other.ciudad == this.ciudad &&
          other.domicilio == this.domicilio &&
          other.ubicacion == this.ubicacion &&
          other.telefono == this.telefono &&
          other.consumo == this.consumo &&
          other.ultimoContacto == this.ultimoContacto &&
          other.horaInicio == this.horaInicio &&
          other.horaCierre == this.horaCierre &&
          other.notasId == this.notasId &&
          other.dias == this.dias &&
          other.eventos == this.eventos &&
          other.kgTotal == this.kgTotal &&
          other.moda == this.moda &&
          other.maximo == this.maximo &&
          other.ultimas10 == this.ultimas10 &&
          other.kgEvento == this.kgEvento &&
          other.kgSemana == this.kgSemana &&
          other.ventasVuelta == this.ventasVuelta &&
          other.puntuacion == this.puntuacion);
}

class ClientesCompanion extends UpdateCompanion<Cliente> {
  final Value<int> id;
  final Value<String> nombre;
  final Value<String> contacto;
  final Value<String> tipoNegocio;
  final Value<String> ciudad;
  final Value<String> domicilio;
  final Value<String> ubicacion;
  final Value<String> telefono;
  final Value<int> consumo;
  final Value<DateTime> ultimoContacto;
  final Value<int> horaInicio;
  final Value<int> horaCierre;
  final Value<int?> notasId;
  final Value<String> dias;
  final Value<int> eventos;
  final Value<double> kgTotal;
  final Value<double> moda;
  final Value<double> maximo;
  final Value<double> ultimas10;
  final Value<double> kgEvento;
  final Value<double> kgSemana;
  final Value<double> ventasVuelta;
  final Value<double> puntuacion;
  const ClientesCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.contacto = const Value.absent(),
    this.tipoNegocio = const Value.absent(),
    this.ciudad = const Value.absent(),
    this.domicilio = const Value.absent(),
    this.ubicacion = const Value.absent(),
    this.telefono = const Value.absent(),
    this.consumo = const Value.absent(),
    this.ultimoContacto = const Value.absent(),
    this.horaInicio = const Value.absent(),
    this.horaCierre = const Value.absent(),
    this.notasId = const Value.absent(),
    this.dias = const Value.absent(),
    this.eventos = const Value.absent(),
    this.kgTotal = const Value.absent(),
    this.moda = const Value.absent(),
    this.maximo = const Value.absent(),
    this.ultimas10 = const Value.absent(),
    this.kgEvento = const Value.absent(),
    this.kgSemana = const Value.absent(),
    this.ventasVuelta = const Value.absent(),
    this.puntuacion = const Value.absent(),
  });
  ClientesCompanion.insert({
    this.id = const Value.absent(),
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
    this.notasId = const Value.absent(),
    required String dias,
    this.eventos = const Value.absent(),
    this.kgTotal = const Value.absent(),
    this.moda = const Value.absent(),
    this.maximo = const Value.absent(),
    this.ultimas10 = const Value.absent(),
    this.kgEvento = const Value.absent(),
    this.kgSemana = const Value.absent(),
    this.ventasVuelta = const Value.absent(),
    this.puntuacion = const Value.absent(),
  }) : nombre = Value(nombre),
       contacto = Value(contacto),
       tipoNegocio = Value(tipoNegocio),
       ciudad = Value(ciudad),
       domicilio = Value(domicilio),
       ubicacion = Value(ubicacion),
       telefono = Value(telefono),
       consumo = Value(consumo),
       ultimoContacto = Value(ultimoContacto),
       horaInicio = Value(horaInicio),
       horaCierre = Value(horaCierre),
       dias = Value(dias);
  static Insertable<Cliente> custom({
    Expression<int>? id,
    Expression<String>? nombre,
    Expression<String>? contacto,
    Expression<String>? tipoNegocio,
    Expression<String>? ciudad,
    Expression<String>? domicilio,
    Expression<String>? ubicacion,
    Expression<String>? telefono,
    Expression<int>? consumo,
    Expression<DateTime>? ultimoContacto,
    Expression<int>? horaInicio,
    Expression<int>? horaCierre,
    Expression<int>? notasId,
    Expression<String>? dias,
    Expression<int>? eventos,
    Expression<double>? kgTotal,
    Expression<double>? moda,
    Expression<double>? maximo,
    Expression<double>? ultimas10,
    Expression<double>? kgEvento,
    Expression<double>? kgSemana,
    Expression<double>? ventasVuelta,
    Expression<double>? puntuacion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (contacto != null) 'contacto': contacto,
      if (tipoNegocio != null) 'tipo_negocio': tipoNegocio,
      if (ciudad != null) 'ciudad': ciudad,
      if (domicilio != null) 'domicilio': domicilio,
      if (ubicacion != null) 'ubicacion': ubicacion,
      if (telefono != null) 'telefono': telefono,
      if (consumo != null) 'consumo': consumo,
      if (ultimoContacto != null) 'ultimo_contacto': ultimoContacto,
      if (horaInicio != null) 'hora_inicio': horaInicio,
      if (horaCierre != null) 'hora_cierre': horaCierre,
      if (notasId != null) 'notas_id': notasId,
      if (dias != null) 'dias': dias,
      if (eventos != null) 'eventos': eventos,
      if (kgTotal != null) 'kg_total': kgTotal,
      if (moda != null) 'moda': moda,
      if (maximo != null) 'maximo': maximo,
      if (ultimas10 != null) 'ultimas10': ultimas10,
      if (kgEvento != null) 'kg_evento': kgEvento,
      if (kgSemana != null) 'kg_semana': kgSemana,
      if (ventasVuelta != null) 'ventas_vuelta': ventasVuelta,
      if (puntuacion != null) 'puntuacion': puntuacion,
    });
  }

  ClientesCompanion copyWith({
    Value<int>? id,
    Value<String>? nombre,
    Value<String>? contacto,
    Value<String>? tipoNegocio,
    Value<String>? ciudad,
    Value<String>? domicilio,
    Value<String>? ubicacion,
    Value<String>? telefono,
    Value<int>? consumo,
    Value<DateTime>? ultimoContacto,
    Value<int>? horaInicio,
    Value<int>? horaCierre,
    Value<int?>? notasId,
    Value<String>? dias,
    Value<int>? eventos,
    Value<double>? kgTotal,
    Value<double>? moda,
    Value<double>? maximo,
    Value<double>? ultimas10,
    Value<double>? kgEvento,
    Value<double>? kgSemana,
    Value<double>? ventasVuelta,
    Value<double>? puntuacion,
  }) {
    return ClientesCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      contacto: contacto ?? this.contacto,
      tipoNegocio: tipoNegocio ?? this.tipoNegocio,
      ciudad: ciudad ?? this.ciudad,
      domicilio: domicilio ?? this.domicilio,
      ubicacion: ubicacion ?? this.ubicacion,
      telefono: telefono ?? this.telefono,
      consumo: consumo ?? this.consumo,
      ultimoContacto: ultimoContacto ?? this.ultimoContacto,
      horaInicio: horaInicio ?? this.horaInicio,
      horaCierre: horaCierre ?? this.horaCierre,
      notasId: notasId ?? this.notasId,
      dias: dias ?? this.dias,
      eventos: eventos ?? this.eventos,
      kgTotal: kgTotal ?? this.kgTotal,
      moda: moda ?? this.moda,
      maximo: maximo ?? this.maximo,
      ultimas10: ultimas10 ?? this.ultimas10,
      kgEvento: kgEvento ?? this.kgEvento,
      kgSemana: kgSemana ?? this.kgSemana,
      ventasVuelta: ventasVuelta ?? this.ventasVuelta,
      puntuacion: puntuacion ?? this.puntuacion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (contacto.present) {
      map['contacto'] = Variable<String>(contacto.value);
    }
    if (tipoNegocio.present) {
      map['tipo_negocio'] = Variable<String>(tipoNegocio.value);
    }
    if (ciudad.present) {
      map['ciudad'] = Variable<String>(ciudad.value);
    }
    if (domicilio.present) {
      map['domicilio'] = Variable<String>(domicilio.value);
    }
    if (ubicacion.present) {
      map['ubicacion'] = Variable<String>(ubicacion.value);
    }
    if (telefono.present) {
      map['telefono'] = Variable<String>(telefono.value);
    }
    if (consumo.present) {
      map['consumo'] = Variable<int>(consumo.value);
    }
    if (ultimoContacto.present) {
      map['ultimo_contacto'] = Variable<DateTime>(ultimoContacto.value);
    }
    if (horaInicio.present) {
      map['hora_inicio'] = Variable<int>(horaInicio.value);
    }
    if (horaCierre.present) {
      map['hora_cierre'] = Variable<int>(horaCierre.value);
    }
    if (notasId.present) {
      map['notas_id'] = Variable<int>(notasId.value);
    }
    if (dias.present) {
      map['dias'] = Variable<String>(dias.value);
    }
    if (eventos.present) {
      map['eventos'] = Variable<int>(eventos.value);
    }
    if (kgTotal.present) {
      map['kg_total'] = Variable<double>(kgTotal.value);
    }
    if (moda.present) {
      map['moda'] = Variable<double>(moda.value);
    }
    if (maximo.present) {
      map['maximo'] = Variable<double>(maximo.value);
    }
    if (ultimas10.present) {
      map['ultimas10'] = Variable<double>(ultimas10.value);
    }
    if (kgEvento.present) {
      map['kg_evento'] = Variable<double>(kgEvento.value);
    }
    if (kgSemana.present) {
      map['kg_semana'] = Variable<double>(kgSemana.value);
    }
    if (ventasVuelta.present) {
      map['ventas_vuelta'] = Variable<double>(ventasVuelta.value);
    }
    if (puntuacion.present) {
      map['puntuacion'] = Variable<double>(puntuacion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientesCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('contacto: $contacto, ')
          ..write('tipoNegocio: $tipoNegocio, ')
          ..write('ciudad: $ciudad, ')
          ..write('domicilio: $domicilio, ')
          ..write('ubicacion: $ubicacion, ')
          ..write('telefono: $telefono, ')
          ..write('consumo: $consumo, ')
          ..write('ultimoContacto: $ultimoContacto, ')
          ..write('horaInicio: $horaInicio, ')
          ..write('horaCierre: $horaCierre, ')
          ..write('notasId: $notasId, ')
          ..write('dias: $dias, ')
          ..write('eventos: $eventos, ')
          ..write('kgTotal: $kgTotal, ')
          ..write('moda: $moda, ')
          ..write('maximo: $maximo, ')
          ..write('ultimas10: $ultimas10, ')
          ..write('kgEvento: $kgEvento, ')
          ..write('kgSemana: $kgSemana, ')
          ..write('ventasVuelta: $ventasVuelta, ')
          ..write('puntuacion: $puntuacion')
          ..write(')'))
        .toString();
  }
}

class $InteraccionesTable extends Interacciones
    with TableInfo<$InteraccionesTable, Interaccione> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InteraccionesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<int> clientId = GeneratedColumn<int>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deliveryIdMeta = const VerificationMeta(
    'deliveryId',
  );
  @override
  late final GeneratedColumn<int> deliveryId = GeneratedColumn<int>(
    'delivery_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, clientId, result, deliveryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interacciones';
  @override
  VerificationContext validateIntegrity(
    Insertable<Interaccione> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('delivery_id')) {
      context.handle(
        _deliveryIdMeta,
        deliveryId.isAcceptableOrUnknown(data['delivery_id']!, _deliveryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deliveryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Interaccione map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Interaccione(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_id'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      deliveryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delivery_id'],
      )!,
    );
  }

  @override
  $InteraccionesTable createAlias(String alias) {
    return $InteraccionesTable(attachedDatabase, alias);
  }
}

class Interaccione extends DataClass implements Insertable<Interaccione> {
  final int id;
  final int clientId;
  final String result;
  final int deliveryId;
  const Interaccione({
    required this.id,
    required this.clientId,
    required this.result,
    required this.deliveryId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_id'] = Variable<int>(clientId);
    map['result'] = Variable<String>(result);
    map['delivery_id'] = Variable<int>(deliveryId);
    return map;
  }

  InteraccionesCompanion toCompanion(bool nullToAbsent) {
    return InteraccionesCompanion(
      id: Value(id),
      clientId: Value(clientId),
      result: Value(result),
      deliveryId: Value(deliveryId),
    );
  }

  factory Interaccione.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Interaccione(
      id: serializer.fromJson<int>(json['id']),
      clientId: serializer.fromJson<int>(json['clientId']),
      result: serializer.fromJson<String>(json['result']),
      deliveryId: serializer.fromJson<int>(json['deliveryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientId': serializer.toJson<int>(clientId),
      'result': serializer.toJson<String>(result),
      'deliveryId': serializer.toJson<int>(deliveryId),
    };
  }

  Interaccione copyWith({
    int? id,
    int? clientId,
    String? result,
    int? deliveryId,
  }) => Interaccione(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    result: result ?? this.result,
    deliveryId: deliveryId ?? this.deliveryId,
  );
  Interaccione copyWithCompanion(InteraccionesCompanion data) {
    return Interaccione(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      result: data.result.present ? data.result.value : this.result,
      deliveryId: data.deliveryId.present
          ? data.deliveryId.value
          : this.deliveryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Interaccione(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('result: $result, ')
          ..write('deliveryId: $deliveryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, clientId, result, deliveryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Interaccione &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.result == this.result &&
          other.deliveryId == this.deliveryId);
}

class InteraccionesCompanion extends UpdateCompanion<Interaccione> {
  final Value<int> id;
  final Value<int> clientId;
  final Value<String> result;
  final Value<int> deliveryId;
  const InteraccionesCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.result = const Value.absent(),
    this.deliveryId = const Value.absent(),
  });
  InteraccionesCompanion.insert({
    this.id = const Value.absent(),
    required int clientId,
    required String result,
    required int deliveryId,
  }) : clientId = Value(clientId),
       result = Value(result),
       deliveryId = Value(deliveryId);
  static Insertable<Interaccione> custom({
    Expression<int>? id,
    Expression<int>? clientId,
    Expression<String>? result,
    Expression<int>? deliveryId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (result != null) 'result': result,
      if (deliveryId != null) 'delivery_id': deliveryId,
    });
  }

  InteraccionesCompanion copyWith({
    Value<int>? id,
    Value<int>? clientId,
    Value<String>? result,
    Value<int>? deliveryId,
  }) {
    return InteraccionesCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      result: result ?? this.result,
      deliveryId: deliveryId ?? this.deliveryId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (deliveryId.present) {
      map['delivery_id'] = Variable<int>(deliveryId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InteraccionesCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('result: $result, ')
          ..write('deliveryId: $deliveryId')
          ..write(')'))
        .toString();
  }
}

class $NotasTable extends Notas with TableInfo<$NotasTable, Nota> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _notaMeta = const VerificationMeta('nota');
  @override
  late final GeneratedColumn<String> nota = GeneratedColumn<String>(
    'nota',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<int> clientId = GeneratedColumn<int>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ventaIdMeta = const VerificationMeta(
    'ventaId',
  );
  @override
  late final GeneratedColumn<int> ventaId = GeneratedColumn<int>(
    'venta_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, nota, clientId, ventaId, color];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Nota> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nota')) {
      context.handle(
        _notaMeta,
        nota.isAcceptableOrUnknown(data['nota']!, _notaMeta),
      );
    } else if (isInserting) {
      context.missing(_notaMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('venta_id')) {
      context.handle(
        _ventaIdMeta,
        ventaId.isAcceptableOrUnknown(data['venta_id']!, _ventaIdMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Nota map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Nota(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nota: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nota'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_id'],
      )!,
      ventaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}venta_id'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
    );
  }

  @override
  $NotasTable createAlias(String alias) {
    return $NotasTable(attachedDatabase, alias);
  }
}

class Nota extends DataClass implements Insertable<Nota> {
  final int id;
  final String nota;
  final int clientId;
  final int? ventaId;
  final String color;
  const Nota({
    required this.id,
    required this.nota,
    required this.clientId,
    this.ventaId,
    required this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nota'] = Variable<String>(nota);
    map['client_id'] = Variable<int>(clientId);
    if (!nullToAbsent || ventaId != null) {
      map['venta_id'] = Variable<int>(ventaId);
    }
    map['color'] = Variable<String>(color);
    return map;
  }

  NotasCompanion toCompanion(bool nullToAbsent) {
    return NotasCompanion(
      id: Value(id),
      nota: Value(nota),
      clientId: Value(clientId),
      ventaId: ventaId == null && nullToAbsent
          ? const Value.absent()
          : Value(ventaId),
      color: Value(color),
    );
  }

  factory Nota.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Nota(
      id: serializer.fromJson<int>(json['id']),
      nota: serializer.fromJson<String>(json['nota']),
      clientId: serializer.fromJson<int>(json['clientId']),
      ventaId: serializer.fromJson<int?>(json['ventaId']),
      color: serializer.fromJson<String>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nota': serializer.toJson<String>(nota),
      'clientId': serializer.toJson<int>(clientId),
      'ventaId': serializer.toJson<int?>(ventaId),
      'color': serializer.toJson<String>(color),
    };
  }

  Nota copyWith({
    int? id,
    String? nota,
    int? clientId,
    Value<int?> ventaId = const Value.absent(),
    String? color,
  }) => Nota(
    id: id ?? this.id,
    nota: nota ?? this.nota,
    clientId: clientId ?? this.clientId,
    ventaId: ventaId.present ? ventaId.value : this.ventaId,
    color: color ?? this.color,
  );
  Nota copyWithCompanion(NotasCompanion data) {
    return Nota(
      id: data.id.present ? data.id.value : this.id,
      nota: data.nota.present ? data.nota.value : this.nota,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      ventaId: data.ventaId.present ? data.ventaId.value : this.ventaId,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Nota(')
          ..write('id: $id, ')
          ..write('nota: $nota, ')
          ..write('clientId: $clientId, ')
          ..write('ventaId: $ventaId, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nota, clientId, ventaId, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Nota &&
          other.id == this.id &&
          other.nota == this.nota &&
          other.clientId == this.clientId &&
          other.ventaId == this.ventaId &&
          other.color == this.color);
}

class NotasCompanion extends UpdateCompanion<Nota> {
  final Value<int> id;
  final Value<String> nota;
  final Value<int> clientId;
  final Value<int?> ventaId;
  final Value<String> color;
  const NotasCompanion({
    this.id = const Value.absent(),
    this.nota = const Value.absent(),
    this.clientId = const Value.absent(),
    this.ventaId = const Value.absent(),
    this.color = const Value.absent(),
  });
  NotasCompanion.insert({
    this.id = const Value.absent(),
    required String nota,
    required int clientId,
    this.ventaId = const Value.absent(),
    required String color,
  }) : nota = Value(nota),
       clientId = Value(clientId),
       color = Value(color);
  static Insertable<Nota> custom({
    Expression<int>? id,
    Expression<String>? nota,
    Expression<int>? clientId,
    Expression<int>? ventaId,
    Expression<String>? color,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nota != null) 'nota': nota,
      if (clientId != null) 'client_id': clientId,
      if (ventaId != null) 'venta_id': ventaId,
      if (color != null) 'color': color,
    });
  }

  NotasCompanion copyWith({
    Value<int>? id,
    Value<String>? nota,
    Value<int>? clientId,
    Value<int?>? ventaId,
    Value<String>? color,
  }) {
    return NotasCompanion(
      id: id ?? this.id,
      nota: nota ?? this.nota,
      clientId: clientId ?? this.clientId,
      ventaId: ventaId ?? this.ventaId,
      color: color ?? this.color,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nota.present) {
      map['nota'] = Variable<String>(nota.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (ventaId.present) {
      map['venta_id'] = Variable<int>(ventaId.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotasCompanion(')
          ..write('id: $id, ')
          ..write('nota: $nota, ')
          ..write('clientId: $clientId, ')
          ..write('ventaId: $ventaId, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $DeliveriesTable deliveries = $DeliveriesTable(this);
  late final $ClientesTable clientes = $ClientesTable(this);
  late final $InteraccionesTable interacciones = $InteraccionesTable(this);
  late final $NotasTable notas = $NotasTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sales,
    deliveries,
    clientes,
    interacciones,
    notas,
  ];
}

typedef $$SalesTableCreateCompanionBuilder =
    SalesCompanion Function({
      Value<int> id,
      required DateTime date,
      required int clientId,
      required double quantity,
      required double price,
      required double total,
      Value<int?> notesId,
      Value<int?> deliveryNumber,
    });
typedef $$SalesTableUpdateCompanionBuilder =
    SalesCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<int> clientId,
      Value<double> quantity,
      Value<double> price,
      Value<double> total,
      Value<int?> notesId,
      Value<int?> deliveryNumber,
    });

class $$SalesTableFilterComposer extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notesId => $composableBuilder(
    column: $table.notesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deliveryNumber => $composableBuilder(
    column: $table.deliveryNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SalesTableOrderingComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notesId => $composableBuilder(
    column: $table.notesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deliveryNumber => $composableBuilder(
    column: $table.deliveryNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get notesId =>
      $composableBuilder(column: $table.notesId, builder: (column) => column);

  GeneratedColumn<int> get deliveryNumber => $composableBuilder(
    column: $table.deliveryNumber,
    builder: (column) => column,
  );
}

class $$SalesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SalesTable,
          Sale,
          $$SalesTableFilterComposer,
          $$SalesTableOrderingComposer,
          $$SalesTableAnnotationComposer,
          $$SalesTableCreateCompanionBuilder,
          $$SalesTableUpdateCompanionBuilder,
          (Sale, BaseReferences<_$AppDatabase, $SalesTable, Sale>),
          Sale,
          PrefetchHooks Function()
        > {
  $$SalesTableTableManager(_$AppDatabase db, $SalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> clientId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<double> total = const Value.absent(),
                Value<int?> notesId = const Value.absent(),
                Value<int?> deliveryNumber = const Value.absent(),
              }) => SalesCompanion(
                id: id,
                date: date,
                clientId: clientId,
                quantity: quantity,
                price: price,
                total: total,
                notesId: notesId,
                deliveryNumber: deliveryNumber,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required int clientId,
                required double quantity,
                required double price,
                required double total,
                Value<int?> notesId = const Value.absent(),
                Value<int?> deliveryNumber = const Value.absent(),
              }) => SalesCompanion.insert(
                id: id,
                date: date,
                clientId: clientId,
                quantity: quantity,
                price: price,
                total: total,
                notesId: notesId,
                deliveryNumber: deliveryNumber,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SalesTable,
      Sale,
      $$SalesTableFilterComposer,
      $$SalesTableOrderingComposer,
      $$SalesTableAnnotationComposer,
      $$SalesTableCreateCompanionBuilder,
      $$SalesTableUpdateCompanionBuilder,
      (Sale, BaseReferences<_$AppDatabase, $SalesTable, Sale>),
      Sale,
      PrefetchHooks Function()
    >;
typedef $$DeliveriesTableCreateCompanionBuilder =
    DeliveriesCompanion Function({
      Value<int> deliveryNumber,
      required DateTime date,
      required int durationSeconds,
      required double avgPrice,
      required double kilograms,
      required int boxes,
      required double remaining,
      required String seller,
      required double total,
    });
typedef $$DeliveriesTableUpdateCompanionBuilder =
    DeliveriesCompanion Function({
      Value<int> deliveryNumber,
      Value<DateTime> date,
      Value<int> durationSeconds,
      Value<double> avgPrice,
      Value<double> kilograms,
      Value<int> boxes,
      Value<double> remaining,
      Value<String> seller,
      Value<double> total,
    });

class $$DeliveriesTableFilterComposer
    extends Composer<_$AppDatabase, $DeliveriesTable> {
  $$DeliveriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get deliveryNumber => $composableBuilder(
    column: $table.deliveryNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgPrice => $composableBuilder(
    column: $table.avgPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kilograms => $composableBuilder(
    column: $table.kilograms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get boxes => $composableBuilder(
    column: $table.boxes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get remaining => $composableBuilder(
    column: $table.remaining,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seller => $composableBuilder(
    column: $table.seller,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeliveriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeliveriesTable> {
  $$DeliveriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get deliveryNumber => $composableBuilder(
    column: $table.deliveryNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgPrice => $composableBuilder(
    column: $table.avgPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kilograms => $composableBuilder(
    column: $table.kilograms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get boxes => $composableBuilder(
    column: $table.boxes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get remaining => $composableBuilder(
    column: $table.remaining,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seller => $composableBuilder(
    column: $table.seller,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeliveriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeliveriesTable> {
  $$DeliveriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get deliveryNumber => $composableBuilder(
    column: $table.deliveryNumber,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgPrice =>
      $composableBuilder(column: $table.avgPrice, builder: (column) => column);

  GeneratedColumn<double> get kilograms =>
      $composableBuilder(column: $table.kilograms, builder: (column) => column);

  GeneratedColumn<int> get boxes =>
      $composableBuilder(column: $table.boxes, builder: (column) => column);

  GeneratedColumn<double> get remaining =>
      $composableBuilder(column: $table.remaining, builder: (column) => column);

  GeneratedColumn<String> get seller =>
      $composableBuilder(column: $table.seller, builder: (column) => column);

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);
}

class $$DeliveriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeliveriesTable,
          Delivery,
          $$DeliveriesTableFilterComposer,
          $$DeliveriesTableOrderingComposer,
          $$DeliveriesTableAnnotationComposer,
          $$DeliveriesTableCreateCompanionBuilder,
          $$DeliveriesTableUpdateCompanionBuilder,
          (Delivery, BaseReferences<_$AppDatabase, $DeliveriesTable, Delivery>),
          Delivery,
          PrefetchHooks Function()
        > {
  $$DeliveriesTableTableManager(_$AppDatabase db, $DeliveriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeliveriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeliveriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeliveriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> deliveryNumber = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<double> avgPrice = const Value.absent(),
                Value<double> kilograms = const Value.absent(),
                Value<int> boxes = const Value.absent(),
                Value<double> remaining = const Value.absent(),
                Value<String> seller = const Value.absent(),
                Value<double> total = const Value.absent(),
              }) => DeliveriesCompanion(
                deliveryNumber: deliveryNumber,
                date: date,
                durationSeconds: durationSeconds,
                avgPrice: avgPrice,
                kilograms: kilograms,
                boxes: boxes,
                remaining: remaining,
                seller: seller,
                total: total,
              ),
          createCompanionCallback:
              ({
                Value<int> deliveryNumber = const Value.absent(),
                required DateTime date,
                required int durationSeconds,
                required double avgPrice,
                required double kilograms,
                required int boxes,
                required double remaining,
                required String seller,
                required double total,
              }) => DeliveriesCompanion.insert(
                deliveryNumber: deliveryNumber,
                date: date,
                durationSeconds: durationSeconds,
                avgPrice: avgPrice,
                kilograms: kilograms,
                boxes: boxes,
                remaining: remaining,
                seller: seller,
                total: total,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeliveriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeliveriesTable,
      Delivery,
      $$DeliveriesTableFilterComposer,
      $$DeliveriesTableOrderingComposer,
      $$DeliveriesTableAnnotationComposer,
      $$DeliveriesTableCreateCompanionBuilder,
      $$DeliveriesTableUpdateCompanionBuilder,
      (Delivery, BaseReferences<_$AppDatabase, $DeliveriesTable, Delivery>),
      Delivery,
      PrefetchHooks Function()
    >;
typedef $$ClientesTableCreateCompanionBuilder =
    ClientesCompanion Function({
      Value<int> id,
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
      Value<int?> notasId,
      required String dias,
      Value<int> eventos,
      Value<double> kgTotal,
      Value<double> moda,
      Value<double> maximo,
      Value<double> ultimas10,
      Value<double> kgEvento,
      Value<double> kgSemana,
      Value<double> ventasVuelta,
      Value<double> puntuacion,
    });
typedef $$ClientesTableUpdateCompanionBuilder =
    ClientesCompanion Function({
      Value<int> id,
      Value<String> nombre,
      Value<String> contacto,
      Value<String> tipoNegocio,
      Value<String> ciudad,
      Value<String> domicilio,
      Value<String> ubicacion,
      Value<String> telefono,
      Value<int> consumo,
      Value<DateTime> ultimoContacto,
      Value<int> horaInicio,
      Value<int> horaCierre,
      Value<int?> notasId,
      Value<String> dias,
      Value<int> eventos,
      Value<double> kgTotal,
      Value<double> moda,
      Value<double> maximo,
      Value<double> ultimas10,
      Value<double> kgEvento,
      Value<double> kgSemana,
      Value<double> ventasVuelta,
      Value<double> puntuacion,
    });

class $$ClientesTableFilterComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contacto => $composableBuilder(
    column: $table.contacto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipoNegocio => $composableBuilder(
    column: $table.tipoNegocio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ciudad => $composableBuilder(
    column: $table.ciudad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get domicilio => $composableBuilder(
    column: $table.domicilio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ubicacion => $composableBuilder(
    column: $table.ubicacion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get telefono => $composableBuilder(
    column: $table.telefono,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consumo => $composableBuilder(
    column: $table.consumo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ultimoContacto => $composableBuilder(
    column: $table.ultimoContacto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get horaInicio => $composableBuilder(
    column: $table.horaInicio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get horaCierre => $composableBuilder(
    column: $table.horaCierre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notasId => $composableBuilder(
    column: $table.notasId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dias => $composableBuilder(
    column: $table.dias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eventos => $composableBuilder(
    column: $table.eventos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kgTotal => $composableBuilder(
    column: $table.kgTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get moda => $composableBuilder(
    column: $table.moda,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maximo => $composableBuilder(
    column: $table.maximo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ultimas10 => $composableBuilder(
    column: $table.ultimas10,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kgEvento => $composableBuilder(
    column: $table.kgEvento,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kgSemana => $composableBuilder(
    column: $table.kgSemana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ventasVuelta => $composableBuilder(
    column: $table.ventasVuelta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get puntuacion => $composableBuilder(
    column: $table.puntuacion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClientesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contacto => $composableBuilder(
    column: $table.contacto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoNegocio => $composableBuilder(
    column: $table.tipoNegocio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ciudad => $composableBuilder(
    column: $table.ciudad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get domicilio => $composableBuilder(
    column: $table.domicilio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ubicacion => $composableBuilder(
    column: $table.ubicacion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get telefono => $composableBuilder(
    column: $table.telefono,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consumo => $composableBuilder(
    column: $table.consumo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ultimoContacto => $composableBuilder(
    column: $table.ultimoContacto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get horaInicio => $composableBuilder(
    column: $table.horaInicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get horaCierre => $composableBuilder(
    column: $table.horaCierre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notasId => $composableBuilder(
    column: $table.notasId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dias => $composableBuilder(
    column: $table.dias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eventos => $composableBuilder(
    column: $table.eventos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kgTotal => $composableBuilder(
    column: $table.kgTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get moda => $composableBuilder(
    column: $table.moda,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maximo => $composableBuilder(
    column: $table.maximo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ultimas10 => $composableBuilder(
    column: $table.ultimas10,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kgEvento => $composableBuilder(
    column: $table.kgEvento,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kgSemana => $composableBuilder(
    column: $table.kgSemana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ventasVuelta => $composableBuilder(
    column: $table.ventasVuelta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get puntuacion => $composableBuilder(
    column: $table.puntuacion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get contacto =>
      $composableBuilder(column: $table.contacto, builder: (column) => column);

  GeneratedColumn<String> get tipoNegocio => $composableBuilder(
    column: $table.tipoNegocio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ciudad =>
      $composableBuilder(column: $table.ciudad, builder: (column) => column);

  GeneratedColumn<String> get domicilio =>
      $composableBuilder(column: $table.domicilio, builder: (column) => column);

  GeneratedColumn<String> get ubicacion =>
      $composableBuilder(column: $table.ubicacion, builder: (column) => column);

  GeneratedColumn<String> get telefono =>
      $composableBuilder(column: $table.telefono, builder: (column) => column);

  GeneratedColumn<int> get consumo =>
      $composableBuilder(column: $table.consumo, builder: (column) => column);

  GeneratedColumn<DateTime> get ultimoContacto => $composableBuilder(
    column: $table.ultimoContacto,
    builder: (column) => column,
  );

  GeneratedColumn<int> get horaInicio => $composableBuilder(
    column: $table.horaInicio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get horaCierre => $composableBuilder(
    column: $table.horaCierre,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notasId =>
      $composableBuilder(column: $table.notasId, builder: (column) => column);

  GeneratedColumn<String> get dias =>
      $composableBuilder(column: $table.dias, builder: (column) => column);

  GeneratedColumn<int> get eventos =>
      $composableBuilder(column: $table.eventos, builder: (column) => column);

  GeneratedColumn<double> get kgTotal =>
      $composableBuilder(column: $table.kgTotal, builder: (column) => column);

  GeneratedColumn<double> get moda =>
      $composableBuilder(column: $table.moda, builder: (column) => column);

  GeneratedColumn<double> get maximo =>
      $composableBuilder(column: $table.maximo, builder: (column) => column);

  GeneratedColumn<double> get ultimas10 =>
      $composableBuilder(column: $table.ultimas10, builder: (column) => column);

  GeneratedColumn<double> get kgEvento =>
      $composableBuilder(column: $table.kgEvento, builder: (column) => column);

  GeneratedColumn<double> get kgSemana =>
      $composableBuilder(column: $table.kgSemana, builder: (column) => column);

  GeneratedColumn<double> get ventasVuelta => $composableBuilder(
    column: $table.ventasVuelta,
    builder: (column) => column,
  );

  GeneratedColumn<double> get puntuacion => $composableBuilder(
    column: $table.puntuacion,
    builder: (column) => column,
  );
}

class $$ClientesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientesTable,
          Cliente,
          $$ClientesTableFilterComposer,
          $$ClientesTableOrderingComposer,
          $$ClientesTableAnnotationComposer,
          $$ClientesTableCreateCompanionBuilder,
          $$ClientesTableUpdateCompanionBuilder,
          (Cliente, BaseReferences<_$AppDatabase, $ClientesTable, Cliente>),
          Cliente,
          PrefetchHooks Function()
        > {
  $$ClientesTableTableManager(_$AppDatabase db, $ClientesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> contacto = const Value.absent(),
                Value<String> tipoNegocio = const Value.absent(),
                Value<String> ciudad = const Value.absent(),
                Value<String> domicilio = const Value.absent(),
                Value<String> ubicacion = const Value.absent(),
                Value<String> telefono = const Value.absent(),
                Value<int> consumo = const Value.absent(),
                Value<DateTime> ultimoContacto = const Value.absent(),
                Value<int> horaInicio = const Value.absent(),
                Value<int> horaCierre = const Value.absent(),
                Value<int?> notasId = const Value.absent(),
                Value<String> dias = const Value.absent(),
                Value<int> eventos = const Value.absent(),
                Value<double> kgTotal = const Value.absent(),
                Value<double> moda = const Value.absent(),
                Value<double> maximo = const Value.absent(),
                Value<double> ultimas10 = const Value.absent(),
                Value<double> kgEvento = const Value.absent(),
                Value<double> kgSemana = const Value.absent(),
                Value<double> ventasVuelta = const Value.absent(),
                Value<double> puntuacion = const Value.absent(),
              }) => ClientesCompanion(
                id: id,
                nombre: nombre,
                contacto: contacto,
                tipoNegocio: tipoNegocio,
                ciudad: ciudad,
                domicilio: domicilio,
                ubicacion: ubicacion,
                telefono: telefono,
                consumo: consumo,
                ultimoContacto: ultimoContacto,
                horaInicio: horaInicio,
                horaCierre: horaCierre,
                notasId: notasId,
                dias: dias,
                eventos: eventos,
                kgTotal: kgTotal,
                moda: moda,
                maximo: maximo,
                ultimas10: ultimas10,
                kgEvento: kgEvento,
                kgSemana: kgSemana,
                ventasVuelta: ventasVuelta,
                puntuacion: puntuacion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
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
                Value<int?> notasId = const Value.absent(),
                required String dias,
                Value<int> eventos = const Value.absent(),
                Value<double> kgTotal = const Value.absent(),
                Value<double> moda = const Value.absent(),
                Value<double> maximo = const Value.absent(),
                Value<double> ultimas10 = const Value.absent(),
                Value<double> kgEvento = const Value.absent(),
                Value<double> kgSemana = const Value.absent(),
                Value<double> ventasVuelta = const Value.absent(),
                Value<double> puntuacion = const Value.absent(),
              }) => ClientesCompanion.insert(
                id: id,
                nombre: nombre,
                contacto: contacto,
                tipoNegocio: tipoNegocio,
                ciudad: ciudad,
                domicilio: domicilio,
                ubicacion: ubicacion,
                telefono: telefono,
                consumo: consumo,
                ultimoContacto: ultimoContacto,
                horaInicio: horaInicio,
                horaCierre: horaCierre,
                notasId: notasId,
                dias: dias,
                eventos: eventos,
                kgTotal: kgTotal,
                moda: moda,
                maximo: maximo,
                ultimas10: ultimas10,
                kgEvento: kgEvento,
                kgSemana: kgSemana,
                ventasVuelta: ventasVuelta,
                puntuacion: puntuacion,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClientesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientesTable,
      Cliente,
      $$ClientesTableFilterComposer,
      $$ClientesTableOrderingComposer,
      $$ClientesTableAnnotationComposer,
      $$ClientesTableCreateCompanionBuilder,
      $$ClientesTableUpdateCompanionBuilder,
      (Cliente, BaseReferences<_$AppDatabase, $ClientesTable, Cliente>),
      Cliente,
      PrefetchHooks Function()
    >;
typedef $$InteraccionesTableCreateCompanionBuilder =
    InteraccionesCompanion Function({
      Value<int> id,
      required int clientId,
      required String result,
      required int deliveryId,
    });
typedef $$InteraccionesTableUpdateCompanionBuilder =
    InteraccionesCompanion Function({
      Value<int> id,
      Value<int> clientId,
      Value<String> result,
      Value<int> deliveryId,
    });

class $$InteraccionesTableFilterComposer
    extends Composer<_$AppDatabase, $InteraccionesTable> {
  $$InteraccionesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deliveryId => $composableBuilder(
    column: $table.deliveryId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InteraccionesTableOrderingComposer
    extends Composer<_$AppDatabase, $InteraccionesTable> {
  $$InteraccionesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deliveryId => $composableBuilder(
    column: $table.deliveryId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InteraccionesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InteraccionesTable> {
  $$InteraccionesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<int> get deliveryId => $composableBuilder(
    column: $table.deliveryId,
    builder: (column) => column,
  );
}

class $$InteraccionesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InteraccionesTable,
          Interaccione,
          $$InteraccionesTableFilterComposer,
          $$InteraccionesTableOrderingComposer,
          $$InteraccionesTableAnnotationComposer,
          $$InteraccionesTableCreateCompanionBuilder,
          $$InteraccionesTableUpdateCompanionBuilder,
          (
            Interaccione,
            BaseReferences<_$AppDatabase, $InteraccionesTable, Interaccione>,
          ),
          Interaccione,
          PrefetchHooks Function()
        > {
  $$InteraccionesTableTableManager(_$AppDatabase db, $InteraccionesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InteraccionesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InteraccionesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InteraccionesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> clientId = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<int> deliveryId = const Value.absent(),
              }) => InteraccionesCompanion(
                id: id,
                clientId: clientId,
                result: result,
                deliveryId: deliveryId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int clientId,
                required String result,
                required int deliveryId,
              }) => InteraccionesCompanion.insert(
                id: id,
                clientId: clientId,
                result: result,
                deliveryId: deliveryId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InteraccionesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InteraccionesTable,
      Interaccione,
      $$InteraccionesTableFilterComposer,
      $$InteraccionesTableOrderingComposer,
      $$InteraccionesTableAnnotationComposer,
      $$InteraccionesTableCreateCompanionBuilder,
      $$InteraccionesTableUpdateCompanionBuilder,
      (
        Interaccione,
        BaseReferences<_$AppDatabase, $InteraccionesTable, Interaccione>,
      ),
      Interaccione,
      PrefetchHooks Function()
    >;
typedef $$NotasTableCreateCompanionBuilder =
    NotasCompanion Function({
      Value<int> id,
      required String nota,
      required int clientId,
      Value<int?> ventaId,
      required String color,
    });
typedef $$NotasTableUpdateCompanionBuilder =
    NotasCompanion Function({
      Value<int> id,
      Value<String> nota,
      Value<int> clientId,
      Value<int?> ventaId,
      Value<String> color,
    });

class $$NotasTableFilterComposer extends Composer<_$AppDatabase, $NotasTable> {
  $$NotasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nota => $composableBuilder(
    column: $table.nota,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ventaId => $composableBuilder(
    column: $table.ventaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotasTableOrderingComposer
    extends Composer<_$AppDatabase, $NotasTable> {
  $$NotasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nota => $composableBuilder(
    column: $table.nota,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ventaId => $composableBuilder(
    column: $table.ventaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotasTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotasTable> {
  $$NotasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nota =>
      $composableBuilder(column: $table.nota, builder: (column) => column);

  GeneratedColumn<int> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<int> get ventaId =>
      $composableBuilder(column: $table.ventaId, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);
}

class $$NotasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotasTable,
          Nota,
          $$NotasTableFilterComposer,
          $$NotasTableOrderingComposer,
          $$NotasTableAnnotationComposer,
          $$NotasTableCreateCompanionBuilder,
          $$NotasTableUpdateCompanionBuilder,
          (Nota, BaseReferences<_$AppDatabase, $NotasTable, Nota>),
          Nota,
          PrefetchHooks Function()
        > {
  $$NotasTableTableManager(_$AppDatabase db, $NotasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nota = const Value.absent(),
                Value<int> clientId = const Value.absent(),
                Value<int?> ventaId = const Value.absent(),
                Value<String> color = const Value.absent(),
              }) => NotasCompanion(
                id: id,
                nota: nota,
                clientId: clientId,
                ventaId: ventaId,
                color: color,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nota,
                required int clientId,
                Value<int?> ventaId = const Value.absent(),
                required String color,
              }) => NotasCompanion.insert(
                id: id,
                nota: nota,
                clientId: clientId,
                ventaId: ventaId,
                color: color,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotasTable,
      Nota,
      $$NotasTableFilterComposer,
      $$NotasTableOrderingComposer,
      $$NotasTableAnnotationComposer,
      $$NotasTableCreateCompanionBuilder,
      $$NotasTableUpdateCompanionBuilder,
      (Nota, BaseReferences<_$AppDatabase, $NotasTable, Nota>),
      Nota,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$DeliveriesTableTableManager get deliveries =>
      $$DeliveriesTableTableManager(_db, _db.deliveries);
  $$ClientesTableTableManager get clientes =>
      $$ClientesTableTableManager(_db, _db.clientes);
  $$InteraccionesTableTableManager get interacciones =>
      $$InteraccionesTableTableManager(_db, _db.interacciones);
  $$NotasTableTableManager get notas =>
      $$NotasTableTableManager(_db, _db.notas);
}
