// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $InspectionSessionRowsTable extends InspectionSessionRows
    with TableInfo<$InspectionSessionRowsTable, InspectionSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InspectionSessionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _industryMeta = const VerificationMeta(
    'industry',
  );
  @override
  late final GeneratedColumn<String> industry = GeneratedColumn<String>(
    'industry',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetTypeIdMeta = const VerificationMeta(
    'assetTypeId',
  );
  @override
  late final GeneratedColumn<String> assetTypeId = GeneratedColumn<String>(
    'asset_type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localOnly'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    industry,
    assetTypeId,
    status,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inspection_session_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<InspectionSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('industry')) {
      context.handle(
        _industryMeta,
        industry.isAcceptableOrUnknown(data['industry']!, _industryMeta),
      );
    } else if (isInserting) {
      context.missing(_industryMeta);
    }
    if (data.containsKey('asset_type_id')) {
      context.handle(
        _assetTypeIdMeta,
        assetTypeId.isAcceptableOrUnknown(
          data['asset_type_id']!,
          _assetTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetTypeIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InspectionSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InspectionSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      industry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}industry'],
      )!,
      assetTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_type_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $InspectionSessionRowsTable createAlias(String alias) {
    return $InspectionSessionRowsTable(attachedDatabase, alias);
  }
}

class InspectionSessionRow extends DataClass
    implements Insertable<InspectionSessionRow> {
  final String id;
  final String industry;
  final String assetTypeId;
  final String status;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const InspectionSessionRow({
    required this.id,
    required this.industry,
    required this.assetTypeId,
    required this.status,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['industry'] = Variable<String>(industry);
    map['asset_type_id'] = Variable<String>(assetTypeId);
    map['status'] = Variable<String>(status);
    map['sync_status'] = Variable<String>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  InspectionSessionRowsCompanion toCompanion(bool nullToAbsent) {
    return InspectionSessionRowsCompanion(
      id: Value(id),
      industry: Value(industry),
      assetTypeId: Value(assetTypeId),
      status: Value(status),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory InspectionSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InspectionSessionRow(
      id: serializer.fromJson<String>(json['id']),
      industry: serializer.fromJson<String>(json['industry']),
      assetTypeId: serializer.fromJson<String>(json['assetTypeId']),
      status: serializer.fromJson<String>(json['status']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'industry': serializer.toJson<String>(industry),
      'assetTypeId': serializer.toJson<String>(assetTypeId),
      'status': serializer.toJson<String>(status),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InspectionSessionRow copyWith({
    String? id,
    String? industry,
    String? assetTypeId,
    String? status,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => InspectionSessionRow(
    id: id ?? this.id,
    industry: industry ?? this.industry,
    assetTypeId: assetTypeId ?? this.assetTypeId,
    status: status ?? this.status,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InspectionSessionRow copyWithCompanion(InspectionSessionRowsCompanion data) {
    return InspectionSessionRow(
      id: data.id.present ? data.id.value : this.id,
      industry: data.industry.present ? data.industry.value : this.industry,
      assetTypeId: data.assetTypeId.present
          ? data.assetTypeId.value
          : this.assetTypeId,
      status: data.status.present ? data.status.value : this.status,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InspectionSessionRow(')
          ..write('id: $id, ')
          ..write('industry: $industry, ')
          ..write('assetTypeId: $assetTypeId, ')
          ..write('status: $status, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    industry,
    assetTypeId,
    status,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InspectionSessionRow &&
          other.id == this.id &&
          other.industry == this.industry &&
          other.assetTypeId == this.assetTypeId &&
          other.status == this.status &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class InspectionSessionRowsCompanion
    extends UpdateCompanion<InspectionSessionRow> {
  final Value<String> id;
  final Value<String> industry;
  final Value<String> assetTypeId;
  final Value<String> status;
  final Value<String> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const InspectionSessionRowsCompanion({
    this.id = const Value.absent(),
    this.industry = const Value.absent(),
    this.assetTypeId = const Value.absent(),
    this.status = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InspectionSessionRowsCompanion.insert({
    required String id,
    required String industry,
    required String assetTypeId,
    required String status,
    this.syncStatus = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       industry = Value(industry),
       assetTypeId = Value(assetTypeId),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<InspectionSessionRow> custom({
    Expression<String>? id,
    Expression<String>? industry,
    Expression<String>? assetTypeId,
    Expression<String>? status,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (industry != null) 'industry': industry,
      if (assetTypeId != null) 'asset_type_id': assetTypeId,
      if (status != null) 'status': status,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InspectionSessionRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? industry,
    Value<String>? assetTypeId,
    Value<String>? status,
    Value<String>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return InspectionSessionRowsCompanion(
      id: id ?? this.id,
      industry: industry ?? this.industry,
      assetTypeId: assetTypeId ?? this.assetTypeId,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (industry.present) {
      map['industry'] = Variable<String>(industry.value);
    }
    if (assetTypeId.present) {
      map['asset_type_id'] = Variable<String>(assetTypeId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InspectionSessionRowsCompanion(')
          ..write('id: $id, ')
          ..write('industry: $industry, ')
          ..write('assetTypeId: $assetTypeId, ')
          ..write('status: $status, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SectionRowsTable extends SectionRows
    with TableInfo<$SectionRowsTable, SectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SectionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES inspection_session_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPlumbingMeta = const VerificationMeta(
    'isPlumbing',
  );
  @override
  late final GeneratedColumn<bool> isPlumbing = GeneratedColumn<bool>(
    'is_plumbing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_plumbing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isIncludedMeta = const VerificationMeta(
    'isIncluded',
  );
  @override
  late final GeneratedColumn<bool> isIncluded = GeneratedColumn<bool>(
    'is_included',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_included" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('notStarted'),
  );
  static const VerificationMeta _elementsJsonMeta = const VerificationMeta(
    'elementsJson',
  );
  @override
  late final GeneratedColumn<String> elementsJson = GeneratedColumn<String>(
    'elements_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    name,
    isPlumbing,
    isIncluded,
    status,
    elementsJson,
    orderIndex,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'section_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_plumbing')) {
      context.handle(
        _isPlumbingMeta,
        isPlumbing.isAcceptableOrUnknown(data['is_plumbing']!, _isPlumbingMeta),
      );
    }
    if (data.containsKey('is_included')) {
      context.handle(
        _isIncludedMeta,
        isIncluded.isAcceptableOrUnknown(data['is_included']!, _isIncludedMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('elements_json')) {
      context.handle(
        _elementsJsonMeta,
        elementsJson.isAcceptableOrUnknown(
          data['elements_json']!,
          _elementsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_elementsJsonMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, id};
  @override
  SectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isPlumbing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_plumbing'],
      )!,
      isIncluded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_included'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      elementsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}elements_json'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SectionRowsTable createAlias(String alias) {
    return $SectionRowsTable(attachedDatabase, alias);
  }
}

class SectionRow extends DataClass implements Insertable<SectionRow> {
  final String id;
  final String sessionId;
  final String name;
  final bool isPlumbing;
  final bool isIncluded;
  final String status;
  final String elementsJson;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SectionRow({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.isPlumbing,
    required this.isIncluded,
    required this.status,
    required this.elementsJson,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['name'] = Variable<String>(name);
    map['is_plumbing'] = Variable<bool>(isPlumbing);
    map['is_included'] = Variable<bool>(isIncluded);
    map['status'] = Variable<String>(status);
    map['elements_json'] = Variable<String>(elementsJson);
    map['order_index'] = Variable<int>(orderIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SectionRowsCompanion toCompanion(bool nullToAbsent) {
    return SectionRowsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      name: Value(name),
      isPlumbing: Value(isPlumbing),
      isIncluded: Value(isIncluded),
      status: Value(status),
      elementsJson: Value(elementsJson),
      orderIndex: Value(orderIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SectionRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      name: serializer.fromJson<String>(json['name']),
      isPlumbing: serializer.fromJson<bool>(json['isPlumbing']),
      isIncluded: serializer.fromJson<bool>(json['isIncluded']),
      status: serializer.fromJson<String>(json['status']),
      elementsJson: serializer.fromJson<String>(json['elementsJson']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'name': serializer.toJson<String>(name),
      'isPlumbing': serializer.toJson<bool>(isPlumbing),
      'isIncluded': serializer.toJson<bool>(isIncluded),
      'status': serializer.toJson<String>(status),
      'elementsJson': serializer.toJson<String>(elementsJson),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SectionRow copyWith({
    String? id,
    String? sessionId,
    String? name,
    bool? isPlumbing,
    bool? isIncluded,
    String? status,
    String? elementsJson,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SectionRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    name: name ?? this.name,
    isPlumbing: isPlumbing ?? this.isPlumbing,
    isIncluded: isIncluded ?? this.isIncluded,
    status: status ?? this.status,
    elementsJson: elementsJson ?? this.elementsJson,
    orderIndex: orderIndex ?? this.orderIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SectionRow copyWithCompanion(SectionRowsCompanion data) {
    return SectionRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      name: data.name.present ? data.name.value : this.name,
      isPlumbing: data.isPlumbing.present
          ? data.isPlumbing.value
          : this.isPlumbing,
      isIncluded: data.isIncluded.present
          ? data.isIncluded.value
          : this.isIncluded,
      status: data.status.present ? data.status.value : this.status,
      elementsJson: data.elementsJson.present
          ? data.elementsJson.value
          : this.elementsJson,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SectionRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('isPlumbing: $isPlumbing, ')
          ..write('isIncluded: $isIncluded, ')
          ..write('status: $status, ')
          ..write('elementsJson: $elementsJson, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    name,
    isPlumbing,
    isIncluded,
    status,
    elementsJson,
    orderIndex,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SectionRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.name == this.name &&
          other.isPlumbing == this.isPlumbing &&
          other.isIncluded == this.isIncluded &&
          other.status == this.status &&
          other.elementsJson == this.elementsJson &&
          other.orderIndex == this.orderIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SectionRowsCompanion extends UpdateCompanion<SectionRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> name;
  final Value<bool> isPlumbing;
  final Value<bool> isIncluded;
  final Value<String> status;
  final Value<String> elementsJson;
  final Value<int> orderIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SectionRowsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.name = const Value.absent(),
    this.isPlumbing = const Value.absent(),
    this.isIncluded = const Value.absent(),
    this.status = const Value.absent(),
    this.elementsJson = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SectionRowsCompanion.insert({
    required String id,
    required String sessionId,
    required String name,
    this.isPlumbing = const Value.absent(),
    this.isIncluded = const Value.absent(),
    this.status = const Value.absent(),
    required String elementsJson,
    required int orderIndex,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       name = Value(name),
       elementsJson = Value(elementsJson),
       orderIndex = Value(orderIndex),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SectionRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? name,
    Expression<bool>? isPlumbing,
    Expression<bool>? isIncluded,
    Expression<String>? status,
    Expression<String>? elementsJson,
    Expression<int>? orderIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (name != null) 'name': name,
      if (isPlumbing != null) 'is_plumbing': isPlumbing,
      if (isIncluded != null) 'is_included': isIncluded,
      if (status != null) 'status': status,
      if (elementsJson != null) 'elements_json': elementsJson,
      if (orderIndex != null) 'order_index': orderIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SectionRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? name,
    Value<bool>? isPlumbing,
    Value<bool>? isIncluded,
    Value<String>? status,
    Value<String>? elementsJson,
    Value<int>? orderIndex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SectionRowsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      isPlumbing: isPlumbing ?? this.isPlumbing,
      isIncluded: isIncluded ?? this.isIncluded,
      status: status ?? this.status,
      elementsJson: elementsJson ?? this.elementsJson,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isPlumbing.present) {
      map['is_plumbing'] = Variable<bool>(isPlumbing.value);
    }
    if (isIncluded.present) {
      map['is_included'] = Variable<bool>(isIncluded.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (elementsJson.present) {
      map['elements_json'] = Variable<String>(elementsJson.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SectionRowsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('isPlumbing: $isPlumbing, ')
          ..write('isIncluded: $isIncluded, ')
          ..write('status: $status, ')
          ..write('elementsJson: $elementsJson, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FindingRowsTable extends FindingRows
    with TableInfo<$FindingRowsTable, FindingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FindingRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES inspection_session_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elementIdMeta = const VerificationMeta(
    'elementId',
  );
  @override
  late final GeneratedColumn<String> elementId = GeneratedColumn<String>(
    'element_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _componentIdMeta = const VerificationMeta(
    'componentId',
  );
  @override
  late final GeneratedColumn<String> componentId = GeneratedColumn<String>(
    'component_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    sectionId,
    elementId,
    componentId,
    description,
    notes,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'finding_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<FindingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionIdMeta);
    }
    if (data.containsKey('element_id')) {
      context.handle(
        _elementIdMeta,
        elementId.isAcceptableOrUnknown(data['element_id']!, _elementIdMeta),
      );
    } else if (isInserting) {
      context.missing(_elementIdMeta);
    }
    if (data.containsKey('component_id')) {
      context.handle(
        _componentIdMeta,
        componentId.isAcceptableOrUnknown(
          data['component_id']!,
          _componentIdMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FindingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FindingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      )!,
      elementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}element_id'],
      )!,
      componentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}component_id'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FindingRowsTable createAlias(String alias) {
    return $FindingRowsTable(attachedDatabase, alias);
  }
}

class FindingRow extends DataClass implements Insertable<FindingRow> {
  final String id;
  final String sessionId;
  final String sectionId;
  final String elementId;
  final String? componentId;
  final String? description;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FindingRow({
    required this.id,
    required this.sessionId,
    required this.sectionId,
    required this.elementId,
    this.componentId,
    this.description,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['section_id'] = Variable<String>(sectionId);
    map['element_id'] = Variable<String>(elementId);
    if (!nullToAbsent || componentId != null) {
      map['component_id'] = Variable<String>(componentId);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FindingRowsCompanion toCompanion(bool nullToAbsent) {
    return FindingRowsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      sectionId: Value(sectionId),
      elementId: Value(elementId),
      componentId: componentId == null && nullToAbsent
          ? const Value.absent()
          : Value(componentId),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FindingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FindingRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      sectionId: serializer.fromJson<String>(json['sectionId']),
      elementId: serializer.fromJson<String>(json['elementId']),
      componentId: serializer.fromJson<String?>(json['componentId']),
      description: serializer.fromJson<String?>(json['description']),
      notes: serializer.fromJson<String?>(json['notes']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'sectionId': serializer.toJson<String>(sectionId),
      'elementId': serializer.toJson<String>(elementId),
      'componentId': serializer.toJson<String?>(componentId),
      'description': serializer.toJson<String?>(description),
      'notes': serializer.toJson<String?>(notes),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FindingRow copyWith({
    String? id,
    String? sessionId,
    String? sectionId,
    String? elementId,
    Value<String?> componentId = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FindingRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    sectionId: sectionId ?? this.sectionId,
    elementId: elementId ?? this.elementId,
    componentId: componentId.present ? componentId.value : this.componentId,
    description: description.present ? description.value : this.description,
    notes: notes.present ? notes.value : this.notes,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FindingRow copyWithCompanion(FindingRowsCompanion data) {
    return FindingRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      elementId: data.elementId.present ? data.elementId.value : this.elementId,
      componentId: data.componentId.present
          ? data.componentId.value
          : this.componentId,
      description: data.description.present
          ? data.description.value
          : this.description,
      notes: data.notes.present ? data.notes.value : this.notes,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FindingRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('sectionId: $sectionId, ')
          ..write('elementId: $elementId, ')
          ..write('componentId: $componentId, ')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    sectionId,
    elementId,
    componentId,
    description,
    notes,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FindingRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.sectionId == this.sectionId &&
          other.elementId == this.elementId &&
          other.componentId == this.componentId &&
          other.description == this.description &&
          other.notes == this.notes &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FindingRowsCompanion extends UpdateCompanion<FindingRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> sectionId;
  final Value<String> elementId;
  final Value<String?> componentId;
  final Value<String?> description;
  final Value<String?> notes;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FindingRowsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.elementId = const Value.absent(),
    this.componentId = const Value.absent(),
    this.description = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FindingRowsCompanion.insert({
    required String id,
    required String sessionId,
    required String sectionId,
    required String elementId,
    this.componentId = const Value.absent(),
    this.description = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       sectionId = Value(sectionId),
       elementId = Value(elementId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FindingRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? sectionId,
    Expression<String>? elementId,
    Expression<String>? componentId,
    Expression<String>? description,
    Expression<String>? notes,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (sectionId != null) 'section_id': sectionId,
      if (elementId != null) 'element_id': elementId,
      if (componentId != null) 'component_id': componentId,
      if (description != null) 'description': description,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FindingRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? sectionId,
    Value<String>? elementId,
    Value<String?>? componentId,
    Value<String?>? description,
    Value<String?>? notes,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FindingRowsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      sectionId: sectionId ?? this.sectionId,
      elementId: elementId ?? this.elementId,
      componentId: componentId ?? this.componentId,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (elementId.present) {
      map['element_id'] = Variable<String>(elementId.value);
    }
    if (componentId.present) {
      map['component_id'] = Variable<String>(componentId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FindingRowsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('sectionId: $sectionId, ')
          ..write('elementId: $elementId, ')
          ..write('componentId: $componentId, ')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EvidenceRowsTable extends EvidenceRows
    with TableInfo<$EvidenceRowsTable, EvidenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EvidenceRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _findingIdMeta = const VerificationMeta(
    'findingId',
  );
  @override
  late final GeneratedColumn<String> findingId = GeneratedColumn<String>(
    'finding_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES finding_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('photo'),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('gallery'),
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localOnly'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    findingId,
    filePath,
    mediaType,
    source,
    caption,
    syncStatus,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'evidence_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<EvidenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('finding_id')) {
      context.handle(
        _findingIdMeta,
        findingId.isAcceptableOrUnknown(data['finding_id']!, _findingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_findingIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EvidenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EvidenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      findingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finding_id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EvidenceRowsTable createAlias(String alias) {
    return $EvidenceRowsTable(attachedDatabase, alias);
  }
}

class EvidenceRow extends DataClass implements Insertable<EvidenceRow> {
  final String id;
  final String findingId;
  final String filePath;
  final String mediaType;
  final String source;
  final String? caption;
  final String syncStatus;
  final DateTime createdAt;
  const EvidenceRow({
    required this.id,
    required this.findingId,
    required this.filePath,
    required this.mediaType,
    required this.source,
    this.caption,
    required this.syncStatus,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['finding_id'] = Variable<String>(findingId);
    map['file_path'] = Variable<String>(filePath);
    map['media_type'] = Variable<String>(mediaType);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EvidenceRowsCompanion toCompanion(bool nullToAbsent) {
    return EvidenceRowsCompanion(
      id: Value(id),
      findingId: Value(findingId),
      filePath: Value(filePath),
      mediaType: Value(mediaType),
      source: Value(source),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
    );
  }

  factory EvidenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EvidenceRow(
      id: serializer.fromJson<String>(json['id']),
      findingId: serializer.fromJson<String>(json['findingId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      source: serializer.fromJson<String>(json['source']),
      caption: serializer.fromJson<String?>(json['caption']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'findingId': serializer.toJson<String>(findingId),
      'filePath': serializer.toJson<String>(filePath),
      'mediaType': serializer.toJson<String>(mediaType),
      'source': serializer.toJson<String>(source),
      'caption': serializer.toJson<String?>(caption),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EvidenceRow copyWith({
    String? id,
    String? findingId,
    String? filePath,
    String? mediaType,
    String? source,
    Value<String?> caption = const Value.absent(),
    String? syncStatus,
    DateTime? createdAt,
  }) => EvidenceRow(
    id: id ?? this.id,
    findingId: findingId ?? this.findingId,
    filePath: filePath ?? this.filePath,
    mediaType: mediaType ?? this.mediaType,
    source: source ?? this.source,
    caption: caption.present ? caption.value : this.caption,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
  );
  EvidenceRow copyWithCompanion(EvidenceRowsCompanion data) {
    return EvidenceRow(
      id: data.id.present ? data.id.value : this.id,
      findingId: data.findingId.present ? data.findingId.value : this.findingId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      source: data.source.present ? data.source.value : this.source,
      caption: data.caption.present ? data.caption.value : this.caption,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EvidenceRow(')
          ..write('id: $id, ')
          ..write('findingId: $findingId, ')
          ..write('filePath: $filePath, ')
          ..write('mediaType: $mediaType, ')
          ..write('source: $source, ')
          ..write('caption: $caption, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    findingId,
    filePath,
    mediaType,
    source,
    caption,
    syncStatus,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EvidenceRow &&
          other.id == this.id &&
          other.findingId == this.findingId &&
          other.filePath == this.filePath &&
          other.mediaType == this.mediaType &&
          other.source == this.source &&
          other.caption == this.caption &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt);
}

class EvidenceRowsCompanion extends UpdateCompanion<EvidenceRow> {
  final Value<String> id;
  final Value<String> findingId;
  final Value<String> filePath;
  final Value<String> mediaType;
  final Value<String> source;
  final Value<String?> caption;
  final Value<String> syncStatus;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const EvidenceRowsCompanion({
    this.id = const Value.absent(),
    this.findingId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.source = const Value.absent(),
    this.caption = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EvidenceRowsCompanion.insert({
    required String id,
    required String findingId,
    required String filePath,
    this.mediaType = const Value.absent(),
    this.source = const Value.absent(),
    this.caption = const Value.absent(),
    this.syncStatus = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       findingId = Value(findingId),
       filePath = Value(filePath),
       createdAt = Value(createdAt);
  static Insertable<EvidenceRow> custom({
    Expression<String>? id,
    Expression<String>? findingId,
    Expression<String>? filePath,
    Expression<String>? mediaType,
    Expression<String>? source,
    Expression<String>? caption,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (findingId != null) 'finding_id': findingId,
      if (filePath != null) 'file_path': filePath,
      if (mediaType != null) 'media_type': mediaType,
      if (source != null) 'source': source,
      if (caption != null) 'caption': caption,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EvidenceRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? findingId,
    Value<String>? filePath,
    Value<String>? mediaType,
    Value<String>? source,
    Value<String?>? caption,
    Value<String>? syncStatus,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return EvidenceRowsCompanion(
      id: id ?? this.id,
      findingId: findingId ?? this.findingId,
      filePath: filePath ?? this.filePath,
      mediaType: mediaType ?? this.mediaType,
      source: source ?? this.source,
      caption: caption ?? this.caption,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (findingId.present) {
      map['finding_id'] = Variable<String>(findingId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EvidenceRowsCompanion(')
          ..write('id: $id, ')
          ..write('findingId: $findingId, ')
          ..write('filePath: $filePath, ')
          ..write('mediaType: $mediaType, ')
          ..write('source: $source, ')
          ..write('caption: $caption, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $InspectionSessionRowsTable inspectionSessionRows =
      $InspectionSessionRowsTable(this);
  late final $SectionRowsTable sectionRows = $SectionRowsTable(this);
  late final $FindingRowsTable findingRows = $FindingRowsTable(this);
  late final $EvidenceRowsTable evidenceRows = $EvidenceRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    inspectionSessionRows,
    sectionRows,
    findingRows,
    evidenceRows,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'inspection_session_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('section_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'inspection_session_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('finding_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'finding_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('evidence_rows', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$InspectionSessionRowsTableCreateCompanionBuilder =
    InspectionSessionRowsCompanion Function({
      required String id,
      required String industry,
      required String assetTypeId,
      required String status,
      Value<String> syncStatus,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$InspectionSessionRowsTableUpdateCompanionBuilder =
    InspectionSessionRowsCompanion Function({
      Value<String> id,
      Value<String> industry,
      Value<String> assetTypeId,
      Value<String> status,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$InspectionSessionRowsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $InspectionSessionRowsTable,
          InspectionSessionRow
        > {
  $$InspectionSessionRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SectionRowsTable, List<SectionRow>>
  _sectionRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sectionRows,
    aliasName: 'inspection_session_rows__id__section_rows__session_id',
  );

  $$SectionRowsTableProcessedTableManager get sectionRowsRefs {
    final manager = $$SectionRowsTableTableManager(
      $_db,
      $_db.sectionRows,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sectionRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FindingRowsTable, List<FindingRow>>
  _findingRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.findingRows,
    aliasName: 'inspection_session_rows__id__finding_rows__session_id',
  );

  $$FindingRowsTableProcessedTableManager get findingRowsRefs {
    final manager = $$FindingRowsTableTableManager(
      $_db,
      $_db.findingRows,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_findingRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$InspectionSessionRowsTableFilterComposer
    extends Composer<_$AppDatabase, $InspectionSessionRowsTable> {
  $$InspectionSessionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetTypeId => $composableBuilder(
    column: $table.assetTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sectionRowsRefs(
    Expression<bool> Function($$SectionRowsTableFilterComposer f) f,
  ) {
    final $$SectionRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sectionRows,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionRowsTableFilterComposer(
            $db: $db,
            $table: $db.sectionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> findingRowsRefs(
    Expression<bool> Function($$FindingRowsTableFilterComposer f) f,
  ) {
    final $$FindingRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.findingRows,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FindingRowsTableFilterComposer(
            $db: $db,
            $table: $db.findingRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InspectionSessionRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $InspectionSessionRowsTable> {
  $$InspectionSessionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetTypeId => $composableBuilder(
    column: $table.assetTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InspectionSessionRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InspectionSessionRowsTable> {
  $$InspectionSessionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get industry =>
      $composableBuilder(column: $table.industry, builder: (column) => column);

  GeneratedColumn<String> get assetTypeId => $composableBuilder(
    column: $table.assetTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> sectionRowsRefs<T extends Object>(
    Expression<T> Function($$SectionRowsTableAnnotationComposer a) f,
  ) {
    final $$SectionRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sectionRows,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.sectionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> findingRowsRefs<T extends Object>(
    Expression<T> Function($$FindingRowsTableAnnotationComposer a) f,
  ) {
    final $$FindingRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.findingRows,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FindingRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.findingRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InspectionSessionRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InspectionSessionRowsTable,
          InspectionSessionRow,
          $$InspectionSessionRowsTableFilterComposer,
          $$InspectionSessionRowsTableOrderingComposer,
          $$InspectionSessionRowsTableAnnotationComposer,
          $$InspectionSessionRowsTableCreateCompanionBuilder,
          $$InspectionSessionRowsTableUpdateCompanionBuilder,
          (InspectionSessionRow, $$InspectionSessionRowsTableReferences),
          InspectionSessionRow,
          PrefetchHooks Function({bool sectionRowsRefs, bool findingRowsRefs})
        > {
  $$InspectionSessionRowsTableTableManager(
    _$AppDatabase db,
    $InspectionSessionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InspectionSessionRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InspectionSessionRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InspectionSessionRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> industry = const Value.absent(),
                Value<String> assetTypeId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InspectionSessionRowsCompanion(
                id: id,
                industry: industry,
                assetTypeId: assetTypeId,
                status: status,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String industry,
                required String assetTypeId,
                required String status,
                Value<String> syncStatus = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => InspectionSessionRowsCompanion.insert(
                id: id,
                industry: industry,
                assetTypeId: assetTypeId,
                status: status,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $InspectionSessionRowsTable,
                    InspectionSessionRow
                  >(table),
                  $$InspectionSessionRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sectionRowsRefs = false, findingRowsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sectionRowsRefs) db.sectionRows,
                    if (findingRowsRefs) db.findingRows,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sectionRowsRefs)
                        await $_getPrefetchedData<
                          InspectionSessionRow,
                          $InspectionSessionRowsTable,
                          SectionRow
                        >(
                          currentTable: table,
                          referencedTable:
                              $$InspectionSessionRowsTableReferences
                                  ._sectionRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InspectionSessionRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).sectionRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (findingRowsRefs)
                        await $_getPrefetchedData<
                          InspectionSessionRow,
                          $InspectionSessionRowsTable,
                          FindingRow
                        >(
                          currentTable: table,
                          referencedTable:
                              $$InspectionSessionRowsTableReferences
                                  ._findingRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InspectionSessionRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).findingRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$InspectionSessionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InspectionSessionRowsTable,
      InspectionSessionRow,
      $$InspectionSessionRowsTableFilterComposer,
      $$InspectionSessionRowsTableOrderingComposer,
      $$InspectionSessionRowsTableAnnotationComposer,
      $$InspectionSessionRowsTableCreateCompanionBuilder,
      $$InspectionSessionRowsTableUpdateCompanionBuilder,
      (InspectionSessionRow, $$InspectionSessionRowsTableReferences),
      InspectionSessionRow,
      PrefetchHooks Function({bool sectionRowsRefs, bool findingRowsRefs})
    >;
typedef $$SectionRowsTableCreateCompanionBuilder =
    SectionRowsCompanion Function({
      required String id,
      required String sessionId,
      required String name,
      Value<bool> isPlumbing,
      Value<bool> isIncluded,
      Value<String> status,
      required String elementsJson,
      required int orderIndex,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SectionRowsTableUpdateCompanionBuilder =
    SectionRowsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> name,
      Value<bool> isPlumbing,
      Value<bool> isIncluded,
      Value<String> status,
      Value<String> elementsJson,
      Value<int> orderIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$SectionRowsTableReferences
    extends BaseReferences<_$AppDatabase, $SectionRowsTable, SectionRow> {
  $$SectionRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $InspectionSessionRowsTable _sessionIdTable(_$AppDatabase db) => db
      .inspectionSessionRows
      .createAlias('section_rows__session_id__inspection_session_rows__id');

  $$InspectionSessionRowsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$InspectionSessionRowsTableTableManager(
      $_db,
      $_db.inspectionSessionRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SectionRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SectionRowsTable> {
  $$SectionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPlumbing => $composableBuilder(
    column: $table.isPlumbing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isIncluded => $composableBuilder(
    column: $table.isIncluded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get elementsJson => $composableBuilder(
    column: $table.elementsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$InspectionSessionRowsTableFilterComposer get sessionId {
    final $$InspectionSessionRowsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.inspectionSessionRows,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InspectionSessionRowsTableFilterComposer(
                $db: $db,
                $table: $db.inspectionSessionRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$SectionRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SectionRowsTable> {
  $$SectionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPlumbing => $composableBuilder(
    column: $table.isPlumbing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isIncluded => $composableBuilder(
    column: $table.isIncluded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get elementsJson => $composableBuilder(
    column: $table.elementsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$InspectionSessionRowsTableOrderingComposer get sessionId {
    final $$InspectionSessionRowsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.inspectionSessionRows,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InspectionSessionRowsTableOrderingComposer(
                $db: $db,
                $table: $db.inspectionSessionRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$SectionRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SectionRowsTable> {
  $$SectionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isPlumbing => $composableBuilder(
    column: $table.isPlumbing,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isIncluded => $composableBuilder(
    column: $table.isIncluded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get elementsJson => $composableBuilder(
    column: $table.elementsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$InspectionSessionRowsTableAnnotationComposer get sessionId {
    final $$InspectionSessionRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.inspectionSessionRows,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InspectionSessionRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.inspectionSessionRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$SectionRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SectionRowsTable,
          SectionRow,
          $$SectionRowsTableFilterComposer,
          $$SectionRowsTableOrderingComposer,
          $$SectionRowsTableAnnotationComposer,
          $$SectionRowsTableCreateCompanionBuilder,
          $$SectionRowsTableUpdateCompanionBuilder,
          (SectionRow, $$SectionRowsTableReferences),
          SectionRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SectionRowsTableTableManager(_$AppDatabase db, $SectionRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SectionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SectionRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SectionRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isPlumbing = const Value.absent(),
                Value<bool> isIncluded = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> elementsJson = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SectionRowsCompanion(
                id: id,
                sessionId: sessionId,
                name: name,
                isPlumbing: isPlumbing,
                isIncluded: isIncluded,
                status: status,
                elementsJson: elementsJson,
                orderIndex: orderIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String name,
                Value<bool> isPlumbing = const Value.absent(),
                Value<bool> isIncluded = const Value.absent(),
                Value<String> status = const Value.absent(),
                required String elementsJson,
                required int orderIndex,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SectionRowsCompanion.insert(
                id: id,
                sessionId: sessionId,
                name: name,
                isPlumbing: isPlumbing,
                isIncluded: isIncluded,
                status: status,
                elementsJson: elementsJson,
                orderIndex: orderIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SectionRowsTable, SectionRow>(table),
                  $$SectionRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$SectionRowsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$SectionRowsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SectionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SectionRowsTable,
      SectionRow,
      $$SectionRowsTableFilterComposer,
      $$SectionRowsTableOrderingComposer,
      $$SectionRowsTableAnnotationComposer,
      $$SectionRowsTableCreateCompanionBuilder,
      $$SectionRowsTableUpdateCompanionBuilder,
      (SectionRow, $$SectionRowsTableReferences),
      SectionRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$FindingRowsTableCreateCompanionBuilder =
    FindingRowsCompanion Function({
      required String id,
      required String sessionId,
      required String sectionId,
      required String elementId,
      Value<String?> componentId,
      Value<String?> description,
      Value<String?> notes,
      Value<String> status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FindingRowsTableUpdateCompanionBuilder =
    FindingRowsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> sectionId,
      Value<String> elementId,
      Value<String?> componentId,
      Value<String?> description,
      Value<String?> notes,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$FindingRowsTableReferences
    extends BaseReferences<_$AppDatabase, $FindingRowsTable, FindingRow> {
  $$FindingRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $InspectionSessionRowsTable _sessionIdTable(_$AppDatabase db) => db
      .inspectionSessionRows
      .createAlias('finding_rows__session_id__inspection_session_rows__id');

  $$InspectionSessionRowsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$InspectionSessionRowsTableTableManager(
      $_db,
      $_db.inspectionSessionRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EvidenceRowsTable, List<EvidenceRow>>
  _evidenceRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.evidenceRows,
    aliasName: 'finding_rows__id__evidence_rows__finding_id',
  );

  $$EvidenceRowsTableProcessedTableManager get evidenceRowsRefs {
    final manager = $$EvidenceRowsTableTableManager(
      $_db,
      $_db.evidenceRows,
    ).filter((f) => f.findingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_evidenceRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FindingRowsTableFilterComposer
    extends Composer<_$AppDatabase, $FindingRowsTable> {
  $$FindingRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get elementId => $composableBuilder(
    column: $table.elementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get componentId => $composableBuilder(
    column: $table.componentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$InspectionSessionRowsTableFilterComposer get sessionId {
    final $$InspectionSessionRowsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.inspectionSessionRows,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InspectionSessionRowsTableFilterComposer(
                $db: $db,
                $table: $db.inspectionSessionRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<bool> evidenceRowsRefs(
    Expression<bool> Function($$EvidenceRowsTableFilterComposer f) f,
  ) {
    final $$EvidenceRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evidenceRows,
      getReferencedColumn: (t) => t.findingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidenceRowsTableFilterComposer(
            $db: $db,
            $table: $db.evidenceRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FindingRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $FindingRowsTable> {
  $$FindingRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get elementId => $composableBuilder(
    column: $table.elementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get componentId => $composableBuilder(
    column: $table.componentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$InspectionSessionRowsTableOrderingComposer get sessionId {
    final $$InspectionSessionRowsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.inspectionSessionRows,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InspectionSessionRowsTableOrderingComposer(
                $db: $db,
                $table: $db.inspectionSessionRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$FindingRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FindingRowsTable> {
  $$FindingRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get elementId =>
      $composableBuilder(column: $table.elementId, builder: (column) => column);

  GeneratedColumn<String> get componentId => $composableBuilder(
    column: $table.componentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$InspectionSessionRowsTableAnnotationComposer get sessionId {
    final $$InspectionSessionRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.inspectionSessionRows,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InspectionSessionRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.inspectionSessionRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> evidenceRowsRefs<T extends Object>(
    Expression<T> Function($$EvidenceRowsTableAnnotationComposer a) f,
  ) {
    final $$EvidenceRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evidenceRows,
      getReferencedColumn: (t) => t.findingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidenceRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.evidenceRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FindingRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FindingRowsTable,
          FindingRow,
          $$FindingRowsTableFilterComposer,
          $$FindingRowsTableOrderingComposer,
          $$FindingRowsTableAnnotationComposer,
          $$FindingRowsTableCreateCompanionBuilder,
          $$FindingRowsTableUpdateCompanionBuilder,
          (FindingRow, $$FindingRowsTableReferences),
          FindingRow,
          PrefetchHooks Function({bool sessionId, bool evidenceRowsRefs})
        > {
  $$FindingRowsTableTableManager(_$AppDatabase db, $FindingRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FindingRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FindingRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FindingRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> sectionId = const Value.absent(),
                Value<String> elementId = const Value.absent(),
                Value<String?> componentId = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FindingRowsCompanion(
                id: id,
                sessionId: sessionId,
                sectionId: sectionId,
                elementId: elementId,
                componentId: componentId,
                description: description,
                notes: notes,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String sectionId,
                required String elementId,
                Value<String?> componentId = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FindingRowsCompanion.insert(
                id: id,
                sessionId: sessionId,
                sectionId: sectionId,
                elementId: elementId,
                componentId: componentId,
                description: description,
                notes: notes,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FindingRowsTable, FindingRow>(table),
                  $$FindingRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sessionId = false, evidenceRowsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (evidenceRowsRefs) db.evidenceRows,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sessionId,
                            referencedTable: $$FindingRowsTableReferences
                                ._sessionIdTable(db),
                            referencedColumn: $$FindingRowsTableReferences
                                ._sessionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (evidenceRowsRefs)
                        await $_getPrefetchedData<
                          FindingRow,
                          $FindingRowsTable,
                          EvidenceRow
                        >(
                          currentTable: table,
                          referencedTable: $$FindingRowsTableReferences
                              ._evidenceRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FindingRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).evidenceRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.findingId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FindingRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FindingRowsTable,
      FindingRow,
      $$FindingRowsTableFilterComposer,
      $$FindingRowsTableOrderingComposer,
      $$FindingRowsTableAnnotationComposer,
      $$FindingRowsTableCreateCompanionBuilder,
      $$FindingRowsTableUpdateCompanionBuilder,
      (FindingRow, $$FindingRowsTableReferences),
      FindingRow,
      PrefetchHooks Function({bool sessionId, bool evidenceRowsRefs})
    >;
typedef $$EvidenceRowsTableCreateCompanionBuilder =
    EvidenceRowsCompanion Function({
      required String id,
      required String findingId,
      required String filePath,
      Value<String> mediaType,
      Value<String> source,
      Value<String?> caption,
      Value<String> syncStatus,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$EvidenceRowsTableUpdateCompanionBuilder =
    EvidenceRowsCompanion Function({
      Value<String> id,
      Value<String> findingId,
      Value<String> filePath,
      Value<String> mediaType,
      Value<String> source,
      Value<String?> caption,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$EvidenceRowsTableReferences
    extends BaseReferences<_$AppDatabase, $EvidenceRowsTable, EvidenceRow> {
  $$EvidenceRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FindingRowsTable _findingIdTable(_$AppDatabase db) =>
      db.findingRows.createAlias('evidence_rows__finding_id__finding_rows__id');

  $$FindingRowsTableProcessedTableManager get findingId {
    final $_column = $_itemColumn<String>('finding_id')!;

    final manager = $$FindingRowsTableTableManager(
      $_db,
      $_db.findingRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_findingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EvidenceRowsTableFilterComposer
    extends Composer<_$AppDatabase, $EvidenceRowsTable> {
  $$EvidenceRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FindingRowsTableFilterComposer get findingId {
    final $$FindingRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.findingId,
      referencedTable: $db.findingRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FindingRowsTableFilterComposer(
            $db: $db,
            $table: $db.findingRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidenceRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $EvidenceRowsTable> {
  $$EvidenceRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FindingRowsTableOrderingComposer get findingId {
    final $$FindingRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.findingId,
      referencedTable: $db.findingRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FindingRowsTableOrderingComposer(
            $db: $db,
            $table: $db.findingRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidenceRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EvidenceRowsTable> {
  $$EvidenceRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FindingRowsTableAnnotationComposer get findingId {
    final $$FindingRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.findingId,
      referencedTable: $db.findingRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FindingRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.findingRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidenceRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EvidenceRowsTable,
          EvidenceRow,
          $$EvidenceRowsTableFilterComposer,
          $$EvidenceRowsTableOrderingComposer,
          $$EvidenceRowsTableAnnotationComposer,
          $$EvidenceRowsTableCreateCompanionBuilder,
          $$EvidenceRowsTableUpdateCompanionBuilder,
          (EvidenceRow, $$EvidenceRowsTableReferences),
          EvidenceRow,
          PrefetchHooks Function({bool findingId})
        > {
  $$EvidenceRowsTableTableManager(_$AppDatabase db, $EvidenceRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EvidenceRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EvidenceRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EvidenceRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> findingId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EvidenceRowsCompanion(
                id: id,
                findingId: findingId,
                filePath: filePath,
                mediaType: mediaType,
                source: source,
                caption: caption,
                syncStatus: syncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String findingId,
                required String filePath,
                Value<String> mediaType = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => EvidenceRowsCompanion.insert(
                id: id,
                findingId: findingId,
                filePath: filePath,
                mediaType: mediaType,
                source: source,
                caption: caption,
                syncStatus: syncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EvidenceRowsTable, EvidenceRow>(table),
                  $$EvidenceRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({findingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (findingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.findingId,
                        referencedTable: $$EvidenceRowsTableReferences
                            ._findingIdTable(db),
                        referencedColumn: $$EvidenceRowsTableReferences
                            ._findingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EvidenceRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EvidenceRowsTable,
      EvidenceRow,
      $$EvidenceRowsTableFilterComposer,
      $$EvidenceRowsTableOrderingComposer,
      $$EvidenceRowsTableAnnotationComposer,
      $$EvidenceRowsTableCreateCompanionBuilder,
      $$EvidenceRowsTableUpdateCompanionBuilder,
      (EvidenceRow, $$EvidenceRowsTableReferences),
      EvidenceRow,
      PrefetchHooks Function({bool findingId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$InspectionSessionRowsTableTableManager get inspectionSessionRows =>
      $$InspectionSessionRowsTableTableManager(_db, _db.inspectionSessionRows);
  $$SectionRowsTableTableManager get sectionRows =>
      $$SectionRowsTableTableManager(_db, _db.sectionRows);
  $$FindingRowsTableTableManager get findingRows =>
      $$FindingRowsTableTableManager(_db, _db.findingRows);
  $$EvidenceRowsTableTableManager get evidenceRows =>
      $$EvidenceRowsTableTableManager(_db, _db.evidenceRows);
}
