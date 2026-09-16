import 'package:flutter/material.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../app_colors.dart';
import 'status_pill.dart';

/// Renders a [SyncStatus] as a subtle, understandable pill — never
/// exposing Firebase/Firestore terminology to the inspector.
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({super.key, required this.status, this.dense = false});

  final SyncStatus status;
  final bool dense;

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
        'Pending sync',
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
