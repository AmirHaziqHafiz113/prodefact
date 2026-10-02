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
  static const VerificationMeta _ownerUidMeta = const VerificationMeta(
    'ownerUid',
  );
  @override
  late final GeneratedColumn<String> ownerUid = GeneratedColumn<String>(
    'owner_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiReviewStateMeta = const VerificationMeta(
    'aiReviewState',
  );
  @override
  late final GeneratedColumn<String> aiReviewState = GeneratedColumn<String>(
    'ai_review_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('notStarted'),
  );
  static const VerificationMeta _propertyTitleMeta = const VerificationMeta(
    'propertyTitle',
  );
  @override
  late final GeneratedColumn<String> propertyTitle = GeneratedColumn<String>(
    'property_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _propertyAddressMeta = const VerificationMeta(
    'propertyAddress',
  );
  @override
  late final GeneratedColumn<String> propertyAddress = GeneratedColumn<String>(
    'property_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectNameMeta = const VerificationMeta(
    'projectName',
  );
  @override
  late final GeneratedColumn<String> projectName = GeneratedColumn<String>(
    'project_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockTowerMeta = const VerificationMeta(
    'blockTower',
  );
  @override
  late final GeneratedColumn<String> blockTower = GeneratedColumn<String>(
    'block_tower',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitNumberMeta = const VerificationMeta(
    'unitNumber',
  );
  @override
  late final GeneratedColumn<String> unitNumber = GeneratedColumn<String>(
    'unit_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientNameMeta = const VerificationMeta(
    'clientName',
  );
  @override
  late final GeneratedColumn<String> clientName = GeneratedColumn<String>(
    'client_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inspectorNameMeta = const VerificationMeta(
    'inspectorName',
  );
  @override
  late final GeneratedColumn<String> inspectorName = GeneratedColumn<String>(
    'inspector_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _developerNameMeta = const VerificationMeta(
    'developerName',
  );
  @override
  late final GeneratedColumn<String> developerName = GeneratedColumn<String>(
    'developer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactNumberMeta = const VerificationMeta(
    'contactNumber',
  );
  @override
  late final GeneratedColumn<String> contactNumber = GeneratedColumn<String>(
    'contact_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inspectionDateMeta = const VerificationMeta(
    'inspectionDate',
  );
  @override
  late final GeneratedColumn<DateTime> inspectionDate =
      GeneratedColumn<DateTime>(
        'inspection_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reportMetadataJsonMeta =
      const VerificationMeta('reportMetadataJson');
  @override
  late final GeneratedColumn<String> reportMetadataJson =
      GeneratedColumn<String>(
        'report_metadata_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _inspectionNoteMeta = const VerificationMeta(
    'inspectionNote',
  );
  @override
  late final GeneratedColumn<String> inspectionNote = GeneratedColumn<String>(
    'inspection_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commercialModeMeta = const VerificationMeta(
    'commercialMode',
  );
  @override
  late final GeneratedColumn<String> commercialMode = GeneratedColumn<String>(
    'commercial_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selectedAiLevelMeta = const VerificationMeta(
    'selectedAiLevel',
  );
  @override
  late final GeneratedColumn<String> selectedAiLevel = GeneratedColumn<String>(
    'selected_ai_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoAnalyseEnabledMeta =
      const VerificationMeta('autoAnalyseEnabled');
  @override
  late final GeneratedColumn<bool> autoAnalyseEnabled = GeneratedColumn<bool>(
    'auto_analyse_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_analyse_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _projectDeveloperNameMeta =
      const VerificationMeta('projectDeveloperName');
  @override
  late final GeneratedColumn<String> projectDeveloperName =
      GeneratedColumn<String>(
        'project_developer_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
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
    ownerUid,
    aiReviewState,
    propertyTitle,
    propertyAddress,
    projectName,
    blockTower,
    unitNumber,
    clientName,
    inspectorName,
    developerName,
    contactNumber,
    inspectionDate,
    reportMetadataJson,
    inspectionNote,
    commercialMode,
    selectedAiLevel,
    autoAnalyseEnabled,
    projectDeveloperName,
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
    if (data.containsKey('owner_uid')) {
      context.handle(
        _ownerUidMeta,
        ownerUid.isAcceptableOrUnknown(data['owner_uid']!, _ownerUidMeta),
      );
    }
    if (data.containsKey('ai_review_state')) {
      context.handle(
        _aiReviewStateMeta,
        aiReviewState.isAcceptableOrUnknown(
          data['ai_review_state']!,
          _aiReviewStateMeta,
        ),
      );
    }
    if (data.containsKey('property_title')) {
      context.handle(
        _propertyTitleMeta,
        propertyTitle.isAcceptableOrUnknown(
          data['property_title']!,
          _propertyTitleMeta,
        ),
      );
    }
    if (data.containsKey('property_address')) {
      context.handle(
        _propertyAddressMeta,
        propertyAddress.isAcceptableOrUnknown(
          data['property_address']!,
          _propertyAddressMeta,
        ),
      );
    }
    if (data.containsKey('project_name')) {
      context.handle(
        _projectNameMeta,
        projectName.isAcceptableOrUnknown(
          data['project_name']!,
          _projectNameMeta,
        ),
      );
    }
    if (data.containsKey('block_tower')) {
      context.handle(
        _blockTowerMeta,
        blockTower.isAcceptableOrUnknown(data['block_tower']!, _blockTowerMeta),
      );
    }
    if (data.containsKey('unit_number')) {
      context.handle(
        _unitNumberMeta,
        unitNumber.isAcceptableOrUnknown(data['unit_number']!, _unitNumberMeta),
      );
    }
    if (data.containsKey('client_name')) {
      context.handle(
        _clientNameMeta,
        clientName.isAcceptableOrUnknown(data['client_name']!, _clientNameMeta),
      );
    }
    if (data.containsKey('inspector_name')) {
      context.handle(
        _inspectorNameMeta,
        inspectorName.isAcceptableOrUnknown(
          data['inspector_name']!,
          _inspectorNameMeta,
        ),
      );
    }
    if (data.containsKey('developer_name')) {
      context.handle(
        _developerNameMeta,
        developerName.isAcceptableOrUnknown(
          data['developer_name']!,
          _developerNameMeta,
        ),
      );
    }
    if (data.containsKey('contact_number')) {
      context.handle(
        _contactNumberMeta,
        contactNumber.isAcceptableOrUnknown(
          data['contact_number']!,
          _contactNumberMeta,
        ),
      );
    }
    if (data.containsKey('inspection_date')) {
      context.handle(
        _inspectionDateMeta,
        inspectionDate.isAcceptableOrUnknown(
          data['inspection_date']!,
          _inspectionDateMeta,
        ),
      );
    }
    if (data.containsKey('report_metadata_json')) {
      context.handle(
        _reportMetadataJsonMeta,
        reportMetadataJson.isAcceptableOrUnknown(
          data['report_metadata_json']!,
          _reportMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('inspection_note')) {
      context.handle(
        _inspectionNoteMeta,
        inspectionNote.isAcceptableOrUnknown(
          data['inspection_note']!,
          _inspectionNoteMeta,
        ),
      );
    }
    if (data.containsKey('commercial_mode')) {
      context.handle(
        _commercialModeMeta,
        commercialMode.isAcceptableOrUnknown(
          data['commercial_mode']!,
          _commercialModeMeta,
        ),
      );
    }
    if (data.containsKey('selected_ai_level')) {
      context.handle(
        _selectedAiLevelMeta,
        selectedAiLevel.isAcceptableOrUnknown(
          data['selected_ai_level']!,
          _selectedAiLevelMeta,
        ),
      );
    }
    if (data.containsKey('auto_analyse_enabled')) {
      context.handle(
        _autoAnalyseEnabledMeta,
        autoAnalyseEnabled.isAcceptableOrUnknown(
          data['auto_analyse_enabled']!,
          _autoAnalyseEnabledMeta,
        ),
      );
    }
    if (data.containsKey('project_developer_name')) {
      context.handle(
        _projectDeveloperNameMeta,
        projectDeveloperName.isAcceptableOrUnknown(
          data['project_developer_name']!,
          _projectDeveloperNameMeta,
        ),
      );
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
      ownerUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_uid'],
      ),
      aiReviewState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_review_state'],
      )!,
      propertyTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}property_title'],
      ),
      propertyAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}property_address'],
      ),
      projectName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_name'],
      ),
      blockTower: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_tower'],
      ),
      unitNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_number'],
      ),
      clientName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_name'],
      ),
      inspectorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inspector_name'],
      ),
      developerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}developer_name'],
      ),
      contactNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_number'],
      ),
      inspectionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}inspection_date'],
      ),
      reportMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_metadata_json'],
      ),
      inspectionNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inspection_note'],
      ),
      commercialMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commercial_mode'],
      ),
      selectedAiLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_ai_level'],
      ),
      autoAnalyseEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_analyse_enabled'],
      )!,
      projectDeveloperName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_developer_name'],
      ),
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

  /// The authenticated user this session belongs to. Null for a "guest"
  /// session created while signed out (added in schema v2).
  final String? ownerUid;

  /// State of the whole-session AI analysis run (added in schema v3) —
  /// see `AiReviewState`.
  final String aiReviewState;
  final String? propertyTitle;
  final String? propertyAddress;

  /// Deprecated in schema v10 in favor of [projectDeveloperName] — kept
  /// (read-only from new code) so an inspection saved before that merge
  /// still loads with its data intact. See
  /// `PropertyDetails.resolvedProjectDeveloperName`.
  final String? projectName;
  final String? blockTower;
  final String? unitNumber;
  final String? clientName;
  final String? inspectorName;
  final String? developerName;
  final String? contactNumber;
  final DateTime? inspectionDate;

  /// The inspector-confirmed report cover-page metadata (added in
  /// schema v8), JSON-encoded — see `ReportMetadata`. Null until
  /// confirmed at least once via the Report Details step; the report
  /// falls back to deriving it fresh from the property-details columns
  /// above in that case. A blob column (like `SectionRows.elementsJson`)
  /// rather than one column per field, since it's edited as a whole
  /// unit on one screen and never queried by individual field.
  final String? reportMetadataJson;

  /// An optional, contextual note about the whole inspection (added in
  /// schema v8) — e.g. "Unit occupied during inspection." Not a defect;
  /// never sent through AI classification.
  final String? inspectionNote;

  /// How this inspection pays for AI analysis — `flexCredits` or
  /// `housePass` (added in schema v9), chosen once via the Choose AI
  /// Plan step. Null for a pre-v9 session or one still awaiting that
  /// choice — see `CommercialMode`, docs/commercial_model.md.
  final String? commercialMode;

  /// The inspector's chosen AI quality tier for this inspection —
  /// `fast`/`smart`/`expert` (added in schema v9). See `AiLevel`.
  final String? selectedAiLevel;

  /// Whether AI analysis should run automatically after Save Finding
  /// (added in schema v9). Defaults to false (Flex Credits' safe
  /// default) — never true for any pre-existing session.
  final bool autoAnalyseEnabled;

  /// The single "Project / Developer Name" field (added in schema v10,
  /// QA/QC setup-simplification pass) — replaces the previous separate
  /// [projectName]/[developerName] fields going forward. Both legacy
  /// columns are kept, untouched, for backward compatibility; see
  /// `PropertyDetails.resolvedProjectDeveloperName`.
  final String? projectDeveloperName;
  const InspectionSessionRow({
    required this.id,
    required this.industry,
    required this.assetTypeId,
    required this.status,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.ownerUid,
    required this.aiReviewState,
    this.propertyTitle,
    this.propertyAddress,
    this.projectName,
    this.blockTower,
    this.unitNumber,
    this.clientName,
    this.inspectorName,
    this.developerName,
    this.contactNumber,
    this.inspectionDate,
    this.reportMetadataJson,
    this.inspectionNote,
    this.commercialMode,
    this.selectedAiLevel,
    required this.autoAnalyseEnabled,
    this.projectDeveloperName,
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
    if (!nullToAbsent || ownerUid != null) {
      map['owner_uid'] = Variable<String>(ownerUid);
    }
    map['ai_review_state'] = Variable<String>(aiReviewState);
    if (!nullToAbsent || propertyTitle != null) {
      map['property_title'] = Variable<String>(propertyTitle);
    }
    if (!nullToAbsent || propertyAddress != null) {
      map['property_address'] = Variable<String>(propertyAddress);
    }
    if (!nullToAbsent || projectName != null) {
      map['project_name'] = Variable<String>(projectName);
    }
    if (!nullToAbsent || blockTower != null) {
      map['block_tower'] = Variable<String>(blockTower);
    }
    if (!nullToAbsent || unitNumber != null) {
      map['unit_number'] = Variable<String>(unitNumber);
    }
    if (!nullToAbsent || clientName != null) {
      map['client_name'] = Variable<String>(clientName);
    }
    if (!nullToAbsent || inspectorName != null) {
      map['inspector_name'] = Variable<String>(inspectorName);
    }
    if (!nullToAbsent || developerName != null) {
      map['developer_name'] = Variable<String>(developerName);
    }
    if (!nullToAbsent || contactNumber != null) {
      map['contact_number'] = Variable<String>(contactNumber);
    }
    if (!nullToAbsent || inspectionDate != null) {
      map['inspection_date'] = Variable<DateTime>(inspectionDate);
    }
    if (!nullToAbsent || reportMetadataJson != null) {
      map['report_metadata_json'] = Variable<String>(reportMetadataJson);
    }
    if (!nullToAbsent || inspectionNote != null) {
      map['inspection_note'] = Variable<String>(inspectionNote);
    }
    if (!nullToAbsent || commercialMode != null) {
      map['commercial_mode'] = Variable<String>(commercialMode);
    }
    if (!nullToAbsent || selectedAiLevel != null) {
      map['selected_ai_level'] = Variable<String>(selectedAiLevel);
    }
    map['auto_analyse_enabled'] = Variable<bool>(autoAnalyseEnabled);
    if (!nullToAbsent || projectDeveloperName != null) {
      map['project_developer_name'] = Variable<String>(projectDeveloperName);
    }
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
      ownerUid: ownerUid == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUid),
      aiReviewState: Value(aiReviewState),
      propertyTitle: propertyTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(propertyTitle),
      propertyAddress: propertyAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(propertyAddress),
      projectName: projectName == null && nullToAbsent
          ? const Value.absent()
          : Value(projectName),
      blockTower: blockTower == null && nullToAbsent
          ? const Value.absent()
          : Value(blockTower),
      unitNumber: unitNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(unitNumber),
      clientName: clientName == null && nullToAbsent
          ? const Value.absent()
          : Value(clientName),
      inspectorName: inspectorName == null && nullToAbsent
          ? const Value.absent()
          : Value(inspectorName),
      developerName: developerName == null && nullToAbsent
          ? const Value.absent()
          : Value(developerName),
      contactNumber: contactNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(contactNumber),
      inspectionDate: inspectionDate == null && nullToAbsent
          ? const Value.absent()
          : Value(inspectionDate),
      reportMetadataJson: reportMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reportMetadataJson),
      inspectionNote: inspectionNote == null && nullToAbsent
          ? const Value.absent()
          : Value(inspectionNote),
      commercialMode: commercialMode == null && nullToAbsent
          ? const Value.absent()
          : Value(commercialMode),
      selectedAiLevel: selectedAiLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedAiLevel),
      autoAnalyseEnabled: Value(autoAnalyseEnabled),
      projectDeveloperName: projectDeveloperName == null && nullToAbsent
          ? const Value.absent()
          : Value(projectDeveloperName),
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
      ownerUid: serializer.fromJson<String?>(json['ownerUid']),
      aiReviewState: serializer.fromJson<String>(json['aiReviewState']),
      propertyTitle: serializer.fromJson<String?>(json['propertyTitle']),
      propertyAddress: serializer.fromJson<String?>(json['propertyAddress']),
      projectName: serializer.fromJson<String?>(json['projectName']),
      blockTower: serializer.fromJson<String?>(json['blockTower']),
      unitNumber: serializer.fromJson<String?>(json['unitNumber']),
      clientName: serializer.fromJson<String?>(json['clientName']),
      inspectorName: serializer.fromJson<String?>(json['inspectorName']),
      developerName: serializer.fromJson<String?>(json['developerName']),
      contactNumber: serializer.fromJson<String?>(json['contactNumber']),
      inspectionDate: serializer.fromJson<DateTime?>(json['inspectionDate']),
      reportMetadataJson: serializer.fromJson<String?>(
        json['reportMetadataJson'],
      ),
      inspectionNote: serializer.fromJson<String?>(json['inspectionNote']),
      commercialMode: serializer.fromJson<String?>(json['commercialMode']),
      selectedAiLevel: serializer.fromJson<String?>(json['selectedAiLevel']),
      autoAnalyseEnabled: serializer.fromJson<bool>(json['autoAnalyseEnabled']),
      projectDeveloperName: serializer.fromJson<String?>(
        json['projectDeveloperName'],
      ),
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
      'ownerUid': serializer.toJson<String?>(ownerUid),
      'aiReviewState': serializer.toJson<String>(aiReviewState),
      'propertyTitle': serializer.toJson<String?>(propertyTitle),
      'propertyAddress': serializer.toJson<String?>(propertyAddress),
      'projectName': serializer.toJson<String?>(projectName),
      'blockTower': serializer.toJson<String?>(blockTower),
      'unitNumber': serializer.toJson<String?>(unitNumber),
      'clientName': serializer.toJson<String?>(clientName),
      'inspectorName': serializer.toJson<String?>(inspectorName),
      'developerName': serializer.toJson<String?>(developerName),
      'contactNumber': serializer.toJson<String?>(contactNumber),
      'inspectionDate': serializer.toJson<DateTime?>(inspectionDate),
      'reportMetadataJson': serializer.toJson<String?>(reportMetadataJson),
      'inspectionNote': serializer.toJson<String?>(inspectionNote),
      'commercialMode': serializer.toJson<String?>(commercialMode),
      'selectedAiLevel': serializer.toJson<String?>(selectedAiLevel),
      'autoAnalyseEnabled': serializer.toJson<bool>(autoAnalyseEnabled),
      'projectDeveloperName': serializer.toJson<String?>(projectDeveloperName),
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
    Value<String?> ownerUid = const Value.absent(),
    String? aiReviewState,
    Value<String?> propertyTitle = const Value.absent(),
    Value<String?> propertyAddress = const Value.absent(),
    Value<String?> projectName = const Value.absent(),
    Value<String?> blockTower = const Value.absent(),
    Value<String?> unitNumber = const Value.absent(),
    Value<String?> clientName = const Value.absent(),
    Value<String?> inspectorName = const Value.absent(),
    Value<String?> developerName = const Value.absent(),
    Value<String?> contactNumber = const Value.absent(),
    Value<DateTime?> inspectionDate = const Value.absent(),
    Value<String?> reportMetadataJson = const Value.absent(),
    Value<String?> inspectionNote = const Value.absent(),
    Value<String?> commercialMode = const Value.absent(),
    Value<String?> selectedAiLevel = const Value.absent(),
    bool? autoAnalyseEnabled,
    Value<String?> projectDeveloperName = const Value.absent(),
  }) => InspectionSessionRow(
    id: id ?? this.id,
    industry: industry ?? this.industry,
    assetTypeId: assetTypeId ?? this.assetTypeId,
    status: status ?? this.status,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    ownerUid: ownerUid.present ? ownerUid.value : this.ownerUid,
    aiReviewState: aiReviewState ?? this.aiReviewState,
    propertyTitle: propertyTitle.present
        ? propertyTitle.value
        : this.propertyTitle,
    propertyAddress: propertyAddress.present
        ? propertyAddress.value
        : this.propertyAddress,
    projectName: projectName.present ? projectName.value : this.projectName,
    blockTower: blockTower.present ? blockTower.value : this.blockTower,
    unitNumber: unitNumber.present ? unitNumber.value : this.unitNumber,
    clientName: clientName.present ? clientName.value : this.clientName,
    inspectorName: inspectorName.present
        ? inspectorName.value
        : this.inspectorName,
    developerName: developerName.present
        ? developerName.value
        : this.developerName,
    contactNumber: contactNumber.present
        ? contactNumber.value
        : this.contactNumber,
    inspectionDate: inspectionDate.present
        ? inspectionDate.value
        : this.inspectionDate,
    reportMetadataJson: reportMetadataJson.present
        ? reportMetadataJson.value
        : this.reportMetadataJson,
    inspectionNote: inspectionNote.present
        ? inspectionNote.value
        : this.inspectionNote,
    commercialMode: commercialMode.present
        ? commercialMode.value
        : this.commercialMode,
    selectedAiLevel: selectedAiLevel.present
        ? selectedAiLevel.value
        : this.selectedAiLevel,
    autoAnalyseEnabled: autoAnalyseEnabled ?? this.autoAnalyseEnabled,
    projectDeveloperName: projectDeveloperName.present
        ? projectDeveloperName.value
        : this.projectDeveloperName,
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
      ownerUid: data.ownerUid.present ? data.ownerUid.value : this.ownerUid,
      aiReviewState: data.aiReviewState.present
          ? data.aiReviewState.value
          : this.aiReviewState,
      propertyTitle: data.propertyTitle.present
          ? data.propertyTitle.value
          : this.propertyTitle,
      propertyAddress: data.propertyAddress.present
          ? data.propertyAddress.value
          : this.propertyAddress,
      projectName: data.projectName.present
          ? data.projectName.value
          : this.projectName,
      blockTower: data.blockTower.present
          ? data.blockTower.value
          : this.blockTower,
      unitNumber: data.unitNumber.present
          ? data.unitNumber.value
          : this.unitNumber,
      clientName: data.clientName.present
          ? data.clientName.value
          : this.clientName,
      inspectorName: data.inspectorName.present
          ? data.inspectorName.value
          : this.inspectorName,
      developerName: data.developerName.present
          ? data.developerName.value
          : this.developerName,
      contactNumber: data.contactNumber.present
          ? data.contactNumber.value
          : this.contactNumber,
      inspectionDate: data.inspectionDate.present
          ? data.inspectionDate.value
          : this.inspectionDate,
      reportMetadataJson: data.reportMetadataJson.present
          ? data.reportMetadataJson.value
          : this.reportMetadataJson,
      inspectionNote: data.inspectionNote.present
          ? data.inspectionNote.value
          : this.inspectionNote,
      commercialMode: data.commercialMode.present
          ? data.commercialMode.value
          : this.commercialMode,
      selectedAiLevel: data.selectedAiLevel.present
          ? data.selectedAiLevel.value
          : this.selectedAiLevel,
      autoAnalyseEnabled: data.autoAnalyseEnabled.present
          ? data.autoAnalyseEnabled.value
          : this.autoAnalyseEnabled,
      projectDeveloperName: data.projectDeveloperName.present
          ? data.projectDeveloperName.value
          : this.projectDeveloperName,
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
          ..write('updatedAt: $updatedAt, ')
          ..write('ownerUid: $ownerUid, ')
          ..write('aiReviewState: $aiReviewState, ')
          ..write('propertyTitle: $propertyTitle, ')
          ..write('propertyAddress: $propertyAddress, ')
          ..write('projectName: $projectName, ')
          ..write('blockTower: $blockTower, ')
          ..write('unitNumber: $unitNumber, ')
          ..write('clientName: $clientName, ')
          ..write('inspectorName: $inspectorName, ')
          ..write('developerName: $developerName, ')
          ..write('contactNumber: $contactNumber, ')
          ..write('inspectionDate: $inspectionDate, ')
          ..write('reportMetadataJson: $reportMetadataJson, ')
          ..write('inspectionNote: $inspectionNote, ')
          ..write('commercialMode: $commercialMode, ')
          ..write('selectedAiLevel: $selectedAiLevel, ')
          ..write('autoAnalyseEnabled: $autoAnalyseEnabled, ')
          ..write('projectDeveloperName: $projectDeveloperName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    industry,
    assetTypeId,
    status,
    syncStatus,
    createdAt,
    updatedAt,
    ownerUid,
    aiReviewState,
    propertyTitle,
    propertyAddress,
    projectName,
    blockTower,
    unitNumber,
    clientName,
    inspectorName,
    developerName,
    contactNumber,
    inspectionDate,
    reportMetadataJson,
    inspectionNote,
    commercialMode,
    selectedAiLevel,
    autoAnalyseEnabled,
    projectDeveloperName,
  ]);
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
          other.updatedAt == this.updatedAt &&
          other.ownerUid == this.ownerUid &&
          other.aiReviewState == this.aiReviewState &&
          other.propertyTitle == this.propertyTitle &&
          other.propertyAddress == this.propertyAddress &&
          other.projectName == this.projectName &&
          other.blockTower == this.blockTower &&
          other.unitNumber == this.unitNumber &&
          other.clientName == this.clientName &&
          other.inspectorName == this.inspectorName &&
          other.developerName == this.developerName &&
          other.contactNumber == this.contactNumber &&
          other.inspectionDate == this.inspectionDate &&
          other.reportMetadataJson == this.reportMetadataJson &&
          other.inspectionNote == this.inspectionNote &&
          other.commercialMode == this.commercialMode &&
          other.selectedAiLevel == this.selectedAiLevel &&
          other.autoAnalyseEnabled == this.autoAnalyseEnabled &&
          other.projectDeveloperName == this.projectDeveloperName);
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
  final Value<String?> ownerUid;
  final Value<String> aiReviewState;
  final Value<String?> propertyTitle;
  final Value<String?> propertyAddress;
  final Value<String?> projectName;
  final Value<String?> blockTower;
  final Value<String?> unitNumber;
  final Value<String?> clientName;
  final Value<String?> inspectorName;
  final Value<String?> developerName;
  final Value<String?> contactNumber;
  final Value<DateTime?> inspectionDate;
  final Value<String?> reportMetadataJson;
  final Value<String?> inspectionNote;
  final Value<String?> commercialMode;
  final Value<String?> selectedAiLevel;
  final Value<bool> autoAnalyseEnabled;
  final Value<String?> projectDeveloperName;
  final Value<int> rowid;
  const InspectionSessionRowsCompanion({
    this.id = const Value.absent(),
    this.industry = const Value.absent(),
    this.assetTypeId = const Value.absent(),
    this.status = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.ownerUid = const Value.absent(),
    this.aiReviewState = const Value.absent(),
    this.propertyTitle = const Value.absent(),
    this.propertyAddress = const Value.absent(),
    this.projectName = const Value.absent(),
    this.blockTower = const Value.absent(),
    this.unitNumber = const Value.absent(),
    this.clientName = const Value.absent(),
    this.inspectorName = const Value.absent(),
    this.developerName = const Value.absent(),
    this.contactNumber = const Value.absent(),
    this.inspectionDate = const Value.absent(),
    this.reportMetadataJson = const Value.absent(),
    this.inspectionNote = const Value.absent(),
    this.commercialMode = const Value.absent(),
    this.selectedAiLevel = const Value.absent(),
    this.autoAnalyseEnabled = const Value.absent(),
    this.projectDeveloperName = const Value.absent(),
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
    this.ownerUid = const Value.absent(),
    this.aiReviewState = const Value.absent(),
    this.propertyTitle = const Value.absent(),
    this.propertyAddress = const Value.absent(),
    this.projectName = const Value.absent(),
    this.blockTower = const Value.absent(),
    this.unitNumber = const Value.absent(),
    this.clientName = const Value.absent(),
    this.inspectorName = const Value.absent(),
    this.developerName = const Value.absent(),
    this.contactNumber = const Value.absent(),
    this.inspectionDate = const Value.absent(),
    this.reportMetadataJson = const Value.absent(),
    this.inspectionNote = const Value.absent(),
    this.commercialMode = const Value.absent(),
    this.selectedAiLevel = const Value.absent(),
    this.autoAnalyseEnabled = const Value.absent(),
    this.projectDeveloperName = const Value.absent(),
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
    Expression<String>? ownerUid,
    Expression<String>? aiReviewState,
    Expression<String>? propertyTitle,
    Expression<String>? propertyAddress,
    Expression<String>? projectName,
    Expression<String>? blockTower,
    Expression<String>? unitNumber,
    Expression<String>? clientName,
    Expression<String>? inspectorName,
    Expression<String>? developerName,
    Expression<String>? contactNumber,
    Expression<DateTime>? inspectionDate,
    Expression<String>? reportMetadataJson,
    Expression<String>? inspectionNote,
    Expression<String>? commercialMode,
    Expression<String>? selectedAiLevel,
    Expression<bool>? autoAnalyseEnabled,
    Expression<String>? projectDeveloperName,
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
      if (ownerUid != null) 'owner_uid': ownerUid,
      if (aiReviewState != null) 'ai_review_state': aiReviewState,
      if (propertyTitle != null) 'property_title': propertyTitle,
      if (propertyAddress != null) 'property_address': propertyAddress,
      if (projectName != null) 'project_name': projectName,
      if (blockTower != null) 'block_tower': blockTower,
      if (unitNumber != null) 'unit_number': unitNumber,
      if (clientName != null) 'client_name': clientName,
      if (inspectorName != null) 'inspector_name': inspectorName,
      if (developerName != null) 'developer_name': developerName,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (inspectionDate != null) 'inspection_date': inspectionDate,
      if (reportMetadataJson != null)
        'report_metadata_json': reportMetadataJson,
      if (inspectionNote != null) 'inspection_note': inspectionNote,
      if (commercialMode != null) 'commercial_mode': commercialMode,
      if (selectedAiLevel != null) 'selected_ai_level': selectedAiLevel,
      if (autoAnalyseEnabled != null)
        'auto_analyse_enabled': autoAnalyseEnabled,
      if (projectDeveloperName != null)
        'project_developer_name': projectDeveloperName,
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
    Value<String?>? ownerUid,
    Value<String>? aiReviewState,
    Value<String?>? propertyTitle,
    Value<String?>? propertyAddress,
    Value<String?>? projectName,
    Value<String?>? blockTower,
    Value<String?>? unitNumber,
    Value<String?>? clientName,
    Value<String?>? inspectorName,
    Value<String?>? developerName,
    Value<String?>? contactNumber,
    Value<DateTime?>? inspectionDate,
    Value<String?>? reportMetadataJson,
    Value<String?>? inspectionNote,
    Value<String?>? commercialMode,
    Value<String?>? selectedAiLevel,
    Value<bool>? autoAnalyseEnabled,
    Value<String?>? projectDeveloperName,
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
      ownerUid: ownerUid ?? this.ownerUid,
      aiReviewState: aiReviewState ?? this.aiReviewState,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      projectName: projectName ?? this.projectName,
      blockTower: blockTower ?? this.blockTower,
      unitNumber: unitNumber ?? this.unitNumber,
      clientName: clientName ?? this.clientName,
      inspectorName: inspectorName ?? this.inspectorName,
      developerName: developerName ?? this.developerName,
      contactNumber: contactNumber ?? this.contactNumber,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      reportMetadataJson: reportMetadataJson ?? this.reportMetadataJson,
      inspectionNote: inspectionNote ?? this.inspectionNote,
      commercialMode: commercialMode ?? this.commercialMode,
      selectedAiLevel: selectedAiLevel ?? this.selectedAiLevel,
      autoAnalyseEnabled: autoAnalyseEnabled ?? this.autoAnalyseEnabled,
      projectDeveloperName: projectDeveloperName ?? this.projectDeveloperName,
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
    if (ownerUid.present) {
      map['owner_uid'] = Variable<String>(ownerUid.value);
    }
    if (aiReviewState.present) {
      map['ai_review_state'] = Variable<String>(aiReviewState.value);
    }
    if (propertyTitle.present) {
      map['property_title'] = Variable<String>(propertyTitle.value);
    }
    if (propertyAddress.present) {
      map['property_address'] = Variable<String>(propertyAddress.value);
    }
    if (projectName.present) {
      map['project_name'] = Variable<String>(projectName.value);
    }
    if (blockTower.present) {
      map['block_tower'] = Variable<String>(blockTower.value);
    }
    if (unitNumber.present) {
      map['unit_number'] = Variable<String>(unitNumber.value);
    }
    if (clientName.present) {
      map['client_name'] = Variable<String>(clientName.value);
    }
    if (inspectorName.present) {
      map['inspector_name'] = Variable<String>(inspectorName.value);
    }
    if (developerName.present) {
      map['developer_name'] = Variable<String>(developerName.value);
    }
    if (contactNumber.present) {
      map['contact_number'] = Variable<String>(contactNumber.value);
    }
    if (inspectionDate.present) {
      map['inspection_date'] = Variable<DateTime>(inspectionDate.value);
    }
    if (reportMetadataJson.present) {
      map['report_metadata_json'] = Variable<String>(reportMetadataJson.value);
    }
    if (inspectionNote.present) {
      map['inspection_note'] = Variable<String>(inspectionNote.value);
    }
    if (commercialMode.present) {
      map['commercial_mode'] = Variable<String>(commercialMode.value);
    }
    if (selectedAiLevel.present) {
      map['selected_ai_level'] = Variable<String>(selectedAiLevel.value);
    }
    if (autoAnalyseEnabled.present) {
      map['auto_analyse_enabled'] = Variable<bool>(autoAnalyseEnabled.value);
    }
    if (projectDeveloperName.present) {
      map['project_developer_name'] = Variable<String>(
        projectDeveloperName.value,
      );
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
          ..write('ownerUid: $ownerUid, ')
          ..write('aiReviewState: $aiReviewState, ')
          ..write('propertyTitle: $propertyTitle, ')
          ..write('propertyAddress: $propertyAddress, ')
          ..write('projectName: $projectName, ')
          ..write('blockTower: $blockTower, ')
          ..write('unitNumber: $unitNumber, ')
          ..write('clientName: $clientName, ')
          ..write('inspectorName: $inspectorName, ')
          ..write('developerName: $developerName, ')
          ..write('contactNumber: $contactNumber, ')
          ..write('inspectionDate: $inspectionDate, ')
          ..write('reportMetadataJson: $reportMetadataJson, ')
          ..write('inspectionNote: $inspectionNote, ')
          ..write('commercialMode: $commercialMode, ')
          ..write('selectedAiLevel: $selectedAiLevel, ')
          ..write('autoAnalyseEnabled: $autoAnalyseEnabled, ')
          ..write('projectDeveloperName: $projectDeveloperName, ')
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
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    note,
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
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
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
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
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

  /// An optional, contextual note about this area (added in schema v8)
  /// — see `Section.note`.
  final String? note;
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
    this.note,
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
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
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
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
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
      note: serializer.fromJson<String?>(json['note']),
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
      'note': serializer.toJson<String?>(note),
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
    Value<String?> note = const Value.absent(),
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
    note: note.present ? note.value : this.note,
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
      note: data.note.present ? data.note.value : this.note,
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
          ..write('updatedAt: $updatedAt, ')
          ..write('note: $note')
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
    note,
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
          other.updatedAt == this.updatedAt &&
          other.note == this.note);
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
  final Value<String?> note;
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
    this.note = const Value.absent(),
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
    this.note = const Value.absent(),
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
    Expression<String>? note,
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
      if (note != null) 'note': note,
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
    Value<String?>? note,
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
      note: note ?? this.note,
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
    if (note.present) {
      map['note'] = Variable<String>(note.value);
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
          ..write('note: $note, ')
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
  static const VerificationMeta _aiStatusMeta = const VerificationMeta(
    'aiStatus',
  );
  @override
  late final GeneratedColumn<String> aiStatus = GeneratedColumn<String>(
    'ai_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('notQueued'),
  );
  static const VerificationMeta _aiAttemptKeyMeta = const VerificationMeta(
    'aiAttemptKey',
  );
  @override
  late final GeneratedColumn<String> aiAttemptKey = GeneratedColumn<String>(
    'ai_attempt_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiAttemptLevelMeta = const VerificationMeta(
    'aiAttemptLevel',
  );
  @override
  late final GeneratedColumn<String> aiAttemptLevel = GeneratedColumn<String>(
    'ai_attempt_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiAttemptSubmittedAtMeta =
      const VerificationMeta('aiAttemptSubmittedAt');
  @override
  late final GeneratedColumn<DateTime> aiAttemptSubmittedAt =
      GeneratedColumn<DateTime>(
        'ai_attempt_submitted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _captureBatchIdMeta = const VerificationMeta(
    'captureBatchId',
  );
  @override
  late final GeneratedColumn<String> captureBatchId = GeneratedColumn<String>(
    'capture_batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    aiStatus,
    aiAttemptKey,
    aiAttemptLevel,
    aiAttemptSubmittedAt,
    captureBatchId,
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
    if (data.containsKey('ai_status')) {
      context.handle(
        _aiStatusMeta,
        aiStatus.isAcceptableOrUnknown(data['ai_status']!, _aiStatusMeta),
      );
    }
    if (data.containsKey('ai_attempt_key')) {
      context.handle(
        _aiAttemptKeyMeta,
        aiAttemptKey.isAcceptableOrUnknown(
          data['ai_attempt_key']!,
          _aiAttemptKeyMeta,
        ),
      );
    }
    if (data.containsKey('ai_attempt_level')) {
      context.handle(
        _aiAttemptLevelMeta,
        aiAttemptLevel.isAcceptableOrUnknown(
          data['ai_attempt_level']!,
          _aiAttemptLevelMeta,
        ),
      );
    }
    if (data.containsKey('ai_attempt_submitted_at')) {
      context.handle(
        _aiAttemptSubmittedAtMeta,
        aiAttemptSubmittedAt.isAcceptableOrUnknown(
          data['ai_attempt_submitted_at']!,
          _aiAttemptSubmittedAtMeta,
        ),
      );
    }
    if (data.containsKey('capture_batch_id')) {
      context.handle(
        _captureBatchIdMeta,
        captureBatchId.isAcceptableOrUnknown(
          data['capture_batch_id']!,
          _captureBatchIdMeta,
        ),
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
      aiStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_status'],
      )!,
      aiAttemptKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_attempt_key'],
      ),
      aiAttemptLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_attempt_level'],
      ),
      aiAttemptSubmittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ai_attempt_submitted_at'],
      ),
      captureBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_batch_id'],
      ),
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

  /// `''` means "not set" (camera-first finding) — see the class doc
  /// comment for why this is an empty string rather than SQL NULL:
  /// relaxing an existing NOT NULL column's constraint isn't something
  /// Drift/SQLite's `ALTER TABLE` supports without a full table
  /// rebuild, so nullability is handled at the application layer
  /// instead (`DriftInspectionRepository` maps `''` <-> `null`) — zero
  /// schema risk to the column that already holds every legacy
  /// finding's real element id.
  final String elementId;
  final String? componentId;
  final String? description;
  final String? notes;
  final String status;

  /// The per-finding AI processing pipeline state (added in schema v6)
  /// — see `AiFindingStatus`. Defaults to `notQueued`, which is also
  /// the correct value for every finding that existed before this
  /// column did.
  final String aiStatus;

  /// The outstanding AI analysis request's idempotency key, level, and
  /// most recent submission time (added in schema v11) — see
  /// `AiAnalysisAttempt`. All three are null when no request may still
  /// be unresolved, which is also the correct value for every finding
  /// that existed before these columns did.
  final String? aiAttemptKey;
  final String? aiAttemptLevel;
  final DateTime? aiAttemptSubmittedAt;

  /// Shared by findings saved from one multi-photo gallery pick (added
  /// in schema v14) — a visual grouping only; each finding is still its
  /// own finding. Null for single captures and every older finding.
  final String? captureBatchId;
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
    required this.aiStatus,
    this.aiAttemptKey,
    this.aiAttemptLevel,
    this.aiAttemptSubmittedAt,
    this.captureBatchId,
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
    map['ai_status'] = Variable<String>(aiStatus);
    if (!nullToAbsent || aiAttemptKey != null) {
      map['ai_attempt_key'] = Variable<String>(aiAttemptKey);
    }
    if (!nullToAbsent || aiAttemptLevel != null) {
      map['ai_attempt_level'] = Variable<String>(aiAttemptLevel);
    }
    if (!nullToAbsent || aiAttemptSubmittedAt != null) {
      map['ai_attempt_submitted_at'] = Variable<DateTime>(aiAttemptSubmittedAt);
    }
    if (!nullToAbsent || captureBatchId != null) {
      map['capture_batch_id'] = Variable<String>(captureBatchId);
    }
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
      aiStatus: Value(aiStatus),
      aiAttemptKey: aiAttemptKey == null && nullToAbsent
          ? const Value.absent()
          : Value(aiAttemptKey),
      aiAttemptLevel: aiAttemptLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(aiAttemptLevel),
      aiAttemptSubmittedAt: aiAttemptSubmittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(aiAttemptSubmittedAt),
      captureBatchId: captureBatchId == null && nullToAbsent
          ? const Value.absent()
          : Value(captureBatchId),
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
      aiStatus: serializer.fromJson<String>(json['aiStatus']),
      aiAttemptKey: serializer.fromJson<String?>(json['aiAttemptKey']),
      aiAttemptLevel: serializer.fromJson<String?>(json['aiAttemptLevel']),
      aiAttemptSubmittedAt: serializer.fromJson<DateTime?>(
        json['aiAttemptSubmittedAt'],
      ),
      captureBatchId: serializer.fromJson<String?>(json['captureBatchId']),
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
      'aiStatus': serializer.toJson<String>(aiStatus),
      'aiAttemptKey': serializer.toJson<String?>(aiAttemptKey),
      'aiAttemptLevel': serializer.toJson<String?>(aiAttemptLevel),
      'aiAttemptSubmittedAt': serializer.toJson<DateTime?>(
        aiAttemptSubmittedAt,
      ),
      'captureBatchId': serializer.toJson<String?>(captureBatchId),
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
    String? aiStatus,
    Value<String?> aiAttemptKey = const Value.absent(),
    Value<String?> aiAttemptLevel = const Value.absent(),
    Value<DateTime?> aiAttemptSubmittedAt = const Value.absent(),
    Value<String?> captureBatchId = const Value.absent(),
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
    aiStatus: aiStatus ?? this.aiStatus,
    aiAttemptKey: aiAttemptKey.present ? aiAttemptKey.value : this.aiAttemptKey,
    aiAttemptLevel: aiAttemptLevel.present
        ? aiAttemptLevel.value
        : this.aiAttemptLevel,
    aiAttemptSubmittedAt: aiAttemptSubmittedAt.present
        ? aiAttemptSubmittedAt.value
        : this.aiAttemptSubmittedAt,
    captureBatchId: captureBatchId.present
        ? captureBatchId.value
        : this.captureBatchId,
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
      aiStatus: data.aiStatus.present ? data.aiStatus.value : this.aiStatus,
      aiAttemptKey: data.aiAttemptKey.present
          ? data.aiAttemptKey.value
          : this.aiAttemptKey,
      aiAttemptLevel: data.aiAttemptLevel.present
          ? data.aiAttemptLevel.value
          : this.aiAttemptLevel,
      aiAttemptSubmittedAt: data.aiAttemptSubmittedAt.present
          ? data.aiAttemptSubmittedAt.value
          : this.aiAttemptSubmittedAt,
      captureBatchId: data.captureBatchId.present
          ? data.captureBatchId.value
          : this.captureBatchId,
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
          ..write('aiStatus: $aiStatus, ')
          ..write('aiAttemptKey: $aiAttemptKey, ')
          ..write('aiAttemptLevel: $aiAttemptLevel, ')
          ..write('aiAttemptSubmittedAt: $aiAttemptSubmittedAt, ')
          ..write('captureBatchId: $captureBatchId, ')
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
    aiStatus,
    aiAttemptKey,
    aiAttemptLevel,
    aiAttemptSubmittedAt,
    captureBatchId,
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
          other.aiStatus == this.aiStatus &&
          other.aiAttemptKey == this.aiAttemptKey &&
          other.aiAttemptLevel == this.aiAttemptLevel &&
          other.aiAttemptSubmittedAt == this.aiAttemptSubmittedAt &&
          other.captureBatchId == this.captureBatchId &&
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
  final Value<String> aiStatus;
  final Value<String?> aiAttemptKey;
  final Value<String?> aiAttemptLevel;
  final Value<DateTime?> aiAttemptSubmittedAt;
  final Value<String?> captureBatchId;
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
    this.aiStatus = const Value.absent(),
    this.aiAttemptKey = const Value.absent(),
    this.aiAttemptLevel = const Value.absent(),
    this.aiAttemptSubmittedAt = const Value.absent(),
    this.captureBatchId = const Value.absent(),
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
    this.aiStatus = const Value.absent(),
    this.aiAttemptKey = const Value.absent(),
    this.aiAttemptLevel = const Value.absent(),
    this.aiAttemptSubmittedAt = const Value.absent(),
    this.captureBatchId = const Value.absent(),
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
    Expression<String>? aiStatus,
    Expression<String>? aiAttemptKey,
    Expression<String>? aiAttemptLevel,
    Expression<DateTime>? aiAttemptSubmittedAt,
    Expression<String>? captureBatchId,
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
      if (aiStatus != null) 'ai_status': aiStatus,
      if (aiAttemptKey != null) 'ai_attempt_key': aiAttemptKey,
      if (aiAttemptLevel != null) 'ai_attempt_level': aiAttemptLevel,
      if (aiAttemptSubmittedAt != null)
        'ai_attempt_submitted_at': aiAttemptSubmittedAt,
      if (captureBatchId != null) 'capture_batch_id': captureBatchId,
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
    Value<String>? aiStatus,
    Value<String?>? aiAttemptKey,
    Value<String?>? aiAttemptLevel,
    Value<DateTime?>? aiAttemptSubmittedAt,
    Value<String?>? captureBatchId,
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
      aiStatus: aiStatus ?? this.aiStatus,
      aiAttemptKey: aiAttemptKey ?? this.aiAttemptKey,
      aiAttemptLevel: aiAttemptLevel ?? this.aiAttemptLevel,
      aiAttemptSubmittedAt: aiAttemptSubmittedAt ?? this.aiAttemptSubmittedAt,
      captureBatchId: captureBatchId ?? this.captureBatchId,
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
    if (aiStatus.present) {
      map['ai_status'] = Variable<String>(aiStatus.value);
    }
    if (aiAttemptKey.present) {
      map['ai_attempt_key'] = Variable<String>(aiAttemptKey.value);
    }
    if (aiAttemptLevel.present) {
      map['ai_attempt_level'] = Variable<String>(aiAttemptLevel.value);
    }
    if (aiAttemptSubmittedAt.present) {
      map['ai_attempt_submitted_at'] = Variable<DateTime>(
        aiAttemptSubmittedAt.value,
      );
    }
    if (captureBatchId.present) {
      map['capture_batch_id'] = Variable<String>(captureBatchId.value);
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
          ..write('aiStatus: $aiStatus, ')
          ..write('aiAttemptKey: $aiAttemptKey, ')
          ..write('aiAttemptLevel: $aiAttemptLevel, ')
          ..write('aiAttemptSubmittedAt: $aiAttemptSubmittedAt, ')
          ..write('captureBatchId: $captureBatchId, ')
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
  static const VerificationMeta _storagePathMeta = const VerificationMeta(
    'storagePath',
  );
  @override
  late final GeneratedColumn<String> storagePath = GeneratedColumn<String>(
    'storage_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotatedFilePathMeta = const VerificationMeta(
    'annotatedFilePath',
  );
  @override
  late final GeneratedColumn<String> annotatedFilePath =
      GeneratedColumn<String>(
        'annotated_file_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
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
    storagePath,
    annotatedFilePath,
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
    if (data.containsKey('storage_path')) {
      context.handle(
        _storagePathMeta,
        storagePath.isAcceptableOrUnknown(
          data['storage_path']!,
          _storagePathMeta,
        ),
      );
    }
    if (data.containsKey('annotated_file_path')) {
      context.handle(
        _annotatedFilePathMeta,
        annotatedFilePath.isAcceptableOrUnknown(
          data['annotated_file_path']!,
          _annotatedFilePathMeta,
        ),
      );
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
      storagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_path'],
      ),
      annotatedFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotated_file_path'],
      ),
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

  /// Where this file lives in cloud storage once uploaded (added in
  /// schema v2). Null until the first successful upload.
  final String? storagePath;

  /// Local path of the inspector's marked-up copy (added in schema v12)
  /// — see `Evidence.annotatedFilePath`. The original at [filePath] is
  /// never overwritten. Null for every pre-existing photo.
  final String? annotatedFilePath;
  const EvidenceRow({
    required this.id,
    required this.findingId,
    required this.filePath,
    required this.mediaType,
    required this.source,
    this.caption,
    required this.syncStatus,
    required this.createdAt,
    this.storagePath,
    this.annotatedFilePath,
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
    if (!nullToAbsent || storagePath != null) {
      map['storage_path'] = Variable<String>(storagePath);
    }
    if (!nullToAbsent || annotatedFilePath != null) {
      map['annotated_file_path'] = Variable<String>(annotatedFilePath);
    }
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
      storagePath: storagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(storagePath),
      annotatedFilePath: annotatedFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(annotatedFilePath),
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
      storagePath: serializer.fromJson<String?>(json['storagePath']),
      annotatedFilePath: serializer.fromJson<String?>(
        json['annotatedFilePath'],
      ),
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
      'storagePath': serializer.toJson<String?>(storagePath),
      'annotatedFilePath': serializer.toJson<String?>(annotatedFilePath),
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
    Value<String?> storagePath = const Value.absent(),
    Value<String?> annotatedFilePath = const Value.absent(),
  }) => EvidenceRow(
    id: id ?? this.id,
    findingId: findingId ?? this.findingId,
    filePath: filePath ?? this.filePath,
    mediaType: mediaType ?? this.mediaType,
    source: source ?? this.source,
    caption: caption.present ? caption.value : this.caption,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    storagePath: storagePath.present ? storagePath.value : this.storagePath,
    annotatedFilePath: annotatedFilePath.present
        ? annotatedFilePath.value
        : this.annotatedFilePath,
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
      storagePath: data.storagePath.present
          ? data.storagePath.value
          : this.storagePath,
      annotatedFilePath: data.annotatedFilePath.present
          ? data.annotatedFilePath.value
          : this.annotatedFilePath,
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
          ..write('createdAt: $createdAt, ')
          ..write('storagePath: $storagePath, ')
          ..write('annotatedFilePath: $annotatedFilePath')
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
    storagePath,
    annotatedFilePath,
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
          other.createdAt == this.createdAt &&
          other.storagePath == this.storagePath &&
          other.annotatedFilePath == this.annotatedFilePath);
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
  final Value<String?> storagePath;
  final Value<String?> annotatedFilePath;
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
    this.storagePath = const Value.absent(),
    this.annotatedFilePath = const Value.absent(),
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
    this.storagePath = const Value.absent(),
    this.annotatedFilePath = const Value.absent(),
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
    Expression<String>? storagePath,
    Expression<String>? annotatedFilePath,
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
      if (storagePath != null) 'storage_path': storagePath,
      if (annotatedFilePath != null) 'annotated_file_path': annotatedFilePath,
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
    Value<String?>? storagePath,
    Value<String?>? annotatedFilePath,
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
      storagePath: storagePath ?? this.storagePath,
      annotatedFilePath: annotatedFilePath ?? this.annotatedFilePath,
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
    if (storagePath.present) {
      map['storage_path'] = Variable<String>(storagePath.value);
    }
    if (annotatedFilePath.present) {
      map['annotated_file_path'] = Variable<String>(annotatedFilePath.value);
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
          ..write('storagePath: $storagePath, ')
          ..write('annotatedFilePath: $annotatedFilePath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiSuggestionRowsTable extends AiSuggestionRows
    with TableInfo<$AiSuggestionRowsTable, AiSuggestionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiSuggestionRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _suggestedElementIdMeta =
      const VerificationMeta('suggestedElementId');
  @override
  late final GeneratedColumn<String> suggestedElementId =
      GeneratedColumn<String>(
        'suggested_element_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedComponentIdMeta =
      const VerificationMeta('suggestedComponentId');
  @override
  late final GeneratedColumn<String> suggestedComponentId =
      GeneratedColumn<String>(
        'suggested_component_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedDefectTypeMeta =
      const VerificationMeta('suggestedDefectType');
  @override
  late final GeneratedColumn<String> suggestedDefectType =
      GeneratedColumn<String>(
        'suggested_defect_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedRecommendationMeta =
      const VerificationMeta('suggestedRecommendation');
  @override
  late final GeneratedColumn<String> suggestedRecommendation =
      GeneratedColumn<String>(
        'suggested_recommendation',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedNotesMeta = const VerificationMeta(
    'suggestedNotes',
  );
  @override
  late final GeneratedColumn<String> suggestedNotes = GeneratedColumn<String>(
    'suggested_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finalElementIdMeta = const VerificationMeta(
    'finalElementId',
  );
  @override
  late final GeneratedColumn<String> finalElementId = GeneratedColumn<String>(
    'final_element_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finalComponentIdMeta = const VerificationMeta(
    'finalComponentId',
  );
  @override
  late final GeneratedColumn<String> finalComponentId = GeneratedColumn<String>(
    'final_component_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finalDefectTypeMeta = const VerificationMeta(
    'finalDefectType',
  );
  @override
  late final GeneratedColumn<String> finalDefectType = GeneratedColumn<String>(
    'final_defect_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finalRecommendationMeta =
      const VerificationMeta('finalRecommendation');
  @override
  late final GeneratedColumn<String> finalRecommendation =
      GeneratedColumn<String>(
        'final_recommendation',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalNotesMeta = const VerificationMeta(
    'finalNotes',
  );
  @override
  late final GeneratedColumn<String> finalNotes = GeneratedColumn<String>(
    'final_notes',
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
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
    'reviewed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suggestedCatalogueEntryIdMeta =
      const VerificationMeta('suggestedCatalogueEntryId');
  @override
  late final GeneratedColumn<String> suggestedCatalogueEntryId =
      GeneratedColumn<String>(
        'suggested_catalogue_entry_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedConfidenceMeta =
      const VerificationMeta('suggestedConfidence');
  @override
  late final GeneratedColumn<double> suggestedConfidence =
      GeneratedColumn<double>(
        'suggested_confidence',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedShortReasonMeta =
      const VerificationMeta('suggestedShortReason');
  @override
  late final GeneratedColumn<String> suggestedShortReason =
      GeneratedColumn<String>(
        'suggested_short_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedCandidateEntryIdsMeta =
      const VerificationMeta('suggestedCandidateEntryIds');
  @override
  late final GeneratedColumn<String> suggestedCandidateEntryIds =
      GeneratedColumn<String>(
        'suggested_candidate_entry_ids',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalCatalogueEntryIdMeta =
      const VerificationMeta('finalCatalogueEntryId');
  @override
  late final GeneratedColumn<String> finalCatalogueEntryId =
      GeneratedColumn<String>(
        'final_catalogue_entry_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _suggestedDefectTermMeta =
      const VerificationMeta('suggestedDefectTerm');
  @override
  late final GeneratedColumn<String> suggestedDefectTerm =
      GeneratedColumn<String>(
        'suggested_defect_term',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    findingId,
    suggestedElementId,
    suggestedComponentId,
    suggestedDefectType,
    suggestedRecommendation,
    suggestedNotes,
    finalElementId,
    finalComponentId,
    finalDefectType,
    finalRecommendation,
    finalNotes,
    status,
    providerId,
    generatedAt,
    reviewedAt,
    suggestedCatalogueEntryId,
    suggestedConfidence,
    suggestedShortReason,
    suggestedCandidateEntryIds,
    finalCatalogueEntryId,
    suggestedDefectTerm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_suggestion_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiSuggestionRow> instance, {
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
    if (data.containsKey('finding_id')) {
      context.handle(
        _findingIdMeta,
        findingId.isAcceptableOrUnknown(data['finding_id']!, _findingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_findingIdMeta);
    }
    if (data.containsKey('suggested_element_id')) {
      context.handle(
        _suggestedElementIdMeta,
        suggestedElementId.isAcceptableOrUnknown(
          data['suggested_element_id']!,
          _suggestedElementIdMeta,
        ),
      );
    }
    if (data.containsKey('suggested_component_id')) {
      context.handle(
        _suggestedComponentIdMeta,
        suggestedComponentId.isAcceptableOrUnknown(
          data['suggested_component_id']!,
          _suggestedComponentIdMeta,
        ),
      );
    }
    if (data.containsKey('suggested_defect_type')) {
      context.handle(
        _suggestedDefectTypeMeta,
        suggestedDefectType.isAcceptableOrUnknown(
          data['suggested_defect_type']!,
          _suggestedDefectTypeMeta,
        ),
      );
    }
    if (data.containsKey('suggested_recommendation')) {
      context.handle(
        _suggestedRecommendationMeta,
        suggestedRecommendation.isAcceptableOrUnknown(
          data['suggested_recommendation']!,
          _suggestedRecommendationMeta,
        ),
      );
    }
    if (data.containsKey('suggested_notes')) {
      context.handle(
        _suggestedNotesMeta,
        suggestedNotes.isAcceptableOrUnknown(
          data['suggested_notes']!,
          _suggestedNotesMeta,
        ),
      );
    }
    if (data.containsKey('final_element_id')) {
      context.handle(
        _finalElementIdMeta,
        finalElementId.isAcceptableOrUnknown(
          data['final_element_id']!,
          _finalElementIdMeta,
        ),
      );
    }
    if (data.containsKey('final_component_id')) {
      context.handle(
        _finalComponentIdMeta,
        finalComponentId.isAcceptableOrUnknown(
          data['final_component_id']!,
          _finalComponentIdMeta,
        ),
      );
    }
    if (data.containsKey('final_defect_type')) {
      context.handle(
        _finalDefectTypeMeta,
        finalDefectType.isAcceptableOrUnknown(
          data['final_defect_type']!,
          _finalDefectTypeMeta,
        ),
      );
    }
    if (data.containsKey('final_recommendation')) {
      context.handle(
        _finalRecommendationMeta,
        finalRecommendation.isAcceptableOrUnknown(
          data['final_recommendation']!,
          _finalRecommendationMeta,
        ),
      );
    }
    if (data.containsKey('final_notes')) {
      context.handle(
        _finalNotesMeta,
        finalNotes.isAcceptableOrUnknown(data['final_notes']!, _finalNotesMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    }
    if (data.containsKey('suggested_catalogue_entry_id')) {
      context.handle(
        _suggestedCatalogueEntryIdMeta,
        suggestedCatalogueEntryId.isAcceptableOrUnknown(
          data['suggested_catalogue_entry_id']!,
          _suggestedCatalogueEntryIdMeta,
        ),
      );
    }
    if (data.containsKey('suggested_confidence')) {
      context.handle(
        _suggestedConfidenceMeta,
        suggestedConfidence.isAcceptableOrUnknown(
          data['suggested_confidence']!,
          _suggestedConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('suggested_short_reason')) {
      context.handle(
        _suggestedShortReasonMeta,
        suggestedShortReason.isAcceptableOrUnknown(
          data['suggested_short_reason']!,
          _suggestedShortReasonMeta,
        ),
      );
    }
    if (data.containsKey('suggested_candidate_entry_ids')) {
      context.handle(
        _suggestedCandidateEntryIdsMeta,
        suggestedCandidateEntryIds.isAcceptableOrUnknown(
          data['suggested_candidate_entry_ids']!,
          _suggestedCandidateEntryIdsMeta,
        ),
      );
    }
    if (data.containsKey('final_catalogue_entry_id')) {
      context.handle(
        _finalCatalogueEntryIdMeta,
        finalCatalogueEntryId.isAcceptableOrUnknown(
          data['final_catalogue_entry_id']!,
          _finalCatalogueEntryIdMeta,
        ),
      );
    }
    if (data.containsKey('suggested_defect_term')) {
      context.handle(
        _suggestedDefectTermMeta,
        suggestedDefectTerm.isAcceptableOrUnknown(
          data['suggested_defect_term']!,
          _suggestedDefectTermMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiSuggestionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiSuggestionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      findingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finding_id'],
      )!,
      suggestedElementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_element_id'],
      ),
      suggestedComponentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_component_id'],
      ),
      suggestedDefectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_defect_type'],
      ),
      suggestedRecommendation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_recommendation'],
      ),
      suggestedNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_notes'],
      ),
      finalElementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_element_id'],
      ),
      finalComponentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_component_id'],
      ),
      finalDefectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_defect_type'],
      ),
      finalRecommendation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_recommendation'],
      ),
      finalNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_notes'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reviewed_at'],
      ),
      suggestedCatalogueEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_catalogue_entry_id'],
      ),
      suggestedConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}suggested_confidence'],
      ),
      suggestedShortReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_short_reason'],
      ),
      suggestedCandidateEntryIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_candidate_entry_ids'],
      ),
      finalCatalogueEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_catalogue_entry_id'],
      ),
      suggestedDefectTerm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_defect_term'],
      ),
    );
  }

  @override
  $AiSuggestionRowsTable createAlias(String alias) {
    return $AiSuggestionRowsTable(attachedDatabase, alias);
  }
}

class AiSuggestionRow extends DataClass implements Insertable<AiSuggestionRow> {
  final String id;
  final String sessionId;
  final String findingId;
  final String? suggestedElementId;
  final String? suggestedComponentId;
  final String? suggestedDefectType;
  final String? suggestedRecommendation;
  final String? suggestedNotes;
  final String? finalElementId;
  final String? finalComponentId;
  final String? finalDefectType;
  final String? finalRecommendation;
  final String? finalNotes;
  final String status;
  final String providerId;
  final DateTime generatedAt;
  final DateTime? reviewedAt;

  /// The controlled catalogue entry id AI selected (added in schema
  /// v6) — null if AI could not confidently classify. See
  /// `DefectCatalogue`/`AiSuggestion.suggestedCatalogueEntryId`.
  final String? suggestedCatalogueEntryId;
  final double? suggestedConfidence;
  final String? suggestedShortReason;

  /// JSON-encoded `List<String>` of ranked alternative catalogue entry
  /// ids (added in schema v6) — empty/absent means no alternates.
  final String? suggestedCandidateEntryIds;

  /// The inspector-approved/corrected catalogue entry id (added in
  /// schema v6) — see `AiSuggestion.finalCatalogueEntryId` for why an
  /// empty string (not SQL NULL) means "reviewed, explicitly left
  /// unresolved".
  final String? finalCatalogueEntryId;

  /// The AI's ONE concrete defect within a multi-defect catalogue
  /// entry's wording (added in schema v14) — see `defectTermsFor`.
  final String? suggestedDefectTerm;
  const AiSuggestionRow({
    required this.id,
    required this.sessionId,
    required this.findingId,
    this.suggestedElementId,
    this.suggestedComponentId,
    this.suggestedDefectType,
    this.suggestedRecommendation,
    this.suggestedNotes,
    this.finalElementId,
    this.finalComponentId,
    this.finalDefectType,
    this.finalRecommendation,
    this.finalNotes,
    required this.status,
    required this.providerId,
    required this.generatedAt,
    this.reviewedAt,
    this.suggestedCatalogueEntryId,
    this.suggestedConfidence,
    this.suggestedShortReason,
    this.suggestedCandidateEntryIds,
    this.finalCatalogueEntryId,
    this.suggestedDefectTerm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['finding_id'] = Variable<String>(findingId);
    if (!nullToAbsent || suggestedElementId != null) {
      map['suggested_element_id'] = Variable<String>(suggestedElementId);
    }
    if (!nullToAbsent || suggestedComponentId != null) {
      map['suggested_component_id'] = Variable<String>(suggestedComponentId);
    }
    if (!nullToAbsent || suggestedDefectType != null) {
      map['suggested_defect_type'] = Variable<String>(suggestedDefectType);
    }
    if (!nullToAbsent || suggestedRecommendation != null) {
      map['suggested_recommendation'] = Variable<String>(
        suggestedRecommendation,
      );
    }
    if (!nullToAbsent || suggestedNotes != null) {
      map['suggested_notes'] = Variable<String>(suggestedNotes);
    }
    if (!nullToAbsent || finalElementId != null) {
      map['final_element_id'] = Variable<String>(finalElementId);
    }
    if (!nullToAbsent || finalComponentId != null) {
      map['final_component_id'] = Variable<String>(finalComponentId);
    }
    if (!nullToAbsent || finalDefectType != null) {
      map['final_defect_type'] = Variable<String>(finalDefectType);
    }
    if (!nullToAbsent || finalRecommendation != null) {
      map['final_recommendation'] = Variable<String>(finalRecommendation);
    }
    if (!nullToAbsent || finalNotes != null) {
      map['final_notes'] = Variable<String>(finalNotes);
    }
    map['status'] = Variable<String>(status);
    map['provider_id'] = Variable<String>(providerId);
    map['generated_at'] = Variable<DateTime>(generatedAt);
    if (!nullToAbsent || reviewedAt != null) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    }
    if (!nullToAbsent || suggestedCatalogueEntryId != null) {
      map['suggested_catalogue_entry_id'] = Variable<String>(
        suggestedCatalogueEntryId,
      );
    }
    if (!nullToAbsent || suggestedConfidence != null) {
      map['suggested_confidence'] = Variable<double>(suggestedConfidence);
    }
    if (!nullToAbsent || suggestedShortReason != null) {
      map['suggested_short_reason'] = Variable<String>(suggestedShortReason);
    }
    if (!nullToAbsent || suggestedCandidateEntryIds != null) {
      map['suggested_candidate_entry_ids'] = Variable<String>(
        suggestedCandidateEntryIds,
      );
    }
    if (!nullToAbsent || finalCatalogueEntryId != null) {
      map['final_catalogue_entry_id'] = Variable<String>(finalCatalogueEntryId);
    }
    if (!nullToAbsent || suggestedDefectTerm != null) {
      map['suggested_defect_term'] = Variable<String>(suggestedDefectTerm);
    }
    return map;
  }

  AiSuggestionRowsCompanion toCompanion(bool nullToAbsent) {
    return AiSuggestionRowsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      findingId: Value(findingId),
      suggestedElementId: suggestedElementId == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedElementId),
      suggestedComponentId: suggestedComponentId == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedComponentId),
      suggestedDefectType: suggestedDefectType == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedDefectType),
      suggestedRecommendation: suggestedRecommendation == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedRecommendation),
      suggestedNotes: suggestedNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedNotes),
      finalElementId: finalElementId == null && nullToAbsent
          ? const Value.absent()
          : Value(finalElementId),
      finalComponentId: finalComponentId == null && nullToAbsent
          ? const Value.absent()
          : Value(finalComponentId),
      finalDefectType: finalDefectType == null && nullToAbsent
          ? const Value.absent()
          : Value(finalDefectType),
      finalRecommendation: finalRecommendation == null && nullToAbsent
          ? const Value.absent()
          : Value(finalRecommendation),
      finalNotes: finalNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(finalNotes),
      status: Value(status),
      providerId: Value(providerId),
      generatedAt: Value(generatedAt),
      reviewedAt: reviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedAt),
      suggestedCatalogueEntryId:
          suggestedCatalogueEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedCatalogueEntryId),
      suggestedConfidence: suggestedConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedConfidence),
      suggestedShortReason: suggestedShortReason == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedShortReason),
      suggestedCandidateEntryIds:
          suggestedCandidateEntryIds == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedCandidateEntryIds),
      finalCatalogueEntryId: finalCatalogueEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(finalCatalogueEntryId),
      suggestedDefectTerm: suggestedDefectTerm == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedDefectTerm),
    );
  }

  factory AiSuggestionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiSuggestionRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      findingId: serializer.fromJson<String>(json['findingId']),
      suggestedElementId: serializer.fromJson<String?>(
        json['suggestedElementId'],
      ),
      suggestedComponentId: serializer.fromJson<String?>(
        json['suggestedComponentId'],
      ),
      suggestedDefectType: serializer.fromJson<String?>(
        json['suggestedDefectType'],
      ),
      suggestedRecommendation: serializer.fromJson<String?>(
        json['suggestedRecommendation'],
      ),
      suggestedNotes: serializer.fromJson<String?>(json['suggestedNotes']),
      finalElementId: serializer.fromJson<String?>(json['finalElementId']),
      finalComponentId: serializer.fromJson<String?>(json['finalComponentId']),
      finalDefectType: serializer.fromJson<String?>(json['finalDefectType']),
      finalRecommendation: serializer.fromJson<String?>(
        json['finalRecommendation'],
      ),
      finalNotes: serializer.fromJson<String?>(json['finalNotes']),
      status: serializer.fromJson<String>(json['status']),
      providerId: serializer.fromJson<String>(json['providerId']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      reviewedAt: serializer.fromJson<DateTime?>(json['reviewedAt']),
      suggestedCatalogueEntryId: serializer.fromJson<String?>(
        json['suggestedCatalogueEntryId'],
      ),
      suggestedConfidence: serializer.fromJson<double?>(
        json['suggestedConfidence'],
      ),
      suggestedShortReason: serializer.fromJson<String?>(
        json['suggestedShortReason'],
      ),
      suggestedCandidateEntryIds: serializer.fromJson<String?>(
        json['suggestedCandidateEntryIds'],
      ),
      finalCatalogueEntryId: serializer.fromJson<String?>(
        json['finalCatalogueEntryId'],
      ),
      suggestedDefectTerm: serializer.fromJson<String?>(
        json['suggestedDefectTerm'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'findingId': serializer.toJson<String>(findingId),
      'suggestedElementId': serializer.toJson<String?>(suggestedElementId),
      'suggestedComponentId': serializer.toJson<String?>(suggestedComponentId),
      'suggestedDefectType': serializer.toJson<String?>(suggestedDefectType),
      'suggestedRecommendation': serializer.toJson<String?>(
        suggestedRecommendation,
      ),
      'suggestedNotes': serializer.toJson<String?>(suggestedNotes),
      'finalElementId': serializer.toJson<String?>(finalElementId),
      'finalComponentId': serializer.toJson<String?>(finalComponentId),
      'finalDefectType': serializer.toJson<String?>(finalDefectType),
      'finalRecommendation': serializer.toJson<String?>(finalRecommendation),
      'finalNotes': serializer.toJson<String?>(finalNotes),
      'status': serializer.toJson<String>(status),
      'providerId': serializer.toJson<String>(providerId),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'reviewedAt': serializer.toJson<DateTime?>(reviewedAt),
      'suggestedCatalogueEntryId': serializer.toJson<String?>(
        suggestedCatalogueEntryId,
      ),
      'suggestedConfidence': serializer.toJson<double?>(suggestedConfidence),
      'suggestedShortReason': serializer.toJson<String?>(suggestedShortReason),
      'suggestedCandidateEntryIds': serializer.toJson<String?>(
        suggestedCandidateEntryIds,
      ),
      'finalCatalogueEntryId': serializer.toJson<String?>(
        finalCatalogueEntryId,
      ),
      'suggestedDefectTerm': serializer.toJson<String?>(suggestedDefectTerm),
    };
  }

  AiSuggestionRow copyWith({
    String? id,
    String? sessionId,
    String? findingId,
    Value<String?> suggestedElementId = const Value.absent(),
    Value<String?> suggestedComponentId = const Value.absent(),
    Value<String?> suggestedDefectType = const Value.absent(),
    Value<String?> suggestedRecommendation = const Value.absent(),
    Value<String?> suggestedNotes = const Value.absent(),
    Value<String?> finalElementId = const Value.absent(),
    Value<String?> finalComponentId = const Value.absent(),
    Value<String?> finalDefectType = const Value.absent(),
    Value<String?> finalRecommendation = const Value.absent(),
    Value<String?> finalNotes = const Value.absent(),
    String? status,
    String? providerId,
    DateTime? generatedAt,
    Value<DateTime?> reviewedAt = const Value.absent(),
    Value<String?> suggestedCatalogueEntryId = const Value.absent(),
    Value<double?> suggestedConfidence = const Value.absent(),
    Value<String?> suggestedShortReason = const Value.absent(),
    Value<String?> suggestedCandidateEntryIds = const Value.absent(),
    Value<String?> finalCatalogueEntryId = const Value.absent(),
    Value<String?> suggestedDefectTerm = const Value.absent(),
  }) => AiSuggestionRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    findingId: findingId ?? this.findingId,
    suggestedElementId: suggestedElementId.present
        ? suggestedElementId.value
        : this.suggestedElementId,
    suggestedComponentId: suggestedComponentId.present
        ? suggestedComponentId.value
        : this.suggestedComponentId,
    suggestedDefectType: suggestedDefectType.present
        ? suggestedDefectType.value
        : this.suggestedDefectType,
    suggestedRecommendation: suggestedRecommendation.present
        ? suggestedRecommendation.value
        : this.suggestedRecommendation,
    suggestedNotes: suggestedNotes.present
        ? suggestedNotes.value
        : this.suggestedNotes,
    finalElementId: finalElementId.present
        ? finalElementId.value
        : this.finalElementId,
    finalComponentId: finalComponentId.present
        ? finalComponentId.value
        : this.finalComponentId,
    finalDefectType: finalDefectType.present
        ? finalDefectType.value
        : this.finalDefectType,
    finalRecommendation: finalRecommendation.present
        ? finalRecommendation.value
        : this.finalRecommendation,
    finalNotes: finalNotes.present ? finalNotes.value : this.finalNotes,
    status: status ?? this.status,
    providerId: providerId ?? this.providerId,
    generatedAt: generatedAt ?? this.generatedAt,
    reviewedAt: reviewedAt.present ? reviewedAt.value : this.reviewedAt,
    suggestedCatalogueEntryId: suggestedCatalogueEntryId.present
        ? suggestedCatalogueEntryId.value
        : this.suggestedCatalogueEntryId,
    suggestedConfidence: suggestedConfidence.present
        ? suggestedConfidence.value
        : this.suggestedConfidence,
    suggestedShortReason: suggestedShortReason.present
        ? suggestedShortReason.value
        : this.suggestedShortReason,
    suggestedCandidateEntryIds: suggestedCandidateEntryIds.present
        ? suggestedCandidateEntryIds.value
        : this.suggestedCandidateEntryIds,
    finalCatalogueEntryId: finalCatalogueEntryId.present
        ? finalCatalogueEntryId.value
        : this.finalCatalogueEntryId,
    suggestedDefectTerm: suggestedDefectTerm.present
        ? suggestedDefectTerm.value
        : this.suggestedDefectTerm,
  );
  AiSuggestionRow copyWithCompanion(AiSuggestionRowsCompanion data) {
    return AiSuggestionRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      findingId: data.findingId.present ? data.findingId.value : this.findingId,
      suggestedElementId: data.suggestedElementId.present
          ? data.suggestedElementId.value
          : this.suggestedElementId,
      suggestedComponentId: data.suggestedComponentId.present
          ? data.suggestedComponentId.value
          : this.suggestedComponentId,
      suggestedDefectType: data.suggestedDefectType.present
          ? data.suggestedDefectType.value
          : this.suggestedDefectType,
      suggestedRecommendation: data.suggestedRecommendation.present
          ? data.suggestedRecommendation.value
          : this.suggestedRecommendation,
      suggestedNotes: data.suggestedNotes.present
          ? data.suggestedNotes.value
          : this.suggestedNotes,
      finalElementId: data.finalElementId.present
          ? data.finalElementId.value
          : this.finalElementId,
      finalComponentId: data.finalComponentId.present
          ? data.finalComponentId.value
          : this.finalComponentId,
      finalDefectType: data.finalDefectType.present
          ? data.finalDefectType.value
          : this.finalDefectType,
      finalRecommendation: data.finalRecommendation.present
          ? data.finalRecommendation.value
          : this.finalRecommendation,
      finalNotes: data.finalNotes.present
          ? data.finalNotes.value
          : this.finalNotes,
      status: data.status.present ? data.status.value : this.status,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      suggestedCatalogueEntryId: data.suggestedCatalogueEntryId.present
          ? data.suggestedCatalogueEntryId.value
          : this.suggestedCatalogueEntryId,
      suggestedConfidence: data.suggestedConfidence.present
          ? data.suggestedConfidence.value
          : this.suggestedConfidence,
      suggestedShortReason: data.suggestedShortReason.present
          ? data.suggestedShortReason.value
          : this.suggestedShortReason,
      suggestedCandidateEntryIds: data.suggestedCandidateEntryIds.present
          ? data.suggestedCandidateEntryIds.value
          : this.suggestedCandidateEntryIds,
      finalCatalogueEntryId: data.finalCatalogueEntryId.present
          ? data.finalCatalogueEntryId.value
          : this.finalCatalogueEntryId,
      suggestedDefectTerm: data.suggestedDefectTerm.present
          ? data.suggestedDefectTerm.value
          : this.suggestedDefectTerm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiSuggestionRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('findingId: $findingId, ')
          ..write('suggestedElementId: $suggestedElementId, ')
          ..write('suggestedComponentId: $suggestedComponentId, ')
          ..write('suggestedDefectType: $suggestedDefectType, ')
          ..write('suggestedRecommendation: $suggestedRecommendation, ')
          ..write('suggestedNotes: $suggestedNotes, ')
          ..write('finalElementId: $finalElementId, ')
          ..write('finalComponentId: $finalComponentId, ')
          ..write('finalDefectType: $finalDefectType, ')
          ..write('finalRecommendation: $finalRecommendation, ')
          ..write('finalNotes: $finalNotes, ')
          ..write('status: $status, ')
          ..write('providerId: $providerId, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('suggestedCatalogueEntryId: $suggestedCatalogueEntryId, ')
          ..write('suggestedConfidence: $suggestedConfidence, ')
          ..write('suggestedShortReason: $suggestedShortReason, ')
          ..write('suggestedCandidateEntryIds: $suggestedCandidateEntryIds, ')
          ..write('finalCatalogueEntryId: $finalCatalogueEntryId, ')
          ..write('suggestedDefectTerm: $suggestedDefectTerm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    sessionId,
    findingId,
    suggestedElementId,
    suggestedComponentId,
    suggestedDefectType,
    suggestedRecommendation,
    suggestedNotes,
    finalElementId,
    finalComponentId,
    finalDefectType,
    finalRecommendation,
    finalNotes,
    status,
    providerId,
    generatedAt,
    reviewedAt,
    suggestedCatalogueEntryId,
    suggestedConfidence,
    suggestedShortReason,
    suggestedCandidateEntryIds,
    finalCatalogueEntryId,
    suggestedDefectTerm,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiSuggestionRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.findingId == this.findingId &&
          other.suggestedElementId == this.suggestedElementId &&
          other.suggestedComponentId == this.suggestedComponentId &&
          other.suggestedDefectType == this.suggestedDefectType &&
          other.suggestedRecommendation == this.suggestedRecommendation &&
          other.suggestedNotes == this.suggestedNotes &&
          other.finalElementId == this.finalElementId &&
          other.finalComponentId == this.finalComponentId &&
          other.finalDefectType == this.finalDefectType &&
          other.finalRecommendation == this.finalRecommendation &&
          other.finalNotes == this.finalNotes &&
          other.status == this.status &&
          other.providerId == this.providerId &&
          other.generatedAt == this.generatedAt &&
          other.reviewedAt == this.reviewedAt &&
          other.suggestedCatalogueEntryId == this.suggestedCatalogueEntryId &&
          other.suggestedConfidence == this.suggestedConfidence &&
          other.suggestedShortReason == this.suggestedShortReason &&
          other.suggestedCandidateEntryIds == this.suggestedCandidateEntryIds &&
          other.finalCatalogueEntryId == this.finalCatalogueEntryId &&
          other.suggestedDefectTerm == this.suggestedDefectTerm);
}

class AiSuggestionRowsCompanion extends UpdateCompanion<AiSuggestionRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> findingId;
  final Value<String?> suggestedElementId;
  final Value<String?> suggestedComponentId;
  final Value<String?> suggestedDefectType;
  final Value<String?> suggestedRecommendation;
  final Value<String?> suggestedNotes;
  final Value<String?> finalElementId;
  final Value<String?> finalComponentId;
  final Value<String?> finalDefectType;
  final Value<String?> finalRecommendation;
  final Value<String?> finalNotes;
  final Value<String> status;
  final Value<String> providerId;
  final Value<DateTime> generatedAt;
  final Value<DateTime?> reviewedAt;
  final Value<String?> suggestedCatalogueEntryId;
  final Value<double?> suggestedConfidence;
  final Value<String?> suggestedShortReason;
  final Value<String?> suggestedCandidateEntryIds;
  final Value<String?> finalCatalogueEntryId;
  final Value<String?> suggestedDefectTerm;
  final Value<int> rowid;
  const AiSuggestionRowsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.findingId = const Value.absent(),
    this.suggestedElementId = const Value.absent(),
    this.suggestedComponentId = const Value.absent(),
    this.suggestedDefectType = const Value.absent(),
    this.suggestedRecommendation = const Value.absent(),
    this.suggestedNotes = const Value.absent(),
    this.finalElementId = const Value.absent(),
    this.finalComponentId = const Value.absent(),
    this.finalDefectType = const Value.absent(),
    this.finalRecommendation = const Value.absent(),
    this.finalNotes = const Value.absent(),
    this.status = const Value.absent(),
    this.providerId = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.suggestedCatalogueEntryId = const Value.absent(),
    this.suggestedConfidence = const Value.absent(),
    this.suggestedShortReason = const Value.absent(),
    this.suggestedCandidateEntryIds = const Value.absent(),
    this.finalCatalogueEntryId = const Value.absent(),
    this.suggestedDefectTerm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiSuggestionRowsCompanion.insert({
    required String id,
    required String sessionId,
    required String findingId,
    this.suggestedElementId = const Value.absent(),
    this.suggestedComponentId = const Value.absent(),
    this.suggestedDefectType = const Value.absent(),
    this.suggestedRecommendation = const Value.absent(),
    this.suggestedNotes = const Value.absent(),
    this.finalElementId = const Value.absent(),
    this.finalComponentId = const Value.absent(),
    this.finalDefectType = const Value.absent(),
    this.finalRecommendation = const Value.absent(),
    this.finalNotes = const Value.absent(),
    this.status = const Value.absent(),
    required String providerId,
    required DateTime generatedAt,
    this.reviewedAt = const Value.absent(),
    this.suggestedCatalogueEntryId = const Value.absent(),
    this.suggestedConfidence = const Value.absent(),
    this.suggestedShortReason = const Value.absent(),
    this.suggestedCandidateEntryIds = const Value.absent(),
    this.finalCatalogueEntryId = const Value.absent(),
    this.suggestedDefectTerm = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       findingId = Value(findingId),
       providerId = Value(providerId),
       generatedAt = Value(generatedAt);
  static Insertable<AiSuggestionRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? findingId,
    Expression<String>? suggestedElementId,
    Expression<String>? suggestedComponentId,
    Expression<String>? suggestedDefectType,
    Expression<String>? suggestedRecommendation,
    Expression<String>? suggestedNotes,
    Expression<String>? finalElementId,
    Expression<String>? finalComponentId,
    Expression<String>? finalDefectType,
    Expression<String>? finalRecommendation,
    Expression<String>? finalNotes,
    Expression<String>? status,
    Expression<String>? providerId,
    Expression<DateTime>? generatedAt,
    Expression<DateTime>? reviewedAt,
    Expression<String>? suggestedCatalogueEntryId,
    Expression<double>? suggestedConfidence,
    Expression<String>? suggestedShortReason,
    Expression<String>? suggestedCandidateEntryIds,
    Expression<String>? finalCatalogueEntryId,
    Expression<String>? suggestedDefectTerm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (findingId != null) 'finding_id': findingId,
      if (suggestedElementId != null)
        'suggested_element_id': suggestedElementId,
      if (suggestedComponentId != null)
        'suggested_component_id': suggestedComponentId,
      if (suggestedDefectType != null)
        'suggested_defect_type': suggestedDefectType,
      if (suggestedRecommendation != null)
        'suggested_recommendation': suggestedRecommendation,
      if (suggestedNotes != null) 'suggested_notes': suggestedNotes,
      if (finalElementId != null) 'final_element_id': finalElementId,
      if (finalComponentId != null) 'final_component_id': finalComponentId,
      if (finalDefectType != null) 'final_defect_type': finalDefectType,
      if (finalRecommendation != null)
        'final_recommendation': finalRecommendation,
      if (finalNotes != null) 'final_notes': finalNotes,
      if (status != null) 'status': status,
      if (providerId != null) 'provider_id': providerId,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (suggestedCatalogueEntryId != null)
        'suggested_catalogue_entry_id': suggestedCatalogueEntryId,
      if (suggestedConfidence != null)
        'suggested_confidence': suggestedConfidence,
      if (suggestedShortReason != null)
        'suggested_short_reason': suggestedShortReason,
      if (suggestedCandidateEntryIds != null)
        'suggested_candidate_entry_ids': suggestedCandidateEntryIds,
      if (finalCatalogueEntryId != null)
        'final_catalogue_entry_id': finalCatalogueEntryId,
      if (suggestedDefectTerm != null)
        'suggested_defect_term': suggestedDefectTerm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiSuggestionRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? findingId,
    Value<String?>? suggestedElementId,
    Value<String?>? suggestedComponentId,
    Value<String?>? suggestedDefectType,
    Value<String?>? suggestedRecommendation,
    Value<String?>? suggestedNotes,
    Value<String?>? finalElementId,
    Value<String?>? finalComponentId,
    Value<String?>? finalDefectType,
    Value<String?>? finalRecommendation,
    Value<String?>? finalNotes,
    Value<String>? status,
    Value<String>? providerId,
    Value<DateTime>? generatedAt,
    Value<DateTime?>? reviewedAt,
    Value<String?>? suggestedCatalogueEntryId,
    Value<double?>? suggestedConfidence,
    Value<String?>? suggestedShortReason,
    Value<String?>? suggestedCandidateEntryIds,
    Value<String?>? finalCatalogueEntryId,
    Value<String?>? suggestedDefectTerm,
    Value<int>? rowid,
  }) {
    return AiSuggestionRowsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      findingId: findingId ?? this.findingId,
      suggestedElementId: suggestedElementId ?? this.suggestedElementId,
      suggestedComponentId: suggestedComponentId ?? this.suggestedComponentId,
      suggestedDefectType: suggestedDefectType ?? this.suggestedDefectType,
      suggestedRecommendation:
          suggestedRecommendation ?? this.suggestedRecommendation,
      suggestedNotes: suggestedNotes ?? this.suggestedNotes,
      finalElementId: finalElementId ?? this.finalElementId,
      finalComponentId: finalComponentId ?? this.finalComponentId,
      finalDefectType: finalDefectType ?? this.finalDefectType,
      finalRecommendation: finalRecommendation ?? this.finalRecommendation,
      finalNotes: finalNotes ?? this.finalNotes,
      status: status ?? this.status,
      providerId: providerId ?? this.providerId,
      generatedAt: generatedAt ?? this.generatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      suggestedCatalogueEntryId:
          suggestedCatalogueEntryId ?? this.suggestedCatalogueEntryId,
      suggestedConfidence: suggestedConfidence ?? this.suggestedConfidence,
      suggestedShortReason: suggestedShortReason ?? this.suggestedShortReason,
      suggestedCandidateEntryIds:
          suggestedCandidateEntryIds ?? this.suggestedCandidateEntryIds,
      finalCatalogueEntryId:
          finalCatalogueEntryId ?? this.finalCatalogueEntryId,
      suggestedDefectTerm: suggestedDefectTerm ?? this.suggestedDefectTerm,
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
    if (findingId.present) {
      map['finding_id'] = Variable<String>(findingId.value);
    }
    if (suggestedElementId.present) {
      map['suggested_element_id'] = Variable<String>(suggestedElementId.value);
    }
    if (suggestedComponentId.present) {
      map['suggested_component_id'] = Variable<String>(
        suggestedComponentId.value,
      );
    }
    if (suggestedDefectType.present) {
      map['suggested_defect_type'] = Variable<String>(
        suggestedDefectType.value,
      );
    }
    if (suggestedRecommendation.present) {
      map['suggested_recommendation'] = Variable<String>(
        suggestedRecommendation.value,
      );
    }
    if (suggestedNotes.present) {
      map['suggested_notes'] = Variable<String>(suggestedNotes.value);
    }
    if (finalElementId.present) {
      map['final_element_id'] = Variable<String>(finalElementId.value);
    }
    if (finalComponentId.present) {
      map['final_component_id'] = Variable<String>(finalComponentId.value);
    }
    if (finalDefectType.present) {
      map['final_defect_type'] = Variable<String>(finalDefectType.value);
    }
    if (finalRecommendation.present) {
      map['final_recommendation'] = Variable<String>(finalRecommendation.value);
    }
    if (finalNotes.present) {
      map['final_notes'] = Variable<String>(finalNotes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (suggestedCatalogueEntryId.present) {
      map['suggested_catalogue_entry_id'] = Variable<String>(
        suggestedCatalogueEntryId.value,
      );
    }
    if (suggestedConfidence.present) {
      map['suggested_confidence'] = Variable<double>(suggestedConfidence.value);
    }
    if (suggestedShortReason.present) {
      map['suggested_short_reason'] = Variable<String>(
        suggestedShortReason.value,
      );
    }
    if (suggestedCandidateEntryIds.present) {
      map['suggested_candidate_entry_ids'] = Variable<String>(
        suggestedCandidateEntryIds.value,
      );
    }
    if (finalCatalogueEntryId.present) {
      map['final_catalogue_entry_id'] = Variable<String>(
        finalCatalogueEntryId.value,
      );
    }
    if (suggestedDefectTerm.present) {
      map['suggested_defect_term'] = Variable<String>(
        suggestedDefectTerm.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiSuggestionRowsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('findingId: $findingId, ')
          ..write('suggestedElementId: $suggestedElementId, ')
          ..write('suggestedComponentId: $suggestedComponentId, ')
          ..write('suggestedDefectType: $suggestedDefectType, ')
          ..write('suggestedRecommendation: $suggestedRecommendation, ')
          ..write('suggestedNotes: $suggestedNotes, ')
          ..write('finalElementId: $finalElementId, ')
          ..write('finalComponentId: $finalComponentId, ')
          ..write('finalDefectType: $finalDefectType, ')
          ..write('finalRecommendation: $finalRecommendation, ')
          ..write('finalNotes: $finalNotes, ')
          ..write('status: $status, ')
          ..write('providerId: $providerId, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('suggestedCatalogueEntryId: $suggestedCatalogueEntryId, ')
          ..write('suggestedConfidence: $suggestedConfidence, ')
          ..write('suggestedShortReason: $suggestedShortReason, ')
          ..write('suggestedCandidateEntryIds: $suggestedCandidateEntryIds, ')
          ..write('finalCatalogueEntryId: $finalCatalogueEntryId, ')
          ..write('suggestedDefectTerm: $suggestedDefectTerm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReportRowsTable extends ReportRows
    with TableInfo<$ReportRowsTable, ReportRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUpdatedAtMeta = const VerificationMeta(
    'sourceUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> sourceUpdatedAt =
      GeneratedColumn<DateTime>(
        'source_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
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
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    filePath,
    fileName,
    generatedAt,
    sourceUpdatedAt,
    syncStatus,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'report_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReportRow> instance, {
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
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    if (data.containsKey('source_updated_at')) {
      context.handle(
        _sourceUpdatedAtMeta,
        sourceUpdatedAt.isAcceptableOrUnknown(
          data['source_updated_at']!,
          _sourceUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceUpdatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  ReportRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReportRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
      sourceUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}source_updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $ReportRowsTable createAlias(String alias) {
    return $ReportRowsTable(attachedDatabase, alias);
  }
}

class ReportRow extends DataClass implements Insertable<ReportRow> {
  final String id;
  final String sessionId;
  final String filePath;
  final String fileName;
  final DateTime generatedAt;

  /// Snapshot of the session's `updatedAt` at generation time, used to
  /// detect staleness — see `Report.isStaleRelativeTo`.
  final DateTime sourceUpdatedAt;
  final String syncStatus;

  /// Incremented each time this session's report is regenerated (added
  /// in schema v7) — surfaced to the inspector as "v2", "v3", etc., so
  /// regenerating after inspection data changed is visibly a new
  /// version rather than a silent overwrite. Starts at 1.
  final int version;
  const ReportRow({
    required this.id,
    required this.sessionId,
    required this.filePath,
    required this.fileName,
    required this.generatedAt,
    required this.sourceUpdatedAt,
    required this.syncStatus,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['file_path'] = Variable<String>(filePath);
    map['file_name'] = Variable<String>(fileName);
    map['generated_at'] = Variable<DateTime>(generatedAt);
    map['source_updated_at'] = Variable<DateTime>(sourceUpdatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['version'] = Variable<int>(version);
    return map;
  }

  ReportRowsCompanion toCompanion(bool nullToAbsent) {
    return ReportRowsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      filePath: Value(filePath),
      fileName: Value(fileName),
      generatedAt: Value(generatedAt),
      sourceUpdatedAt: Value(sourceUpdatedAt),
      syncStatus: Value(syncStatus),
      version: Value(version),
    );
  }

  factory ReportRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReportRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      sourceUpdatedAt: serializer.fromJson<DateTime>(json['sourceUpdatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'filePath': serializer.toJson<String>(filePath),
      'fileName': serializer.toJson<String>(fileName),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'sourceUpdatedAt': serializer.toJson<DateTime>(sourceUpdatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'version': serializer.toJson<int>(version),
    };
  }

  ReportRow copyWith({
    String? id,
    String? sessionId,
    String? filePath,
    String? fileName,
    DateTime? generatedAt,
    DateTime? sourceUpdatedAt,
    String? syncStatus,
    int? version,
  }) => ReportRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    filePath: filePath ?? this.filePath,
    fileName: fileName ?? this.fileName,
    generatedAt: generatedAt ?? this.generatedAt,
    sourceUpdatedAt: sourceUpdatedAt ?? this.sourceUpdatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    version: version ?? this.version,
  );
  ReportRow copyWithCompanion(ReportRowsCompanion data) {
    return ReportRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      sourceUpdatedAt: data.sourceUpdatedAt.present
          ? data.sourceUpdatedAt.value
          : this.sourceUpdatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReportRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('sourceUpdatedAt: $sourceUpdatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    filePath,
    fileName,
    generatedAt,
    sourceUpdatedAt,
    syncStatus,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.filePath == this.filePath &&
          other.fileName == this.fileName &&
          other.generatedAt == this.generatedAt &&
          other.sourceUpdatedAt == this.sourceUpdatedAt &&
          other.syncStatus == this.syncStatus &&
          other.version == this.version);
}

class ReportRowsCompanion extends UpdateCompanion<ReportRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> filePath;
  final Value<String> fileName;
  final Value<DateTime> generatedAt;
  final Value<DateTime> sourceUpdatedAt;
  final Value<String> syncStatus;
  final Value<int> version;
  final Value<int> rowid;
  const ReportRowsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.sourceUpdatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReportRowsCompanion.insert({
    required String id,
    required String sessionId,
    required String filePath,
    required String fileName,
    required DateTime generatedAt,
    required DateTime sourceUpdatedAt,
    this.syncStatus = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       filePath = Value(filePath),
       fileName = Value(fileName),
       generatedAt = Value(generatedAt),
       sourceUpdatedAt = Value(sourceUpdatedAt);
  static Insertable<ReportRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? filePath,
    Expression<String>? fileName,
    Expression<DateTime>? generatedAt,
    Expression<DateTime>? sourceUpdatedAt,
    Expression<String>? syncStatus,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (filePath != null) 'file_path': filePath,
      if (fileName != null) 'file_name': fileName,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (sourceUpdatedAt != null) 'source_updated_at': sourceUpdatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReportRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? filePath,
    Value<String>? fileName,
    Value<DateTime>? generatedAt,
    Value<DateTime>? sourceUpdatedAt,
    Value<String>? syncStatus,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return ReportRowsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      generatedAt: generatedAt ?? this.generatedAt,
      sourceUpdatedAt: sourceUpdatedAt ?? this.sourceUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
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
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (sourceUpdatedAt.present) {
      map['source_updated_at'] = Variable<DateTime>(sourceUpdatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReportRowsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('sourceUpdatedAt: $sourceUpdatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfileRowsTable extends UserProfileRows
    with TableInfo<$UserProfileRowsTable, UserProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyNameMeta = const VerificationMeta(
    'companyName',
  );
  @override
  late final GeneratedColumn<String> companyName = GeneratedColumn<String>(
    'company_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inspectorNameMeta = const VerificationMeta(
    'inspectorName',
  );
  @override
  late final GeneratedColumn<String> inspectorName = GeneratedColumn<String>(
    'inspector_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _defaultAiLevelMeta = const VerificationMeta(
    'defaultAiLevel',
  );
  @override
  late final GeneratedColumn<String> defaultAiLevel = GeneratedColumn<String>(
    'default_ai_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyName,
    inspectorName,
    updatedAt,
    defaultAiLevel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_name')) {
      context.handle(
        _companyNameMeta,
        companyName.isAcceptableOrUnknown(
          data['company_name']!,
          _companyNameMeta,
        ),
      );
    }
    if (data.containsKey('inspector_name')) {
      context.handle(
        _inspectorNameMeta,
        inspectorName.isAcceptableOrUnknown(
          data['inspector_name']!,
          _inspectorNameMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('default_ai_level')) {
      context.handle(
        _defaultAiLevelMeta,
        defaultAiLevel.isAcceptableOrUnknown(
          data['default_ai_level']!,
          _defaultAiLevelMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_name'],
      ),
      inspectorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inspector_name'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      defaultAiLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_ai_level'],
      ),
    );
  }

  @override
  $UserProfileRowsTable createAlias(String alias) {
    return $UserProfileRowsTable(attachedDatabase, alias);
  }
}

class UserProfileRow extends DataClass implements Insertable<UserProfileRow> {
  final String id;
  final String? companyName;
  final String? inspectorName;
  final DateTime updatedAt;

  /// The inspector's preferred default AI quality tier for new
  /// inspections (added in schema v9) — see `AiLevel`, `UserProfile.
  /// defaultAiLevel`. Null falls back to the app-wide default.
  final String? defaultAiLevel;
  const UserProfileRow({
    required this.id,
    this.companyName,
    this.inspectorName,
    required this.updatedAt,
    this.defaultAiLevel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || companyName != null) {
      map['company_name'] = Variable<String>(companyName);
    }
    if (!nullToAbsent || inspectorName != null) {
      map['inspector_name'] = Variable<String>(inspectorName);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || defaultAiLevel != null) {
      map['default_ai_level'] = Variable<String>(defaultAiLevel);
    }
    return map;
  }

  UserProfileRowsCompanion toCompanion(bool nullToAbsent) {
    return UserProfileRowsCompanion(
      id: Value(id),
      companyName: companyName == null && nullToAbsent
          ? const Value.absent()
          : Value(companyName),
      inspectorName: inspectorName == null && nullToAbsent
          ? const Value.absent()
          : Value(inspectorName),
      updatedAt: Value(updatedAt),
      defaultAiLevel: defaultAiLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAiLevel),
    );
  }

  factory UserProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileRow(
      id: serializer.fromJson<String>(json['id']),
      companyName: serializer.fromJson<String?>(json['companyName']),
      inspectorName: serializer.fromJson<String?>(json['inspectorName']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      defaultAiLevel: serializer.fromJson<String?>(json['defaultAiLevel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyName': serializer.toJson<String?>(companyName),
      'inspectorName': serializer.toJson<String?>(inspectorName),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'defaultAiLevel': serializer.toJson<String?>(defaultAiLevel),
    };
  }

  UserProfileRow copyWith({
    String? id,
    Value<String?> companyName = const Value.absent(),
    Value<String?> inspectorName = const Value.absent(),
    DateTime? updatedAt,
    Value<String?> defaultAiLevel = const Value.absent(),
  }) => UserProfileRow(
    id: id ?? this.id,
    companyName: companyName.present ? companyName.value : this.companyName,
    inspectorName: inspectorName.present
        ? inspectorName.value
        : this.inspectorName,
    updatedAt: updatedAt ?? this.updatedAt,
    defaultAiLevel: defaultAiLevel.present
        ? defaultAiLevel.value
        : this.defaultAiLevel,
  );
  UserProfileRow copyWithCompanion(UserProfileRowsCompanion data) {
    return UserProfileRow(
      id: data.id.present ? data.id.value : this.id,
      companyName: data.companyName.present
          ? data.companyName.value
          : this.companyName,
      inspectorName: data.inspectorName.present
          ? data.inspectorName.value
          : this.inspectorName,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      defaultAiLevel: data.defaultAiLevel.present
          ? data.defaultAiLevel.value
          : this.defaultAiLevel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileRow(')
          ..write('id: $id, ')
          ..write('companyName: $companyName, ')
          ..write('inspectorName: $inspectorName, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('defaultAiLevel: $defaultAiLevel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, companyName, inspectorName, updatedAt, defaultAiLevel);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileRow &&
          other.id == this.id &&
          other.companyName == this.companyName &&
          other.inspectorName == this.inspectorName &&
          other.updatedAt == this.updatedAt &&
          other.defaultAiLevel == this.defaultAiLevel);
}

class UserProfileRowsCompanion extends UpdateCompanion<UserProfileRow> {
  final Value<String> id;
  final Value<String?> companyName;
  final Value<String?> inspectorName;
  final Value<DateTime> updatedAt;
  final Value<String?> defaultAiLevel;
  final Value<int> rowid;
  const UserProfileRowsCompanion({
    this.id = const Value.absent(),
    this.companyName = const Value.absent(),
    this.inspectorName = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.defaultAiLevel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfileRowsCompanion.insert({
    required String id,
    this.companyName = const Value.absent(),
    this.inspectorName = const Value.absent(),
    required DateTime updatedAt,
    this.defaultAiLevel = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<UserProfileRow> custom({
    Expression<String>? id,
    Expression<String>? companyName,
    Expression<String>? inspectorName,
    Expression<DateTime>? updatedAt,
    Expression<String>? defaultAiLevel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyName != null) 'company_name': companyName,
      if (inspectorName != null) 'inspector_name': inspectorName,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (defaultAiLevel != null) 'default_ai_level': defaultAiLevel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfileRowsCompanion copyWith({
    Value<String>? id,
    Value<String?>? companyName,
    Value<String?>? inspectorName,
    Value<DateTime>? updatedAt,
    Value<String?>? defaultAiLevel,
    Value<int>? rowid,
  }) {
    return UserProfileRowsCompanion(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      inspectorName: inspectorName ?? this.inspectorName,
      updatedAt: updatedAt ?? this.updatedAt,
      defaultAiLevel: defaultAiLevel ?? this.defaultAiLevel,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyName.present) {
      map['company_name'] = Variable<String>(companyName.value);
    }
    if (inspectorName.present) {
      map['inspector_name'] = Variable<String>(inspectorName.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (defaultAiLevel.present) {
      map['default_ai_level'] = Variable<String>(defaultAiLevel.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileRowsCompanion(')
          ..write('id: $id, ')
          ..write('companyName: $companyName, ')
          ..write('inspectorName: $inspectorName, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('defaultAiLevel: $defaultAiLevel, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletCacheRowsTable extends WalletCacheRows
    with TableInfo<$WalletCacheRowsTable, WalletCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletCacheRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceCreditsMeta = const VerificationMeta(
    'balanceCredits',
  );
  @override
  late final GeneratedColumn<int> balanceCredits = GeneratedColumn<int>(
    'balance_credits',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  List<GeneratedColumn> get $columns => [id, balanceCredits, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_cache_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('balance_credits')) {
      context.handle(
        _balanceCreditsMeta,
        balanceCredits.isAcceptableOrUnknown(
          data['balance_credits']!,
          _balanceCreditsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_balanceCreditsMeta);
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
  WalletCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletCacheRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      balanceCredits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_credits'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WalletCacheRowsTable createAlias(String alias) {
    return $WalletCacheRowsTable(attachedDatabase, alias);
  }
}

class WalletCacheRow extends DataClass implements Insertable<WalletCacheRow> {
  final String id;
  final int balanceCredits;
  final DateTime updatedAt;
  const WalletCacheRow({
    required this.id,
    required this.balanceCredits,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['balance_credits'] = Variable<int>(balanceCredits);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WalletCacheRowsCompanion toCompanion(bool nullToAbsent) {
    return WalletCacheRowsCompanion(
      id: Value(id),
      balanceCredits: Value(balanceCredits),
      updatedAt: Value(updatedAt),
    );
  }

  factory WalletCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletCacheRow(
      id: serializer.fromJson<String>(json['id']),
      balanceCredits: serializer.fromJson<int>(json['balanceCredits']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'balanceCredits': serializer.toJson<int>(balanceCredits),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WalletCacheRow copyWith({
    String? id,
    int? balanceCredits,
    DateTime? updatedAt,
  }) => WalletCacheRow(
    id: id ?? this.id,
    balanceCredits: balanceCredits ?? this.balanceCredits,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WalletCacheRow copyWithCompanion(WalletCacheRowsCompanion data) {
    return WalletCacheRow(
      id: data.id.present ? data.id.value : this.id,
      balanceCredits: data.balanceCredits.present
          ? data.balanceCredits.value
          : this.balanceCredits,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletCacheRow(')
          ..write('id: $id, ')
          ..write('balanceCredits: $balanceCredits, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, balanceCredits, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletCacheRow &&
          other.id == this.id &&
          other.balanceCredits == this.balanceCredits &&
          other.updatedAt == this.updatedAt);
}

class WalletCacheRowsCompanion extends UpdateCompanion<WalletCacheRow> {
  final Value<String> id;
  final Value<int> balanceCredits;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WalletCacheRowsCompanion({
    this.id = const Value.absent(),
    this.balanceCredits = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletCacheRowsCompanion.insert({
    required String id,
    required int balanceCredits,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       balanceCredits = Value(balanceCredits),
       updatedAt = Value(updatedAt);
  static Insertable<WalletCacheRow> custom({
    Expression<String>? id,
    Expression<int>? balanceCredits,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (balanceCredits != null) 'balance_credits': balanceCredits,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletCacheRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? balanceCredits,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WalletCacheRowsCompanion(
      id: id ?? this.id,
      balanceCredits: balanceCredits ?? this.balanceCredits,
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
    if (balanceCredits.present) {
      map['balance_credits'] = Variable<int>(balanceCredits.value);
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
    return (StringBuffer('WalletCacheRowsCompanion(')
          ..write('id: $id, ')
          ..write('balanceCredits: $balanceCredits, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AreaCandidateRowsTable extends AreaCandidateRows
    with TableInfo<$AreaCandidateRowsTable, AreaCandidateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AreaCandidateRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawNameMeta = const VerificationMeta(
    'rawName',
  );
  @override
  late final GeneratedColumn<String> rawName = GeneratedColumn<String>(
    'raw_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _propertyTypeMeta = const VerificationMeta(
    'propertyType',
  );
  @override
  late final GeneratedColumn<String> propertyType = GeneratedColumn<String>(
    'property_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _submittedMeta = const VerificationMeta(
    'submitted',
  );
  @override
  late final GeneratedColumn<bool> submitted = GeneratedColumn<bool>(
    'submitted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("submitted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rawName,
    normalizedName,
    propertyType,
    createdAt,
    submitted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'area_candidate_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AreaCandidateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('raw_name')) {
      context.handle(
        _rawNameMeta,
        rawName.isAcceptableOrUnknown(data['raw_name']!, _rawNameMeta),
      );
    } else if (isInserting) {
      context.missing(_rawNameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('property_type')) {
      context.handle(
        _propertyTypeMeta,
        propertyType.isAcceptableOrUnknown(
          data['property_type']!,
          _propertyTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_propertyTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('submitted')) {
      context.handle(
        _submittedMeta,
        submitted.isAcceptableOrUnknown(data['submitted']!, _submittedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AreaCandidateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AreaCandidateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      rawName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      propertyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}property_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      submitted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}submitted'],
      )!,
    );
  }

  @override
  $AreaCandidateRowsTable createAlias(String alias) {
    return $AreaCandidateRowsTable(attachedDatabase, alias);
  }
}

class AreaCandidateRow extends DataClass
    implements Insertable<AreaCandidateRow> {
  final String id;
  final String rawName;
  final String normalizedName;
  final String propertyType;
  final DateTime createdAt;
  final bool submitted;
  const AreaCandidateRow({
    required this.id,
    required this.rawName,
    required this.normalizedName,
    required this.propertyType,
    required this.createdAt,
    required this.submitted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['raw_name'] = Variable<String>(rawName);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['property_type'] = Variable<String>(propertyType);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['submitted'] = Variable<bool>(submitted);
    return map;
  }

  AreaCandidateRowsCompanion toCompanion(bool nullToAbsent) {
    return AreaCandidateRowsCompanion(
      id: Value(id),
      rawName: Value(rawName),
      normalizedName: Value(normalizedName),
      propertyType: Value(propertyType),
      createdAt: Value(createdAt),
      submitted: Value(submitted),
    );
  }

  factory AreaCandidateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AreaCandidateRow(
      id: serializer.fromJson<String>(json['id']),
      rawName: serializer.fromJson<String>(json['rawName']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      propertyType: serializer.fromJson<String>(json['propertyType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      submitted: serializer.fromJson<bool>(json['submitted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'rawName': serializer.toJson<String>(rawName),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'propertyType': serializer.toJson<String>(propertyType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'submitted': serializer.toJson<bool>(submitted),
    };
  }

  AreaCandidateRow copyWith({
    String? id,
    String? rawName,
    String? normalizedName,
    String? propertyType,
    DateTime? createdAt,
    bool? submitted,
  }) => AreaCandidateRow(
    id: id ?? this.id,
    rawName: rawName ?? this.rawName,
    normalizedName: normalizedName ?? this.normalizedName,
    propertyType: propertyType ?? this.propertyType,
    createdAt: createdAt ?? this.createdAt,
    submitted: submitted ?? this.submitted,
  );
  AreaCandidateRow copyWithCompanion(AreaCandidateRowsCompanion data) {
    return AreaCandidateRow(
      id: data.id.present ? data.id.value : this.id,
      rawName: data.rawName.present ? data.rawName.value : this.rawName,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      propertyType: data.propertyType.present
          ? data.propertyType.value
          : this.propertyType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      submitted: data.submitted.present ? data.submitted.value : this.submitted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AreaCandidateRow(')
          ..write('id: $id, ')
          ..write('rawName: $rawName, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('propertyType: $propertyType, ')
          ..write('createdAt: $createdAt, ')
          ..write('submitted: $submitted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    rawName,
    normalizedName,
    propertyType,
    createdAt,
    submitted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AreaCandidateRow &&
          other.id == this.id &&
          other.rawName == this.rawName &&
          other.normalizedName == this.normalizedName &&
          other.propertyType == this.propertyType &&
          other.createdAt == this.createdAt &&
          other.submitted == this.submitted);
}

class AreaCandidateRowsCompanion extends UpdateCompanion<AreaCandidateRow> {
  final Value<String> id;
  final Value<String> rawName;
  final Value<String> normalizedName;
  final Value<String> propertyType;
  final Value<DateTime> createdAt;
  final Value<bool> submitted;
  final Value<int> rowid;
  const AreaCandidateRowsCompanion({
    this.id = const Value.absent(),
    this.rawName = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.propertyType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.submitted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AreaCandidateRowsCompanion.insert({
    required String id,
    required String rawName,
    required String normalizedName,
    required String propertyType,
    required DateTime createdAt,
    this.submitted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       rawName = Value(rawName),
       normalizedName = Value(normalizedName),
       propertyType = Value(propertyType),
       createdAt = Value(createdAt);
  static Insertable<AreaCandidateRow> custom({
    Expression<String>? id,
    Expression<String>? rawName,
    Expression<String>? normalizedName,
    Expression<String>? propertyType,
    Expression<DateTime>? createdAt,
    Expression<bool>? submitted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rawName != null) 'raw_name': rawName,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (propertyType != null) 'property_type': propertyType,
      if (createdAt != null) 'created_at': createdAt,
      if (submitted != null) 'submitted': submitted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AreaCandidateRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? rawName,
    Value<String>? normalizedName,
    Value<String>? propertyType,
    Value<DateTime>? createdAt,
    Value<bool>? submitted,
    Value<int>? rowid,
  }) {
    return AreaCandidateRowsCompanion(
      id: id ?? this.id,
      rawName: rawName ?? this.rawName,
      normalizedName: normalizedName ?? this.normalizedName,
      propertyType: propertyType ?? this.propertyType,
      createdAt: createdAt ?? this.createdAt,
      submitted: submitted ?? this.submitted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rawName.present) {
      map['raw_name'] = Variable<String>(rawName.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (propertyType.present) {
      map['property_type'] = Variable<String>(propertyType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (submitted.present) {
      map['submitted'] = Variable<bool>(submitted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AreaCandidateRowsCompanion(')
          ..write('id: $id, ')
          ..write('rawName: $rawName, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('propertyType: $propertyType, ')
          ..write('createdAt: $createdAt, ')
          ..write('submitted: $submitted, ')
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
  late final $AiSuggestionRowsTable aiSuggestionRows = $AiSuggestionRowsTable(
    this,
  );
  late final $ReportRowsTable reportRows = $ReportRowsTable(this);
  late final $UserProfileRowsTable userProfileRows = $UserProfileRowsTable(
    this,
  );
  late final $WalletCacheRowsTable walletCacheRows = $WalletCacheRowsTable(
    this,
  );
  late final $AreaCandidateRowsTable areaCandidateRows =
      $AreaCandidateRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    inspectionSessionRows,
    sectionRows,
    findingRows,
    evidenceRows,
    aiSuggestionRows,
    reportRows,
    userProfileRows,
    walletCacheRows,
    areaCandidateRows,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'inspection_session_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ai_suggestion_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'finding_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ai_suggestion_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'inspection_session_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('report_rows', kind: UpdateKind.delete)],
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
      Value<String?> ownerUid,
      Value<String> aiReviewState,
      Value<String?> propertyTitle,
      Value<String?> propertyAddress,
      Value<String?> projectName,
      Value<String?> blockTower,
      Value<String?> unitNumber,
      Value<String?> clientName,
      Value<String?> inspectorName,
      Value<String?> developerName,
      Value<String?> contactNumber,
      Value<DateTime?> inspectionDate,
      Value<String?> reportMetadataJson,
      Value<String?> inspectionNote,
      Value<String?> commercialMode,
      Value<String?> selectedAiLevel,
      Value<bool> autoAnalyseEnabled,
      Value<String?> projectDeveloperName,
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
      Value<String?> ownerUid,
      Value<String> aiReviewState,
      Value<String?> propertyTitle,
      Value<String?> propertyAddress,
      Value<String?> projectName,
      Value<String?> blockTower,
      Value<String?> unitNumber,
      Value<String?> clientName,
      Value<String?> inspectorName,
      Value<String?> developerName,
      Value<String?> contactNumber,
      Value<DateTime?> inspectionDate,
      Value<String?> reportMetadataJson,
      Value<String?> inspectionNote,
      Value<String?> commercialMode,
      Value<String?> selectedAiLevel,
      Value<bool> autoAnalyseEnabled,
      Value<String?> projectDeveloperName,
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

  static MultiTypedResultKey<$AiSuggestionRowsTable, List<AiSuggestionRow>>
  _aiSuggestionRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.aiSuggestionRows,
    aliasName: 'inspection_session_rows__id__ai_suggestion_rows__session_id',
  );

  $$AiSuggestionRowsTableProcessedTableManager get aiSuggestionRowsRefs {
    final manager = $$AiSuggestionRowsTableTableManager(
      $_db,
      $_db.aiSuggestionRows,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _aiSuggestionRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReportRowsTable, List<ReportRow>>
  _reportRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reportRows,
    aliasName: 'inspection_session_rows__id__report_rows__session_id',
  );

  $$ReportRowsTableProcessedTableManager get reportRowsRefs {
    final manager = $$ReportRowsTableTableManager(
      $_db,
      $_db.reportRows,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_reportRowsRefsTable($_db));
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

  ColumnFilters<String> get ownerUid => $composableBuilder(
    column: $table.ownerUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiReviewState => $composableBuilder(
    column: $table.aiReviewState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get propertyTitle => $composableBuilder(
    column: $table.propertyTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get propertyAddress => $composableBuilder(
    column: $table.propertyAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectName => $composableBuilder(
    column: $table.projectName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockTower => $composableBuilder(
    column: $table.blockTower,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitNumber => $composableBuilder(
    column: $table.unitNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientName => $composableBuilder(
    column: $table.clientName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inspectorName => $composableBuilder(
    column: $table.inspectorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get developerName => $composableBuilder(
    column: $table.developerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactNumber => $composableBuilder(
    column: $table.contactNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get inspectionDate => $composableBuilder(
    column: $table.inspectionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportMetadataJson => $composableBuilder(
    column: $table.reportMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inspectionNote => $composableBuilder(
    column: $table.inspectionNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commercialMode => $composableBuilder(
    column: $table.commercialMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedAiLevel => $composableBuilder(
    column: $table.selectedAiLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoAnalyseEnabled => $composableBuilder(
    column: $table.autoAnalyseEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectDeveloperName => $composableBuilder(
    column: $table.projectDeveloperName,
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

  Expression<bool> aiSuggestionRowsRefs(
    Expression<bool> Function($$AiSuggestionRowsTableFilterComposer f) f,
  ) {
    final $$AiSuggestionRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiSuggestionRows,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiSuggestionRowsTableFilterComposer(
            $db: $db,
            $table: $db.aiSuggestionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reportRowsRefs(
    Expression<bool> Function($$ReportRowsTableFilterComposer f) f,
  ) {
    final $$ReportRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reportRows,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportRowsTableFilterComposer(
            $db: $db,
            $table: $db.reportRows,
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

  ColumnOrderings<String> get ownerUid => $composableBuilder(
    column: $table.ownerUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiReviewState => $composableBuilder(
    column: $table.aiReviewState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get propertyTitle => $composableBuilder(
    column: $table.propertyTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get propertyAddress => $composableBuilder(
    column: $table.propertyAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectName => $composableBuilder(
    column: $table.projectName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockTower => $composableBuilder(
    column: $table.blockTower,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitNumber => $composableBuilder(
    column: $table.unitNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientName => $composableBuilder(
    column: $table.clientName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inspectorName => $composableBuilder(
    column: $table.inspectorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get developerName => $composableBuilder(
    column: $table.developerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactNumber => $composableBuilder(
    column: $table.contactNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get inspectionDate => $composableBuilder(
    column: $table.inspectionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportMetadataJson => $composableBuilder(
    column: $table.reportMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inspectionNote => $composableBuilder(
    column: $table.inspectionNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commercialMode => $composableBuilder(
    column: $table.commercialMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedAiLevel => $composableBuilder(
    column: $table.selectedAiLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoAnalyseEnabled => $composableBuilder(
    column: $table.autoAnalyseEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectDeveloperName => $composableBuilder(
    column: $table.projectDeveloperName,
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

  GeneratedColumn<String> get ownerUid =>
      $composableBuilder(column: $table.ownerUid, builder: (column) => column);

  GeneratedColumn<String> get aiReviewState => $composableBuilder(
    column: $table.aiReviewState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get propertyTitle => $composableBuilder(
    column: $table.propertyTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get propertyAddress => $composableBuilder(
    column: $table.propertyAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get projectName => $composableBuilder(
    column: $table.projectName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blockTower => $composableBuilder(
    column: $table.blockTower,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitNumber => $composableBuilder(
    column: $table.unitNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientName => $composableBuilder(
    column: $table.clientName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inspectorName => $composableBuilder(
    column: $table.inspectorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get developerName => $composableBuilder(
    column: $table.developerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactNumber => $composableBuilder(
    column: $table.contactNumber,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get inspectionDate => $composableBuilder(
    column: $table.inspectionDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reportMetadataJson => $composableBuilder(
    column: $table.reportMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inspectionNote => $composableBuilder(
    column: $table.inspectionNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commercialMode => $composableBuilder(
    column: $table.commercialMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedAiLevel => $composableBuilder(
    column: $table.selectedAiLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoAnalyseEnabled => $composableBuilder(
    column: $table.autoAnalyseEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get projectDeveloperName => $composableBuilder(
    column: $table.projectDeveloperName,
    builder: (column) => column,
  );

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

  Expression<T> aiSuggestionRowsRefs<T extends Object>(
    Expression<T> Function($$AiSuggestionRowsTableAnnotationComposer a) f,
  ) {
    final $$AiSuggestionRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiSuggestionRows,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiSuggestionRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.aiSuggestionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> reportRowsRefs<T extends Object>(
    Expression<T> Function($$ReportRowsTableAnnotationComposer a) f,
  ) {
    final $$ReportRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reportRows,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.reportRows,
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
          PrefetchHooks Function({
            bool sectionRowsRefs,
            bool findingRowsRefs,
            bool aiSuggestionRowsRefs,
            bool reportRowsRefs,
          })
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
                Value<String?> ownerUid = const Value.absent(),
                Value<String> aiReviewState = const Value.absent(),
                Value<String?> propertyTitle = const Value.absent(),
                Value<String?> propertyAddress = const Value.absent(),
                Value<String?> projectName = const Value.absent(),
                Value<String?> blockTower = const Value.absent(),
                Value<String?> unitNumber = const Value.absent(),
                Value<String?> clientName = const Value.absent(),
                Value<String?> inspectorName = const Value.absent(),
                Value<String?> developerName = const Value.absent(),
                Value<String?> contactNumber = const Value.absent(),
                Value<DateTime?> inspectionDate = const Value.absent(),
                Value<String?> reportMetadataJson = const Value.absent(),
                Value<String?> inspectionNote = const Value.absent(),
                Value<String?> commercialMode = const Value.absent(),
                Value<String?> selectedAiLevel = const Value.absent(),
                Value<bool> autoAnalyseEnabled = const Value.absent(),
                Value<String?> projectDeveloperName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InspectionSessionRowsCompanion(
                id: id,
                industry: industry,
                assetTypeId: assetTypeId,
                status: status,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                ownerUid: ownerUid,
                aiReviewState: aiReviewState,
                propertyTitle: propertyTitle,
                propertyAddress: propertyAddress,
                projectName: projectName,
                blockTower: blockTower,
                unitNumber: unitNumber,
                clientName: clientName,
                inspectorName: inspectorName,
                developerName: developerName,
                contactNumber: contactNumber,
                inspectionDate: inspectionDate,
                reportMetadataJson: reportMetadataJson,
                inspectionNote: inspectionNote,
                commercialMode: commercialMode,
                selectedAiLevel: selectedAiLevel,
                autoAnalyseEnabled: autoAnalyseEnabled,
                projectDeveloperName: projectDeveloperName,
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
                Value<String?> ownerUid = const Value.absent(),
                Value<String> aiReviewState = const Value.absent(),
                Value<String?> propertyTitle = const Value.absent(),
                Value<String?> propertyAddress = const Value.absent(),
                Value<String?> projectName = const Value.absent(),
                Value<String?> blockTower = const Value.absent(),
                Value<String?> unitNumber = const Value.absent(),
                Value<String?> clientName = const Value.absent(),
                Value<String?> inspectorName = const Value.absent(),
                Value<String?> developerName = const Value.absent(),
                Value<String?> contactNumber = const Value.absent(),
                Value<DateTime?> inspectionDate = const Value.absent(),
                Value<String?> reportMetadataJson = const Value.absent(),
                Value<String?> inspectionNote = const Value.absent(),
                Value<String?> commercialMode = const Value.absent(),
                Value<String?> selectedAiLevel = const Value.absent(),
                Value<bool> autoAnalyseEnabled = const Value.absent(),
                Value<String?> projectDeveloperName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InspectionSessionRowsCompanion.insert(
                id: id,
                industry: industry,
                assetTypeId: assetTypeId,
                status: status,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                ownerUid: ownerUid,
                aiReviewState: aiReviewState,
                propertyTitle: propertyTitle,
                propertyAddress: propertyAddress,
                projectName: projectName,
                blockTower: blockTower,
                unitNumber: unitNumber,
                clientName: clientName,
                inspectorName: inspectorName,
                developerName: developerName,
                contactNumber: contactNumber,
                inspectionDate: inspectionDate,
                reportMetadataJson: reportMetadataJson,
                inspectionNote: inspectionNote,
                commercialMode: commercialMode,
                selectedAiLevel: selectedAiLevel,
                autoAnalyseEnabled: autoAnalyseEnabled,
                projectDeveloperName: projectDeveloperName,
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
              ({
                sectionRowsRefs = false,
                findingRowsRefs = false,
                aiSuggestionRowsRefs = false,
                reportRowsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sectionRowsRefs) db.sectionRows,
                    if (findingRowsRefs) db.findingRows,
                    if (aiSuggestionRowsRefs) db.aiSuggestionRows,
                    if (reportRowsRefs) db.reportRows,
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
                      if (aiSuggestionRowsRefs)
                        await $_getPrefetchedData<
                          InspectionSessionRow,
                          $InspectionSessionRowsTable,
                          AiSuggestionRow
                        >(
                          currentTable: table,
                          referencedTable:
                              $$InspectionSessionRowsTableReferences
                                  ._aiSuggestionRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InspectionSessionRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).aiSuggestionRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (reportRowsRefs)
                        await $_getPrefetchedData<
                          InspectionSessionRow,
                          $InspectionSessionRowsTable,
                          ReportRow
                        >(
                          currentTable: table,
                          referencedTable:
                              $$InspectionSessionRowsTableReferences
                                  ._reportRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InspectionSessionRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).reportRowsRefs,
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
      PrefetchHooks Function({
        bool sectionRowsRefs,
        bool findingRowsRefs,
        bool aiSuggestionRowsRefs,
        bool reportRowsRefs,
      })
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
      Value<String?> note,
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
      Value<String?> note,
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

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
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

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

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
                Value<String?> note = const Value.absent(),
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
                note: note,
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
                Value<String?> note = const Value.absent(),
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
                note: note,
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
      Value<String> aiStatus,
      Value<String?> aiAttemptKey,
      Value<String?> aiAttemptLevel,
      Value<DateTime?> aiAttemptSubmittedAt,
      Value<String?> captureBatchId,
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
      Value<String> aiStatus,
      Value<String?> aiAttemptKey,
      Value<String?> aiAttemptLevel,
      Value<DateTime?> aiAttemptSubmittedAt,
      Value<String?> captureBatchId,
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

  static MultiTypedResultKey<$AiSuggestionRowsTable, List<AiSuggestionRow>>
  _aiSuggestionRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.aiSuggestionRows,
    aliasName: 'finding_rows__id__ai_suggestion_rows__finding_id',
  );

  $$AiSuggestionRowsTableProcessedTableManager get aiSuggestionRowsRefs {
    final manager = $$AiSuggestionRowsTableTableManager(
      $_db,
      $_db.aiSuggestionRows,
    ).filter((f) => f.findingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _aiSuggestionRowsRefsTable($_db),
    );
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

  ColumnFilters<String> get aiStatus => $composableBuilder(
    column: $table.aiStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiAttemptKey => $composableBuilder(
    column: $table.aiAttemptKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiAttemptLevel => $composableBuilder(
    column: $table.aiAttemptLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get aiAttemptSubmittedAt => $composableBuilder(
    column: $table.aiAttemptSubmittedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get captureBatchId => $composableBuilder(
    column: $table.captureBatchId,
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

  Expression<bool> aiSuggestionRowsRefs(
    Expression<bool> Function($$AiSuggestionRowsTableFilterComposer f) f,
  ) {
    final $$AiSuggestionRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiSuggestionRows,
      getReferencedColumn: (t) => t.findingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiSuggestionRowsTableFilterComposer(
            $db: $db,
            $table: $db.aiSuggestionRows,
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

  ColumnOrderings<String> get aiStatus => $composableBuilder(
    column: $table.aiStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiAttemptKey => $composableBuilder(
    column: $table.aiAttemptKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiAttemptLevel => $composableBuilder(
    column: $table.aiAttemptLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get aiAttemptSubmittedAt => $composableBuilder(
    column: $table.aiAttemptSubmittedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get captureBatchId => $composableBuilder(
    column: $table.captureBatchId,
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

  GeneratedColumn<String> get aiStatus =>
      $composableBuilder(column: $table.aiStatus, builder: (column) => column);

  GeneratedColumn<String> get aiAttemptKey => $composableBuilder(
    column: $table.aiAttemptKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiAttemptLevel => $composableBuilder(
    column: $table.aiAttemptLevel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get aiAttemptSubmittedAt => $composableBuilder(
    column: $table.aiAttemptSubmittedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get captureBatchId => $composableBuilder(
    column: $table.captureBatchId,
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

  Expression<T> aiSuggestionRowsRefs<T extends Object>(
    Expression<T> Function($$AiSuggestionRowsTableAnnotationComposer a) f,
  ) {
    final $$AiSuggestionRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiSuggestionRows,
      getReferencedColumn: (t) => t.findingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiSuggestionRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.aiSuggestionRows,
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
          PrefetchHooks Function({
            bool sessionId,
            bool evidenceRowsRefs,
            bool aiSuggestionRowsRefs,
          })
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
                Value<String> aiStatus = const Value.absent(),
                Value<String?> aiAttemptKey = const Value.absent(),
                Value<String?> aiAttemptLevel = const Value.absent(),
                Value<DateTime?> aiAttemptSubmittedAt = const Value.absent(),
                Value<String?> captureBatchId = const Value.absent(),
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
                aiStatus: aiStatus,
                aiAttemptKey: aiAttemptKey,
                aiAttemptLevel: aiAttemptLevel,
                aiAttemptSubmittedAt: aiAttemptSubmittedAt,
                captureBatchId: captureBatchId,
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
                Value<String> aiStatus = const Value.absent(),
                Value<String?> aiAttemptKey = const Value.absent(),
                Value<String?> aiAttemptLevel = const Value.absent(),
                Value<DateTime?> aiAttemptSubmittedAt = const Value.absent(),
                Value<String?> captureBatchId = const Value.absent(),
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
                aiStatus: aiStatus,
                aiAttemptKey: aiAttemptKey,
                aiAttemptLevel: aiAttemptLevel,
                aiAttemptSubmittedAt: aiAttemptSubmittedAt,
                captureBatchId: captureBatchId,
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
              ({
                sessionId = false,
                evidenceRowsRefs = false,
                aiSuggestionRowsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (evidenceRowsRefs) db.evidenceRows,
                    if (aiSuggestionRowsRefs) db.aiSuggestionRows,
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
                      if (aiSuggestionRowsRefs)
                        await $_getPrefetchedData<
                          FindingRow,
                          $FindingRowsTable,
                          AiSuggestionRow
                        >(
                          currentTable: table,
                          referencedTable: $$FindingRowsTableReferences
                              ._aiSuggestionRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FindingRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).aiSuggestionRowsRefs,
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
      PrefetchHooks Function({
        bool sessionId,
        bool evidenceRowsRefs,
        bool aiSuggestionRowsRefs,
      })
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
      Value<String?> storagePath,
      Value<String?> annotatedFilePath,
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
      Value<String?> storagePath,
      Value<String?> annotatedFilePath,
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

  ColumnFilters<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotatedFilePath => $composableBuilder(
    column: $table.annotatedFilePath,
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

  ColumnOrderings<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotatedFilePath => $composableBuilder(
    column: $table.annotatedFilePath,
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

  GeneratedColumn<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get annotatedFilePath => $composableBuilder(
    column: $table.annotatedFilePath,
    builder: (column) => column,
  );

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
                Value<String?> storagePath = const Value.absent(),
                Value<String?> annotatedFilePath = const Value.absent(),
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
                storagePath: storagePath,
                annotatedFilePath: annotatedFilePath,
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
                Value<String?> storagePath = const Value.absent(),
                Value<String?> annotatedFilePath = const Value.absent(),
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
                storagePath: storagePath,
                annotatedFilePath: annotatedFilePath,
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
typedef $$AiSuggestionRowsTableCreateCompanionBuilder =
    AiSuggestionRowsCompanion Function({
      required String id,
      required String sessionId,
      required String findingId,
      Value<String?> suggestedElementId,
      Value<String?> suggestedComponentId,
      Value<String?> suggestedDefectType,
      Value<String?> suggestedRecommendation,
      Value<String?> suggestedNotes,
      Value<String?> finalElementId,
      Value<String?> finalComponentId,
      Value<String?> finalDefectType,
      Value<String?> finalRecommendation,
      Value<String?> finalNotes,
      Value<String> status,
      required String providerId,
      required DateTime generatedAt,
      Value<DateTime?> reviewedAt,
      Value<String?> suggestedCatalogueEntryId,
      Value<double?> suggestedConfidence,
      Value<String?> suggestedShortReason,
      Value<String?> suggestedCandidateEntryIds,
      Value<String?> finalCatalogueEntryId,
      Value<String?> suggestedDefectTerm,
      Value<int> rowid,
    });
typedef $$AiSuggestionRowsTableUpdateCompanionBuilder =
    AiSuggestionRowsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> findingId,
      Value<String?> suggestedElementId,
      Value<String?> suggestedComponentId,
      Value<String?> suggestedDefectType,
      Value<String?> suggestedRecommendation,
      Value<String?> suggestedNotes,
      Value<String?> finalElementId,
      Value<String?> finalComponentId,
      Value<String?> finalDefectType,
      Value<String?> finalRecommendation,
      Value<String?> finalNotes,
      Value<String> status,
      Value<String> providerId,
      Value<DateTime> generatedAt,
      Value<DateTime?> reviewedAt,
      Value<String?> suggestedCatalogueEntryId,
      Value<double?> suggestedConfidence,
      Value<String?> suggestedShortReason,
      Value<String?> suggestedCandidateEntryIds,
      Value<String?> finalCatalogueEntryId,
      Value<String?> suggestedDefectTerm,
      Value<int> rowid,
    });

final class $$AiSuggestionRowsTableReferences
    extends
        BaseReferences<_$AppDatabase, $AiSuggestionRowsTable, AiSuggestionRow> {
  $$AiSuggestionRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $InspectionSessionRowsTable _sessionIdTable(_$AppDatabase db) =>
      db.inspectionSessionRows.createAlias(
        'ai_suggestion_rows__session_id__inspection_session_rows__id',
      );

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

  static $FindingRowsTable _findingIdTable(_$AppDatabase db) => db.findingRows
      .createAlias('ai_suggestion_rows__finding_id__finding_rows__id');

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

class $$AiSuggestionRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AiSuggestionRowsTable> {
  $$AiSuggestionRowsTableFilterComposer({
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

  ColumnFilters<String> get suggestedElementId => $composableBuilder(
    column: $table.suggestedElementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedComponentId => $composableBuilder(
    column: $table.suggestedComponentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedDefectType => $composableBuilder(
    column: $table.suggestedDefectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedRecommendation => $composableBuilder(
    column: $table.suggestedRecommendation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedNotes => $composableBuilder(
    column: $table.suggestedNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalElementId => $composableBuilder(
    column: $table.finalElementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalComponentId => $composableBuilder(
    column: $table.finalComponentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalDefectType => $composableBuilder(
    column: $table.finalDefectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalRecommendation => $composableBuilder(
    column: $table.finalRecommendation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalNotes => $composableBuilder(
    column: $table.finalNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedCatalogueEntryId => $composableBuilder(
    column: $table.suggestedCatalogueEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get suggestedConfidence => $composableBuilder(
    column: $table.suggestedConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedShortReason => $composableBuilder(
    column: $table.suggestedShortReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedCandidateEntryIds => $composableBuilder(
    column: $table.suggestedCandidateEntryIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalCatalogueEntryId => $composableBuilder(
    column: $table.finalCatalogueEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedDefectTerm => $composableBuilder(
    column: $table.suggestedDefectTerm,
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

class $$AiSuggestionRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiSuggestionRowsTable> {
  $$AiSuggestionRowsTableOrderingComposer({
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

  ColumnOrderings<String> get suggestedElementId => $composableBuilder(
    column: $table.suggestedElementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedComponentId => $composableBuilder(
    column: $table.suggestedComponentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedDefectType => $composableBuilder(
    column: $table.suggestedDefectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedRecommendation => $composableBuilder(
    column: $table.suggestedRecommendation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedNotes => $composableBuilder(
    column: $table.suggestedNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalElementId => $composableBuilder(
    column: $table.finalElementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalComponentId => $composableBuilder(
    column: $table.finalComponentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalDefectType => $composableBuilder(
    column: $table.finalDefectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalRecommendation => $composableBuilder(
    column: $table.finalRecommendation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalNotes => $composableBuilder(
    column: $table.finalNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedCatalogueEntryId => $composableBuilder(
    column: $table.suggestedCatalogueEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get suggestedConfidence => $composableBuilder(
    column: $table.suggestedConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedShortReason => $composableBuilder(
    column: $table.suggestedShortReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedCandidateEntryIds => $composableBuilder(
    column: $table.suggestedCandidateEntryIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalCatalogueEntryId => $composableBuilder(
    column: $table.finalCatalogueEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedDefectTerm => $composableBuilder(
    column: $table.suggestedDefectTerm,
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

class $$AiSuggestionRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiSuggestionRowsTable> {
  $$AiSuggestionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get suggestedElementId => $composableBuilder(
    column: $table.suggestedElementId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedComponentId => $composableBuilder(
    column: $table.suggestedComponentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedDefectType => $composableBuilder(
    column: $table.suggestedDefectType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedRecommendation => $composableBuilder(
    column: $table.suggestedRecommendation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedNotes => $composableBuilder(
    column: $table.suggestedNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalElementId => $composableBuilder(
    column: $table.finalElementId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalComponentId => $composableBuilder(
    column: $table.finalComponentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalDefectType => $composableBuilder(
    column: $table.finalDefectType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalRecommendation => $composableBuilder(
    column: $table.finalRecommendation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalNotes => $composableBuilder(
    column: $table.finalNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedCatalogueEntryId => $composableBuilder(
    column: $table.suggestedCatalogueEntryId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get suggestedConfidence => $composableBuilder(
    column: $table.suggestedConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedShortReason => $composableBuilder(
    column: $table.suggestedShortReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedCandidateEntryIds => $composableBuilder(
    column: $table.suggestedCandidateEntryIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalCatalogueEntryId => $composableBuilder(
    column: $table.finalCatalogueEntryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedDefectTerm => $composableBuilder(
    column: $table.suggestedDefectTerm,
    builder: (column) => column,
  );

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

class $$AiSuggestionRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiSuggestionRowsTable,
          AiSuggestionRow,
          $$AiSuggestionRowsTableFilterComposer,
          $$AiSuggestionRowsTableOrderingComposer,
          $$AiSuggestionRowsTableAnnotationComposer,
          $$AiSuggestionRowsTableCreateCompanionBuilder,
          $$AiSuggestionRowsTableUpdateCompanionBuilder,
          (AiSuggestionRow, $$AiSuggestionRowsTableReferences),
          AiSuggestionRow,
          PrefetchHooks Function({bool sessionId, bool findingId})
        > {
  $$AiSuggestionRowsTableTableManager(
    _$AppDatabase db,
    $AiSuggestionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiSuggestionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiSuggestionRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiSuggestionRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> findingId = const Value.absent(),
                Value<String?> suggestedElementId = const Value.absent(),
                Value<String?> suggestedComponentId = const Value.absent(),
                Value<String?> suggestedDefectType = const Value.absent(),
                Value<String?> suggestedRecommendation = const Value.absent(),
                Value<String?> suggestedNotes = const Value.absent(),
                Value<String?> finalElementId = const Value.absent(),
                Value<String?> finalComponentId = const Value.absent(),
                Value<String?> finalDefectType = const Value.absent(),
                Value<String?> finalRecommendation = const Value.absent(),
                Value<String?> finalNotes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<DateTime?> reviewedAt = const Value.absent(),
                Value<String?> suggestedCatalogueEntryId = const Value.absent(),
                Value<double?> suggestedConfidence = const Value.absent(),
                Value<String?> suggestedShortReason = const Value.absent(),
                Value<String?> suggestedCandidateEntryIds =
                    const Value.absent(),
                Value<String?> finalCatalogueEntryId = const Value.absent(),
                Value<String?> suggestedDefectTerm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiSuggestionRowsCompanion(
                id: id,
                sessionId: sessionId,
                findingId: findingId,
                suggestedElementId: suggestedElementId,
                suggestedComponentId: suggestedComponentId,
                suggestedDefectType: suggestedDefectType,
                suggestedRecommendation: suggestedRecommendation,
                suggestedNotes: suggestedNotes,
                finalElementId: finalElementId,
                finalComponentId: finalComponentId,
                finalDefectType: finalDefectType,
                finalRecommendation: finalRecommendation,
                finalNotes: finalNotes,
                status: status,
                providerId: providerId,
                generatedAt: generatedAt,
                reviewedAt: reviewedAt,
                suggestedCatalogueEntryId: suggestedCatalogueEntryId,
                suggestedConfidence: suggestedConfidence,
                suggestedShortReason: suggestedShortReason,
                suggestedCandidateEntryIds: suggestedCandidateEntryIds,
                finalCatalogueEntryId: finalCatalogueEntryId,
                suggestedDefectTerm: suggestedDefectTerm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String findingId,
                Value<String?> suggestedElementId = const Value.absent(),
                Value<String?> suggestedComponentId = const Value.absent(),
                Value<String?> suggestedDefectType = const Value.absent(),
                Value<String?> suggestedRecommendation = const Value.absent(),
                Value<String?> suggestedNotes = const Value.absent(),
                Value<String?> finalElementId = const Value.absent(),
                Value<String?> finalComponentId = const Value.absent(),
                Value<String?> finalDefectType = const Value.absent(),
                Value<String?> finalRecommendation = const Value.absent(),
                Value<String?> finalNotes = const Value.absent(),
                Value<String> status = const Value.absent(),
                required String providerId,
                required DateTime generatedAt,
                Value<DateTime?> reviewedAt = const Value.absent(),
                Value<String?> suggestedCatalogueEntryId = const Value.absent(),
                Value<double?> suggestedConfidence = const Value.absent(),
                Value<String?> suggestedShortReason = const Value.absent(),
                Value<String?> suggestedCandidateEntryIds =
                    const Value.absent(),
                Value<String?> finalCatalogueEntryId = const Value.absent(),
                Value<String?> suggestedDefectTerm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiSuggestionRowsCompanion.insert(
                id: id,
                sessionId: sessionId,
                findingId: findingId,
                suggestedElementId: suggestedElementId,
                suggestedComponentId: suggestedComponentId,
                suggestedDefectType: suggestedDefectType,
                suggestedRecommendation: suggestedRecommendation,
                suggestedNotes: suggestedNotes,
                finalElementId: finalElementId,
                finalComponentId: finalComponentId,
                finalDefectType: finalDefectType,
                finalRecommendation: finalRecommendation,
                finalNotes: finalNotes,
                status: status,
                providerId: providerId,
                generatedAt: generatedAt,
                reviewedAt: reviewedAt,
                suggestedCatalogueEntryId: suggestedCatalogueEntryId,
                suggestedConfidence: suggestedConfidence,
                suggestedShortReason: suggestedShortReason,
                suggestedCandidateEntryIds: suggestedCandidateEntryIds,
                finalCatalogueEntryId: finalCatalogueEntryId,
                suggestedDefectTerm: suggestedDefectTerm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiSuggestionRowsTable, AiSuggestionRow>(table),
                  $$AiSuggestionRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, findingId = false}) {
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
                        referencedTable: $$AiSuggestionRowsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$AiSuggestionRowsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (findingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.findingId,
                        referencedTable: $$AiSuggestionRowsTableReferences
                            ._findingIdTable(db),
                        referencedColumn: $$AiSuggestionRowsTableReferences
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

typedef $$AiSuggestionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiSuggestionRowsTable,
      AiSuggestionRow,
      $$AiSuggestionRowsTableFilterComposer,
      $$AiSuggestionRowsTableOrderingComposer,
      $$AiSuggestionRowsTableAnnotationComposer,
      $$AiSuggestionRowsTableCreateCompanionBuilder,
      $$AiSuggestionRowsTableUpdateCompanionBuilder,
      (AiSuggestionRow, $$AiSuggestionRowsTableReferences),
      AiSuggestionRow,
      PrefetchHooks Function({bool sessionId, bool findingId})
    >;
typedef $$ReportRowsTableCreateCompanionBuilder = ReportRowsCompanion Function({
  required String id,
  required String sessionId,
  required String filePath,
  required String fileName,
  required DateTime generatedAt,
  required DateTime sourceUpdatedAt,
  Value<String> syncStatus,
  Value<int> version,
  Value<int> rowid,
});
typedef $$ReportRowsTableUpdateCompanionBuilder = ReportRowsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> filePath,
  Value<String> fileName,
  Value<DateTime> generatedAt,
  Value<DateTime> sourceUpdatedAt,
  Value<String> syncStatus,
  Value<int> version,
  Value<int> rowid,
});

final class $$ReportRowsTableReferences
    extends BaseReferences<_$AppDatabase, $ReportRowsTable, ReportRow> {
  $$ReportRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $InspectionSessionRowsTable _sessionIdTable(_$AppDatabase db) => db
      .inspectionSessionRows
      .createAlias('report_rows__session_id__inspection_session_rows__id');

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

class $$ReportRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ReportRowsTable> {
  $$ReportRowsTableFilterComposer({
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

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sourceUpdatedAt => $composableBuilder(
    column: $table.sourceUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
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

class $$ReportRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReportRowsTable> {
  $$ReportRowsTableOrderingComposer({
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

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sourceUpdatedAt => $composableBuilder(
    column: $table.sourceUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
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

class $$ReportRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReportRowsTable> {
  $$ReportRowsTableAnnotationComposer({
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

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get sourceUpdatedAt => $composableBuilder(
    column: $table.sourceUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

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

class $$ReportRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReportRowsTable,
          ReportRow,
          $$ReportRowsTableFilterComposer,
          $$ReportRowsTableOrderingComposer,
          $$ReportRowsTableAnnotationComposer,
          $$ReportRowsTableCreateCompanionBuilder,
          $$ReportRowsTableUpdateCompanionBuilder,
          (ReportRow, $$ReportRowsTableReferences),
          ReportRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$ReportRowsTableTableManager(_$AppDatabase db, $ReportRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<DateTime> sourceUpdatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportRowsCompanion(
                id: id,
                sessionId: sessionId,
                filePath: filePath,
                fileName: fileName,
                generatedAt: generatedAt,
                sourceUpdatedAt: sourceUpdatedAt,
                syncStatus: syncStatus,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String filePath,
                required String fileName,
                required DateTime generatedAt,
                required DateTime sourceUpdatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportRowsCompanion.insert(
                id: id,
                sessionId: sessionId,
                filePath: filePath,
                fileName: fileName,
                generatedAt: generatedAt,
                sourceUpdatedAt: sourceUpdatedAt,
                syncStatus: syncStatus,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReportRowsTable, ReportRow>(table),
                  $$ReportRowsTableReferences(db, table, e),
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
                        referencedTable: $$ReportRowsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$ReportRowsTableReferences
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

typedef $$ReportRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReportRowsTable,
      ReportRow,
      $$ReportRowsTableFilterComposer,
      $$ReportRowsTableOrderingComposer,
      $$ReportRowsTableAnnotationComposer,
      $$ReportRowsTableCreateCompanionBuilder,
      $$ReportRowsTableUpdateCompanionBuilder,
      (ReportRow, $$ReportRowsTableReferences),
      ReportRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$UserProfileRowsTableCreateCompanionBuilder =
    UserProfileRowsCompanion Function({
      required String id,
      Value<String?> companyName,
      Value<String?> inspectorName,
      required DateTime updatedAt,
      Value<String?> defaultAiLevel,
      Value<int> rowid,
    });
typedef $$UserProfileRowsTableUpdateCompanionBuilder =
    UserProfileRowsCompanion Function({
      Value<String> id,
      Value<String?> companyName,
      Value<String?> inspectorName,
      Value<DateTime> updatedAt,
      Value<String?> defaultAiLevel,
      Value<int> rowid,
    });

class $$UserProfileRowsTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileRowsTable> {
  $$UserProfileRowsTableFilterComposer({
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

  ColumnFilters<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inspectorName => $composableBuilder(
    column: $table.inspectorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultAiLevel => $composableBuilder(
    column: $table.defaultAiLevel,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfileRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileRowsTable> {
  $$UserProfileRowsTableOrderingComposer({
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

  ColumnOrderings<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inspectorName => $composableBuilder(
    column: $table.inspectorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultAiLevel => $composableBuilder(
    column: $table.defaultAiLevel,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfileRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileRowsTable> {
  $$UserProfileRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inspectorName => $composableBuilder(
    column: $table.inspectorName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get defaultAiLevel => $composableBuilder(
    column: $table.defaultAiLevel,
    builder: (column) => column,
  );
}

class $$UserProfileRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfileRowsTable,
          UserProfileRow,
          $$UserProfileRowsTableFilterComposer,
          $$UserProfileRowsTableOrderingComposer,
          $$UserProfileRowsTableAnnotationComposer,
          $$UserProfileRowsTableCreateCompanionBuilder,
          $$UserProfileRowsTableUpdateCompanionBuilder,
          (
            UserProfileRow,
            BaseReferences<
              _$AppDatabase,
              $UserProfileRowsTable,
              UserProfileRow
            >,
          ),
          UserProfileRow,
          PrefetchHooks Function()
        > {
  $$UserProfileRowsTableTableManager(
    _$AppDatabase db,
    $UserProfileRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> companyName = const Value.absent(),
                Value<String?> inspectorName = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> defaultAiLevel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfileRowsCompanion(
                id: id,
                companyName: companyName,
                inspectorName: inspectorName,
                updatedAt: updatedAt,
                defaultAiLevel: defaultAiLevel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> companyName = const Value.absent(),
                Value<String?> inspectorName = const Value.absent(),
                required DateTime updatedAt,
                Value<String?> defaultAiLevel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfileRowsCompanion.insert(
                id: id,
                companyName: companyName,
                inspectorName: inspectorName,
                updatedAt: updatedAt,
                defaultAiLevel: defaultAiLevel,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserProfileRowsTable, UserProfileRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UserProfileRowsTable,
                    UserProfileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfileRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfileRowsTable,
      UserProfileRow,
      $$UserProfileRowsTableFilterComposer,
      $$UserProfileRowsTableOrderingComposer,
      $$UserProfileRowsTableAnnotationComposer,
      $$UserProfileRowsTableCreateCompanionBuilder,
      $$UserProfileRowsTableUpdateCompanionBuilder,
      (
        UserProfileRow,
        BaseReferences<_$AppDatabase, $UserProfileRowsTable, UserProfileRow>,
      ),
      UserProfileRow,
      PrefetchHooks Function()
    >;
typedef $$WalletCacheRowsTableCreateCompanionBuilder =
    WalletCacheRowsCompanion Function({
      required String id,
      required int balanceCredits,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WalletCacheRowsTableUpdateCompanionBuilder =
    WalletCacheRowsCompanion Function({
      Value<String> id,
      Value<int> balanceCredits,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$WalletCacheRowsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletCacheRowsTable> {
  $$WalletCacheRowsTableFilterComposer({
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

  ColumnFilters<int> get balanceCredits => $composableBuilder(
    column: $table.balanceCredits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletCacheRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletCacheRowsTable> {
  $$WalletCacheRowsTableOrderingComposer({
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

  ColumnOrderings<int> get balanceCredits => $composableBuilder(
    column: $table.balanceCredits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletCacheRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletCacheRowsTable> {
  $$WalletCacheRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get balanceCredits => $composableBuilder(
    column: $table.balanceCredits,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WalletCacheRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletCacheRowsTable,
          WalletCacheRow,
          $$WalletCacheRowsTableFilterComposer,
          $$WalletCacheRowsTableOrderingComposer,
          $$WalletCacheRowsTableAnnotationComposer,
          $$WalletCacheRowsTableCreateCompanionBuilder,
          $$WalletCacheRowsTableUpdateCompanionBuilder,
          (
            WalletCacheRow,
            BaseReferences<
              _$AppDatabase,
              $WalletCacheRowsTable,
              WalletCacheRow
            >,
          ),
          WalletCacheRow,
          PrefetchHooks Function()
        > {
  $$WalletCacheRowsTableTableManager(
    _$AppDatabase db,
    $WalletCacheRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletCacheRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletCacheRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletCacheRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> balanceCredits = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletCacheRowsCompanion(
                id: id,
                balanceCredits: balanceCredits,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int balanceCredits,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WalletCacheRowsCompanion.insert(
                id: id,
                balanceCredits: balanceCredits,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WalletCacheRowsTable, WalletCacheRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WalletCacheRowsTable,
                    WalletCacheRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletCacheRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletCacheRowsTable,
      WalletCacheRow,
      $$WalletCacheRowsTableFilterComposer,
      $$WalletCacheRowsTableOrderingComposer,
      $$WalletCacheRowsTableAnnotationComposer,
      $$WalletCacheRowsTableCreateCompanionBuilder,
      $$WalletCacheRowsTableUpdateCompanionBuilder,
      (
        WalletCacheRow,
        BaseReferences<_$AppDatabase, $WalletCacheRowsTable, WalletCacheRow>,
      ),
      WalletCacheRow,
      PrefetchHooks Function()
    >;
typedef $$AreaCandidateRowsTableCreateCompanionBuilder =
    AreaCandidateRowsCompanion Function({
      required String id,
      required String rawName,
      required String normalizedName,
      required String propertyType,
      required DateTime createdAt,
      Value<bool> submitted,
      Value<int> rowid,
    });
typedef $$AreaCandidateRowsTableUpdateCompanionBuilder =
    AreaCandidateRowsCompanion Function({
      Value<String> id,
      Value<String> rawName,
      Value<String> normalizedName,
      Value<String> propertyType,
      Value<DateTime> createdAt,
      Value<bool> submitted,
      Value<int> rowid,
    });

class $$AreaCandidateRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AreaCandidateRowsTable> {
  $$AreaCandidateRowsTableFilterComposer({
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

  ColumnFilters<String> get rawName => $composableBuilder(
    column: $table.rawName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get propertyType => $composableBuilder(
    column: $table.propertyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AreaCandidateRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AreaCandidateRowsTable> {
  $$AreaCandidateRowsTableOrderingComposer({
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

  ColumnOrderings<String> get rawName => $composableBuilder(
    column: $table.rawName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get propertyType => $composableBuilder(
    column: $table.propertyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AreaCandidateRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AreaCandidateRowsTable> {
  $$AreaCandidateRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rawName =>
      $composableBuilder(column: $table.rawName, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get propertyType => $composableBuilder(
    column: $table.propertyType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get submitted =>
      $composableBuilder(column: $table.submitted, builder: (column) => column);
}

class $$AreaCandidateRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AreaCandidateRowsTable,
          AreaCandidateRow,
          $$AreaCandidateRowsTableFilterComposer,
          $$AreaCandidateRowsTableOrderingComposer,
          $$AreaCandidateRowsTableAnnotationComposer,
          $$AreaCandidateRowsTableCreateCompanionBuilder,
          $$AreaCandidateRowsTableUpdateCompanionBuilder,
          (
            AreaCandidateRow,
            BaseReferences<
              _$AppDatabase,
              $AreaCandidateRowsTable,
              AreaCandidateRow
            >,
          ),
          AreaCandidateRow,
          PrefetchHooks Function()
        > {
  $$AreaCandidateRowsTableTableManager(
    _$AppDatabase db,
    $AreaCandidateRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AreaCandidateRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AreaCandidateRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AreaCandidateRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> rawName = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String> propertyType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> submitted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AreaCandidateRowsCompanion(
                id: id,
                rawName: rawName,
                normalizedName: normalizedName,
                propertyType: propertyType,
                createdAt: createdAt,
                submitted: submitted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String rawName,
                required String normalizedName,
                required String propertyType,
                required DateTime createdAt,
                Value<bool> submitted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AreaCandidateRowsCompanion.insert(
                id: id,
                rawName: rawName,
                normalizedName: normalizedName,
                propertyType: propertyType,
                createdAt: createdAt,
                submitted: submitted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AreaCandidateRowsTable, AreaCandidateRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AreaCandidateRowsTable,
                    AreaCandidateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AreaCandidateRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AreaCandidateRowsTable,
      AreaCandidateRow,
      $$AreaCandidateRowsTableFilterComposer,
      $$AreaCandidateRowsTableOrderingComposer,
      $$AreaCandidateRowsTableAnnotationComposer,
      $$AreaCandidateRowsTableCreateCompanionBuilder,
      $$AreaCandidateRowsTableUpdateCompanionBuilder,
      (
        AreaCandidateRow,
        BaseReferences<
          _$AppDatabase,
          $AreaCandidateRowsTable,
          AreaCandidateRow
        >,
      ),
      AreaCandidateRow,
      PrefetchHooks Function()
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
  $$AiSuggestionRowsTableTableManager get aiSuggestionRows =>
      $$AiSuggestionRowsTableTableManager(_db, _db.aiSuggestionRows);
  $$ReportRowsTableTableManager get reportRows =>
      $$ReportRowsTableTableManager(_db, _db.reportRows);
  $$UserProfileRowsTableTableManager get userProfileRows =>
      $$UserProfileRowsTableTableManager(_db, _db.userProfileRows);
  $$WalletCacheRowsTableTableManager get walletCacheRows =>
      $$WalletCacheRowsTableTableManager(_db, _db.walletCacheRows);
  $$AreaCandidateRowsTableTableManager get areaCandidateRows =>
      $$AreaCandidateRowsTableTableManager(_db, _db.areaCandidateRows);
}
