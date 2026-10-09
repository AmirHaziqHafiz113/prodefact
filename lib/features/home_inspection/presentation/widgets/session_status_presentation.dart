import 'package:flutter/material.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';

/// The inspection's top-level lifecycle status, made explicit — a
/// session isn't "Completed" merely because physical inspection or AI
/// review finished; that only happens once a report has actually been
/// generated (`InspectionStatus.reported`). Mapped onto the shared
/// [AppStatus] vocabulary so a session chip looks like every other
/// status chip in the app.
(AppStatus status, String label) sessionLifecycleStatus(
  InspectionStatus status,
) => switch (status) {
  InspectionStatus.inProgress => (AppStatus.inProgress, 'In Progress'),
  InspectionStatus.physicalInspectionComplete => (
    AppStatus.analysing,
    'AI Processing',
  ),
  InspectionStatus.aiReviewComplete => (AppStatus.reportReady, 'Report Ready'),
  InspectionStatus.reported => (AppStatus.completed, 'Completed'),
};

/// Label/icon/colours for [status] — the tuple form older call sites use.
(String label, IconData icon, Color foreground, Color background)
sessionLifecyclePresentation(InspectionStatus status) {
  final (appStatus, label) = sessionLifecycleStatus(status);
  final style = appStatusStyle(appStatus);
  return (label, style.icon, style.foreground, style.background);
}

/// A session's chip on list surfaces: [sessionLifecycleStatus], except
/// that an in-progress inspection with nothing recorded yet reads
/// "Draft", and one waiting on the inspector's decisions reads "Needs
/// Review".
(AppStatus status, String label) sessionCardStatus(
  InspectionSessionSummary summary,
) {
  if (summary.isDraft) return (AppStatus.draft, 'Draft');
  if (summary.status != InspectionStatus.reported &&
      summary.aiPendingReviewCount > 0) {
    return (AppStatus.needsReview, 'Needs Review');
  }
  return sessionLifecycleStatus(summary.status);
}

/// A small pill rendering [sessionLifecycleStatus].
class SessionLifecyclePill extends StatelessWidget {
  const SessionLifecyclePill({
    super.key,
    required this.status,
    this.dense = true,
  });

  final InspectionStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (appStatus, label) = sessionLifecycleStatus(status);
    return AppStatusChip(status: appStatus, label: label, dense: dense);
  }
}

/// A human date ("9 Oct 2026") for inspection cards and headers.
String formatInspectionDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

/// A short relative timestamp ("2h ago", "just now") from real data.
String formatRelativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatInspectionDate(dateTime);
}
