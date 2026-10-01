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
export 'ai/ai_progress.dart';
export 'ai/ai_review_coordinator.dart';
export 'areas/area_candidate.dart';
export 'areas/area_candidate_service.dart';
export 'billing/analyse_finding_exception.dart';
export 'billing/billing_call_exception.dart';
export 'billing/analyse_finding_result.dart';
export 'billing/analysis_estimate.dart';
export 'billing/billing_service.dart';
export 'billing/commercial_config.dart';
export 'billing/house_pass_status_service.dart';
export 'billing/house_pass_summary.dart';
export 'billing/payment_intent.dart';
export 'billing/wallet_activity_service.dart';
export 'billing/wallet_transaction.dart';
export 'entities/ai_analysis_attempt.dart';
export 'entities/ai_finding_status.dart';
export 'entities/ai_level.dart';
export 'entities/ai_review.dart';
export 'entities/ai_review_state.dart';
export 'entities/asset_type.dart';
export 'entities/auth_user.dart';
export 'entities/commercial_mode.dart';
export 'entities/component.dart';
export 'entities/defect_catalogue.dart';
export 'entities/element.dart';
export 'entities/evidence.dart';
export 'entities/finding.dart';
export 'entities/finding_status.dart';
export 'entities/industry.dart';
export 'entities/inspection.dart';
export 'entities/inspection_session.dart';
export 'entities/property_details.dart';
export 'entities/report.dart';
export 'entities/report_metadata.dart';
export 'entities/section.dart';
export 'entities/section_status.dart';
export 'entities/sync_status.dart';
export 'entities/user_profile.dart';
export 'entities/wallet_cache.dart';
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
export 'services/connectivity_service.dart';
export 'services/evidence_capture_service.dart';
export 'services/evidence_file_store.dart';
export 'sync/sync_coordinator.dart';
export 'sync/sync_result.dart';
