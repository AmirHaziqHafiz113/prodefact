/// Generic inspection engine/domain, shared across all future industries.
///
/// Nothing in this library knows about Home Inspection specifically —
/// industry-specific configuration lives under `lib/features/*` instead
/// and is expressed in terms of these entities.
library;

export 'entities/ai_review.dart';
export 'entities/asset_type.dart';
export 'entities/auth_user.dart';
export 'entities/component.dart';
export 'entities/element.dart';
export 'entities/evidence.dart';
export 'entities/finding.dart';
export 'entities/finding_status.dart';
export 'entities/industry.dart';
export 'entities/inspection.dart';
export 'entities/inspection_session.dart';
export 'entities/report.dart';
export 'entities/section.dart';
export 'entities/section_status.dart';
export 'entities/sync_status.dart';
export 'repository/cloud_inspection_repository.dart';
export 'repository/inspection_repository.dart';
export 'services/auth_service.dart';
export 'sync/sync_coordinator.dart';
export 'sync/sync_result.dart';
