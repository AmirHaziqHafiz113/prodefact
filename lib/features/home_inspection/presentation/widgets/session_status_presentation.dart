import 'package:flutter/material.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';

/// The inspection's top-level lifecycle status, made explicit — a
/// session isn't "Completed" merely because physical inspection or AI
/// review finished; that only happens once a report has actually been
/// generated (`InspectionStatus.reported`). Shared by the Inspections
/// list, Home's hero/recent cards, and anywhere else a session's
/// status needs the same label/icon/color rather than a second,
/// possibly-drifting copy of this mapping.
(String label, IconData icon, Color foreground, Color background)
sessionLifecyclePresentation(InspectionStatus status) => switch (status) {
  InspectionStatus.inProgress => (
    'In Progress',
    Icons.pending_outlined,
    AppColors.warning,
    AppColors.warningBg,
  ),
  InspectionStatus.physicalInspectionComplete => (
    'AI Processing',
    Icons.smart_toy_outlined,
    AppColors.info,
    AppColors.infoBg,
  ),
  InspectionStatus.aiReviewComplete => (
    'Report Ready',
    Icons.fact_check_outlined,
    AppColors.info,
    AppColors.infoBg,
  ),
  InspectionStatus.reported => (
    'Completed',
    Icons.check_circle_outline,
    AppColors.success,
    AppColors.successBg,
  ),
};

/// A small pill rendering [sessionLifecyclePresentation] — the shared
/// widget form, so screens don't each build their own `StatusPill`
/// call with the same four-way switch inline.
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
    final (label, icon, fg, bg) = sessionLifecyclePresentation(status);
    return StatusPill(
      label: label,
      icon: icon,
      foreground: fg,
      background: bg,
      dense: dense,
    );
  }
}
