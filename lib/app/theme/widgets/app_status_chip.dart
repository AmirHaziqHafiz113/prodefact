import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'status_pill.dart';

/// The one status vocabulary every chip in the app maps onto — sessions,
/// areas, findings and AI suggestions — so "Needs review" looks the same
/// wherever it appears. See docs/ux_architecture.md ("Visual system").
enum AppStatus {
  draft,
  notStarted,
  inProgress,
  queued,
  analysing,
  confirmed,
  needsReview,
  failed,
  rejected,
  reportReady,
  completed,
}

/// Label, icon and colours for [status]. Always icon + label, never
/// colour alone.
({String label, IconData icon, Color foreground, Color background})
appStatusStyle(AppStatus status) => switch (status) {
  AppStatus.draft => (
    label: 'Draft',
    icon: Icons.edit_note_outlined,
    foreground: AppColors.textSecondary,
    background: AppColors.neutralBg,
  ),
  AppStatus.notStarted => (
    label: 'Not started',
    icon: Icons.circle_outlined,
    foreground: AppColors.textSecondary,
    background: AppColors.neutralBg,
  ),
  AppStatus.inProgress => (
    label: 'In Progress',
    icon: Icons.timelapse,
    foreground: AppColors.warning,
    background: AppColors.warningBg,
  ),
  AppStatus.queued => (
    label: 'Queued',
    icon: Icons.hourglass_empty,
    foreground: AppColors.textSecondary,
    background: AppColors.neutralBg,
  ),
  AppStatus.analysing => (
    label: 'Analysing',
    icon: Icons.auto_awesome,
    foreground: AppColors.info,
    background: AppColors.infoBg,
  ),
  AppStatus.confirmed => (
    label: 'Confirmed',
    icon: Icons.check_circle,
    foreground: AppColors.success,
    background: AppColors.successBg,
  ),
  AppStatus.needsReview => (
    label: 'Needs Review',
    icon: Icons.help_outline,
    foreground: AppColors.warning,
    background: AppColors.warningBg,
  ),
  AppStatus.failed => (
    label: 'Failed',
    icon: Icons.error_outline,
    foreground: AppColors.danger,
    background: AppColors.dangerBg,
  ),
  AppStatus.rejected => (
    label: 'Rejected',
    icon: Icons.block,
    foreground: AppColors.danger,
    background: AppColors.dangerBg,
  ),
  AppStatus.reportReady => (
    label: 'Report Ready',
    icon: Icons.fact_check_outlined,
    foreground: AppColors.info,
    background: AppColors.infoBg,
  ),
  AppStatus.completed => (
    label: 'Completed',
    icon: Icons.verified_outlined,
    foreground: AppColors.success,
    background: AppColors.successBg,
  ),
};

/// A [StatusPill] for an [AppStatus]. [label] overrides the default
/// wording where a screen needs a more specific phrase ("Accepted by
/// AI") while keeping the same icon and colour.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.status,
    this.label,
    this.dense = true,
  });

  final AppStatus status;
  final String? label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = appStatusStyle(status);
    return StatusPill(
      label: label ?? style.label,
      icon: style.icon,
      foreground: style.foreground,
      background: style.background,
      dense: dense,
    );
  }
}
