import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../config/property_type.dart';
import '../../providers/active_session_providers.dart';
import '../screens/ai_review_overview_screen.dart';
import '../screens/area_inspection_screen.dart';
import '../screens/inspection_overview_screen.dart';
import '../screens/report_screen.dart';

/// Resumes [sessionId] as the active session, then pushes [location].
/// Shared by every "open this inspection's X" action so each screen
/// doesn't re-implement the resume-then-navigate sequence.
Future<bool> _resumeThenPush(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
  String location,
) async {
  final resumed = await ref
      .read(activeSessionProvider.notifier)
      .resume(sessionId);
  if (!context.mounted) return false;
  if (!resumed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open that inspection. Please try again.'),
      ),
    );
    return false;
  }
  context.push(location);
  return true;
}

/// Opens [sessionId]'s Inspection Overview — what tapping an inspection
/// card does everywhere.
Future<void> resumeAndOpenInspection(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) => _resumeThenPush(
  context,
  ref,
  sessionId,
  InspectionOverviewScreen.routePath,
);

/// Opens [sessionId]'s AI Review (its findings that need a decision).
Future<void> resumeAndOpenReview(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) => _resumeThenPush(context, ref, sessionId, AiReviewOverviewScreen.routePath);

/// Opens [sessionId]'s Report screen (the existing report flow).
Future<void> resumeAndOpenReport(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) => _resumeThenPush(context, ref, sessionId, ReportScreen.routePath);

/// The Area Findings location for [sectionId]; [capture] opens the
/// camera as soon as the screen appears (the "+" quick-capture path).
String areaFindingsLocation(String sectionId, {bool capture = false}) =>
    '${AreaInspectionScreen.routePathPrefix}/$sectionId'
    '${capture ? '?capture=1' : ''}';

/// The area "Continue Inspection" should open: the area of the newest
/// finding if that area isn't complete yet (the inspector was just
/// working there), otherwise the first area in [queue] order (plumbing
/// first) that isn't complete. Null when every area is complete.
Section? continueAreaFor(InspectionSession session, List<Section> queue) {
  bool open(Section s) =>
      areaVisitStateOf(session, s) != AreaVisitState.completed;
  final newest = session.findings
      .sortedBy((f) => f.createdAt)
      .reversed
      .map((f) => queue.firstWhereOrNull((s) => s.id == f.sectionId))
      .firstWhereOrNull((s) => s != null);
  if (newest != null && open(newest)) return newest;
  return queue.firstWhereOrNull(open);
}

/// A session's display title: its property title, else its property
/// type's label.
String summaryTitle(InspectionSessionSummary summary) =>
    summary.propertyTitle?.isNotEmpty == true
    ? summary.propertyTitle!
    : (PropertyType.values
              .firstWhereOrNull((p) => p.name == summary.assetTypeId)
              ?.label ??
          summary.assetTypeId);

/// The drawn-illustration fallback for an [assetTypeId].
AppPropertyIllustrationKind illustrationKindFor(String assetTypeId) =>
    assetTypeId == PropertyType.landed.name
    ? AppPropertyIllustrationKind.landed
    : AppPropertyIllustrationKind.highRise;
