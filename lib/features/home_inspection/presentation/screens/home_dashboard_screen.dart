import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/session_list_providers.dart';
import '../../providers/wallet_providers.dart';
import 'inspection_sessions_screen.dart';
import 'property_type_selection_screen.dart';
import 'wallet_screen.dart';

/// The Home tab: a compact commercial/progress overview — real Credits
/// balance and aggregate physical/AI/review progress across active
/// inspections — with inspection work still the primary entry point
/// (New Inspection stays one tap away). Every figure here comes from
/// the same counts the Inspections list and Wallet screen already
/// show; nothing is fabricated for this dashboard. See
/// docs/commercial_model.md ("Home/Wallet compact commercial UX").
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  static const routePath = '/home-inspection/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(sessionSummariesProvider);
    final balanceAsync = ref.watch(walletBalanceProvider);
    final cacheAsync = ref.watch(walletCacheProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _WalletSummaryCard(
              balanceAsync: balanceAsync,
              cacheAsync: cacheAsync,
              onTap: () => context.go(WalletScreen.routePath),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSectionHeader(title: 'Inspection progress'),
            const SizedBox(height: AppSpacing.md),
            summariesAsync.when(
              loading: () => const AppLoadingView(),
              error: (error, stackTrace) => AppErrorView(
                message: 'Could not load your inspections.',
                onRetry: () => ref.invalidate(sessionSummariesProvider),
              ),
              data: (sessions) => _ProgressRings(sessions: sessions),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () =>
                  context.push(PropertyTypeSelectionScreen.routePath),
              icon: const Icon(Icons.add),
              label: const Text('New Inspection'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => context.go(InspectionSessionsScreen.routePath),
              child: const Text('View all inspections'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.balanceAsync,
    required this.cacheAsync,
    required this.onTap,
  });

  final AsyncValue<int> balanceAsync;
  final AsyncValue<WalletCache?> cacheAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedBalance =
        balanceAsync.value ?? cacheAsync.value?.balanceCredits;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Credits',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      resolvedBalance == null
                          ? (balanceAsync.hasError ? 'Unavailable' : 'Loading…')
                          : '$resolvedBalance Credits',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRings extends StatelessWidget {
  const _ProgressRings({required this.sessions});

  final List<InspectionSessionSummary> sessions;

  @override
  Widget build(BuildContext context) {
    final active = sessions.where((s) => !s.isComplete).toList();

    if (active.isEmpty) {
      return const AppEmptyView(
        icon: Icons.fact_check_outlined,
        title: 'No active inspections.',
        message: 'Start a new inspection to see progress here.',
      );
    }

    final physicalDone = active
        .where((s) => s.status != InspectionStatus.inProgress)
        .length;

    final totalEligible = active.fold<int>(
      0,
      (sum, s) => sum + s.aiEligibleFindingsCount,
    );
    final totalProcessed = active.fold<int>(
      0,
      (sum, s) => sum + s.aiProcessedFindingsCount,
    );
    final totalPendingReview = active.fold<int>(
      0,
      (sum, s) => sum + s.aiPendingReviewCount,
    );
    final totalReviewed = totalProcessed - totalPendingReview;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        AppRingProgress(
          value: active.isEmpty ? 0 : physicalDone / active.length,
          label: 'Physical\n$physicalDone of ${active.length}',
          color: AppColors.accent,
        ),
        AppRingProgress(
          value: totalEligible == 0 ? 0 : totalProcessed / totalEligible,
          label: 'AI Analysed\n$totalProcessed of $totalEligible',
          color: AppColors.info,
        ),
        AppRingProgress(
          value: totalProcessed == 0 ? 0 : totalReviewed / totalProcessed,
          label: 'Reviewed\n$totalReviewed of $totalProcessed',
          color: AppColors.success,
        ),
      ],
    );
  }
}
