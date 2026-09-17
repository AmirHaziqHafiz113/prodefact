import 'package:flutter/material.dart';

import '../../../core/inspection/entities/sync_status.dart';
import '../app_colors.dart';
import '../app_metrics.dart';
import 'app_mini_progress_line.dart';
import 'app_property_illustration.dart';
import 'sync_status_pill.dart';

/// A substantially redesigned inspection/property row — replaces a
/// plain text-stacked list item with: a property illustration, a
/// coloured status-accent edge, and (in full mode) three compact real
/// progress indicators (Physical/AI/Review) plus a sync pill. Used by
/// both the Inspections list (full) and Home's recent-inspections list
/// (compact — no progress bars, no overflow menu) so the two screens
/// share one visual language for "a property" instead of two
/// different ad hoc row designs.
class AppInspectionCard extends StatelessWidget {
  const AppInspectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.illustrationKind,
    required this.statusPill,
    required this.accentColor,
    required this.onTap,
    this.syncStatus,
    this.pendingSyncCount = 0,
    this.aiFraction,
    this.aiFractionLabel,
    this.reviewFraction,
    this.reviewFractionLabel,
    this.physicalComplete,
    this.trailing,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final AppPropertyIllustrationKind illustrationKind;

  /// The session's status pill — built by the caller (e.g.
  /// `SessionLifecyclePill`), so this shared design-system widget
  /// never depends on the feature-layer `InspectionStatus` enum or its
  /// label/icon/color mapping.
  final Widget statusPill;

  /// The colour behind [statusPill] — reused for the row's left accent
  /// edge so status is visible before reading any text.
  final Color accentColor;
  final VoidCallback onTap;

  final SyncStatus? syncStatus;
  final int pendingSyncCount;

  /// Real AI-processed fraction (0.0–1.0) and its "X/Y" label — null
  /// hides the row entirely rather than showing a fabricated 0%.
  final double? aiFraction;
  final String? aiFractionLabel;
  final double? reviewFraction;
  final String? reviewFractionLabel;

  /// Whether physical inspection is complete — a real, if coarse,
  /// binary fact from the session's own lifecycle status (a per-area
  /// fraction isn't available at list-summary granularity without an
  /// expensive per-card detail load — see `InspectionSessionSummary`'s
  /// own doc comment on why it deliberately omits that). Null hides
  /// the row.
  final bool? physicalComplete;

  /// An overflow menu or other trailing action — omitted in [dense]
  /// mode (Home's recent list has no per-row actions).
  final Widget? trailing;

  /// Compact mode for Home's recent-inspections list: illustration,
  /// title/subtitle, and a status pill only — no progress bars, no
  /// sync pill, no trailing action.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A coloured status-accent edge — the row's status is
              // visible even at a glance/scroll, before reading text.
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(
                    dense ? AppSpacing.md : AppSpacing.lg,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppPropertyIllustration(
                        kind: illustrationKind,
                        size: dense ? 48 : 56,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                statusPill,
                              ],
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            if (!dense) ...[
                              const SizedBox(height: AppSpacing.sm),
                              if (physicalComplete != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: AppMiniProgressLine(
                                    label: 'Phys',
                                    value: physicalComplete! ? 1 : 0,
                                    fractionLabel: physicalComplete!
                                        ? 'Complete'
                                        : 'In progress',
                                    color: AppColors.primary,
                                  ),
                                ),
                              if (aiFraction != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: AppMiniProgressLine(
                                    label: 'AI',
                                    value: aiFraction!,
                                    fractionLabel: aiFractionLabel ?? '',
                                    color: AppColors.info,
                                  ),
                                ),
                              if (reviewFraction != null)
                                AppMiniProgressLine(
                                  label: 'Rev',
                                  value: reviewFraction!,
                                  fractionLabel: reviewFractionLabel ?? '',
                                  color: AppColors.plumbing,
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
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        trailing!,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
