import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/session_list_providers.dart';
import '../widgets/session_navigation.dart';
import '../widgets/session_status_presentation.dart';

/// The Review tab: every inspection with findings waiting on the
/// inspector (a pending AI suggestion or a failed analysis — see
/// `attentionSessionsProvider`). Tapping one opens that inspection's AI
/// Review, which lists only the findings that need a decision. Nothing
/// else lives here, so it is an inbox, not another inspections list.
class ReviewInboxScreen extends ConsumerWidget {
  const ReviewInboxScreen({super.key});

  static const routePath = '/home-inspection/review-inbox';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(sessionSummariesProvider);
    final items = ref.watch(attentionSessionsProvider);
    final totalFindings = items.fold<int>(
      0,
      (sum, s) => sum + s.aiPendingReviewCount + s.aiFailedFindingsCount,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(sessionSummariesProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              120,
            ),
            children: [
              Text('Review', style: Theme.of(context).textTheme.headlineMedium),
              Text(
                items.isEmpty
                    ? 'Findings that need your decision appear here.'
                    : '$totalFindings finding${totalFindings == 1 ? '' : 's'} '
                          'across ${items.length} '
                          'inspection${items.length == 1 ? '' : 's'} '
                          '${totalFindings == 1 ? 'needs' : 'need'} you.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              summariesAsync.when(
                loading: () => const AppSkeletonCardList(count: 2),
                error: (error, stackTrace) => AppErrorView(
                  message: 'Could not load your inspections.',
                  onRetry: () => ref.invalidate(sessionSummariesProvider),
                ),
                data: (_) => items.isEmpty
                    ? const AppEmptyView(
                        icon: Icons.task_alt,
                        title: "You're all caught up",
                        message:
                            'When AI is unsure about a finding, or an '
                            'analysis fails, it will wait for you here.',
                      )
                    : Column(
                        children: [
                          for (final summary in items)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _ReviewInboxCard(summary: summary),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewInboxCard extends ConsumerWidget {
  const _ReviewInboxCard({required this.summary});

  final InspectionSessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = summary.aiPendingReviewCount;
    final failed = summary.aiFailedFindingsCount;
    return Card(
      key: ValueKey('review-inbox-${summary.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => resumeAndOpenReview(context, ref, summary.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              AppPropertyPhoto(
                photoPath: summary.coverPhotoPath,
                kind: illustrationKindFor(summary.assetTypeId),
                width: 56,
                height: 56,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summaryTitle(summary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      [
                        if (summary.unitNumber?.isNotEmpty == true)
                          'Unit ${summary.unitNumber}',
                        'Updated ${formatRelativeTime(summary.updatedAt)}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (pending > 0)
                          AppStatusChip(
                            status: AppStatus.needsReview,
                            label: '$pending to review',
                          ),
                        if (failed > 0)
                          AppStatusChip(
                            status: AppStatus.failed,
                            label: '$failed failed',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
