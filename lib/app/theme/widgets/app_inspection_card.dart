import 'package:flutter/material.dart';

import '../../../core/inspection/entities/sync_status.dart';
import '../app_colors.dart';
import '../app_metrics.dart';
import 'app_property_illustration.dart';
import 'app_property_photo.dart';
import 'sync_status_pill.dart';

/// One property/inspection job on the Inspections list: the residence
/// photo (or drawn illustration), title, address, date, a progress bar,
/// finding and unresolved counts, one status chip, and sync state when
/// it matters. Built from caller-supplied values so this design-system
/// widget never depends on feature-layer status enums.
class AppInspectionCard extends StatelessWidget {
  const AppInspectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.illustrationKind,
    required this.statusPill,
    required this.onTap,
    this.photoPath,
    this.dateLabel,
    this.progress,
    this.progressLabel,
    this.findingsCount = 0,
    this.unresolvedCount = 0,
    this.syncStatus,
    this.pendingSyncCount = 0,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final AppPropertyIllustrationKind illustrationKind;
  final String? photoPath;

  /// The session's status chip, built by the caller.
  final Widget statusPill;
  final VoidCallback onTap;

  /// "9 Oct 2026" — the inspection date (or creation date).
  final String? dateLabel;

  /// Real progress (0.0–1.0) and its label; null hides the bar rather
  /// than showing a fabricated 0%.
  final double? progress;
  final String? progressLabel;

  final int findingsCount;

  /// Findings waiting on the inspector (pending review or failed).
  final int unresolvedCount;

  /// The session's sync state (null hides it).
  final SyncStatus? syncStatus;
  final int pendingSyncCount;

  /// An overflow menu.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPropertyPhoto(
                photoPath: photoPath,
                kind: illustrationKind,
                width: 76,
                height: 76,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        statusPill,
                        if (dateLabel != null)
                          _Meta(icon: Icons.event_outlined, text: dateLabel!),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: 2,
                      children: [
                        if (progressLabel != null)
                          _Meta(icon: Icons.timeline, text: progressLabel!),
                        _Meta(
                          icon: Icons.photo_camera_outlined,
                          text:
                              '$findingsCount finding'
                              '${findingsCount == 1 ? '' : 's'}',
                        ),
                        if (unresolvedCount > 0)
                          _Meta(
                            icon: Icons.help_outline,
                            text: '$unresolvedCount unresolved',
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    if (syncStatus != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SyncStatusPill(
                        status: syncStatus!,
                        dense: true,
                        pendingCount: pendingSyncCount,
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
