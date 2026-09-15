/// Generic inspection engine/domain, shared across all future industries.
///
/// Nothing in this library knows about Home Inspection specifically —
/// industry-specific configuration lives under `lib/features/*` instead
/// and is expressed in terms of these entities.
library;

export 'ai/ai_analysis_request.dart';
export 'ai/ai_analysis_response.dart';
export 'ai/ai_analysis_result.dart';
export 'ai/ai_inspection_service.dart';
export 'ai/ai_review_coordinator.dart';
export 'entities/ai_review.dart';
export 'entities/ai_review_state.dart';
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
export 'report/report_coordinator.dart';
export 'report/report_file_naming.dart';
export 'report/report_file_store.dart';
export 'report/report_generation_result.dart';
export 'report/report_model.dart';
export 'report/report_model_builder.dart';
export 'report/report_renderer.dart';
export 'report/report_share_service.dart';
export 'repository/cloud_inspection_repository.dart';
export 'repository/inspection_repository.dart';
export 'services/analytics_service.dart';
export 'services/auth_service.dart';
export 'services/evidence_capture_service.dart';
export 'services/evidence_file_store.dart';
export 'sync/sync_coordinator.dart';
export 'sync/sync_result.dart';
