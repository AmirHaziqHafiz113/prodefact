import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/billing/billing_providers.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../providers/session_list_providers.dart';
import '../../providers/user_profile_providers.dart';
import '../../providers/wallet_providers.dart';
import '../widgets/attention_sheet.dart';
import 'house_pass_screen.dart';
import 'profile_screen.dart';
import 'top_up_screen.dart';

/// The Wallet tab: real Credits balance, this-month usage stats, a
/// real-data usage-over-time graph, a human-readable activity feed,
/// and a plain-language explanation of the two real commercial modes
/// (Flex Credits / House Pass) — see docs/commercial_model.md. Nothing
/// here ever computes a price or grants Credits itself.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  static const routePath = '/home-inspection/wallet';

  final _pricingKey = const _PricingScrollKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final cacheAsync = ref.watch(walletCacheProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);
    final configAsync = ref.watch(commercialConfigProvider);
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final attentionCount = ref.watch(attentionSessionsProvider).length;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletBalanceProvider);
            ref.invalidate(walletTransactionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppTopBar(
                attentionCount: attentionCount,
                onAttentionTap: () => showAttentionSheet(context, ref),
                displayName: profileAsync.value?.inspectorName,
                email: authState.value?.email,
                onAvatarTap: () => context.push(ProfileScreen.routePath),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Wallet', style: Theme.of(context).textTheme.headlineMedium),
              Text(
                'Manage your AI credits and usage.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              _BalanceCard(
                balanceAsync: balanceAsync,
                cacheAsync: cacheAsync,
                creditsPerMyr: configAsync.value?.creditsPerMyr,
                onTopUp: () => context.push(TopUpScreen.routePath),
                onViewPricing: () => Scrollable.ensureVisible(
                  _pricingKey.currentContext ?? context,
                  duration: const Duration(milliseconds: 400),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              configAsync.maybeWhen(
                data: (config) {
                  final balance =
                      balanceAsync.value ?? cacheAsync.value?.balanceCredits;
                  if (balance == null ||
                      balance >= config.lowBalanceThresholdCredits) {
                    return const SizedBox.shrink();
                  }
                  return const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppInlineWarningBanner(
                      message:
                          'Your Credits balance is low. AI analysis will '
                          'ask you to top up before it runs — physical '
                          'inspection is never affected.',
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(title: 'Usage summary'),
              transactionsAsync.when(
                loading: () => const AppSkeletonCardList(count: 1),
                error: (error, stackTrace) => AppErrorView(
                  message: 'Could not load your wallet activity.',
                  onRetry: () => ref.invalidate(walletTransactionsProvider),
                ),
                data: (transactions) =>
                    _UsageSummary(transactions: transactions),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSectionHeader(title: 'Recent activity'),
              transactionsAsync.maybeWhen(
                data: (transactions) => transactions.isEmpty
                    ? const AppEmptyView(
                        icon: Icons.receipt_long_outlined,
                        title: 'No activity yet.',
                      )
                    : AppGroupedList(
                        children: [
                          for (final transaction in transactions)
                            _ActivityRow(transaction: transaction),
                        ],
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _HousePassPurchaseSection(),
              const SizedBox(height: AppSpacing.xl),
              KeyedSubtree(key: _pricingKey, child: const _PricingExplainer()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a House Pass is bought for an inspection — outside field work
/// (QA #23). Once a pass is active the backend applies it to that
/// inspection's AI analysis automatically; inspectors never pick a
/// billing mechanism while recording findings.
class _HousePassPurchaseSection extends ConsumerWidget {
  const _HousePassPurchaseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionSummariesProvider).value ?? const [];
    final open = sessions
        .where((s) => s.status != InspectionStatus.reported)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'House Pass',
          subtitle:
              'Covers AI for one inspection. Applied automatically once '
              'active.',
        ),
        if (open.isEmpty)
          Text(
            'Start an inspection to buy a House Pass for it.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          AppGroupedList(
            children: [
              for (final session in open)
                ListTile(
                  key: ValueKey('house-pass-${session.id}'),
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(
                    session.propertyTitle ?? session.unitNumber ?? 'Inspection',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: session.unitNumber == null
                      ? null
                      : Text('Unit ${session.unitNumber}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '${HousePassScreen.routePath}/${session.id}',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A stable key so "View Pricing" can scroll straight to the pricing
/// explainer at the bottom of the list, instead of a fake/dead button.
class _PricingScrollKey extends GlobalObjectKey {
  const _PricingScrollKey() : super('wallet_pricing_explainer');
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balanceAsync,
    required this.cacheAsync,
    required this.creditsPerMyr,
    required this.onTopUp,
    required this.onViewPricing,
  });

  final AsyncValue<int> balanceAsync;
  final AsyncValue<WalletCache?> cacheAsync;

  /// Null only while `commercialConfigProvider` hasn't resolved yet —
  /// the RM equivalent is simply omitted until then, never guessed.
  final int? creditsPerMyr;
  final VoidCallback onTopUp;
  final VoidCallback onViewPricing;

  @override
  Widget build(BuildContext context) {
    // Prefer the real, fresh balance; fall back to the local display
    // cache only while that's still loading or unavailable — never the
    // other way around (see docs/commercial_model.md).
    final resolvedBalance =
        balanceAsync.value ?? cacheAsync.value?.balanceCredits;
    final isStale = balanceAsync.value == null && resolvedBalance != null;

    return AppHeroCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI CREDITS',
                  style: TextStyle(
                    color: AppColors.onHeroSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                if (balanceAsync.isLoading && resolvedBalance == null)
                  const SizedBox(
                    height: 32,
                    width: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                else if (balanceAsync.hasError && resolvedBalance == null)
                  const Text(
                    'Could not load your balance.',
                    style: TextStyle(color: AppColors.onHero),
                  )
                else
                  AppAnimatedNumber(
                    value: resolvedBalance!,
                    suffix: ' credits',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.onHero,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (resolvedBalance != null &&
                    creditsPerMyr != null &&
                    creditsPerMyr! > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '≈ RM${(resolvedBalance / creditsPerMyr!).toStringAsFixed(2)} '
                    '· RM${(1 / creditsPerMyr!).toStringAsFixed(2)} / credit',
                    style: const TextStyle(
                      color: AppColors.onHeroSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (isStale)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Last known balance — refreshing…',
                      style: TextStyle(
                        color: AppColors.onHeroSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                        ),
                        onPressed: onTopUp,
                        icon: const Icon(Icons.add_card_outlined),
                        label: const Text('Top Up'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        onPressed: onViewPricing,
                        icon: const Icon(Icons.bar_chart_outlined),
                        label: const Text('View Pricing'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageSummary extends StatelessWidget {
  const _UsageSummary({required this.transactions});

  final List<WalletTransactionSummary> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = transactions.where(
      (t) => t.createdAt.year == now.year && t.createdAt.month == now.month,
    );
    final spent = thisMonth
        .where((t) => t.direction == LedgerDirection.debit)
        .fold<int>(0, (sum, t) => sum + t.amountCredits);
    final analysisCount = thisMonth
        .where((t) => t.type == WalletTransactionType.usage)
        .length;
    final avgPerAnalysis = analysisCount == 0 ? 0 : spent / analysisCount;

    // Real Credits spent per day over the last 7 days — never a fake
    // or interpolated series.
    final days = List.generate(
      7,
      (i) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i)),
    );
    final points = [
      for (final day in days)
        AppBarChartPoint(
          label: _weekdayLabel(day.weekday),
          value: transactions
              .where(
                (t) =>
                    t.direction == LedgerDirection.debit &&
                    t.createdAt.year == day.year &&
                    t.createdAt.month == day.month &&
                    t.createdAt.day == day.day,
              )
              .fold<int>(0, (sum, t) => sum + t.amountCredits)
              .toDouble(),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.receipt_long_outlined,
                    value: '$spent',
                    label: 'Credits used',
                    caption: 'This month',
                    dense: true,
                  ),
                ),
                const SizedBox(
                  height: 48,
                  child: VerticalDivider(width: AppSpacing.lg),
                ),
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.smart_toy_outlined,
                    value: '$analysisCount',
                    label: 'Analyses run',
                    caption: 'This month',
                    iconColor: AppColors.info,
                    dense: true,
                  ),
                ),
                const SizedBox(
                  height: 48,
                  child: VerticalDivider(width: AppSpacing.lg),
                ),
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.insights_outlined,
                    value: avgPerAnalysis.toStringAsFixed(1),
                    label: 'Avg. / analysis',
                    caption: 'Credits',
                    iconColor: AppColors.plumbing,
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Credit usage',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Last 7 days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppBarChart(
              points: points,
              emptyMessage: 'No usage in the last 7 days.',
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayLabel(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}

/// One row in the grouped transaction list (§9/§19) — the list itself
/// is the container (`AppGroupedList`), not each individual row, so a
/// long activity feed reads as one unit rather than a stack of cards.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.transaction});

  final WalletTransactionSummary transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.direction == LedgerDirection.credit;
    final (icon, color) = switch (transaction.type) {
      WalletTransactionType.topup => (Icons.add, AppColors.success),
      WalletTransactionType.usage => (Icons.remove, AppColors.danger),
      WalletTransactionType.reservation => (
        Icons.lock_clock_outlined,
        AppColors.textMuted,
      ),
      WalletTransactionType.reservationRelease => (
        Icons.refresh,
        AppColors.success,
      ),
      WalletTransactionType.refund => (
        Icons.replay_outlined,
        AppColors.success,
      ),
      WalletTransactionType.adjustment => (
        Icons.tune_outlined,
        AppColors.textMuted,
      ),
      WalletTransactionType.housePassPurchase => (
        Icons.verified_outlined,
        AppColors.primary,
      ),
      WalletTransactionType.unknown => (
        Icons.receipt_long_outlined,
        AppColors.textMuted,
      ),
    };

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isCredit ? AppColors.successBg : AppColors.dangerBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(transaction.description),
      subtitle: Text(_formatDate(transaction.createdAt)),
      trailing: transaction.amountCredits == 0
          ? null
          : Text(
              '${isCredit ? '+' : '-'}${transaction.amountCredits}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isCredit ? AppColors.success : AppColors.textPrimary,
              ),
            ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

/// A plain-language, real-business-rule explanation of the two
/// commercial modes — informational only (the actual choice happens
/// once, in the New Inspection wizard's Plan step); never restates a
/// mockup's illustrative subscription pricing, since House Pass is a
/// fixed RM30-per-property product, not a monthly plan.
class _PricingExplainer extends ConsumerWidget {
  const _PricingExplainer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(commercialConfigProvider);
    return configAsync.maybeWhen(
      data: (config) {
        final flexInfo = config.aiLevels.isEmpty ? null : config.aiLevels.first;
        return Card(
          color: AppColors.surfaceAlt,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose the right plan for you',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Flexible options for every inspector.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PlanTile(
                        icon: Icons.bolt_outlined,
                        title: 'Flex Credits',
                        description: 'Pay as you go. No commitment.',
                        priceLine: flexInfo == null
                            ? null
                            : 'RM${(1 / config.creditsPerMyr).toStringAsFixed(2)} / credit',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _PlanTile(
                        icon: Icons.home_outlined,
                        title: 'House Pass',
                        description: 'One fixed price for the whole property.',
                        priceLine:
                            'RM${config.housePass.priceMyr.toStringAsFixed(0)} / property',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.priceLine,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? priceLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          if (priceLine != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              priceLine!,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}
