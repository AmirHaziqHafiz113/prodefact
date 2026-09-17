import 'package:flutter/material.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../app_colors.dart';
import 'status_pill.dart';

/// Renders a [SyncStatus] as a subtle, understandable pill — never
/// exposing Firebase/Firestore terminology to the inspector.
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({
    super.key,
    required this.status,
    this.dense = false,
    this.pendingCount = 0,
  });

  final SyncStatus status;
  final bool dense;

  /// A real count of not-yet-synced items (evidence photos) for this
  /// inspection — shown as "N items waiting" instead of the generic
  /// "Pending sync" label when known and greater than zero. Never a
  /// fabricated number; 0 (the default) falls back to the generic
  /// label.
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg, bg) = switch (status) {
      SyncStatus.localOnly => (
        'Local only',
        Icons.cloud_off_outlined,
        AppColors.textSecondary,
        AppColors.neutralBg,
      ),
      SyncStatus.pendingCreate || SyncStatus.pendingUpdate => (
        pendingCount > 0
            ? '$pendingCount item${pendingCount == 1 ? '' : 's'} waiting'
            : 'Pending sync',
        Icons.cloud_sync_outlined,
        AppColors.warning,
        AppColors.warningBg,
      ),
      SyncStatus.pendingDelete => (
        'Pending delete',
        Icons.cloud_sync_outlined,
        AppColors.warning,
        AppColors.warningBg,
      ),
      SyncStatus.synced => (
        'Synced',
        Icons.cloud_done_outlined,
        AppColors.success,
        AppColors.successBg,
      ),
    };
    return Tooltip(
      message: label,
      child: StatusPill(
        label: label,
        icon: icon,
        foreground: fg,
        background: bg,
        dense: dense,
      ),
    );
  }
}
