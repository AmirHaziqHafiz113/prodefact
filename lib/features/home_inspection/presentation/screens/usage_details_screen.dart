import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/session_list_providers.dart';
import '../../providers/wallet_providers.dart';
import '../widgets/session_navigation.dart';

/// Where the inspector's Tokens went, in plain terms: by category (AI
/// Analysis, Storage, Processing, Other infrastructure) and by
/// inspection. Built from the server's cost records
/// (`users/{uid}/usageRecords`) — the raw Firebase/OpenAI figures behind
/// them stay server-side. See docs/token_billing.md.
class UsageDetailsScreen extends ConsumerWidget {
  const UsageDetailsScreen({super.key});

  static const routePath = '/home-inspection/wallet/usage';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(walletUsageRecordsProvider);
    final sessions = ref.watch(sessionSummariesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Usage details')),
      body: recordsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppSkeletonCardList(count: 2),
        ),
        error: (error, stackTrace) => AppErrorView(
          message: 'Could not load your usage.',
          onRetry: () => ref.invalidate(walletUsageRecordsProvider),
        ),
        data: (records) {
          if (records.isEmpty) {
            return const AppEmptyView(
              icon: Icons.pie_chart_outline,
              title: 'No usage yet',
              message:
                  'Each AI analysis records what it used here — by '
                  'category and by inspection.',
            );
          }
          final total = records.fold<int>(0, (s, r) => s + r.tokensCharged);
          final categories = [
            (
              'AI Analysis',
              Icons.auto_awesome,
              AppColors.primary,
              records.fold<int>(0, (s, r) => s + r.aiAnalysisTokens),
            ),
            (
              'Storage',
              Icons.cloud_outlined,
              AppColors.info,
              records.fold<int>(0, (s, r) => s + r.storageTokens),
            ),
            (
              'Processing',
              Icons.memory_outlined,
              AppColors.plumbing,
              records.fold<int>(0, (s, r) => s + r.processingTokens),
            ),
            (
              'Other infrastructure',
              Icons.dns_outlined,
              AppColors.textSecondary,
              records.fold<int>(0, (s, r) => s + r.otherTokens),
            ),
          ];
          final byInspection =
              groupBy(
                records,
                (UsageRecordSummary r) => r.inspectionId ?? '',
              ).entries.toList()..sort(
                (a, b) => b.value
                    .fold<int>(0, (s, r) => s + r.tokensCharged)
                    .compareTo(
                      a.value.fold<int>(0, (s, r) => s + r.tokensCharged),
                    ),
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Text(
                records.length >= 100
                    ? 'Your last 100 operations'
                    : '${records.length} '
                          'operation${records.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total used',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatTokens(total),
                          key: const ValueKey('usage-total'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Text(
                        '≈ ${tokensAsMyr(total)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: AppSpacing.xl),
                      for (final (label, icon, color, tokens) in categories)
                        _CategoryRow(
                          label: label,
                          icon: icon,
                          color: color,
                          tokens: tokens,
                          fraction: total == 0 ? 0 : tokens / total,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'By inspection'),
              AppGroupedList(
                children: [
                  for (final entry in byInspection)
                    ListTile(
                      key: ValueKey('usage-inspection-${entry.key}'),
                      leading: const Icon(Icons.home_work_outlined),
                      title: Text(
                        _inspectionTitle(entry.key, sessions),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${entry.value.length} '
                        'analys${entry.value.length == 1 ? 'is' : 'es'}',
                      ),
                      trailing: Text(
                        formatTokenCount(
                          entry.value.fold<int>(
                            0,
                            (s, r) => s + r.tokensCharged,
                          ),
                        ),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Tokens cover ProDefact\'s running costs for each operation '
                '— AI analysis, storing your photos, processing and other '
                'infrastructure — plus a fixed 100% markup. '
                '1,000,000 Tokens = RM1.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  String _inspectionTitle(
    String inspectionId,
    List<InspectionSessionSummary> sessions,
  ) {
    if (inspectionId.isEmpty) return 'Other';
    final summary = sessions.firstWhereOrNull((s) => s.id == inspectionId);
    return summary == null
        ? 'Inspection not on this device'
        : summaryTitle(summary);
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.tokens,
    required this.fraction,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int tokens;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                formatTokenCount(tokens),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.surfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
